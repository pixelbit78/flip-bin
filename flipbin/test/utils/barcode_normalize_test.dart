import 'package:flutter_test/flutter_test.dart';
import 'package:flipbin/utils/barcode_normalize.dart';

void main() {
  group('BarcodeNormalize', () {
    test('digitsOnly strips non-digits', () {
      expect(BarcodeNormalize.digitsOnly('013-388 550265'), equals('013388550265'));
      expect(BarcodeNormalize.digitsOnly('abc'), equals(''));
    });

    test('stripLeadingZeros', () {
      expect(BarcodeNormalize.stripLeadingZeros('013388550265'), equals('13388550265'));
      expect(BarcodeNormalize.stripLeadingZeros('13388550265'), equals('13388550265'));
      expect(BarcodeNormalize.stripLeadingZeros('0000'), equals(''));
    });

    test('significantDigits', () {
      expect(BarcodeNormalize.significantDigits('013388550265'), equals('13388550265'));
      expect(BarcodeNormalize.significantDigits(' 13388550265 '), equals('13388550265'));
      expect(BarcodeNormalize.significantDigits('000'), isNull);
    });

    test('isNumericUpcLike', () {
      expect(BarcodeNormalize.isNumericUpcLike('013388550265'), isTrue);
      expect(BarcodeNormalize.isNumericUpcLike('13388550265'), isTrue);
      expect(BarcodeNormalize.isNumericUpcLike('1234567'), isFalse); // too short
      expect(BarcodeNormalize.isNumericUpcLike('mario'), isFalse);
      expect(BarcodeNormalize.isNumericUpcLike('12-345678901'), isTrue);
    });

    test('equalsFlexible matches leading-zero variants both ways', () {
      expect(
        BarcodeNormalize.equalsFlexible('13388550265', '013388550265'),
        isTrue,
      );
      expect(
        BarcodeNormalize.equalsFlexible('013388550265', '13388550265'),
        isTrue,
      );
      expect(
        BarcodeNormalize.equalsFlexible('013388550265', '013388550265'),
        isTrue,
      );
      expect(
        BarcodeNormalize.equalsFlexible('013388550265', '999999999999'),
        isFalse,
      );
      expect(BarcodeNormalize.equalsFlexible(null, '013388550265'), isFalse);
    });

    test('matchesSearch description-style substring on barcode text', () {
      expect(
        BarcodeNormalize.matchesSearch('012345678905', '234567'),
        isTrue,
      );
    });

    test('matchesSearch leading-zero mismatch both directions', () {
      expect(
        BarcodeNormalize.matchesSearch('13388550265', '013388550265'),
        isTrue,
      );
      expect(
        BarcodeNormalize.matchesSearch('013388550265', '13388550265'),
        isTrue,
      );
    });
  });
}
