import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flipbin/providers/scanner_provider.dart';
import 'package:flipbin/utils/proxied_image_url.dart';

/// Screen providing live camera barcode scanning with manual UPC lookup fallback.
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final TextEditingController _manualController = TextEditingController();

  /// On web, browsers require a user gesture before getUserMedia.
  /// Keep autoStart:false on web and start from the Enable Camera button —
  /// but only AFTER MobileScanner is mounted (controller.attach).
  late final MobileScannerController _scannerController =
      MobileScannerController(
    // unrestricted = lowest latency to first decode on web (BarcodeDetector /
    // zxing-wasm). noDuplicates still filters repeats via our provider gen.
    detectionSpeed: DetectionSpeed.unrestricted,
    facing: CameraFacing.back,
    autoStart: !kIsWeb,
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

  bool _cameraStarted = !kIsWeb;
  bool _startingCamera = false;
  String? _cameraStartError;

  /// Debounce identical codes so a held barcode does not spam lookups.
  String? _lastHandledCode;
  DateTime? _lastHandledAt;

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
  }

  @override
  void dispose() {
    _barcodeSubscription?.cancel();
    _barcodeSubscription = null;
    _manualController.dispose();
    // We own the controller (autoStart may be false); dispose explicitly.
    unawaited(_scannerController.dispose());
    super.dispose();
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

      // Keep manual field in sync so Look Up and auto path share the same UPC.
      if (_manualController.text != raw) {
        _manualController.text = raw;
      }
      ref.read(scannerProvider.notifier).onBarcodeDetected(raw);
      break;
    }
  }

  Future<void> _enableCamera() async {
    if (_startingCamera || _cameraStarted) return;
    setState(() {
      _startingCamera = true;
      _cameraStartError = null;
    });
    try {
      // MobileScanner must already be mounted so controller.attach() ran;
      // start() waits briefly for attach on mobile_scanner 7.x.
      await _scannerController.start();
      if (!mounted) return;
      setState(() {
        _cameraStarted = true;
        _startingCamera = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _startingCamera = false;
        _cameraStartError = e.toString();
      });
    }
  }

  void _onManualLookup() {
    final upc = _manualController.text.trim();
    if (upc.isNotEmpty) {
      // Same pipeline as auto-detect.
      ref.read(scannerProvider.notifier).onBarcodeDetected(upc);
    }
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
    );
  }

  Widget _buildViewfinder(BuildContext context) {
    // Always keep MobileScanner mounted so attach() completes before start().
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _scannerController,
          // Handling is via controller.barcodes subscription in initState.
          fit: BoxFit.cover,
          errorBuilder: (context, error) {
            return _buildCameraPlaceholder(
              icon: Icons.videocam_off,
              title: 'Camera Unavailable or Permission Denied',
              subtitle:
                  'Please grant camera permission in your browser or enter the barcode manually below.',
              action: ElevatedButton.icon(
                onPressed: _startingCamera ? null : _enableCamera,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            );
          },
        ),
        if (_cameraStarted && _cameraStartError == null)
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
        if (_cameraStartError != null)
          _buildCameraPlaceholder(
            icon: Icons.videocam_off,
            title: 'Camera Unavailable or Permission Denied',
            subtitle:
                'Please grant camera permission in your browser or enter the barcode manually below.\n$_cameraStartError',
            action: ElevatedButton.icon(
              onPressed: _startingCamera
                  ? null
                  : () {
                      setState(() => _cameraStartError = null);
                      _enableCamera();
                    },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          )
        else if (kIsWeb && !_cameraStarted)
          _buildCameraPlaceholder(
            icon: Icons.photo_camera,
            title: 'Camera ready',
            subtitle:
                'Tap Enable Camera to grant permission and start scanning barcodes. You can also enter a UPC manually below.',
            action: ElevatedButton.icon(
              onPressed: _startingCamera ? null : _enableCamera,
              icon: _startingCamera
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.videocam),
              label: Text(_startingCamera ? 'Starting…' : 'Enable Camera'),
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
        title: const Text('Barcode Scanner'),
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
                      decoration: const InputDecoration(
                        hintText: 'Enter UPC manually...',
                        prefixIcon: Icon(Icons.keyboard),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      onSubmitted: (_) => _onManualLookup(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _onManualLookup,
                    child: const Text('Look Up'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (scanState.isLookingUp)
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
            else if (scanState.result != null)
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
                                  // Prefer <img> on web: cover CDNs often omit CORS,
                                  // which breaks CanvasKit byte-fetch Image.network.
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
                                onPressed: () {
                                  context.go('/inventory/new');
                                },
                                icon: const Icon(Icons.add_box),
                                label: const Text('Add to Inventory'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  context.go('/expenses/new');
                                },
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
            else if (scanState.error != null || scanState.rawBarcode != null)
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
                      onPressed: () => context.go('/inventory/new'),
                      child: const Text('Add Manually to Inventory'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
