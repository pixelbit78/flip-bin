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

    test('maps blu-ray / dvd / vhs / cd / book', () {
      expect(ItemType.fromCategory('Movies > Blu-ray'), ItemType.bluray);
      expect(ItemType.fromCategory('DVD Movies'), ItemType.dvd);
      expect(ItemType.fromCategory('Movies > VHS'), ItemType.vhs);
      expect(ItemType.fromCategory('Videocassette'), ItemType.vhs);
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

  group('ItemType.fromLabel', () {
    test('recognizes VHS and aliases', () {
      expect(ItemType.fromLabel('VHS'), ItemType.vhs);
      expect(ItemType.fromLabel('vhs'), ItemType.vhs);
      expect(ItemType.fromLabel('vhs tape'), ItemType.vhs);
      expect(ItemType.fromLabel('Blu-ray'), ItemType.bluray);
      expect(ItemType.fromLabel('blu ray'), ItemType.bluray);
    });
  });

  group('ItemType.label', () {
    test('VHS label is VHS', () {
      expect(ItemType.vhs.label, 'VHS');
    });
  });

  group('ItemStatus.next', () {
    test('cycles Active ↔ Personal; Sold stays Sold', () {
      expect(ItemStatus.active.next, ItemStatus.personal);
      expect(ItemStatus.personal.next, ItemStatus.active);
      expect(ItemStatus.sold.next, ItemStatus.sold);
    });
  });
}
