import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/providers/database_provider.dart';
import 'package:flipbin/providers/inventory_provider.dart';
import 'package:flipbin/screens/inventory/inventory_list_screen.dart';
import 'package:flipbin/screens/inventory/item_detail_screen.dart';
import 'package:flipbin/widgets/status_badge.dart';

void main() {
  final sampleItems = [
    InventoryItem(
      id: 1,
      dateAdded: DateTime.now(),
      itemDescription: 'Super Mario Galaxy',
      type: ItemType.game,
      cost: 15.00,
      quantity: 1,
      status: ItemStatus.active,
    ),
    InventoryItem(
      id: 2,
      dateAdded: DateTime.now(),
      itemDescription: 'The Matrix 4K',
      type: ItemType.bluray,
      cost: 8.50,
      quantity: 1,
      status: ItemStatus.sold,
    ),
    InventoryItem(
      id: 3,
      dateAdded: DateTime.now(),
      itemDescription: 'Personal Zelda Copy',
      type: ItemType.game,
      cost: 0.00,
      quantity: 1,
      status: ItemStatus.personal,
    ),
  ];

  testWidgets('inventory list shows items with type and status badges',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryListProvider(const InventoryFilter()).overrideWith(
            (ref) => Stream.value(sampleItems),
          ),
        ],
        child: const MaterialApp(
          home: InventoryListScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Super Mario Galaxy'), findsOneWidget);
    expect(find.text('The Matrix 4K'), findsOneWidget);
    expect(find.text('Personal Zelda Copy'), findsOneWidget);
    expect(find.text('\$15.00'), findsOneWidget);
    expect(find.text('\$8.50'), findsOneWidget);
    expect(find.text('Game'), findsNWidgets(2));
    expect(find.text('Blu-ray'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(StatusBadge), matching: find.text('Active')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(StatusBadge), matching: find.text('Sold')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(StatusBadge), matching: find.text('Personal')),
        findsOneWidget);
  });

  testWidgets('filter chips filter by status', (tester) async {
    InventoryFilter? capturedFilter;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryListProvider.overrideWith(
            (ref, filter) {
              capturedFilter = filter;
              return Stream.value(sampleItems);
            },
          ),
        ],
        child: const MaterialApp(
          home: InventoryListScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final soldChip = find.widgetWithText(FilterChip, 'Sold');
    expect(soldChip, findsOneWidget);
    await tester.tap(soldChip);
    await tester.pumpAndSettle();

    expect(capturedFilter?.statusFilter, equals(ItemStatus.sold));
  });

  testWidgets(
      'Personal filter chip selects personal status and shows personal rows', (
    tester,
  ) async {
    InventoryFilter? capturedFilter;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryListProvider.overrideWith(
            (ref, filter) {
              capturedFilter = filter;
              final items = filter.statusFilter == null
                  ? sampleItems
                  : sampleItems
                      .where((i) => i.status == filter.statusFilter)
                      .toList();
              return Stream.value(items);
            },
          ),
        ],
        child: const MaterialApp(
          home: InventoryListScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Personal Zelda Copy'), findsOneWidget);

    final personalChip = find.widgetWithText(FilterChip, 'Personal');
    expect(personalChip, findsOneWidget);
    await tester.tap(personalChip);
    await tester.pumpAndSettle();

    expect(capturedFilter?.statusFilter, equals(ItemStatus.personal));
    expect(find.text('Personal Zelda Copy'), findsOneWidget);
    expect(find.text('Super Mario Galaxy'), findsNothing);
    expect(find.text('The Matrix 4K'), findsNothing);
    expect(find.text('No items found'), findsNothing);
  });

  testWidgets('search bar filters items', (tester) async {
    InventoryFilter? capturedFilter;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryListProvider.overrideWith(
            (ref, filter) {
              capturedFilter = filter;
              return Stream.value(sampleItems);
            },
          ),
        ],
        child: const MaterialApp(
          home: InventoryListScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final searchField = find.byType(TextField);
    expect(searchField, findsOneWidget);
    await tester.enterText(searchField, 'mario');
    await tester.pumpAndSettle();

    expect(capturedFilter?.searchQuery, equals('mario'));
  });

  testWidgets('item detail form validates required fields', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ItemDetailScreen(itemId: 'new'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final saveButton = find.widgetWithText(ElevatedButton, 'Save');
    expect(saveButton, findsOneWidget);
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Description is required'), findsOneWidget);
  });

  testWidgets('status change to sold auto-fills date sold', (tester) async {
    final activeItem = InventoryItem(
      id: 10,
      dateAdded: DateTime.now(),
      itemDescription: 'Test Item',
      type: ItemType.game,
      cost: 10.0,
      quantity: 1,
      status: ItemStatus.active,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryItemProvider(10)
              .overrideWith((ref) => Future.value(activeItem)),
        ],
        child: const MaterialApp(
          home: ItemDetailScreen(itemId: '10'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initial status is Active and Date Sold is Not Sold
    expect(find.text('Not Sold'), findsOneWidget);

    // Tap Status dropdown and change to Sold
    final statusDropdown =
        find.widgetWithText(DropdownButtonFormField<ItemStatus>, 'Active');
    await tester.tap(statusDropdown);
    await tester.pumpAndSettle();

    final soldOption = find.text('Sold').last;
    await tester.tap(soldOption);
    await tester.pumpAndSettle();

    // Date Sold field should now show today's date formatted
    expect(find.text('Not Sold'), findsNothing);
  });

  testWidgets('item detail hides Platform and Sale Number fields',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ItemDetailScreen(itemId: 'new'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Platform (e.g. PS5, Xbox)'), findsNothing);
    expect(find.text('Sale Number / Order ID'), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'Save'), findsOneWidget);
  });

  testWidgets('item detail Save stays anchored while form scrolls',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SizedBox(
            width: 390,
            height: 700,
            child: ItemDetailScreen(itemId: 'new'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final saveButton = find.widgetWithText(ElevatedButton, 'Save');
    expect(saveButton, findsOneWidget);
    // Save should be visible without scrolling (anchored at bottom).
    expect(tester.getRect(saveButton).bottom, lessThanOrEqualTo(700));

    // Scroll the form; Save remains on screen.
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(saveButton, findsOneWidget);
    expect(tester.getRect(saveButton).bottom, lessThanOrEqualTo(700));
  });

  testWidgets('editing other fields preserves hidden platform and saleNumber', (
    tester,
  ) async {
    final db = FlipBinDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final id = await db.inventoryItemsDao.insertItem(
      InventoryItemsCompanion.insert(
        dateAdded: DateTime(2026, 1, 10),
        itemDescription: 'Kept Fields Item',
        type: ItemType.game,
        cost: 12.0,
        status: ItemStatus.active,
        platform: const Value('eBay'),
        saleNumber: const Value('ORD-999'),
        comments: const Value('old note'),
      ),
    );

    final router = GoRouter(
      initialLocation: '/inventory/$id',
      routes: [
        GoRoute(
          path: '/inventory',
          builder: (_, __) => const Scaffold(body: Text('Inventory List')),
          routes: [
            GoRoute(
              path: ':id',
              builder: (_, state) => ItemDetailScreen(
                itemId: state.pathParameters['id']!,
              ),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Platform (e.g. PS5, Xbox)'), findsNothing);
    expect(find.text('Sale Number / Order ID'), findsNothing);

    // Comments field may need scrolling into view behind Save bar.
    await tester.ensureVisible(find.byType(TextFormField).last);
    await tester.enterText(find.byType(TextFormField).last, 'updated note');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    final saved = await db.inventoryItemsDao.getById(id);
    expect(saved.platform, equals('eBay'));
    expect(saved.saleNumber, equals('ORD-999'));
    expect(saved.comments, equals('updated note'));
    expect(saved.itemDescription, equals('Kept Fields Item'));
  });
}
