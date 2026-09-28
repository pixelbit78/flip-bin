import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flipbin/services/barcode_lookup_service.dart';

/// State for the barcode scanner.
class ScanState {
  final bool isScanning;
  final bool isLookingUp;
  final BarcodeResult? result;
  final String? error;
  final String? rawBarcode;

  const ScanState({
    this.isScanning = false,
    this.isLookingUp = false,
    this.result,
    this.error,
    this.rawBarcode,
  });

  ScanState copyWith({
    bool? isScanning,
    bool? isLookingUp,
    BarcodeResult? result,
    String? error,
    String? rawBarcode,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return ScanState(
      isScanning: isScanning ?? this.isScanning,
      isLookingUp: isLookingUp ?? this.isLookingUp,
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
      rawBarcode: rawBarcode ?? this.rawBarcode,
    );
  }
}

/// Notifier managing barcode scanner state with generation counter
/// to handle race conditions from rapid scans. (Review Focus #4)
class ScannerNotifier extends StateNotifier<ScanState> {
  final BarcodeLookupService _lookupService;
  int _generation = 0;

  ScannerNotifier(this._lookupService) : super(const ScanState());

  /// Called when a barcode is detected by the camera scanner.
  /// Uses a generation counter to discard stale results when a new
  /// barcode arrives while a previous lookup is still in-flight.
  void onBarcodeDetected(String barcode) {
    _generation++;
    final currentGeneration = _generation;

    state = ScanState(
      isScanning: state.isScanning,
      isLookingUp: true,
      rawBarcode: barcode,
    );

    _lookupService.lookup(barcode).then((result) {
      // Only update state if this is still the latest scan
      if (_generation == currentGeneration) {
        state = state.copyWith(
          isLookingUp: false,
          result: result,
          clearResult: result == null,
          clearError: true,
        );
      }
    }).catchError((Object error) {
      if (_generation == currentGeneration) {
        state = state.copyWith(
          isLookingUp: false,
          error: error.toString(),
          clearResult: true,
        );
      }
    });
  }

  void setScanning(bool scanning) {
    state = state.copyWith(isScanning: scanning);
  }

  void reset() {
    _generation++;
    state = const ScanState();
  }
}

/// Provider for barcode scanner state.
final scannerProvider =
    StateNotifierProvider<ScannerNotifier, ScanState>((ref) {
  final lookupService = ref.watch(barcodeLookupServiceProvider);
  return ScannerNotifier(lookupService);
});
