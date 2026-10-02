import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/providers/database_provider.dart';
import 'package:flipbin/providers/inventory_provider.dart';

void main() {
  late FlipBinDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = FlipBinDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('Save as sold updates status, fills dateSold, drops barcode matches', () async {
    final id = await db.inventoryItemsDao.insertItem(
      InventoryItemsCompanion.insert(
        dateAdded: DateTime(2026, 1, 1),
        barcode: const Value('012345678905'),
        itemDescription: 'Match Me',
        type: ItemType.game,
        cost: 10,
        status: ItemStatus.active,
      ),
    );

    final before = await container.read(
      inventoryMatchesByBarcodeProvider('012345678905').future,
    );
    expect(before, hasLength(1));

    await container.read(inventoryControllerProvider).updateInventoryItem(
          before.first.copyWith(status: ItemStatus.sold),
        );

    final afterDb = await db.inventoryItemsDao.getById(id);
    expect(afterDb.status, ItemStatus.sold);
    expect(afterDb.dateSold, isNotNull);

    await Future<void>.delayed(const Duration(milliseconds: 50));
    final after = await container.read(
      inventoryMatchesByBarcodeProvider('012345678905').future,
    );
    expect(after, isEmpty);
  });

  test('Save as sold works for personal matches too', () async {
    final id = await db.inventoryItemsDao.insertItem(
      InventoryItemsCompanion.insert(
        dateAdded: DateTime(2026, 2, 1),
        barcode: const Value('978020137962'),
        itemDescription: 'Personal Match',
        type: ItemType.book,
        cost: 5,
        status: ItemStatus.personal,
      ),
    );

    final before = await container.read(
      inventoryMatchesByBarcodeProvider('978020137962').future,
    );
    expect(before, hasLength(1));

    await container.read(inventoryControllerProvider).updateInventoryItem(
          before.first.copyWith(status: ItemStatus.sold),
        );

    final afterDb = await db.inventoryItemsDao.getById(id);
    expect(afterDb.status, ItemStatus.sold);
    expect(afterDb.dateSold, isNotNull);
  });
}
