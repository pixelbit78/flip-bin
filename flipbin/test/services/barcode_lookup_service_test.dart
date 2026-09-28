import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/services/barcode_lookup_service.dart';

class MockDio extends Mock implements Dio {}
class MockBarcodeCacheDao extends Mock implements BarcodeCacheDao {}

void main() {
  late MockDio mockDio;
  late MockBarcodeCacheDao mockCacheDao;
  late BarcodeLookupService service;

  setUpAll(() {
    registerFallbackValue(
      BarcodeCacheEntriesCompanion.insert(
        barcode: '',
        source: '',
        fetchedAt: DateTime.now(),
      ),
    );
  });

  setUp(() {
    mockDio = MockDio();
    mockCacheDao = MockBarcodeCacheDao();
    // Default: non-web path (direct UPCitemdb), matching VM test environment.
    service = BarcodeLookupService(
      dio: mockDio,
      cacheDao: mockCacheDao,
      useSameOriginProxy: false,
    );
  });

  test('returns cached result without hitting API', () async {
    const barcode = '012345678901';
    final cached = BarcodeCacheEntry(
      barcode: barcode,
      productName: 'Cached Game',
      description: 'Cached Description',
      imageUrl: 'https://example.com/cached.jpg',
      category: 'Games',
      source: 'Cache',
      fetchedAt: DateTime.now(),
    );

    when(() => mockCacheDao.lookup(barcode)).thenAnswer((_) async => cached);

    final result = await service.lookup(barcode);

    expect(result, isNotNull);
    expect(result!.barcode, equals(barcode));
    expect(result.productName, equals('Cached Game'));
    expect(result.source, equals('Cache'));
    verifyNever(() => mockDio.get(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ));
  });

  test('tries UPCitemdb on cache miss, caches result', () async {
    const barcode = '008888511618';
    when(() => mockCacheDao.lookup(barcode)).thenAnswer((_) async => null);
    when(() => mockCacheDao.insertOrUpdate(any())).thenAnswer((_) async {});

    when(() => mockDio.get(
          'https://api.upcitemdb.com/prod/trial/lookup',
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: {
            'code': 'OK',
            'total': 1,
            'items': [
              {
                'title': 'Borderlands 2',
                'description': 'Action RPG game',
                'images': ['https://example.com/borderlands.jpg'],
                'category': 'Video Games',
              }
            ],
          },
        ));

    final result = await service.lookup(barcode);

    expect(result, isNotNull);
    expect(result!.barcode, equals(barcode));
    expect(result.productName, equals('Borderlands 2'));
    expect(result.description, equals('Action RPG game'));
    expect(result.imageUrl, equals('https://example.com/borderlands.jpg'));
    expect(result.source, equals('UPCitemdb'));

    verify(() => mockCacheDao.insertOrUpdate(any())).called(1);
  });

  test('uses same-origin /api/upc proxy when enabled', () async {
    const barcode = '008888511618';
    const origin = 'https://flipbin.example';
    service = BarcodeLookupService(
      dio: mockDio,
      cacheDao: mockCacheDao,
      useSameOriginProxy: true,
      proxyOrigin: origin,
    );

    when(() => mockCacheDao.lookup(barcode)).thenAnswer((_) async => null);
    when(() => mockCacheDao.insertOrUpdate(any())).thenAnswer((_) async {});

    when(() => mockDio.get(
          '$origin/api/upc',
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: {
            'barcode': barcode,
            'productName': 'Borderlands 2',
            'description': 'Action RPG game',
            'imageUrl': 'https://example.com/borderlands.jpg',
            'category': 'Video Games',
            'source': 'UPCitemdb',
          },
        ));

    final result = await service.lookup(barcode);

    expect(result, isNotNull);
    expect(result!.productName, equals('Borderlands 2'));
    expect(result.source, equals('UPCitemdb'));
    expect(result.imageUrl, equals('https://example.com/borderlands.jpg'));

    verify(() => mockDio.get(
          '$origin/api/upc',
          queryParameters: {'upc': barcode},
          options: any(named: 'options'),
        )).called(1);
    verifyNever(() => mockDio.get(
          'https://api.upcitemdb.com/prod/trial/lookup',
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ));
    verify(() => mockCacheDao.insertOrUpdate(any())).called(1);
  });

  test('proxy 404 returns null (not found)', () async {
    const barcode = '999999999999';
    const origin = 'https://flipbin.example';
    service = BarcodeLookupService(
      dio: mockDio,
      cacheDao: mockCacheDao,
      useSameOriginProxy: true,
      proxyOrigin: origin,
    );

    when(() => mockCacheDao.lookup(barcode)).thenAnswer((_) async => null);

    when(() => mockDio.get(
          '$origin/api/upc',
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 404,
          data: {'error': 'not_found', 'barcode': barcode},
        ));

    final result = await service.lookup(barcode);
    expect(result, isNull);
    verifyNever(() => mockCacheDao.insertOrUpdate(any()));
  });

  test('returns null when UPCitemdb fails', () async {
    const barcode = '999999999999';
    when(() => mockCacheDao.lookup(barcode)).thenAnswer((_) async => null);

    when(() => mockDio.get(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 404,
        ),
      ),
    );

    final result = await service.lookup(barcode);
    expect(result, isNull);
  });

  test('returns null on network timeout', () async {
    const barcode = '123456789012';
    when(() => mockCacheDao.lookup(barcode)).thenAnswer((_) async => null);

    when(() => mockDio.get(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionTimeout,
      ),
    );

    final result = await service.lookup(barcode);
    expect(result, isNull);
  });

  test('preserves leading zeros in barcode through lookup', () async {
    const barcode = '008888511618';
    when(() => mockCacheDao.lookup(barcode)).thenAnswer((_) async => null);
    when(() => mockCacheDao.insertOrUpdate(any())).thenAnswer((_) async {});

    when(() => mockDio.get(
          'https://api.upcitemdb.com/prod/trial/lookup',
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: {
            'items': [
              {'title': 'Test Item'},
            ],
          },
        ));

    final result = await service.lookup(barcode);

    expect(result, isNotNull);
    expect(result!.barcode, equals(barcode));
    expect(result.barcode.startsWith('00'), isTrue);

    verify(() => mockDio.get(
          'https://api.upcitemdb.com/prod/trial/lookup',
          queryParameters: {'upc': barcode},
          options: any(named: 'options'),
        )).called(1);
  });
}
