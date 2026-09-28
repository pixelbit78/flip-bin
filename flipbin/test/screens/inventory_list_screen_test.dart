import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/enums.dart';
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
  ];

  testWidgets('inventory list shows items with type and status badges', (tester) async {
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
    expect(find.text('\$15.00'), findsOneWidget);
    expect(find.text('\$8.50'), findsOneWidget);
    expect(find.text('Game'), findsOneWidget);
    expect(find.text('Blu-ray'), findsOneWidget);
    expect(find.descendant(of: find.byType(StatusBadge), matching: find.text('Active')), findsOneWidget);
    expect(find.descendant(of: find.byType(StatusBadge), matching: find.text('Sold')), findsOneWidget);
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
          inventoryItemProvider(10).overrideWith((ref) => Future.value(activeItem)),
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
    final statusDropdown = find.widgetWithText(DropdownButtonFormField<ItemStatus>, 'Active');
    await tester.tap(statusDropdown);
    await tester.pumpAndSettle();

    final soldOption = find.text('Sold').last;
    await tester.tap(soldOption);
    await tester.pumpAndSettle();

    // Date Sold field should now show today's date formatted
    expect(find.text('Not Sold'), findsNothing);
  });
}
