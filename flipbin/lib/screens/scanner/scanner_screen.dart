import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/providers/inventory_provider.dart';
import 'package:flipbin/providers/scanner_provider.dart';
import 'package:flipbin/services/barcode_lookup_service.dart';
import 'package:flipbin/services/camera_permission_store.dart';
import 'package:flipbin/utils/proxied_image_url.dart';
import 'package:flipbin/utils/web_camera_permission.dart';
import 'package:flipbin/widgets/scanner/scanner_quick_add_sheets.dart';
import 'package:flipbin/widgets/status_badge.dart';

/// Screen providing live camera barcode scanning with manual UPC lookup fallback.
///
/// When [returnBarcodeOnly] is true (Inventory search filter), a successful
/// scan or manual entry pops the route with the raw barcode string and skips
/// UPC lookup / Add to Inventory. Default false keeps the add-item flow.
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key, this.returnBarcodeOnly = false});

  /// If true, pop with the scanned barcode instead of running product lookup.
  final bool returnBarcodeOnly;

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final TextEditingController _manualController = TextEditingController();
  final CameraPermissionStore _cameraPermissionStore = CameraPermissionStore();

  /// Prefer autoStart alone. Do NOT also call start() while autoStart is
  /// initializing — that races and throws MobileScannerErrorCode.controllerInitializing.
  late final MobileScannerController _scannerController =
      MobileScannerController(
    detectionSpeed: DetectionSpeed.unrestricted,
    facing: CameraFacing.back,
    autoStart: true,
    formats: const [
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.ean8,
      BarcodeFormat.ean13,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
      BarcodeFormat.qrCode,
    ],
  );

  /// Direct subscription to the controller barcode stream (recommended path
  /// in mobile_scanner 7.x). Handles both captures and stream errors.
  StreamSubscription<BarcodeCapture>? _barcodeSubscription;

  bool _cameraStarted = false;
  bool _startingCamera = true;

  /// One-shot overlay when autoStart failed because the browser needs a
  /// user gesture to show the camera permission prompt. Disappears after grant.
  bool _needsAllowTap = false;

  /// Hard denial — show site-settings instructions, not a silent retry loop.
  bool _permissionHardDenied = false;

  String? _cameraStartError;

  /// Debounce identical codes so a held barcode does not spam lookups.
  String? _lastHandledCode;
  DateTime? _lastHandledAt;

  /// Ensures filter-only mode pops at most once per visit.
  bool _returnedOnce = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // Prefer native BarcodeDetector, fall back to zxing-wasm. Legacy
      // ZXing-js (mobile_scanner 4.x) often failed to decode clear UPC-A.
      MobileScannerPlatform.instance
          .setWebBarcodeReader(WebBarcodeReader.auto);
    }
    _barcodeSubscription = _scannerController.barcodes.listen(
      _handleBarcodeCapture,
      onError: (Object error, StackTrace stack) {
        debugPrint('Barcode stream error: $error');
      },
      cancelOnError: false,
    );
    _scannerController.addListener(_onScannerStateChanged);
  }

  @override
  void dispose() {
    _scannerController.removeListener(_onScannerStateChanged);
    _barcodeSubscription?.cancel();
    _barcodeSubscription = null;
    _manualController.dispose();
    unawaited(_scannerController.dispose());
    super.dispose();
  }

  void _onScannerStateChanged() {
    if (!mounted) return;
    final state = _scannerController.value;

    if (state.isRunning) {
      setState(() {
        _cameraStarted = true;
        _startingCamera = false;
        _needsAllowTap = false;
        _permissionHardDenied = false;
        _cameraStartError = null;
      });
      unawaited(_cameraPermissionStore.setAllowed(true));
      return;
    }

    if (state.isStarting) {
      if (!_startingCamera || _cameraStartError != null || _needsAllowTap) {
        setState(() {
          _startingCamera = true;
          _cameraStartError = null;
          _needsAllowTap = false;
        });
      }
      return;
    }

    final error = state.error;
    if (error != null && !_cameraStarted) {
      unawaited(_handleControllerError(error));
    }
  }

  Future<void> _handleControllerError(MobileScannerException error) async {
    if (!mounted) return;

    final denied = _isPermissionDenied(error);
    if (denied) {
      final permState = kIsWeb ? await queryCameraPermissionState() : null;
      if (!mounted) return;

      // Browser permanently denied → clear site-settings UX.
      if (permState == 'denied') {
        setState(() {
          _startingCamera = false;
          _cameraStarted = false;
          _needsAllowTap = false;
          _permissionHardDenied = true;
          _cameraStartError = _deniedMessage();
        });
        unawaited(_cameraPermissionStore.setAllowed(false));
        return;
      }

      // Still "prompt" (or unknown): autoStart likely blocked without a
      // user gesture. Show one-shot Allow camera; tap provides the gesture.
      setState(() {
        _startingCamera = false;
        _cameraStarted = false;
        _permissionHardDenied = false;
        _needsAllowTap = true;
        _cameraStartError = null;
      });
      return;
    }

    setState(() {
      _startingCamera = false;
      _cameraStarted = false;
      _needsAllowTap = false;
      _permissionHardDenied = false;
      _cameraStartError = _friendlyCameraError(error);
    });
  }

  bool _isPermissionDenied(Object e) {
    if (e is MobileScannerException) {
      if (e.errorCode == MobileScannerErrorCode.permissionDenied) return true;
      final msg = (e.errorDetails?.message ?? '').toLowerCase();
      if (msg.contains('notallowed') ||
          msg.contains('permission') ||
          msg.contains('denied')) {
        return true;
      }
    }
    final raw = e.toString().toLowerCase();
    return raw.contains('permission') ||
        raw.contains('notallowed') ||
        raw.contains('denied') ||
        raw.contains('notallowederror');
  }

  String _deniedMessage() {
    return 'Camera permission was denied for this site.\n\n'
        'To enable it on Chrome Android (including the installed FlipBin app):\n'
        '1. Open Chrome → tap the lock / tune icon next to the URL '
        '(or Menu → Settings → Site settings → Camera).\n'
        '2. Set Camera to Allow for flip-bin.vercel.app.\n'
        '3. Kill and reopen FlipBin — the camera will start automatically.\n\n'
        'You can also enter a UPC manually below.';
  }

  String _friendlyCameraError(Object e) {
    if (_isPermissionDenied(e)) return _deniedMessage();
    final raw = e.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('notfound') || lower.contains('no device')) {
      return 'No camera was found on this device. Enter a UPC manually below.';
    }
    // Never surface the double-start race as a user-facing failure.
    if (lower.contains('controllerinitializing') ||
        lower.contains('still initializing')) {
      return 'Camera is still starting. Please wait a moment.';
    }
    return 'Could not start the camera. Check browser permissions or enter a '
        'UPC manually below.\n$raw';
  }

  /// Manual start ONLY after autoStart already failed and the user taps.
  /// Provides the user gesture some browsers require for getUserMedia.
  Future<void> _onAllowCameraTap() async {
    if (_startingCamera || _cameraStarted) return;
    setState(() {
      _startingCamera = true;
      _needsAllowTap = false;
      _cameraStartError = null;
      _permissionHardDenied = false;
    });

    try {
      // autoStart already finished (failed). Safe to call start() once here.
      if (!_scannerController.value.isRunning &&
          !_scannerController.value.isStarting) {
        await _scannerController.start();
      }
      // Success / permission error is reflected via the controller listener.
      if (!mounted) return;
      if (!_scannerController.value.isRunning &&
          _scannerController.value.error != null) {
        await _handleControllerError(_scannerController.value.error!);
      }
    } catch (e) {
      if (!mounted) return;
      // Ignore the initializing race if somehow still in flight.
      if (e is MobileScannerException &&
          e.errorCode == MobileScannerErrorCode.controllerInitializing) {
        setState(() => _startingCamera = true);
        return;
      }
      if (_isPermissionDenied(e)) {
        await _handleControllerError(
          e is MobileScannerException
              ? e
              : MobileScannerException(
                  errorCode: MobileScannerErrorCode.permissionDenied,
                  errorDetails: MobileScannerErrorDetails(message: e.toString()),
                ),
        );
        return;
      }
      setState(() {
        _startingCamera = false;
        _cameraStartError = _friendlyCameraError(e);
      });
    }
  }

  Future<void> _openCameraHelp() async {
    final uri = Uri.parse(
      'https://support.google.com/chrome/answer/2693767?hl=en',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _returnBarcode(String code) {
    if (_returnedOnce || !mounted) return;
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;
    _returnedOnce = true;
    context.pop(trimmed);
  }

  void _handleBarcodeCapture(BarcodeCapture capture) {
    final barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;

      final now = DateTime.now();
      if (_lastHandledCode == raw &&
          _lastHandledAt != null &&
          now.difference(_lastHandledAt!) < const Duration(seconds: 2)) {
        return;
      }
      _lastHandledCode = raw;
      _lastHandledAt = now;

      if (_manualController.text != raw) {
        _manualController.text = raw;
      }
      if (widget.returnBarcodeOnly) {
        _returnBarcode(raw);
      } else {
        ref.read(scannerProvider.notifier).onBarcodeDetected(raw);
      }
      break;
    }
  }

  void _onManualLookup() {
    final upc = _manualController.text.trim();
    if (upc.isEmpty) return;
    if (widget.returnBarcodeOnly) {
      _returnBarcode(upc);
      return;
    }
    ref.read(scannerProvider.notifier).onBarcodeDetected(upc);
  }

  Widget _buildCameraPlaceholder({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      color: const Color(0xFF1E222B),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: Colors.orangeAccent),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              if (action != null) ...[
                const SizedBox(height: 16),
                action,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewfinder(BuildContext context) {
    // Always keep MobileScanner mounted so attach() completes and autoStart
    // can request getUserMedia. Overlays handle loading / allow / denied UX.
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _scannerController,
          fit: BoxFit.cover,
          errorBuilder: (context, error) {
            // Prefer our overlays; fall through only if we have nothing better.
            if (_needsAllowTap ||
                _permissionHardDenied ||
                _cameraStartError != null ||
                _startingCamera) {
              return const SizedBox.shrink();
            }
            return _buildCameraPlaceholder(
              icon: Icons.videocam_off,
              title: 'Camera Unavailable or Permission Denied',
              subtitle: _friendlyCameraError(error),
              action: TextButton.icon(
                onPressed: _onAllowCameraTap,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            );
          },
        ),
        if (_cameraStarted && _cameraStartError == null && !_needsAllowTap)
          Center(
            child: Container(
              width: 220,
              height: 140,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2.5,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        if (_permissionHardDenied || _cameraStartError != null)
          _buildCameraPlaceholder(
            icon: Icons.videocam_off,
            title: _permissionHardDenied
                ? 'Camera Permission Denied'
                : 'Camera Unavailable',
            subtitle: _cameraStartError ?? _deniedMessage(),
            action: Column(
              children: [
                TextButton.icon(
                  onPressed: _startingCamera ? null : _onAllowCameraTap,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry after enabling permission'),
                ),
                TextButton.icon(
                  onPressed: _openCameraHelp,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('How to change site settings'),
                ),
              ],
            ),
          )
        else if (_needsAllowTap)
          _buildCameraPlaceholder(
            icon: Icons.photo_camera,
            title: 'Allow camera',
            subtitle:
                'Your browser needs one tap to show the camera permission '
                'prompt. After you allow it, FlipBin will remember and '
                'auto-start next time.',
            action: ElevatedButton.icon(
              onPressed: _startingCamera ? null : _onAllowCameraTap,
              icon: _startingCamera
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.videocam),
              label: Text(_startingCamera ? 'Starting…' : 'Allow camera'),
            ),
          )
        else if (_startingCamera && !_cameraStarted)
          _buildCameraPlaceholder(
            icon: Icons.photo_camera,
            title: 'Starting camera…',
            subtitle:
                'Allow camera access if your browser asks. You can also enter a UPC manually below.',
            action: const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(scannerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.returnBarcodeOnly ? 'Scan to filter' : 'Barcode Scanner',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: _cameraStarted
                ? () => _scannerController.toggleTorch()
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: _cameraStarted
                ? () => _scannerController.switchCamera()
                : null,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 280,
              margin: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.black,
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildViewfinder(context),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _manualController,
                      decoration: InputDecoration(
                        hintText: widget.returnBarcodeOnly
                            ? 'Enter barcode to filter...'
                            : 'Enter UPC manually...',
                        prefixIcon: const Icon(Icons.keyboard),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      onSubmitted: (_) => _onManualLookup(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _onManualLookup,
                    child: Text(widget.returnBarcodeOnly ? 'Use' : 'Look Up'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!widget.returnBarcodeOnly && scanState.isLookingUp)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Looking up barcode...'),
                  ],
                ),
              )
            else if (!widget.returnBarcodeOnly && scanState.result != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Auto-detected',
                                style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'via ${scanState.result!.source}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (proxiedImageUrl(scanState.result!.imageUrl) !=
                                null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  proxiedImageUrl(scanState.result!.imageUrl)!,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  webHtmlElementStrategy:
                                      WebHtmlElementStrategy.prefer,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.image_not_supported,
                                    size: 50,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    scanState.result!.productName ??
                                        'Unknown Product',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'UPC: ${scanState.result!.barcode}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (scanState.result!.category != null)
                                    Text(
                                      'Category: ${scanState.result!.category}',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _openInventoryQuickAdd(
                                  scanState.result!,
                                ),
                                icon: const Icon(Icons.add_box),
                                label: const Text('Add to Inventory'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _openExpenseQuickAdd(
                                  scanState.result!,
                                ),
                                icon: const Icon(Icons.post_add),
                                label: const Text('Add to Expense'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (!widget.returnBarcodeOnly &&
                (scanState.error != null || scanState.rawBarcode != null))
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Icon(
                      Icons.search_off,
                      size: 40,
                      color: Colors.white38,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      scanState.error ??
                          'No product details found for UPC: ${scanState.rawBarcode}',
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        final raw = scanState.rawBarcode;
                        final scan = raw != null && raw.isNotEmpty
                            ? BarcodeResult(
                                barcode: raw,
                                source: 'manual',
                              )
                            : const BarcodeResult(
                                barcode: '',
                                source: 'manual',
                              );
                        _openInventoryQuickAdd(scan);
                      },
                      child: const Text('Add Manually to Inventory'),
                    ),
                  ],
                ),
              ),
            // Inventory matches for the current UPC (independent of catalog lookup).
            if (!widget.returnBarcodeOnly &&
                scanState.rawBarcode != null &&
                scanState.rawBarcode!.trim().isNotEmpty)
              _buildInventoryMatches(scanState.rawBarcode!.trim()),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryMatches(String barcode) {
    final matchesAsync = ref.watch(inventoryMatchesByBarcodeProvider(barcode));
    return matchesAsync.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'In your inventory (${items.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 8),
              for (final item in items) _buildInventoryMatchRow(item),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildInventoryMatchRow(InventoryItem item) {
    final dateFmt = DateFormat.yMMMd();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.itemDescription,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusBadge(status: item.status),
                      Text(
                        '\$${item.cost.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Added ${dateFmt.format(item.dateAdded)}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _saveAsSold(item),
              child: const Text('Save as sold'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openInventoryQuickAdd(BarcodeResult scan) async {
    final saved = await showScannerInventoryQuickAdd(
      context: context,
      ref: ref,
      scan: scan,
    );
    if (!mounted || !saved) return;
    ref.read(scannerProvider.notifier).reset();
    _lastHandledCode = null;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Added to inventory'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openExpenseQuickAdd(BarcodeResult scan) async {
    final saved = await showScannerExpenseQuickAdd(
      context: context,
      ref: ref,
      scan: scan,
    );
    if (!mounted || !saved) return;
    ref.read(scannerProvider.notifier).reset();
    _lastHandledCode = null;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Added to expenses'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveAsSold(InventoryItem item) async {
    try {
      await ref.read(inventoryControllerProvider).updateInventoryItem(
            item.copyWith(status: ItemStatus.sold),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Marked "${item.itemDescription}" as sold'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not mark as sold: $e')),
      );
    }
  }
}
