import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
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
class BarcodeLookupService {
  final Dio _dio;
  final BarcodeCacheDao _cacheDao;

  BarcodeLookupService({
    required Dio dio,
    required BarcodeCacheDao cacheDao,
  })  : _dio = dio,
        _cacheDao = cacheDao;

  /// Looks up barcode in local cache, then UPC Database, then Open Food Facts.
  Future<BarcodeResult?> lookup(String barcode) async {
    // 1. Check local cache
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

    // 2. Try UPC Database API
    try {
      final upcUrl = 'https://api.upcdatabase.org/product/$barcode';
      final response = await _dio.get(
        upcUrl,
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        final title = (data['title'] ?? data['name']) as String?;
        final description = data['description'] as String?;
        String? imageUrl;
        if (data['images'] is List && (data['images'] as List).isNotEmpty) {
          imageUrl = (data['images'] as List).first as String?;
        }
        final category = data['category'] as String?;

        if (title != null && title.trim().isNotEmpty) {
          await _cacheDao.insertOrUpdate(
            BarcodeCacheEntriesCompanion.insert(
              barcode: barcode,
              productName: Value(title),
              description: Value(description),
              imageUrl: Value(imageUrl),
              category: Value(category),
              source: 'UPC Database',
              fetchedAt: DateTime.now(),
            ),
          );

          return BarcodeResult(
            barcode: barcode,
            productName: title,
            description: description,
            imageUrl: imageUrl,
            category: category,
            source: 'UPC Database',
          );
        }
      }
    } catch (_) {
      // Fall through to Open Food Facts
    }

    // 3. Try Open Food Facts API
    try {
      final offUrl = 'https://world.openfoodfacts.org/api/v0/product/$barcode.json';
      final response = await _dio.get(
        offUrl,
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        if (data['status'] == 1 && data['product'] is Map) {
          final product = data['product'] as Map<String, dynamic>;
          final name = (product['product_name'] ?? product['generic_name']) as String?;
          final imageUrl = (product['image_url'] ?? product['image_front_url']) as String?;
          final category = (product['categories'] ?? product['category']) as String?;

          if (name != null && name.trim().isNotEmpty) {
            await _cacheDao.insertOrUpdate(
              BarcodeCacheEntriesCompanion.insert(
                barcode: barcode,
                productName: Value(name),
                description: const Value(null),
                imageUrl: Value(imageUrl),
                category: Value(category),
                source: 'Open Food Facts',
                fetchedAt: DateTime.now(),
              ),
            );

            return BarcodeResult(
              barcode: barcode,
              productName: name,
              imageUrl: imageUrl,
              category: category,
              source: 'Open Food Facts',
            );
          }
        }
      }
    } catch (_) {
      // Fall through to return null
    }

    return null;
  }
}

/// Riverpod provider for [BarcodeLookupService].
final barcodeLookupServiceProvider = Provider<BarcodeLookupService>((ref) {
  final db = ref.watch(databaseProvider);
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );
  return BarcodeLookupService(
    dio: dio,
    cacheDao: db.barcodeCacheDao,
  );
});
