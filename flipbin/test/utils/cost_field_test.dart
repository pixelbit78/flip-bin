import 'package:flutter_test/flutter_test.dart';
import 'package:flipbin/utils/cost_field.dart';

void main() {
  group('shouldClearCostOnFocus', () {
    test('clears zero variants', () {
      expect(shouldClearCostOnFocus('0'), isTrue);
      expect(shouldClearCostOnFocus('0.0'), isTrue);
      expect(shouldClearCostOnFocus('0.00'), isTrue);
      expect(shouldClearCostOnFocus(' 0.00 '), isTrue);
    });

    test('keeps positive amounts', () {
      expect(shouldClearCostOnFocus('0.01'), isFalse);
      expect(shouldClearCostOnFocus('12.50'), isFalse);
      expect(shouldClearCostOnFocus('5'), isFalse);
    });

    test('leaves empty / non-numeric alone', () {
      expect(shouldClearCostOnFocus(''), isFalse);
      expect(shouldClearCostOnFocus('  '), isFalse);
      expect(shouldClearCostOnFocus('abc'), isFalse);
    });
  });
}
