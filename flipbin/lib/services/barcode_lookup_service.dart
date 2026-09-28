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

/// Service to lookup product information by barcode with local cache.
///
/// Cascade:
/// 1. Local SQLite cache
/// 2. Same-origin `/api/upc` proxy (web) or direct UPCitemdb trial (non-web)
/// 3. null / not found
///
/// Open Food Facts and Open Products Facts are intentionally not used.
class BarcodeLookupService {
  final Dio _dio;
  final BarcodeCacheDao _cacheDao;

  /// When true, call same-origin `/api/upc` (Vercel serverless proxy).
  /// Defaults to [kIsWeb]. Override in tests.
  final bool useSameOriginProxy;

  /// Optional origin override for proxy URL (tests). Defaults to [Uri.base.origin].
  final String? proxyOrigin;

  BarcodeLookupService({
    required Dio dio,
    required BarcodeCacheDao cacheDao,
    bool? useSameOriginProxy,
    this.proxyOrigin,
  })  : _dio = dio,
        _cacheDao = cacheDao,
        useSameOriginProxy = useSameOriginProxy ?? kIsWeb;

  Options get _timeoutOptions => Options(
        sendTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        validateStatus: (status) =>
            status != null && status < 500, // treat 404 as handled miss
      );

  String get _proxyLookupUrl {
    final origin = proxyOrigin ?? (kIsWeb ? Uri.base.origin : '');
    if (origin.isEmpty) {
      return '/api/upc';
    }
    return '$origin/api/upc';
  }

  /// Looks up barcode in local cache, then UPCitemdb (via proxy on web).
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

    if (useSameOriginProxy) {
      return _lookupViaProxy(barcode);
    }
    return _lookupUpcItemDb(barcode);
  }

  /// Same-origin Vercel function: GET /api/upc?upc=...
  Future<BarcodeResult?> _lookupViaProxy(String barcode) async {
    try {
      final response = await _dio.get(
        _proxyLookupUrl,
        queryParameters: {'upc': barcode},
        options: _timeoutOptions,
      );

      if (response.statusCode != 200 || response.data is! Map) {
        return null;
      }

      final map = Map<String, dynamic>.from(response.data as Map);
      final productName = map['productName'] as String?;
      if (productName == null || productName.trim().isEmpty) {
        return null;
      }

      final description = map['description'] as String?;
      final imageUrl = map['imageUrl'] as String?;
      final category = map['category'] as String?;
      final source = (map['source'] as String?) ?? 'UPCitemdb';

      await _cacheDao.insertOrUpdate(
        BarcodeCacheEntriesCompanion.insert(
          barcode: barcode,
          productName: Value(productName),
          description: Value(description),
          imageUrl: Value(imageUrl),
          category: Value(category),
          source: source,
          fetchedAt: DateTime.now(),
        ),
      );

      return BarcodeResult(
        barcode: barcode,
        productName: productName,
        description: description,
        imageUrl: imageUrl,
        category: category,
        source: source,
      );
    } catch (_) {
      return null;
    }
  }

  /// Direct UPCitemdb trial API (non-web / native). Browser CORS blocks this
  /// from arbitrary origins; web uses [_lookupViaProxy] instead.
  Future<BarcodeResult?> _lookupUpcItemDb(String barcode) async {
    try {
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
}

/// Riverpod provider for [BarcodeLookupService].
final barcodeLookupServiceProvider = Provider<BarcodeLookupService>((ref) {
  final db = ref.watch(databaseProvider);
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {
        'User-Agent': 'FlipBin/1.0 (https://github.com/pixelbit78/flip-bin)',
      },
    ),
  );
  return BarcodeLookupService(
    dio: dio,
    cacheDao: db.barcodeCacheDao,
  );
});
