import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/providers/inventory_provider.dart';
import 'package:flipbin/screens/inventory/inventory_list_screen.dart';
import 'package:flipbin/screens/inventory/item_detail_screen.dart';
import 'package:flipbin/widgets/sell_quantity_sheet.dart';

InventoryItem lot({int id = 7, int qty = 17, double cost = 4.65, double? cpi = 0.2735}) =>
    InventoryItem(
      id: id,
      dateAdded: DateTime(2026, 9, 1),
      itemDescription: '17 comics',
      type: ItemType.book,
      cost: cost,
      quantity: qty,
      costPerItem: cpi,
      status: ItemStatus.active,
    );

void main() {
  testWidgets('Edit Item qty > 1: Cost per item label, 4dp value, read-only total',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        inventoryItemProvider(7).overrideWith((ref) => Future.value(lot())),
      ],
      child: const MaterialApp(home: ItemDetailScreen(itemId: '7')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Cost per item (\$)'), findsOneWidget);
    expect(find.text('0.2735'), findsOneWidget);
    expect(find.byKey(const Key('editTotalCost')), findsOneWidget);
    // Stored total is shown untouched (no recompute on open).
    expect(find.text('\$ 4.65'), findsOneWidget);
    // Formatter: [0-9.] only.
    await tester.enterText(find.byKey(const Key('editCostPerItem')), '-3a.5');
    await tester.pump();
    expect(find.text('3.5'), findsOneWidget);
    expect(find.text('\$ 59.50'), findsOneWidget); // 17 × 3.5
  });

  testWidgets('Edit Item qty 1: Cost (\$), no total', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        inventoryItemProvider(8).overrideWith(
            (ref) => Future.value(lot(id: 8, qty: 1, cost: 10, cpi: 10))),
      ],
      child: const MaterialApp(home: ItemDetailScreen(itemId: '8')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Cost (\$)'), findsOneWidget);
    expect(find.byKey(const Key('editTotalCost')), findsNothing);
  });

  testWidgets('Inventory list lot row shows ×N, total and ea; x of y sold',
      (tester) async {
    final parent = lot(id: 1, qty: 75, cost: 85.50, cpi: 1.14);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        soldChildUnitsProvider.overrideWith((ref) => Stream.value({1: 20})),
        inventoryListProvider(const InventoryFilter())
            .overrideWith((ref) => Stream.value([parent])),
      ],
      child: const MaterialApp(home: InventoryListScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('×75'), findsOneWidget);
    expect(find.text('\$85.50'), findsOneWidget);
    expect(find.text('\$1.14 ea'), findsOneWidget);
    expect(find.text('20 of 95 sold'), findsOneWidget);
  });

  testWidgets('Sell sheet defaults to All and previews a split', (tester) async {
    SellChoice? result;
    final item = lot(qty: 23, cost: 46, cpi: 2);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => ElevatedButton(
          onPressed: () async => result = await showSellQuantitySheet(ctx, item),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('How many sold?'), findsOneWidget);
    expect(find.byKey(const Key('sellQtyValue')), findsOneWidget);
    expect(find.text('23'), findsOneWidget);
    expect(find.textContaining('Sell all 23'), findsOneWidget);
    for (var i = 0; i < 18; i++) {
      await tester.tap(find.byKey(const Key('sellQtyMinus')));
    }
    await tester.pump();
    expect(find.textContaining('Sell 5 of 23 → 18 stay Active (\$36.00)'),
        findsOneWidget);
    expect(find.textContaining('×5, \$10.00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sellConfirm')));
    await tester.pumpAndSettle();
    expect(result?.units, 5);
  });
}
