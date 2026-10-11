import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flipbin/app/theme.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/providers/database_provider.dart';
import 'package:flipbin/screens/inventory/inventory_list_screen.dart';

/// L-02 follow-up: the Inventory status chip is its own button semantics node
/// (not merged into the row), and activating it runs the sell flow, not Edit.
void main() {
  late FlipBinDatabase db;
  setUp(() => db = FlipBinDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 6; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await t.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('status chip: separate button node; tap -> sell sheet, not Edit',
      (t) async {
    t.view.physicalSize = const Size(412, 839);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final handle = t.ensureSemantics();
    await t.runAsync(() async {
      await db.inventoryItemsDao.insertItem(InventoryItemsCompanion.insert(
        dateAdded: DateTime(2026, 9, 1),
        itemDescription: 'Lot A',
        type: ItemType.vhs,
        cost: 6,
        quantity: const Value(3),
        costPerItem: const Value(2),
        status: ItemStatus.active,
      ));
      await db.inventoryItemsDao.insertItem(InventoryItemsCompanion.insert(
        dateAdded: DateTime(2026, 8, 1),
        itemDescription: 'Sold one',
        type: ItemType.game,
        cost: 4,
        status: ItemStatus.sold,
        dateSold: Value(DateTime(2026, 9, 2)),
      ));
    });
    final router = GoRouter(initialLocation: '/inventory', routes: [
      GoRoute(
        path: '/inventory',
        builder: (_, __) => const InventoryListScreen(),
        routes: [
          GoRoute(
              path: ':id',
              builder: (_, __) => const Scaffold(body: Text('EDIT SCREEN'))),
        ],
      ),
    ]);
    await t.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp.router(theme: FlipBinTheme.dark, routerConfig: router),
    ));
    await settle(t);

    const activeLabel = 'Status Active, tap to mark sold';
    final chip = find.bySemanticsLabel(activeLabel);
    expect(chip, findsOneWidget);
    final node = t.getSemantics(chip);
    expect(
      node,
      matchesSemantics(
          label: activeLabel, isButton: true, hasTapAction: true),
      reason: 'own node, not merged with the row',
    );
    expect(node.rect.width, greaterThanOrEqualTo(44));
    expect(node.rect.height, greaterThanOrEqualTo(44));

    // The row's own node must not carry the chip's label.
    final row = t.getSemantics(find.text('Lot A'));
    expect(row.id, isNot(node.id));
    expect(row.getSemanticsData().label, isNot(contains('Status Active')));

    // Sold chip: separate, non-button node.
    final sold = t.getSemantics(find.bySemanticsLabel('Status Sold'));
    expect(sold, matchesSemantics(label: 'Status Sold'));

    // Activate the chip like a screen reader would.
    t.semantics.tap(find.semantics.byLabel(activeLabel));
    await settle(t);
    await t.pumpAndSettle();
    expect(find.text('How many sold?'), findsOneWidget);
    expect(find.text('EDIT SCREEN'), findsNothing);

    handle.dispose();
    await t.pumpWidget(const SizedBox());
    await settle(t);
    await t.pump(const Duration(seconds: 1));
  });
}
