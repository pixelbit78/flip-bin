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
    service = BarcodeLookupService(dio: mockDio, cacheDao: mockCacheDao);
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
    verifyNever(() => mockDio.get(any(), options: any(named: 'options')));
  });

  test('tries UPC Database API on cache miss, caches result', () async {
    const barcode = '008888511618';
    when(() => mockCacheDao.lookup(barcode)).thenAnswer((_) async => null);
    when(() => mockCacheDao.insertOrUpdate(any())).thenAnswer((_) async {});

    when(() => mockDio.get(
      'https://api.upcdatabase.org/product/$barcode',
      options: any(named: 'options'),
    )).thenAnswer((_) async => Response(
      requestOptions: RequestOptions(path: ''),
      statusCode: 200,
      data: {
        'title': 'Borderlands 2',
        'description': 'Action RPG game',
        'images': ['https://example.com/borderlands.jpg'],
        'category': 'Video Games',
      },
    ));

    final result = await service.lookup(barcode);

    expect(result, isNotNull);
    expect(result!.barcode, equals(barcode));
    expect(result.productName, equals('Borderlands 2'));
    expect(result.description, equals('Action RPG game'));
    expect(result.imageUrl, equals('https://example.com/borderlands.jpg'));
    expect(result.source, equals('UPC Database'));

    verify(() => mockCacheDao.insertOrUpdate(any())).called(1);
  });

  test('falls through to Open Food Facts when UPC DB returns 404', () async {
    const barcode = '001111222233';
    when(() => mockCacheDao.lookup(barcode)).thenAnswer((_) async => null);
    when(() => mockCacheDao.insertOrUpdate(any())).thenAnswer((_) async {});

    when(() => mockDio.get(
      'https://api.upcdatabase.org/product/$barcode',
      options: any(named: 'options'),
    )).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: ''),
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 404,
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    when(() => mockDio.get(
      'https://world.openfoodfacts.org/api/v0/product/$barcode.json',
      options: any(named: 'options'),
    )).thenAnswer((_) async => Response(
      requestOptions: RequestOptions(path: ''),
      statusCode: 200,
      data: {
        'status': 1,
        'product': {
          'product_name': 'Energy Drink',
          'image_url': 'https://example.com/drink.jpg',
          'categories': 'Beverages',
        },
      },
    ));

    final result = await service.lookup(barcode);

    expect(result, isNotNull);
    expect(result!.productName, equals('Energy Drink'));
    expect(result.source, equals('Open Food Facts'));
    verify(() => mockCacheDao.insertOrUpdate(any())).called(1);
  });

  test('returns null when all APIs fail', () async {
    const barcode = '999999999999';
    when(() => mockCacheDao.lookup(barcode)).thenAnswer((_) async => null);

    when(() => mockDio.get(
      'https://api.upcdatabase.org/product/$barcode',
      options: any(named: 'options'),
    )).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: ''),
        response: Response(requestOptions: RequestOptions(path: ''), statusCode: 404),
        type: DioExceptionType.badResponse,
      ),
    );

    when(() => mockDio.get(
      'https://world.openfoodfacts.org/api/v0/product/$barcode.json',
      options: any(named: 'options'),
    )).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: ''),
        response: Response(requestOptions: RequestOptions(path: ''), statusCode: 404),
        type: DioExceptionType.badResponse,
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
      'https://api.upcdatabase.org/product/$barcode',
      options: any(named: 'options'),
    )).thenAnswer((_) async => Response(
      requestOptions: RequestOptions(path: ''),
      statusCode: 200,
      data: {
        'title': 'Test Item',
      },
    ));

    final result = await service.lookup(barcode);

    expect(result, isNotNull);
    expect(result!.barcode, equals(barcode));
    expect(result.barcode.startsWith('00'), isTrue);

    verify(() => mockDio.get(
      'https://api.upcdatabase.org/product/008888511618',
      options: any(named: 'options'),
    )).called(1);
  });
}
