import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/providers/inventory_provider.dart';
import 'package:flipbin/screens/inventory/item_detail_screen.dart';

void main() {
  testWidgets('mark sold button updates active item state', (tester) async {
    final item = InventoryItem(
      id: 42,
      dateAdded: DateTime(2026, 9, 29),
      itemDescription: 'Test Item',
      type: ItemType.game,
      cost: 10,
      quantity: 1,
      status: ItemStatus.active,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryItemProvider(42).overrideWith((ref) => Future.value(item)),
        ],
        child: const MaterialApp(
          home: ItemDetailScreen(itemId: '42'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('markSoldButton')), findsOneWidget);
    expect(find.byTooltip('Mark sold'), findsOneWidget);
    expect(find.text('Not Sold'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('markSoldButton')));
    await tester.tap(find.byKey(const Key('markSoldButton')));
    await tester.pump();

    expect(find.byTooltip('Sold'), findsOneWidget);
    expect(find.text('Not Sold'), findsNothing);
    final dateSoldTile = find.ancestor(
      of: find.text('Date Sold'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(of: dateSoldTile, matching: find.text('2026-09-29')),
      findsOneWidget,
    );
  });

  testWidgets('mark sold button is muted and inactive for sold item',
      (tester) async {
    final item = InventoryItem(
      id: 43,
      dateAdded: DateTime(2026, 9, 29),
      itemDescription: 'Already Sold Item',
      type: ItemType.game,
      cost: 10,
      quantity: 1,
      status: ItemStatus.sold,
      dateSold: DateTime(2026, 9, 28),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryItemProvider(43).overrideWith((ref) => Future.value(item)),
        ],
        child: const MaterialApp(
          home: ItemDetailScreen(itemId: '43'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Sold'), findsOneWidget);
    expect(find.byTooltip('Mark sold'), findsNothing);
    final dateSoldTile = find.ancestor(
      of: find.text('Date Sold'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(of: dateSoldTile, matching: find.text('2026-09-28')),
      findsOneWidget,
    );
  });
}
