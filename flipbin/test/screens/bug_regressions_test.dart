import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/providers/database_provider.dart';
import 'package:flipbin/screens/inventory/item_detail_screen.dart';

void main() {
  late FlipBinDatabase db;
  setUp(() => db = FlipBinDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> addVhs(WidgetTester t) async => (await t.runAsync(() =>
      db.inventoryItemsDao.insertItem(InventoryItemsCompanion.insert(
        dateAdded: DateTime(2026, 7, 1),
        itemDescription: 'VHS bulk',
        type: ItemType.vhs,
        cost: 15,
        quantity: const Value(10),
        costPerItem: const Value(1.5),
        status: ItemStatus.active,
      ))))!;

  Widget app(Object id) => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          routerConfig: GoRouter(initialLocation: '/item/$id', routes: [
            GoRoute(path: '/', builder: (_, __) => const SizedBox()),
            GoRoute(
                path: '/item/:id',
                builder: (_, s) =>
                    ItemDetailScreen(itemId: s.pathParameters['id']!)),
          ]),
        ),
      );

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 5; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await t.pump();
    }
  }

  testWidgets('BUG-02: Edit Item after a partial sale shows DB values; '
      'unchanged Save keeps totals', (t) async {
    final id = await addVhs(t);
    // Open once (caches provider in the old code), then sell 1 underneath.
    await t.pumpWidget(app(id));
    await settle(t);
    await t.runAsync(() => db.inventoryItemsDao.sellUnits(id, 1));
    await settle(t);
    // Re-open the screen.
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(app(id));
    await settle(t);
    expect(find.text('9'), findsWidgets); // qty stepper
    expect(find.text('\$ 13.50'), findsOneWidget);
    await t.tap(find.byKey(const Key('itemSaveButton')));
    await settle(t);
    final rows = (await t.runAsync(() => db.inventoryItemsDao.getAllForExport()))!;
    expect(rows.fold<int>(0, (s, r) => s + r.quantity), 10);
    expect(rows.fold<double>(0, (s, r) => s + r.cost), closeTo(15.0, 1e-9));
    await t.pumpWidget(const SizedBox());
    await settle(t);
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('BUG-02: sale while Edit is open, then Save never inflates',
      (t) async {
    final id = await addVhs(t);
    await t.pumpWidget(app(id));
    await settle(t);
    await t.runAsync(() => db.inventoryItemsDao.sellUnits(id, 1));
    await settle(t);
    await t.tap(find.byKey(const Key('itemSaveButton')));
    await settle(t);
    final p = (await t.runAsync(() => db.inventoryItemsDao.getById(id)))!;
    expect([p.quantity, p.cost], [9, 13.5]);
    await t.pumpWidget(const SizedBox());
    await settle(t);
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('BUG-03: double Save on Add Item inserts one row', (t) async {
    await t.pumpWidget(app('new'));
    await settle(t);
    await t.enterText(find.widgetWithText(TextFormField, 'Description *'), 'QA cost test');
    await t.tap(find.byKey(const Key('itemSaveButton')));
    await t.tap(find.byKey(const Key('itemSaveButton')), warnIfMissed: false);
    await settle(t);
    final rows = (await t.runAsync(() => db.inventoryItemsDao.getAllForExport()))!;
    expect(rows, hasLength(1));
    await t.pumpWidget(const SizedBox());
    await settle(t);
    await t.pump(const Duration(seconds: 1));
  });

  Widget pushedApp() {
    final router = GoRouter(initialLocation: '/', routes: [
      GoRoute(
        path: '/',
        builder: (c, __) => Scaffold(
          body: TextButton(
              onPressed: () => c.push('/item/new'), child: const Text('open')),
        ),
        routes: [
          GoRoute(
              path: 'item/:id',
              builder: (_, s) =>
                  ItemDetailScreen(itemId: s.pathParameters['id']!)),
        ],
      ),
    ]);
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Future<int> rowCount(WidgetTester t) async =>
      (await t.runAsync(() => db.inventoryItemsDao.getAllForExport()))!.length;

  testWidgets('BUG-03b: two taps in the same frame on Add Item -> one row',
      (t) async {
    await t.pumpWidget(pushedApp());
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.enterText(
        find.widgetWithText(TextFormField, 'Description *'), 'Double tap');
    final save = find.byKey(const Key('itemSaveButton'));
    // Two pointer events dispatched before any frame is pumped.
    await t.tap(save);
    await t.tap(save, warnIfMissed: false);
    await settle(t);
    await t.pumpAndSettle();
    expect(await rowCount(t), 1);
    await t.pumpWidget(const SizedBox());
    await settle(t);
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('BUG-03b: tap during the pop animation after Save -> one row',
      (t) async {
    await t.pumpWidget(pushedApp());
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.enterText(
        find.widgetWithText(TextFormField, 'Description *'), 'Pop tap');
    final save = find.byKey(const Key('itemSaveButton'));
    await t.tap(save);
    // Let the insert finish and the pop start, but not complete.
    for (var i = 0; i < 4; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(save, findsOneWidget, reason: 'route should still be animating out');
    await t.tap(save, warnIfMissed: false);
    await t.pump(const Duration(milliseconds: 16));
    await t.tap(save, warnIfMissed: false);
    await settle(t);
    await t.pumpAndSettle();
    expect(await rowCount(t), 1);
    await t.pumpWidget(const SizedBox());
    await settle(t);
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('BUG-03b: deep-linked Add Item (go, not pop), taps while '
      'leaving -> one row', (t) async {
    final router = GoRouter(initialLocation: '/inventory/new', routes: [
      GoRoute(
        path: '/inventory',
        builder: (_, __) => const Scaffold(body: Text('Inventory List')),
        routes: [
          GoRoute(
              path: ':id',
              builder: (_, s) =>
                  ItemDetailScreen(itemId: s.pathParameters['id']!)),
        ],
      ),
    ]);
    await t.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp.router(routerConfig: router),
    ));
    await settle(t);
    await t.enterText(
        find.widgetWithText(TextFormField, 'Description *'), 'Deep link');
    final save = find.byKey(const Key('itemSaveButton'));
    await t.tap(save);
    for (var i = 0; i < 12; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await t.pump(const Duration(milliseconds: 8));
      if (save.evaluate().isNotEmpty) await t.tap(save, warnIfMissed: false);
    }
    await settle(t);
    await t.pumpAndSettle();
    expect(await rowCount(t), 1);
    await t.pumpWidget(const SizedBox());
    await settle(t);
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('BUG-03b: Save callback fired again after a successful save '
      '(screen leaving) does not insert twice', (t) async {
    await t.pumpWidget(pushedApp());
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.enterText(
        find.widgetWithText(TextFormField, 'Description *'), 'Stale handler');
    await t.pump();
    final save = find.byKey(const Key('itemSaveButton'));
    // Capture the handler as a late/stale pointer event would see it.
    final onPressed = t.widget<ElevatedButton>(save).onPressed!;
    onPressed();
    onPressed(); // same frame
    for (var i = 0; i < 3; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(await rowCount(t), 1);
    onPressed(); // after the save finished, while the route is closing
    for (var i = 0; i < 3; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await t.pump(const Duration(milliseconds: 16));
    }
    await t.pumpAndSettle();
    expect(await rowCount(t), 1);
    await t.pumpWidget(const SizedBox());
    await settle(t);
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('BUG-02: edited cost + sale underneath -> Save refuses, '
      'DB row unchanged', (t) async {
    final id = await addVhs(t); // qty 10, $15.00, 1.50 ea
    await t.pumpWidget(app(id));
    await settle(t);
    // User edits cost per item.
    final cost = find.widgetWithText(TextFormField, 'Cost per item (\$)');
    await t.enterText(cost, '2.00');
    await t.pump();
    // A sale happens underneath.
    await t.runAsync(() => db.inventoryItemsDao.sellUnits(id, 1));
    await settle(t);
    final before = (await t.runAsync(() => db.inventoryItemsDao.getById(id)))!;
    expect([before.quantity, before.cost, before.status],
        [9, 13.5, ItemStatus.active]);
    await t.tap(find.byKey(const Key('itemSaveButton')));
    await settle(t);
    expect(find.textContaining('This item changed'), findsOneWidget);
    final after = (await t.runAsync(() => db.inventoryItemsDao.getById(id)))!;
    expect([after.quantity, after.cost, after.costPerItem, after.status],
        [before.quantity, before.cost, before.costPerItem, before.status]);
    // Still on Edit Item, Save usable again.
    expect(find.byKey(const Key('itemSaveButton')), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await settle(t);
    await t.pump(const Duration(seconds: 1));
  });
}
