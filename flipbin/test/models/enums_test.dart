import 'package:flutter_test/flutter_test.dart';
import 'package:flipbin/models/enums.dart';

void main() {
  group('ItemType.fromCategory', () {
    test('maps video games / consoles to game', () {
      expect(
        ItemType.fromCategory('Electronics > Video Games > Nintendo'),
        ItemType.game,
      );
      expect(ItemType.fromCategory('Xbox One Games'), ItemType.game);
      expect(ItemType.fromCategory('PlayStation 5'), ItemType.game);
    });

    test('maps blu-ray / dvd / cd / book', () {
      expect(ItemType.fromCategory('Movies > Blu-ray'), ItemType.bluray);
      expect(ItemType.fromCategory('DVD Movies'), ItemType.dvd);
      expect(ItemType.fromCategory('Music > CD'), ItemType.cd);
      expect(ItemType.fromCategory('Media > Books > Fiction'), ItemType.book);
    });

    test('falls back to other / label', () {
      expect(ItemType.fromCategory(null), ItemType.other);
      expect(ItemType.fromCategory(''), ItemType.other);
      expect(ItemType.fromCategory('Kitchen Appliances'), ItemType.other);
      expect(ItemType.fromCategory('Game'), ItemType.game);
    });
  });

  group('ItemStatus.fromLabel', () {
    test('matches canonical labels and names', () {
      expect(ItemStatus.fromLabel('Active'), ItemStatus.active);
      expect(ItemStatus.fromLabel('Sold'), ItemStatus.sold);
      expect(ItemStatus.fromLabel('Personal'), ItemStatus.personal);
      expect(ItemStatus.fromLabel('personal'), ItemStatus.personal);
      expect(ItemStatus.fromLabel(null), ItemStatus.active);
      expect(ItemStatus.fromLabel(''), ItemStatus.active);
    });

    test('accepts legacy Personal spreadsheet variants', () {
      expect(ItemStatus.fromLabel('Personal Use'), ItemStatus.personal);
      expect(ItemStatus.fromLabel('Personal Item'), ItemStatus.personal);
      expect(ItemStatus.fromLabel('Personal Use Date'), ItemStatus.personal);
      expect(ItemStatus.fromLabel('personal use'), ItemStatus.personal);
    });

    test('does not reclassify sold/unknown as personal', () {
      expect(ItemStatus.fromLabel('Sold'), ItemStatus.sold);
      expect(ItemStatus.fromLabel('Unknown'), ItemStatus.active);
    });
  });
}
