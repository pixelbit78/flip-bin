import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/enums.dart';

void main() {
  late FlipBinDatabase db;

  setUp(() {
    db = FlipBinDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertItem({
    required String desc,
    required ItemStatus status,
    required DateTime dateAdded,
    DateTime? dateSold,
    double cost = 10,
  }) {
    return db.inventoryItemsDao.insertItem(
      InventoryItemsCompanion.insert(
        dateAdded: dateAdded,
        itemDescription: desc,
        type: ItemType.game,
        cost: cost,
        status: status,
        dateSold: Value(dateSold),
      ),
    );
  }

  test('age band filter matches Active 30–59 only', () async {
    final now = DateTime.now();
    await insertItem(
      desc: 'young',
      status: ItemStatus.active,
      dateAdded: now.subtract(const Duration(days: 10)),
    );
    await insertItem(
      desc: 'mid',
      status: ItemStatus.active,
      dateAdded: now.subtract(const Duration(days: 45)),
    );
    await insertItem(
      desc: 'old60',
      status: ItemStatus.active,
      dateAdded: now.subtract(const Duration(days: 70)),
    );
    await insertItem(
      desc: 'sold mid',
      status: ItemStatus.sold,
      dateAdded: now.subtract(const Duration(days: 45)),
      dateSold: now.subtract(const Duration(days: 1)),
    );

    final list = await db.inventoryItemsDao
        .watchAll(
          statusFilter: ItemStatus.active,
          ageMinDays: 30,
          ageMaxDays: 59,
        )
        .first;
    expect(list.map((e) => e.itemDescription).toList(), ['mid']);
  });

  test('soldWithinDays filters Sold by dateSold', () async {
    final now = DateTime.now();
    await insertItem(
      desc: 'recent sold',
      status: ItemStatus.sold,
      dateAdded: now.subtract(const Duration(days: 120)),
      dateSold: now.subtract(const Duration(days: 5)),
    );
    await insertItem(
      desc: 'old sold',
      status: ItemStatus.sold,
      dateAdded: now.subtract(const Duration(days: 200)),
      dateSold: now.subtract(const Duration(days: 120)),
    );
    await insertItem(
      desc: 'active',
      status: ItemStatus.active,
      dateAdded: now.subtract(const Duration(days: 5)),
    );

    final list = await db.inventoryItemsDao
        .watchAll(statusFilter: ItemStatus.sold, soldWithinDays: 90)
        .first;
    expect(list.map((e) => e.itemDescription).toList(), ['recent sold']);
  });

  test('addedMonth any status; soldMonth Sold + dateSold month', () async {
    final sep = DateTime(2026, 9, 15);
    final aug = DateTime(2026, 8, 15);
    await insertItem(
      desc: 'listed sep active',
      status: ItemStatus.active,
      dateAdded: sep,
    );
    await insertItem(
      desc: 'listed sep sold',
      status: ItemStatus.sold,
      dateAdded: sep,
      dateSold: DateTime(2026, 9, 20),
    );
    await insertItem(
      desc: 'listed aug',
      status: ItemStatus.active,
      dateAdded: aug,
    );
    await insertItem(
      desc: 'sold sep added earlier',
      status: ItemStatus.sold,
      dateAdded: aug,
      dateSold: DateTime(2026, 9, 10),
    );

    final listed = await db.inventoryItemsDao
        .watchAll(addedMonth: DateTime(2026, 9, 1))
        .first;
    expect(
      listed.map((e) => e.itemDescription).toSet(),
      {'listed sep active', 'listed sep sold'},
    );

    final sold = await db.inventoryItemsDao
        .watchAll(
          statusFilter: ItemStatus.sold,
          soldMonth: DateTime(2026, 9, 1),
        )
        .first;
    expect(
      sold.map((e) => e.itemDescription).toSet(),
      {'listed sep sold', 'sold sep added earlier'},
    );
  });
}
