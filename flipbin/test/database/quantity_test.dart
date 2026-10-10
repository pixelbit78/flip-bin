import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/utils/cost_field.dart';

void main() {
  late FlipBinDatabase db;
  setUp(() => db = FlipBinDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> addLot(String d, {int qty = 1, double? cpi, double? cost,
      ItemStatus status = ItemStatus.active, DateTime? added}) {
    return db.inventoryItemsDao.insertItem(InventoryItemsCompanion.insert(
      dateAdded: added ?? DateTime(2026, 1, 5),
      itemDescription: d,
      type: ItemType.book,
      cost: cost ?? 0,
      quantity: Value(qty),
      costPerItem: cpi == null ? const Value.absent() : Value(cpi),
      status: status,
    ));
  }

  group('applyCostRules', () {
    test('user cpi derives total', () async {
      final id = await addLot('17 comics', qty: 17, cpi: 4);
      final i = await db.inventoryItemsDao.getById(id);
      expect(i.cost, 68.00);
      expect(i.costPerItem, 4.0);
    });
    test('system path keeps cost, derives cpi 4dp', () async {
      final id = await addLot('17 comics', qty: 17, cost: 4.65);
      final i = await db.inventoryItemsDao.getById(id);
      expect(i.cost, 4.65);
      expect(i.costPerItem, 0.2735);
    });
    test('applyUserCostEdit holds cpi, recomputes total', () {
      final i = InventoryItem(
          id: 1, dateAdded: DateTime(2026), itemDescription: 'x',
          type: ItemType.book, cost: 4.65, quantity: 17, costPerItem: 0.2735,
          status: ItemStatus.active);
      final e = InventoryItemsDao.applyUserCostEdit(i, qty: 18, cpi: 0.2735);
      expect(e.cost, 4.92); // 18 × 0.2735 = 4.923
    });
  });

  group('split math (§3.4)', () {
    test('108.30/95 sell 20 → 22.80 + 85.50', () async {
      final id = await addLot('95 comics', qty: 95, cost: 108.30);
      final childId = await db.inventoryItemsDao.sellUnits(id, 20);
      final p = await db.inventoryItemsDao.getById(id);
      final c = await db.inventoryItemsDao.getById(childId);
      expect(c.cost, 22.80);
      expect(c.quantity, 20);
      expect(c.parentId, id);
      expect(c.status, ItemStatus.sold);
      expect(c.dateAdded, p.dateAdded);
      expect(p.cost, 85.50);
      expect(p.quantity, 75);
    });
    test('4.65/17 sell 5 → 1.37 + 3.28', () async {
      final id = await addLot('17 comics', qty: 17, cost: 4.65);
      final childId = await db.inventoryItemsDao.sellUnits(id, 5);
      expect((await db.inventoryItemsDao.getById(childId)).cost, 1.37);
      expect((await db.inventoryItemsDao.getById(id)).cost, 3.28);
    });
    test('drift case cpi 0.335 qty 2 C 0.67 → 0.34 + 0.33', () async {
      final id = await addLot('pair', qty: 2, cpi: 0.335);
      expect((await db.inventoryItemsDao.getById(id)).cost, 0.67);
      final childId = await db.inventoryItemsDao.sellUnits(id, 1);
      expect((await db.inventoryItemsDao.getById(childId)).cost, 0.34);
      expect((await db.inventoryItemsDao.getById(id)).cost, 0.33);
    });
    test('tiny cpi child may be \$0.00', () async {
      final id = await addLot('pins', qty: 1000, cpi: 0.001);
      final childId = await db.inventoryItemsDao.sellUnits(id, 3);
      expect((await db.inventoryItemsDao.getById(childId)).cost, 0.0);
      expect((await db.inventoryItemsDao.getById(id)).cost, 1.0);
    });
    test('sell all flips row, cost unchanged', () async {
      final id = await addLot('lot', qty: 3, cost: 6);
      final sid = await db.inventoryItemsDao.sellUnits(id, 3);
      expect(sid, id);
      final r = await db.inventoryItemsDao.getById(id);
      expect(r.status, ItemStatus.sold);
      expect(r.dateSold, isNotNull);
      expect(r.cost, 6.0);
    });
    test('out of range throws', () async {
      final id = await addLot('lot', qty: 3, cost: 6);
      expect(() => db.inventoryItemsDao.sellUnits(id, 0), throwsArgumentError);
      expect(() => db.inventoryItemsDao.sellUnits(id, 4), throwsArgumentError);
    });
    test('personal remainder stays personal', () async {
      final id = await addLot('lot', qty: 3, cost: 6, status: ItemStatus.personal);
      await db.inventoryItemsDao.sellUnits(id, 1);
      expect((await db.inventoryItemsDao.getById(id)).status, ItemStatus.personal);
    });
  });

  group('unsell', () {
    test('merge restores total exactly', () async {
      final id = await addLot('pair', qty: 2, cpi: 0.335);
      final childId = await db.inventoryItemsDao.sellUnits(id, 1);
      final back = await db.inventoryItemsDao.unsell(childId);
      expect(back, id);
      final p = await db.inventoryItemsDao.getById(id);
      expect(p.cost, 0.67);
      expect(p.quantity, 2);
      expect(p.costPerItem, 0.335);
      final all = await db.inventoryItemsDao.getAllForExport();
      expect(all, hasLength(1));
    });
    test('no live parent → flip to active', () async {
      final id = await addLot('one', cost: 5);
      await db.inventoryItemsDao.sellUnits(id, 1);
      await db.inventoryItemsDao.unsell(id);
      final r = await db.inventoryItemsDao.getById(id);
      expect(r.status, ItemStatus.active);
      expect(r.dateSold, isNull);
    });
  });

  group('unit metrics', () {
    test('counts, total cost, sell-through and monthly use units', () async {
      final now = DateTime.now();
      final a = await addLot('95 comics', qty: 95, cost: 108.30, added: now);
      await addLot('single', cost: 10, added: now);
      await db.inventoryItemsDao.sellUnits(a, 20);
      final dao = db.inventoryItemsDao;
      expect(await dao.watchCountByStatus(ItemStatus.active).first, 76);
      expect(await dao.watchCountByStatus(ItemStatus.sold).first, 20);
      expect(await dao.watchTotalCostByStatus(ItemStatus.active).first,
          closeTo(95.50, 1e-9));
      final st = await dao.watchSellThrough().first;
      expect(st.sold, 20);
      expect(st.stillActive, 76);
      final listed = await dao.watchMonthlyListedCounts(monthCount: 1).first;
      expect(listed.single.count, 96); // lot counted once at full size + 1
      final sold = await dao.watchMonthlySoldCounts(monthCount: 1).first;
      expect(sold.single.count, 20);
    });
  });

  group('migration v1 → v2', () {
    test('additive backfill, cost untouched, idempotent', () async {
      await db.close();
      final exec = NativeDatabase.memory(setup: (raw) {
        for (final ddl in kSchemaV1Ddl) {
          raw.execute(ddl);
        }
        raw.execute("INSERT INTO inventory_items (date_added, item_description, type, cost, quantity, status) VALUES "
            "(1700000000, '95 comics from 7miletreasures', 'book', 108.3, 1, 'active'),"
            "(1700000000, '17 comics', 'book', 4.65, 1, 'active'),"
            "(1700000000, 'defensive', 'book', 20.0, 4, 'active')");
        raw.execute('PRAGMA user_version = 1');
      });
      db = FlipBinDatabase(exec);
      for (var k = 0; k < 3; k++) {
        await db.inventoryItemsDao.backfillCostPerItemProxy(db);
      }
      final rows = await db.inventoryItemsDao.getAllForExport();
      expect(rows.map((r) => r.cost), [108.3, 4.65, 20.0]);
      expect(rows.map((r) => r.costPerItem), [108.3, 4.65, 5.0]);
      expect(rows.every((r) => r.parentId == null), isTrue);
    });
  });

  group('Review lots', () {
    test('suggest + apply keeps cost, sets cpi; rerun is empty', () async {
      await addLot('95 comics from 7miletreasures', cost: 108.30);
      await addLot('17 comics', cost: 4.65);
      await addLot('Halo', cost: 8);
      await addLot('2019 Topps', cost: 8);
      final s = await db.inventoryItemsDao.lotSuggestions();
      expect(s.map((e) => e.suggestedQty).toSet(), {95, 17});
      for (final e in s) {
        await db.inventoryItemsDao.applyLotQty(e.item.id, e.suggestedQty);
      }
      final rows = await db.inventoryItemsDao.getAllForExport();
      final byD = {for (final r in rows) r.itemDescription: r};
      expect(byD['17 comics']!.costPerItem, 0.2735);
      expect(byD['17 comics']!.cost, 4.65);
      expect(byD['95 comics from 7miletreasures']!.costPerItem, 1.14);
      expect(await db.inventoryItemsDao.lotSuggestions(), isEmpty);
    });
  });

  group('helpers', () {
    test('formatting', () {
      expect(formatEach(0.2735), r'$0.27 ea');
      expect(formatEach(0.001), r'$0.00 ea');
      expect(formatCpiField(0.2735), '0.2735');
      expect(formatCpiField(1.14), '1.14');
      expect(formatCpiField(45), '45.00');
      expect(lineTotal(400, 0.0125), 5.0);
      expect(validateCostInput(''), 'Cost is required');
      expect(validateCostInput('abc'), 'Enter a valid amount');
      expect(validateCostInput('-1'), 'Cost cannot be negative');
      expect(validateCostInput('1.5'), isNull);
    });
    test('suggestQtyFromDescription', () {
      expect(suggestQtyFromDescription('17 comics'), 17);
      expect(suggestQtyFromDescription('Lot of 12 Nintendo games'), 12);
      expect(suggestQtyFromDescription('3DS Zelda'), isNull);
      expect(suggestQtyFromDescription('1 comic'), isNull);
      expect(suggestQtyFromDescription('2019 Topps'), isNull);
    });
  });
}

extension on InventoryItemsDao {
  Future<void> backfillCostPerItemProxy(FlipBinDatabase db) =>
      db.backfillCostPerItem();
}
