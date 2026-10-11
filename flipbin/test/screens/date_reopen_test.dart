import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/providers/database_provider.dart';
import 'package:flipbin/screens/inventory/item_detail_screen.dart';

// Edit Item must show the latest DB row on every open (date-reopen bug).
// Throwaway in-memory DB only.
void main() {
  late FlipBinDatabase db;
  setUp(() => db = FlipBinDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 6; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await t.pump(const Duration(milliseconds: 50));
    }
    await t.pumpAndSettle();
  }

  Widget app() {
    final router = GoRouter(initialLocation: '/inventory', routes: [
      GoRoute(
        path: '/inventory',
        builder: (c, __) => Scaffold(
          body: Column(children: [
            TextButton(onPressed: () => c.go('/inventory/1'), child: const Text('open1')),
          ]),
        ),
        routes: [
          GoRoute(
              path: ':id',
              builder: (_, s) => ItemDetailScreen(itemId: s.pathParameters['id']!)),
        ],
      ),
    ]);
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Future<void> run(WidgetTester t, ItemStatus st, String tileLabel) async {
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.runAsync(() => db.inventoryItemsDao.insertItem(InventoryItemsCompanion.insert(
          dateAdded: DateTime(2026, 8, 3),
          itemDescription: 'Date item',
          type: ItemType.game,
          cost: 5,
          status: st,
          dateSold: Value(st == ItemStatus.sold ? DateTime(2026, 8, 5) : null),
        )));
    await t.pumpWidget(app());
    await settle(t);
    await t.tap(find.text('open1'));
    await settle(t);
    await t.tap(find.text(tileLabel));
    await t.pumpAndSettle();
    await t.tap(find.text('20'));
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    final save = find.widgetWithText(ElevatedButton, 'Save');
    await t.ensureVisible(save);
    await t.tap(save);
    await settle(t);
    expect(find.text('open1'), findsOneWidget, reason: 'back on list');
    final row = (await t.runAsync(() => db.inventoryItemsDao.getById(1)))!;
    final dbDate = st == ItemStatus.sold ? row.dateSold! : row.dateAdded;
    expect(dbDate.day, 20, reason: 'save persisted');
    // Reopen.
    await t.tap(find.text('open1'));
    await settle(t);
    final shown = DateFormat('yyyy-MM-dd').format(dbDate);
    final tile = find.ancestor(of: find.text(tileLabel), matching: find.byType(ListTile));
    expect(find.descendant(of: tile, matching: find.text(shown)), findsOneWidget,
        reason: 'reopened Edit Item shows DB value $shown');
    await t.pumpWidget(const SizedBox());
    await settle(t);
    await t.pump(const Duration(seconds: 1));
  }

  testWidgets('reopen after Date Added change (Active)', (t) => run(t, ItemStatus.active, 'Date Added'));
  testWidgets('reopen after Date Sold change (Sold)', (t) => run(t, ItemStatus.sold, 'Date Sold'));

  testWidgets('every field: DB change while closed or open shows on Edit Item',
      (t) async {
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.runAsync(() => db.inventoryItemsDao.insertItem(InventoryItemsCompanion.insert(
          dateAdded: DateTime(2026, 8, 3),
          itemDescription: 'Before',
          type: ItemType.game,
          cost: 5,
          status: ItemStatus.active,
        )));
    await t.pumpWidget(app());
    await settle(t);
    await t.tap(find.text('open1'));
    await settle(t);
    expect(find.text('Before'), findsOneWidget);
    // Changed underneath while the untouched form is open.
    Future<void> update(String d, DateTime added, String upc, ItemType type) async {
      final cur = (await t.runAsync(() => db.inventoryItemsDao.getById(1)))!;
      await t.runAsync(() => db.inventoryItemsDao.updateItem(cur.copyWith(
            itemDescription: d,
            dateAdded: added,
            barcode: Value(upc),
            type: type,
            imageUrl: const Value('https://example.invalid/x.png'),
          )));
    }
    await update('After', DateTime(2026, 8, 21), '012993441012', ItemType.vhs);
    await settle(t);
    expect(find.text('After'), findsOneWidget);
    expect(find.text('2026-08-21'), findsOneWidget);
    expect(find.text('012993441012'), findsOneWidget);
    // Close, change again, reopen.
    t.state<NavigatorState>(find.byType(Navigator).last).pop();
    await settle(t);
    await update('Again', DateTime(2026, 8, 22), '4006381333931', ItemType.game);
    await t.tap(find.text('open1'));
    await settle(t);
    expect(find.text('Again'), findsOneWidget);
    expect(find.text('2026-08-22'), findsOneWidget);
    expect(find.text('4006381333931'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await settle(t);
    await t.pump(const Duration(seconds: 1));
  });
}
