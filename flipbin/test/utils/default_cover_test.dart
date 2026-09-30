import 'package:flutter_test/flutter_test.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/utils/default_cover.dart';

void main() {
  test('defaultCoverAssetFor returns a distinct asset per type', () {
    final paths = {
      for (final t in ItemType.values) t: defaultCoverAssetFor(t),
    };
    expect(paths[ItemType.dvd], 'assets/covers/dvd.png');
    expect(paths[ItemType.game], 'assets/covers/game.png');
    expect(paths[ItemType.bluray], 'assets/covers/bluray.png');
    expect(paths[ItemType.vhs], 'assets/covers/vhs.png');
    expect(paths[ItemType.cd], 'assets/covers/cd.png');
    expect(paths[ItemType.book], 'assets/covers/book.png');
    expect(paths[ItemType.other], 'assets/covers/other.png');
    expect(paths.values.toSet().length, ItemType.values.length);
  });
}
