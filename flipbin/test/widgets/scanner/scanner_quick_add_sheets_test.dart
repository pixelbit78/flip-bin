import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flipbin/app/theme.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/providers/database_provider.dart';
import 'package:flipbin/providers/expense_provider.dart';
import 'package:flipbin/providers/inventory_provider.dart';
import 'package:flipbin/services/barcode_lookup_service.dart';
import 'package:flipbin/widgets/scanner/scanner_quick_add_sheets.dart';

const _scan = BarcodeResult(
  barcode: '363736111540',
  productName: 'URISTAT Ultra UTI Pain Relief Cranberry',
  category: 'Health > OTC',
  imageUrl: null,
  source: 'upcitemdb',
);

void main() {
  late FlipBinDatabase db;

  setUp(() {
    db = FlipBinDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget wrap(Widget child) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: FlipBinTheme.dark,
        home: Scaffold(body: child),
      ),
    );
  }

  group('ScannerInventoryQuickAddSheet UI', () {
    testWidgets('renders product summary, cost, status, helpers',
        (tester) async {
      await tester.pumpWidget(
        wrap(const ScannerInventoryQuickAddSheet(scan: _scan)),
      );
      await tester.pump();

      expect(find.text('Add to Inventory'), findsOneWidget);
      expect(find.byKey(const Key('scannerProductSummary')), findsOneWidget);
      expect(find.textContaining('URISTAT'), findsWidgets);
      expect(find.textContaining('363736111540'), findsWidgets);
      expect(find.byKey(const Key('scannerInventoryCost')), findsOneWidget);
      expect(find.byKey(const Key('scannerInventoryStatus')), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Sold'), findsOneWidget);
      expect(find.text('Personal'), findsOneWidget);
      expect(find.text('Sold sets Date Sold to today.'), findsOneWidget);
      expect(
        find.text('Title, UPC, category & cover come from the scan.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('scannerQuickAddCancel')), findsOneWidget);
      expect(find.byKey(const Key('scannerQuickAddOk')), findsOneWidget);
    });

    testWidgets('OK without cost shows validation error', (tester) async {
      await tester.pumpWidget(
        wrap(const ScannerInventoryQuickAddSheet(scan: _scan)),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('scannerQuickAddOk')));
      await tester.pump();

      expect(find.text('Cost is required'), findsOneWidget);
    });

    testWidgets('Sold segment can be selected', (tester) async {
      await tester.pumpWidget(
        wrap(const ScannerInventoryQuickAddSheet(scan: _scan)),
      );
      await tester.pump();

      await tester.tap(find.text('Sold'));
      await tester.pump();
      // Still on sheet — no navigation.
      expect(find.text('Add to Inventory'), findsOneWidget);
      expect(find.text('Sold'), findsOneWidget);
    });
  });

  group('ScannerExpenseQuickAddSheet UI', () {
    testWidgets('renders fields with defaults', (tester) async {
      await tester.pumpWidget(
        wrap(const ScannerExpenseQuickAddSheet(scan: _scan)),
      );
      await tester.pump();

      expect(find.text('Add to Expense'), findsOneWidget);
      expect(find.byKey(const Key('scannerExpenseAmount')), findsOneWidget);
      expect(find.byKey(const Key('scannerExpenseQuantity')), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.byKey(const Key('scannerExpenseDate')), findsOneWidget);
      expect(
        find.byKey(const Key('scannerExpenseDescription')),
        findsOneWidget,
      );
      expect(find.textContaining('URISTAT'), findsWidgets);
      expect(find.text('Shipping'), findsOneWidget);
      expect(find.text('Business'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
      expect(
        find.text('UPC linked from scan when available.'),
        findsOneWidget,
      );
    });

    testWidgets('OK without amount shows validation error', (tester) async {
      await tester.pumpWidget(
        wrap(const ScannerExpenseQuickAddSheet(scan: _scan)),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('scannerQuickAddOk')));
      await tester.pump();

      expect(find.text('Amount is required'), findsOneWidget);
    });
  });

  group('quick-add save paths (controllers)', () {
    test('inventory Active save from scan metadata', () async {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final title = scanProductTitle(_scan);
      final type = ItemType.fromCategory(_scan.category);
      await container.read(inventoryControllerProvider).saveInventoryItem(
            InventoryItemsCompanion.insert(
              dateAdded: DateTime.now(),
              itemDescription: title,
              type: type,
              cost: 12.50,
              quantity: const Value(1),
              status: ItemStatus.active,
              barcode: Value(_scan.barcode),
            ),
          );

      final items = await db.inventoryItemsDao.getAllForExport();
      expect(items.length, 1);
      expect(items.first.cost, 12.50);
      expect(items.first.status, ItemStatus.active);
      expect(items.first.dateSold, isNull);
      expect(items.first.barcode, _scan.barcode);
      expect(items.first.itemDescription, title);
    });

    test('inventory Sold save stamps dateSold today', () async {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final now = DateTime.now();
      await container.read(inventoryControllerProvider).saveInventoryItem(
            InventoryItemsCompanion.insert(
              dateAdded: now,
              itemDescription: scanProductTitle(_scan),
              type: ItemType.fromCategory(_scan.category),
              cost: 5,
              status: ItemStatus.sold,
              dateSold: Value(now),
              barcode: Value(_scan.barcode),
            ),
          );

      final items = await db.inventoryItemsDao.getAllForExport();
      expect(items.single.status, ItemStatus.sold);
      expect(items.single.dateSold, isNotNull);
      expect(items.single.dateSold!.day, now.day);
    });

    test('expense save links UPC and Business type', () async {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      await container.read(expenseControllerProvider).saveExpense(
            ExpensesCompanion.insert(
              date: DateTime.now(),
              merchant: '',
              itemDescription: scanProductTitle(_scan),
              quantity: const Value(1),
              unitPrice: 8.99,
              expenseType: ExpenseType.business,
              upc: Value(_scan.barcode),
            ),
          );

      final expenses = await db.expensesDao.getAllForExport();
      expect(expenses.length, 1);
      expect(expenses.first.unitPrice, 8.99);
      expect(expenses.first.expenseType, ExpenseType.business);
      expect(expenses.first.upc, _scan.barcode);
    });
  });

  group('helpers', () {
    test('scanProductTitle falls back to UPC', () {
      expect(
        scanProductTitle(const BarcodeResult(barcode: '123', source: 'x')),
        'UPC 123',
      );
      expect(
        scanProductTitle(
          const BarcodeResult(
            barcode: '1',
            productName: 'Name',
            source: 'x',
          ),
        ),
        'Name',
      );
    });

    test('ExpenseType.scannerQuickAdd matches SoT chips', () {
      expect(
        ExpenseType.scannerQuickAdd.map((e) => e.label).toList(),
        ['Shipping', 'Business', 'Other'],
      );
    });
  });
}
