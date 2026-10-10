import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/drilldown_query.dart';
import 'package:flipbin/models/enums.dart';

void main() {
  test('BUG-04: Listed drill-down units == sell-through card listed', () async {
    final db = FlipBinDatabase(NativeDatabase.memory());
    final dao = db.inventoryItemsDao;
    final now = DateTime.now();
    Future<void> add(String d, ItemStatus st, int q,
        {required int addedAgo, int? soldAgo}) =>
        dao.insertItem(InventoryItemsCompanion.insert(
          dateAdded: now.subtract(Duration(days: addedAgo)),
          itemDescription: d,
          type: ItemType.other,
          cost: q.toDouble(),
          quantity: Value(q),
          status: st,
          dateSold: Value(soldAgo == null ? null : now.subtract(Duration(days: soldAgo))),
        ));
    await add('Active new', ItemStatus.active, 3, addedAgo: 5);
    await add('Book pair', ItemStatus.personal, 2, addedAgo: 5); // excluded
    await add('CD set', ItemStatus.sold, 4, addedAgo: 200, soldAgo: 10); // included
    await add('Old active', ItemStatus.active, 1, addedAgo: 200);
    await add('Old sold', ItemStatus.sold, 1, addedAgo: 200, soldAgo: 120);

    final card = await dao.watchSellThrough(windowDays: 90).first;
    final q = DrillDownQuery.sellThroughListed(windowDays: 90);
    final rt = DrillDownQuery.fromQueryParameters(q.toQueryParameters());
    final rows = await dao
        .watchAll(addedWithinDays: rt.addedWithinDays, sellThroughCohort: rt.sellThroughCohort)
        .first;
    expect(rows.map((r) => r.itemDescription).toSet(), {'Active new', 'CD set'});
    expect(rows.fold<int>(0, (s, r) => s + r.quantity), card.listed);
    expect(card.listed, 7);
    await db.close();
  });
}
