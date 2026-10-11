import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flipbin/app/theme.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/drilldown_query.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/providers/database_provider.dart';
import 'package:flipbin/screens/dashboard/dashboard_screen.dart';
import 'package:flipbin/screens/drilldown/inventory_drilldown_screen.dart';
import 'package:flipbin/screens/expenses/expense_list_screen.dart';
import 'package:flipbin/screens/inventory/inventory_list_screen.dart';
import 'package:flipbin/screens/inventory/item_detail_screen.dart';

import '../support/tap_targets.dart';

/// L-01…L-05 + FAB labels at 412 px on a desktop platform (compact defaults).
void main() {
  final desktop = TargetPlatformVariant.only(TargetPlatform.linux);
  late FlipBinDatabase db;
  SemanticsHandle? semantics;
  setUp(() async {
    db = FlipBinDatabase(NativeDatabase.memory());
    final now = DateTime.now();
    Future<void> add(String d, ItemStatus s, int ageDays, {int q = 1}) =>
        db.inventoryItemsDao.insertItem(InventoryItemsCompanion.insert(
          dateAdded: now.subtract(Duration(days: ageDays)),
          itemDescription: d,
          type: ItemType.game,
          cost: 4,
          quantity: Value(q),
          status: s,
          dateSold: Value(s == ItemStatus.sold ? now : null),
        ));
    await add('Active new', ItemStatus.active, 5, q: 3);
    await add('Aging 40', ItemStatus.active, 40);
    await add('Aging 70', ItemStatus.active, 70);
    await add('Aging 120', ItemStatus.active, 120);
    await add('Personal one', ItemStatus.personal, 10);
    await add('Sold one', ItemStatus.sold, 20);
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 6; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await t.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> phone(WidgetTester t, Widget child) async {
    t.view.physicalSize = const Size(412, 839);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(theme: FlipBinTheme.dark, home: child),
    ));
    await settle(t);
    semantics = t.ensureSemantics();
  }

  Future<void> scanScrolling(WidgetTester t) async {
    final s = find.byType(Scrollable);
    for (var i = 0; i < 6; i++) {
      expectAllTappablesAtLeast(t);
      if (s.evaluate().isEmpty) break;
      await t.drag(s.first, const Offset(0, -300), warnIfMissed: false);
      await settle(t);
    }
  }

  Future<void> done(WidgetTester t) async {
    semantics?.dispose();
    semantics = null;
    await t.pumpWidget(const SizedBox());
    await settle(t);
    await t.pump(const Duration(seconds: 1));
  }

  testWidgets('L-02/L-03 + FAB: Inventory list', (t) async {
    await phone(t, const InventoryListScreen());
    expect(find.bySemanticsLabel('Add item'), findsOneWidget);
    // L-02: Active/Personal chips are tappable (mark-sold) with a 44px hit area.
    expect(find.bySemanticsLabel(RegExp('Status Active')), findsWidgets);
    await scanScrolling(t);
    await done(t);
  }, variant: desktop);

  testWidgets('FAB: Expenses list has an "Add expense" label', (t) async {
    await phone(t, const ExpenseListScreen());
    expect(find.bySemanticsLabel('Add expense'), findsOneWidget);
    expectAllTappablesAtLeast(t);
    await done(t);
  }, variant: desktop);

  for (final q in [
    DrillDownQuery.sellThroughListed(),
    DrillDownQuery.sellThroughSold(),
    DrillDownQuery.sellThroughStillActive(),
    DrillDownQuery.aging(minDays: 30, maxDays: 59),
  ]) {
    testWidgets('L-01: drill-down "${q.title}" chips', (t) async {
      await phone(t, InventoryDrillDownScreen(initialQuery: q));
      await scanScrolling(t);
      await done(t);
    }, variant: desktop);
  }

  testWidgets('L-04: Home aging rows', (t) async {
    await phone(t, const DashboardScreen());
    await scanScrolling(t);
    await done(t);
  }, variant: desktop);

  testWidgets('L-05: Edit Item Date Sold row is one full-size tappable',
      (t) async {
    await phone(t, const ItemDetailScreen(itemId: '6'));
    for (final label in ['Date Added', 'Date Sold']) {
      await t.ensureVisible(find.text(label));
      await t.pump();
      final tile = find.ancestor(of: find.text(label), matching: find.byType(ListTile));
      expect(t.getSize(tile).height, greaterThanOrEqualTo(44));
      final node = t.getSemantics(find.text(label));
      expect(node.rect.height, greaterThanOrEqualTo(44), reason: '$label semantics node');
    }
    await scanScrolling(t);
    await done(t);
  }, variant: desktop);
}
