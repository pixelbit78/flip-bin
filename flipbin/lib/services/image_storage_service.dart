import 'dart:typed_data';

/// Service for storing and retrieving images.
/// On web, uses IndexedDB. For tests and non-web, uses in-memory map.
class ImageStorageService {
  final Map<String, Uint8List> _store = {};

  /// Save image bytes under the given key.
  Future<void> saveImage(String key, Uint8List bytes) async {
    _store[key] = bytes;
  }

  /// Load image bytes for the given key, or null if not found.
  Future<Uint8List?> loadImage(String key) async {
    return _store[key];
  }

  /// Delete image for the given key.
  Future<void> deleteImage(String key) async {
    _store.remove(key);
  }
}
