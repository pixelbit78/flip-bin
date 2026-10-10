// QA-only fixture data (SPEC §12.9, TEST_PLAN §2/§5). Referenced only behind
// `kIsQa` in the app (tree-shaken from prod) and by tests / the generator.
import 'package:drift/drift.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/enums.dart';

DateTime _d(DateTime t, int daysAgo) => t.subtract(Duration(days: daysAgo));

/// TEST_PLAN §2 v2 sample relative to [t] (today). Includes split B + B′.
/// Ids are explicit so B′.parentId = B.
List<InventoryItemsCompanion> v2SampleInventory(DateTime t) {
  InventoryItemsCompanion row(int id, String desc, ItemType type, int qty,
      double cpi, double cost, ItemStatus status, int added,
      {int? sold, int? parent}) {
    return InventoryItemsCompanion.insert(
      id: Value(id),
      dateAdded: _d(t, added),
      itemDescription: desc,
      type: type,
      cost: cost,
      quantity: Value(qty),
      costPerItem: Value(cpi),
      parentId: Value(parent),
      status: status,
      dateSold: Value(sold == null ? null : _d(t, sold)),
    );
  }

  return [
    row(1, 'Halo 3', ItemType.game, 1, 10.00, 10.00, ItemStatus.active, 10),
    row(2, 'DVD lot', ItemType.dvd, 3, 2.00, 6.00, ItemStatus.active, 40),
    row(3, 'DVD lot', ItemType.dvd, 2, 2.00, 4.00, ItemStatus.sold, 40,
        sold: 5, parent: 2),
    row(4, 'CD set', ItemType.cd, 3, 4.00, 12.00, ItemStatus.sold, 100, sold: 20),
    row(5, 'VHS bulk', ItemType.vhs, 10, 1.50, 15.00, ItemStatus.active, 95),
    row(6, 'Book pair', ItemType.book, 2, 7.25, 14.50, ItemStatus.personal, 15),
    row(7, 'Blu-ray', ItemType.bluray, 4, 3.00, 12.00, ItemStatus.active, 65),
  ];
}

List<ExpensesCompanion> sampleExpenses(DateTime t) => [
      ExpensesCompanion.insert(
        date: _d(t, 3),
        merchant: 'QA Supplies',
        itemDescription: 'Bubble mailers',
        quantity: const Value(2),
        unitPrice: 4.50,
        expenseType: ExpenseType.values.first,
      ),
    ];

/// Legacy v1 rows (no cost_per_item / parent_id) as raw SQL VALUES tuples:
/// (date_added secs, description, type, cost, quantity, status, date_sold).
List<String> legacyV1InventoryInserts(DateTime t) {
  int s(int daysAgo) => _d(t, daysAgo).millisecondsSinceEpoch ~/ 1000;
  String row(String desc, String type, double cost, int qty, String status,
          int added, [int? sold]) =>
      "(${s(added)}, '${desc.replaceAll("'", "''")}', '$type', $cost, $qty, "
      "'$status', ${sold == null ? 'NULL' : s(sold)})";
  return [
    row('95 comics from 7miletreasures', 'book', 108.30, 1, 'active', 50),
    row('17 comics', 'book', 4.65, 1, 'active', 45),
    row('23 comics from thrift School', 'book', 46.00, 1, 'active', 35),
    row('QA single game', 'game', 10.00, 1, 'active', 20),
    row('QA defensive qty 4 row', 'dvd', 20.00, 4, 'active', 25),
    row('QA sold single', 'cd', 8.00, 1, 'sold', 60, 10),
    row('QA personal single', 'bluray', 12.00, 1, 'personal', 30),
    row('QA free item', 'other', 0.00, 1, 'active', 5),
  ];
}

String legacyV1ExpenseInsert(DateTime t) {
  final secs = _d(t, 3).millisecondsSinceEpoch ~/ 1000;
  return "($secs, 'QA Supplies', 'Bubble mailers', 2, 4.5, "
      "'${ExpenseType.values.first.name}')";
}

/// Rebuild the DB with the v1 schema + legacy rows. On next open the real
/// v1→v2 onUpgrade + backfill run.
Future<void> writeLegacyV1(FlipBinDatabase db, DateTime t) async {
  await db.customStatement('PRAGMA foreign_keys = OFF');
  for (final table in ['inventory_items', 'expenses', 'barcode_cache_entries']) {
    await db.customStatement('DROP TABLE IF EXISTS "$table"');
  }
  for (final ddl in kSchemaV1Ddl) {
    await db.customStatement(ddl);
  }
  await db.customStatement(
      'INSERT INTO inventory_items (date_added, item_description, type, cost, '
      'quantity, status, date_sold) VALUES ${legacyV1InventoryInserts(t).join(', ')}');
  await db.customStatement(
      'INSERT INTO expenses (date, merchant, item_description, quantity, '
      'unit_price, expense_type) VALUES ${legacyV1ExpenseInsert(t)}');
  await db.customStatement('PRAGMA user_version = 1');
}

Future<void> writeV2Sample(FlipBinDatabase db, DateTime t) async {
  await db.inventoryItemsDao.replaceAll(v2SampleInventory(t));
  await db.expensesDao.replaceAll(sampleExpenses(t));
}
