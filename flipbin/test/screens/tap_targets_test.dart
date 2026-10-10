import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flipbin/app/theme.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/providers/inventory_provider.dart';
import 'package:flipbin/screens/inventory/item_detail_screen.dart';

import '../support/tap_targets.dart';

/// BUG-05/06: 412 px wide phone, but on a desktop platform so Flutter would
/// default to compact density (what web on desktop browsers gets).
Future<void> phone(WidgetTester t, Widget child, {List<Override> o = const []}) async {
  t.view.physicalSize = const Size(412, 839);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: o,
    child: MaterialApp(theme: FlipBinTheme.dark, home: child),
  ));
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
}

void main() {
  final desktop = TargetPlatformVariant.only(TargetPlatform.linux);

  testWidgets('BUG-06: Edit Item (lot) has no tappable under 44px', (t) async {
    final item = InventoryItem(
      id: 7,
      dateAdded: DateTime(2026, 7, 1),
      itemDescription: 'VHS bulk',
      type: ItemType.vhs,
      cost: 15,
      quantity: 10,
      costPerItem: 1.5,
      status: ItemStatus.active,
    );
    await phone(t, const ItemDetailScreen(itemId: '7'), o: [
      soldChildUnitsProvider.overrideWith((ref) => Stream.value(const <int, int>{})),
      inventoryItemProvider(7).overrideWith((ref) => Stream.value(item)),
    ]);
    // Check the whole scrollable form, page by page.
    final scrollable = find.byType(Scrollable).first;
    for (var i = 0; i < 8; i++) {
      expectAllTappablesAtLeast(t);
      await t.drag(scrollable, const Offset(0, -300));
      await t.pump();
    }
    expect(t.getSize(find.byKey(const Key('itemSaveButton'))).height,
        greaterThanOrEqualTo(44));
  }, variant: desktop);

  testWidgets('BUG-06: Add Item has no tappable under 44px', (t) async {
    await phone(t, const ItemDetailScreen(itemId: 'new'), o: [
      soldChildUnitsProvider.overrideWith((ref) => Stream.value(const <int, int>{})),
    ]);
    final scrollable = find.byType(Scrollable).first;
    for (var i = 0; i < 8; i++) {
      expectAllTappablesAtLeast(t);
      await t.drag(scrollable, const Offset(0, -300));
      await t.pump();
    }
  }, variant: desktop);

  testWidgets(
      'BUG-05: scanner result-row button constructions are >= 44px '
      '(Save as sold / Add to Inventory / Add to Expense / Look Up)', (t) async {
    // Same widget constructions as scanner_screen.dart (the screen itself needs
    // a live camera controller, so it isn't pumped here).
    await phone(
      t,
      Scaffold(
        body: Column(children: [
          Row(children: [
            const Expanded(child: TextField(decoration: InputDecoration(isDense: true))),
            ElevatedButton(onPressed: () {}, child: const Text('Look Up')),
          ]),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                  onPressed: () {}, icon: const Icon(Icons.add_box), label: const Text('Add to Inventory')),
            ),
            Expanded(
              child: OutlinedButton.icon(
                  onPressed: () {}, icon: const Icon(Icons.post_add), label: const Text('Add to Expense')),
            ),
          ]),
          ElevatedButton(onPressed: () {}, child: const Text('Save as sold')),
          IconButton(onPressed: () {}, icon: const Icon(Icons.flash_on)),
          TextButton(onPressed: () {}, child: const Text('x')),
          FilledButton(onPressed: () {}, child: const Text('y')),
        ]),
      ),
    );
    expectAllTappablesAtLeast(t);
  }, variant: desktop);
}
