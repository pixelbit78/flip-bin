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

      final activeList = await db.inventoryItemsDao
          .watchAll(statusFilter: ItemStatus.active)
          .first;
      expect(activeList.length, equals(2));

      final soldList = await db.inventoryItemsDao
          .watchAll(statusFilter: ItemStatus.sold)
          .first;
      expect(soldList.length, equals(1));
      expect(soldList.first.itemDescription, equals('Item 3'));
    });

    test('watchAll filters personal separately from sold', () async {
      final now = DateTime.now();
      await db.inventoryItemsDao.insertItem(
        InventoryItemsCompanion.insert(
          dateAdded: now,
          itemDescription: 'Keep Active',
          type: ItemType.game,
          cost: 5.0,
          status: ItemStatus.active,
        ),
      );
      await db.inventoryItemsDao.insertItem(
        InventoryItemsCompanion.insert(
          dateAdded: now,
          itemDescription: 'Shelf Copy',
          type: ItemType.dvd,
          cost: 0.0,
          status: ItemStatus.personal,
        ),
      );
      await db.inventoryItemsDao.insertItem(
        InventoryItemsCompanion.insert(
          dateAdded: now,
          itemDescription: 'Sold Copy',
          type: ItemType.bluray,
          cost: 6.0,
          status: ItemStatus.sold,
        ),
      );

      final personal = await db.inventoryItemsDao
          .watchAll(statusFilter: ItemStatus.personal)
          .first;
      expect(personal.length, equals(1));
      expect(personal.first.itemDescription, equals('Shelf Copy'));
      expect(personal.first.status, equals(ItemStatus.personal));

      final sold = await db.inventoryItemsDao
          .watchAll(statusFilter: ItemStatus.sold)
          .first;
      expect(
          sold.map((e) => e.itemDescription).toList(), equals(['Sold Copy']));

      final all = await db.inventoryItemsDao.watchAll().first;
      expect(all.length, equals(3));
    });

    test('watchByBarcodeActiveOrPersonal returns active/personal only',
        () async {
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

      final searchResults =
          await db.inventoryItemsDao.watchAll(searchQuery: 'mario').first;
      expect(searchResults.length, equals(1));
      expect(
          searchResults.first.itemDescription, equals('Super Mario Sunshine'));
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

      final activeCount =
          await db.inventoryItemsDao.countByStatus(ItemStatus.active);
      final soldCount =
          await db.inventoryItemsDao.countByStatus(ItemStatus.sold);
      final personalCount =
          await db.inventoryItemsDao.countByStatus(ItemStatus.personal);

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

      final marchTotal =
          await db.expensesDao.totalForMonth(DateTime(2026, 3, 1));
      final aprilTotal =
          await db.expensesDao.totalForMonth(DateTime(2026, 4, 1));

      expect(marchTotal, equals(25.00));
      expect(aprilTotal, equals(20.00));
    });
  });

  group('BarcodeCacheDao', () {
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
