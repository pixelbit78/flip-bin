import 'package:flutter_test/flutter_test.dart';
import 'package:flipbin/utils/proxied_image_url.dart';

void main() {
  group('proxiedImageUrl', () {
    test('returns null for null/empty', () {
      expect(proxiedImageUrl(null, forceWeb: true), isNull);
      expect(proxiedImageUrl('  ', forceWeb: true), isNull);
    });

    test('passes through on non-web', () {
      const raw = 'https://covers3.booksamillion.com/covers/dvd/x.jpg';
      expect(
        proxiedImageUrl(raw, forceWeb: false, origin: 'https://flip-bin.vercel.app'),
        equals(raw),
      );
    });

    test('rewrites absolute https via /api/image on web', () {
      const raw = 'https://covers3.booksamillion.com/covers/dvd/x.jpg';
      expect(
        proxiedImageUrl(raw, forceWeb: true, origin: 'https://flip-bin.vercel.app'),
        equals(
          'https://flip-bin.vercel.app/api/image?url=${Uri.encodeQueryComponent(raw)}',
        ),
      );
    });

    test('upgrades http target when proxying', () {
      const raw = 'http://covers3.booksamillion.com/covers/dvd/x.jpg';
      const https = 'https://covers3.booksamillion.com/covers/dvd/x.jpg';
      expect(
        proxiedImageUrl(raw, forceWeb: true, origin: 'https://flip-bin.vercel.app'),
        equals(
          'https://flip-bin.vercel.app/api/image?url=${Uri.encodeQueryComponent(https)}',
        ),
      );
    });

    test('leaves existing proxy URLs alone', () {
      const proxied =
          'https://flip-bin.vercel.app/api/image?url=https%3A%2F%2Fexample.com%2Fa.jpg';
      expect(
        proxiedImageUrl(proxied, forceWeb: true, origin: 'https://flip-bin.vercel.app'),
        equals(proxied),
      );
    });
  });
}
