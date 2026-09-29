import 'package:flutter_test/flutter_test.dart';
import 'package:flipbin/utils/proxied_image_url.dart';

void main() {
  group('proxiedImageUrl', () {
    test('returns null for null/empty', () {
      expect(proxiedImageUrl(null), isNull);
      expect(proxiedImageUrl('  '), isNull);
    });

    test('passes through https', () {
      const raw = 'https://covers3.booksamillion.com/covers/dvd/x.jpg';
      expect(proxiedImageUrl(raw), equals(raw));
    });

    test('upgrades http to https', () {
      const raw = 'http://covers3.booksamillion.com/covers/dvd/x.jpg';
      const https = 'https://covers3.booksamillion.com/covers/dvd/x.jpg';
      expect(proxiedImageUrl(raw), equals(https));
    });

    test('leaves existing proxy URLs alone', () {
      const proxied =
          'https://flip-bin.vercel.app/api/image?url=https%3A%2F%2Fexample.com%2Fa.jpg';
      expect(proxiedImageUrl(proxied), equals(proxied));
    });
  });
}
