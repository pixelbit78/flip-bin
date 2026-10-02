import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/enums.dart';

void main() {
  late FlipBinDatabase db;

  setUp(() {
    db = FlipBinDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('InventoryItemsDao', () {
    test('insert and retrieve inventory item', () async {
      final now = DateTime.now();
      final id = await db.inventoryItemsDao.insertItem(
        InventoryItemsCompanion.insert(
          dateAdded: now,
          itemDescription: 'Halo Combat Evolved',
          type: ItemType.game,
          cost: 8.76,
          status: ItemStatus.active,
          barcode: const Value('012345678901'),
        ),
      );

      final item = await db.inventoryItemsDao.getById(id);
      expect(item.id, equals(id));
      expect(item.itemDescription, equals('Halo Combat Evolved'));
      expect(item.type, equals(ItemType.game));
      expect(item.cost, equals(8.76));
      expect(item.status, equals(ItemStatus.active));
      expect(item.quantity, equals(1));
    });

    test('watchAll filters by status', () async {
      final now = DateTime.now();
      await db.inventoryItemsDao.insertItem(
        InventoryItemsCompanion.insert(
          dateAdded: now,
          itemDescription: 'Item 1',
          type: ItemType.game,
          cost: 5.0,
          status: ItemStatus.active,
        ),
      );
      await db.inventoryItemsDao.insertItem(
        InventoryItemsCompanion.insert(
          dateAdded: now,
          itemDescription: 'Item 2',
          type: ItemType.dvd,
          cost: 4.0,
          status: ItemStatus.active,
        ),
      );
      await db.inventoryItemsDao.insertItem(
        InventoryItemsCompanion.insert(
          dateAdded: now,
          itemDescription: 'Item 3',
          type: ItemType.bluray,
          cost: 6.0,
          status: ItemStatus.sold,
        ),
      );

      final activeList = await db.inventoryItemsDao.watchAll(statusFilter: ItemStatus.active).first;
      expect(activeList.length, equals(2));

      final soldList = await db.inventoryItemsDao.watchAll(statusFilter: ItemStatus.sold).first;
      expect(soldList.length, equals(1));
      expect(soldList.first.itemDescription, equals('Item 3'));
    });

    test('watchByBarcodeActiveOrPersonal returns active/personal only', () async {
      final now = DateTime.now();
      const upc = '012345678901';
      await db.inventoryItemsDao.insertItem(
        InventoryItemsCompanion.insert(
          dateAdded: now,
          itemDescription: 'Active Copy',
          type: ItemType.game,
          cost: 5.0,
          status: ItemStatus.active,
          barcode: const Value(upc),
        ),
      );
      await db.inventoryItemsDao.insertItem(
        InventoryItemsCompanion.insert(
          dateAdded: now,
          itemDescription: 'Personal Copy',
          type: ItemType.game,
          cost: 0.0,
          status: ItemStatus.personal,
          barcode: const Value(upc),
        ),
      );
      await db.inventoryItemsDao.insertItem(
        InventoryItemsCompanion.insert(
          dateAdded: now,
          itemDescription: 'Sold Copy',
          type: ItemType.game,
          cost: 5.0,
          status: ItemStatus.sold,
          barcode: const Value(upc),
        ),
      );
      await db.inventoryItemsDao.insertItem(
        InventoryItemsCompanion.insert(
          dateAdded: now,
          itemDescription: 'Other UPC',
          type: ItemType.dvd,
          cost: 3.0,
          status: ItemStatus.active,
          barcode: const Value('999999999999'),
        ),
      );

      final matches = await db.inventoryItemsDao
          .watchByBarcodeActiveOrPersonal(' 012345678901 ')
          .first;
      expect(matches.length, equals(2));
      expect(
        matches.map((e) => e.itemDescription).toSet(),
        equals({'Active Copy', 'Personal Copy'}),
      );
    });

    test('watchAll filters by search query', () async {
      final now = DateTime.now();
      await db.inventoryItemsDao.insertItem(
        InventoryItemsCompanion.insert(
          dateAdded: now,
          itemDescription: 'Super Mario Sunshine',
          type: ItemType.game,
          cost: 25.0,
          status: ItemStatus.active,
        ),
      );
      await db.inventoryItemsDao.insertItem(
        InventoryItemsCompanion.insert(
          dateAdded: now,
          itemDescription: 'Fable Xbox',
          type: ItemType.game,
          cost: 10.0,
          status: ItemStatus.active,
        ),
      );

      final searchResults = await db.inventoryItemsDao.watchAll(searchQuery: 'mario').first;
      expect(searchResults.length, equals(1));
      expect(searchResults.first.itemDescription, equals('Super Mario Sunshine'));
    });

    test('countByStatus returns correct count', () async {
      final now = DateTime.now();
      await db.inventoryItemsDao.insertItem(
        InventoryItemsCompanion.insert(
          dateAdded: now,
          itemDescription: 'Game 1',
          type: ItemType.game,
          cost: 10.0,
          status: ItemStatus.active,
        ),
      );
      await db.inventoryItemsDao.insertItem(
        InventoryItemsCompanion.insert(
          dateAdded: now,
          itemDescription: 'Game 2',
          type: ItemType.game,
          cost: 15.0,
          status: ItemStatus.active,
        ),
      );
      await db.inventoryItemsDao.insertItem(
        InventoryItemsCompanion.insert(
          dateAdded: now,
          itemDescription: 'Game 3',
          type: ItemType.game,
          cost: 20.0,
          status: ItemStatus.sold,
        ),
      );

      final activeCount = await db.inventoryItemsDao.countByStatus(ItemStatus.active);
      final soldCount = await db.inventoryItemsDao.countByStatus(ItemStatus.sold);
      final personalCount = await db.inventoryItemsDao.countByStatus(ItemStatus.personal);

      expect(activeCount, equals(2));
      expect(soldCount, equals(1));
      expect(personalCount, equals(0));
    });

    test('barcode stored as string preserves leading zeros', () async {
      final now = DateTime.now();
      const upc = '008888511618';
      final id = await db.inventoryItemsDao.insertItem(
        InventoryItemsCompanion.insert(
          dateAdded: now,
          itemDescription: 'Zero Leading UPC Item',
          type: ItemType.game,
          cost: 9.99,
          status: ItemStatus.active,
          barcode: const Value(upc),
        ),
      );

      final item = await db.inventoryItemsDao.getById(id);
      expect(item.barcode, equals(upc));
      expect(item.barcode!.startsWith('00'), isTrue);
    });

    test('watchTotalCostTimesQtyByStatus multiplies cost by quantity', () async {
      final now = DateTime.now();
      await db.inventoryItemsDao.insertItem(
        InventoryItemsCompanion.insert(
          dateAdded: now,
          itemDescription: 'Qty Item',
          type: ItemType.dvd,
          cost: 10.0,
          quantity: const Value(3),
          status: ItemStatus.active,
        ),
      );
      await db.inventoryItemsDao.insertItem(
        InventoryItemsCompanion.insert(
          dateAdded: now,
          itemDescription: 'Sold ignored',
          type: ItemType.dvd,
          cost: 50.0,
          quantity: const Value(2),
          status: ItemStatus.sold,
        ),
      );

      final total = await db.inventoryItemsDao
          .watchTotalCostTimesQtyByStatus(ItemStatus.active)
          .first;
      expect(total, equals(30.0));

      // Legacy sum(cost) stays cost-only
      final costOnly =
          await db.inventoryItemsDao.watchTotalCostByStatus(ItemStatus.active).first;
      expect(costOnly, equals(10.0));
    });

    test('watchAvgDaysToSell averages sold days', () async {
      final added = DateTime(2026, 1, 1);
      await db.inventoryItemsDao.insertItem(
        InventoryItemsCompanion.insert(
          dateAdded: added,
          itemDescription: 'Fast',
          type: ItemType.dvd,
          cost: 5.0,
          status: ItemStatus.sold,
          dateSold: Value(DateTime(2026, 1, 11)), // 10d
        ),
      );
      await db.inventoryItemsDao.insertItem(
        InventoryItemsCompanion.insert(
          dateAdded: added,
          itemDescription: 'Slow',
          type: ItemType.book,
          cost: 3.0,
          status: ItemStatus.sold,
          dateSold: Value(DateTime(2026, 1, 31)), // 30d
        ),
      );
      await db.inventoryItemsDao.insertItem(
        InventoryItemsCompanion.insert(
          dateAdded: added,
          itemDescription: 'Active ignored',
          type: ItemType.game,
          cost: 1.0,
          status: ItemStatus.active,
        ),
      );

      final avg = await db.inventoryItemsDao.watchAvgDaysToSell().first;
      expect(avg, equals(20.0));
    });

    test('watchAgingCapital and buckets use Active age thresholds', () async {
      final now = DateTime.now();
      Future<void> add(String name, int ageDays, double cost, {int qty = 1}) {
        return db.inventoryItemsDao.insertItem(
          InventoryItemsCompanion.insert(
            dateAdded: now.subtract(Duration(days: ageDays)),
            itemDescription: name,
            type: ItemType.other,
            cost: cost,
            quantity: Value(qty),
            status: ItemStatus.active,
          ),
        );
      }

      await add('Fresh', 10, 100); // ignored (<30)
      await add('Mid', 45, 10, qty: 2); // 30–59: $20
      await add('Old', 70, 30); // 60–89: $30
      await add('Ancient', 100, 40); // 90+: $40
      await db.inventoryItemsDao.insertItem(
        InventoryItemsCompanion.insert(
          dateAdded: now.subtract(const Duration(days: 200)),
          itemDescription: 'Sold old',
          type: ItemType.dvd,
          cost: 999,
          status: ItemStatus.sold,
          dateSold: Value(now),
        ),
      );

      final aging = await db.inventoryItemsDao.watchAgingCapital().first;
      expect(aging.itemCount, equals(3));
      expect(aging.totalCostTimesQty, equals(90.0));

      final buckets = await db.inventoryItemsDao.watchAgingBuckets().first;
      expect(buckets.bucket30to59.itemCount, equals(1));
      expect(buckets.bucket30to59.totalCostTimesQty, equals(20.0));
      expect(buckets.bucket60to89.totalCostTimesQty, equals(30.0));
      expect(buckets.bucket90plus.totalCostTimesQty, equals(40.0));
    });

    test('watchSellThrough 90d cohort definition', () async {
      final now = DateTime.now();
      // Active within 90d
      await db.inventoryItemsDao.insertItem(
        InventoryItemsCompanion.insert(
          dateAdded: now.subtract(const Duration(days: 20)),
          itemDescription: 'Active recent',
          type: ItemType.dvd,
          cost: 1,
          status: ItemStatus.active,
        ),
      );
      // Active older than 90d — excluded
      await db.inventoryItemsDao.insertItem(
        InventoryItemsCompanion.insert(
          dateAdded: now.subtract(const Duration(days: 120)),
          itemDescription: 'Active old',
          type: ItemType.dvd,
          cost: 1,
          status: ItemStatus.active,
        ),
      );
      // Sold with dateSold within 90d
      await db.inventoryItemsDao.insertItem(
        InventoryItemsCompanion.insert(
          dateAdded: now.subtract(const Duration(days: 200)),
          itemDescription: 'Sold recent',
          type: ItemType.book,
          cost: 1,
          status: ItemStatus.sold,
          dateSold: Value(now.subtract(const Duration(days: 5))),
        ),
      );
      // Sold with dateSold older than 90d — excluded
      await db.inventoryItemsDao.insertItem(
        InventoryItemsCompanion.insert(
          dateAdded: now.subtract(const Duration(days: 200)),
          itemDescription: 'Sold old',
          type: ItemType.book,
          cost: 1,
          status: ItemStatus.sold,
          dateSold: Value(now.subtract(const Duration(days: 100))),
        ),
      );

      final st = await db.inventoryItemsDao.watchSellThrough().first;
      expect(st.stillActive, equals(1));
      expect(st.sold, equals(1));
      expect(st.listed, equals(2));
      expect(st.rate, equals(0.5));
    });

    test('watchTopMovers returns fastest sold first', () async {
      final added = DateTime(2026, 1, 1);
      await db.inventoryItemsDao.insertItem(
        InventoryItemsCompanion.insert(
          dateAdded: added,
          itemDescription: 'Slow',
          type: ItemType.book,
          cost: 3,
          status: ItemStatus.sold,
          dateSold: Value(DateTime(2026, 1, 20)), // 19d
        ),
      );
      await db.inventoryItemsDao.insertItem(
        InventoryItemsCompanion.insert(
          dateAdded: added,
          itemDescription: 'Fast',
          type: ItemType.dvd,
          cost: 8,
          status: ItemStatus.sold,
          dateSold: Value(DateTime(2026, 1, 5)), // 4d
        ),
      );
      await db.inventoryItemsDao.insertItem(
        InventoryItemsCompanion.insert(
          dateAdded: added,
          itemDescription: 'Mid',
          type: ItemType.game,
          cost: 12,
          status: ItemStatus.sold,
          dateSold: Value(DateTime(2026, 1, 10)), // 9d
        ),
      );

      final top = await db.inventoryItemsDao.watchTopMovers(limit: 3).first;
      expect(top.map((e) => e.itemDescription).toList(),
          equals(['Fast', 'Mid', 'Slow']));
      expect(top.first.daysToSell, equals(4));
    });
  });

  group('ExpensesDao', () {
    test('insert and retrieve expense', () async {
      final now = DateTime.now();
      final id = await db.expensesDao.insertExpense(
        ExpensesCompanion.insert(
          date: now,
          merchant: 'USPS',
          itemDescription: 'Priority Mail Boxes',
          quantity: const Value(3),
          unitPrice: 4.50,
          expenseType: ExpenseType.shipping,
        ),
      );

      final expense = await db.expensesDao.getById(id);
      expect(expense.id, equals(id));
      expect(expense.merchant, equals('USPS'));
      expect(expense.quantity, equals(3));
      expect(expense.unitPrice, equals(4.50));
      expect(expense.total, equals(13.50));
      expect(expense.expenseType, equals(ExpenseType.shipping));
    });

    test('totalForMonth filters correctly', () async {
      final march = DateTime(2026, 3, 15);
      final april = DateTime(2026, 4, 10);

      await db.expensesDao.insertExpense(
        ExpensesCompanion.insert(
          date: march,
          merchant: 'Staples',
          itemDescription: 'Tape',
          quantity: const Value(2),
          unitPrice: 5.00,
          expenseType: ExpenseType.shipping,
        ),
      );
      await db.expensesDao.insertExpense(
        ExpensesCompanion.insert(
          date: march,
          merchant: 'Walmart',
          itemDescription: 'Bubble Wrap',
          quantity: const Value(1),
          unitPrice: 15.00,
          expenseType: ExpenseType.shipping,
        ),
      );
      await db.expensesDao.insertExpense(
        ExpensesCompanion.insert(
          date: april,
          merchant: 'Software Co',
          itemDescription: 'Inventory app',
          quantity: const Value(1),
          unitPrice: 20.00,
          expenseType: ExpenseType.software,
        ),
      );

      final marchTotal = await db.expensesDao.totalForMonth(DateTime(2026, 3, 1));
      final aprilTotal = await db.expensesDao.totalForMonth(DateTime(2026, 4, 1));

      expect(marchTotal, equals(25.00));

      expect(aprilTotal, equals(20.00));
    });

    test('watchMonthlyTotals returns last 6 months qty×unitPrice', () async {
      final anchor = DateTime(2026, 9, 15);
      await db.expensesDao.insertExpense(
        ExpensesCompanion.insert(
          date: DateTime(2026, 9, 2),
          merchant: 'A',
          itemDescription: 'Sep',
          quantity: const Value(2),
          unitPrice: 10.0,
          expenseType: ExpenseType.shipping,
        ),
      );
      await db.expensesDao.insertExpense(
        ExpensesCompanion.insert(
          date: DateTime(2026, 8, 10),
          merchant: 'B',
          itemDescription: 'Aug',
          quantity: const Value(1),
          unitPrice: 40.0,
          expenseType: ExpenseType.other,
        ),
      );
      await db.expensesDao.insertExpense(
        ExpensesCompanion.insert(
          date: DateTime(2026, 1, 1),
          merchant: 'C',
          itemDescription: 'Too old',
          quantity: const Value(1),
          unitPrice: 999.0,
          expenseType: ExpenseType.other,
        ),
      );

      final months = await db.expensesDao
          .watchMonthlyTotals(monthCount: 6, anchor: anchor)
          .first;
      expect(months.length, equals(6));
      expect(months.first.month, equals(DateTime(2026, 4, 1)));
      expect(months.last.month, equals(DateTime(2026, 9, 1)));
      expect(months.last.total, equals(20.0));
      expect(months[4].total, equals(40.0)); // August (index 4 of Apr..Sep)
      expect(months[0].total, equals(0.0));
    });

    test('watchMonthlyTotals monthCount 24 includes older months', () async {
      final anchor = DateTime(2026, 9, 15);
      await db.expensesDao.insertExpense(
        ExpensesCompanion.insert(
          date: DateTime(2025, 1, 10),
          merchant: 'Old',
          itemDescription: 'Jan 2025',
          quantity: const Value(1),
          unitPrice: 12.0,
          expenseType: ExpenseType.other,
        ),
      );

      final months = await db.expensesDao
          .watchMonthlyTotals(monthCount: 24, anchor: anchor)
          .first;
      expect(months.length, equals(24));
      expect(months.first.month, equals(DateTime(2024, 10, 1)));
      expect(months.last.month, equals(DateTime(2026, 9, 1)));
      final jan2025 = months.firstWhere(
        (m) => m.month == DateTime(2025, 1, 1),
      );
      expect(jan2025.total, equals(12.0));
    });
  });

  group('BarcodeCacheDao'
, () {
    test('barcode cache lookup returns null on miss', () async {
      final result = await db.barcodeCacheDao.lookup('unknown_upc');
      expect(result, isNull);
    });

    test('barcode cache insertOrUpdate then lookup', () async {
      const upc = '810142295154';
      final now = DateTime.now();

      await db.barcodeCacheDao.insertOrUpdate(
        BarcodeCacheEntriesCompanion.insert(
          barcode: upc,
          productName: const Value('Duck Brand Bubble Wrap'),
          description: const Value('175 ft bubble cushioning roll'),
          imageUrl: const Value('https://example.com/bubble.jpg'),
          category: const Value('Shipping Supplies'),
          source: 'UPC Database',
          fetchedAt: now,
        ),
      );

      final cached = await db.barcodeCacheDao.lookup(upc);
      expect(cached, isNotNull);
      expect(cached!.barcode, equals(upc));
      expect(cached.productName, equals('Duck Brand Bubble Wrap'));
      expect(cached.source, equals('UPC Database'));
    });
  });
}
