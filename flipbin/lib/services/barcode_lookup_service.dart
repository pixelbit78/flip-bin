import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/providers/database_provider.dart';

/// Data class representing product details found via barcode lookup.
class BarcodeResult {
  final String barcode;
  final String? productName;
  final String? description;
  final String? imageUrl;
  final String? category;
  final String source;

  const BarcodeResult({
    required this.barcode,
    this.productName,
    this.description,
    this.imageUrl,
    this.category,
    required this.source,
  });
}

/// Service to lookup product information by barcode using cascading APIs with local cache.
///
/// Cascade (matches product intent for FlipBin resellers):
/// 1. Local SQLite cache
/// 2. UPCitemdb trial API (best retail coverage; may be blocked by CORS on web)
/// 3. Open Products Facts (CORS-friendly; non-food / games / electronics)
/// 4. Open Food Facts (CORS-friendly; groceries)
class BarcodeLookupService {
  final Dio _dio;
  final BarcodeCacheDao _cacheDao;

  BarcodeLookupService({
    required Dio dio,
    required BarcodeCacheDao cacheDao,
  })  : _dio = dio,
        _cacheDao = cacheDao;

  Options get _timeoutOptions => Options(
        sendTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      );

  /// Looks up barcode in local cache, then cascading third-party APIs.
  Future<BarcodeResult?> lookup(String barcode) async {
    final cached = await _cacheDao.lookup(barcode);
    if (cached != null) {
      return BarcodeResult(
        barcode: cached.barcode,
        productName: cached.productName,
        description: cached.description,
        imageUrl: cached.imageUrl,
        category: cached.category,
        source: cached.source,
      );
    }

    // UPCitemdb trial API only allows CORS from upcitemdb.com, so browser
    // calls from github.io fail. Skip on web; Open*Facts send ACAO: *.
    if (!kIsWeb) {
      final fromUpcItemDb = await _lookupUpcItemDb(barcode);
      if (fromUpcItemDb != null) return fromUpcItemDb;
    }

    final fromOpenProducts = await _lookupOpenFacts(
      barcode,
      baseUrl: 'https://world.openproductsfacts.org',
      source: 'Open Products Facts',
    );
    if (fromOpenProducts != null) return fromOpenProducts;

    final fromOpenFood = await _lookupOpenFacts(
      barcode,
      baseUrl: 'https://world.openfoodfacts.org',
      source: 'Open Food Facts',
    );
    if (fromOpenFood != null) return fromOpenFood;

    return null;
  }

  Future<BarcodeResult?> _lookupUpcItemDb(String barcode) async {
    try {
      // Trial endpoint documented by UPCitemdb. Note: browser CORS only allows
      // upcitemdb.com origins, so this often fails on Flutter web and we fall
      // through to Open*Facts (which send Access-Control-Allow-Origin: *).
      final response = await _dio.get(
        'https://api.upcitemdb.com/prod/trial/lookup',
        queryParameters: {'upc': barcode},
        options: _timeoutOptions,
      );

      if (response.statusCode != 200 || response.data is! Map) return null;
      final data = response.data as Map<String, dynamic>;
      final items = data['items'];
      if (items is! List || items.isEmpty) return null;

      final item = items.first;
      if (item is! Map) return null;
      final map = Map<String, dynamic>.from(item);

      final title = (map['title'] ?? map['name']) as String?;
      if (title == null || title.trim().isEmpty) return null;

      final description = map['description'] as String?;
      String? imageUrl;
      final images = map['images'];
      if (images is List && images.isNotEmpty) {
        imageUrl = images.first?.toString();
      }
      final category = map['category'] as String?;

      await _cacheDao.insertOrUpdate(
        BarcodeCacheEntriesCompanion.insert(
          barcode: barcode,
          productName: Value(title),
          description: Value(description),
          imageUrl: Value(imageUrl),
          category: Value(category),
          source: 'UPCitemdb',
          fetchedAt: DateTime.now(),
        ),
      );

      return BarcodeResult(
        barcode: barcode,
        productName: title,
        description: description,
        imageUrl: imageUrl,
        category: category,
        source: 'UPCitemdb',
      );
    } catch (_) {
      return null;
    }
  }

  Future<BarcodeResult?> _lookupOpenFacts(
    String barcode, {
    required String baseUrl,
    required String source,
  }) async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/v0/product/$barcode.json',
        options: _timeoutOptions,
      );

      if (response.statusCode != 200 || response.data is! Map) return null;
      final data = response.data as Map<String, dynamic>;
      if (data['status'] != 1 || data['product'] is! Map) return null;

      final product = Map<String, dynamic>.from(data['product'] as Map);
      final name =
          (product['product_name'] ?? product['generic_name']) as String?;
      if (name == null || name.trim().isEmpty) return null;

      final imageUrl =
          (product['image_url'] ?? product['image_front_url']) as String?;
      final category =
          (product['categories'] ?? product['category']) as String?;

      await _cacheDao.insertOrUpdate(
        BarcodeCacheEntriesCompanion.insert(
          barcode: barcode,
          productName: Value(name),
          description: const Value(null),
          imageUrl: Value(imageUrl),
          category: Value(category),
          source: source,
          fetchedAt: DateTime.now(),
        ),
      );

      return BarcodeResult(
        barcode: barcode,
        productName: name,
        imageUrl: imageUrl,
        category: category,
        source: source,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Riverpod provider for [BarcodeLookupService].
final barcodeLookupServiceProvider = Provider<BarcodeLookupService>((ref) {
  final db = ref.watch(databaseProvider);
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {
        // Open*Facts ask for a descriptive User-Agent.
        'User-Agent': 'FlipBin/1.0 (https://github.com/pixelbit78/flip-bin)',
      },
    ),
  );
  return BarcodeLookupService(
    dio: dio,
    cacheDao: db.barcodeCacheDao,
  );
});
