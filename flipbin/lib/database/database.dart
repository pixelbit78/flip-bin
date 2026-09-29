import 'package:drift/drift.dart';
import 'connection/connection.dart' as impl;
import 'package:flipbin/models/enums.dart';

part 'database.g.dart';

/// Table for inventory items.
class InventoryItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get dateAdded => dateTime()();
  TextColumn get barcode => text().nullable()();
  TextColumn get itemDescription => text()();
  TextColumn get type => textEnum<ItemType>()();
  RealColumn get cost => real()();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  TextColumn get platform => text().nullable()();
  TextColumn get status => textEnum<ItemStatus>()();
  DateTimeColumn get dateSold => dateTime().nullable()();
  TextColumn get saleNumber => text().nullable()();
  TextColumn get comments => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get lookupName => text().nullable()();
  TextColumn get lookupDescription => text().nullable()();
}

/// Table for business expenses.
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  TextColumn get merchant => text()();
  TextColumn get receiptImagePath => text().nullable()();
  TextColumn get upc => text().nullable()();
  TextColumn get itemDescription => text()();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  RealColumn get unitPrice => real()();
  TextColumn get expenseType => textEnum<ExpenseType>()();
  RealColumn get taxAmount => real().nullable()();
}

/// Table for cached barcode lookup results.
class BarcodeCacheEntries extends Table {
  TextColumn get barcode => text()();
  TextColumn get productName => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get source => text()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {barcode};
}

/// Extension for computed fields on [InventoryItem].
extension InventoryItemExtension on InventoryItem {
  int? get daysToSell {
    if (dateSold == null) return null;
    return dateSold!.difference(dateAdded).inDays;
  }
}

/// Extension for computed fields on [Expense].
extension ExpenseExtension on Expense {
  double get total => quantity * unitPrice;
}

@DriftAccessor(tables: [InventoryItems])
class InventoryItemsDao extends DatabaseAccessor<FlipBinDatabase> with _$InventoryItemsDaoMixin {
  InventoryItemsDao(super.db);

  Stream<List<InventoryItem>> watchAll({ItemStatus? statusFilter, String? searchQuery}) {
    final query = select(inventoryItems);
    if (statusFilter != null) {
      query.where((tbl) => tbl.status.equalsValue(statusFilter));
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = '%${searchQuery.trim().toLowerCase()}%';
      query.where((tbl) => tbl.itemDescription.lower().like(term));
    }
    query.orderBy([(tbl) => OrderingTerm.desc(tbl.dateAdded)]);
    return query.watch();
  }

  Future<InventoryItem> getById(int id) {
    return (select(inventoryItems)..where((tbl) => tbl.id.equals(id))).getSingle();
  }

  Future<int> insertItem(InventoryItemsCompanion item) {
    return into(inventoryItems).insert(item);
  }

  Future<bool> updateItem(InventoryItem item) {
    return update(inventoryItems).replace(item);
  }

  Future<int> deleteItem(int id) {
    return (delete(inventoryItems)..where((tbl) => tbl.id.equals(id))).go();
  }

  /// Active or personal inventory rows matching [barcode] (trimmed).
  /// Sold items are excluded so Save-as-sold removes them from this stream.
  Stream<List<InventoryItem>> watchByBarcodeActiveOrPersonal(String barcode) {
    final normalized = barcode.trim();
    if (normalized.isEmpty) {
      return Stream.value(const []);
    }
    final query = select(inventoryItems)
      ..where(
        (tbl) =>
            tbl.barcode.equals(normalized) &
            (tbl.status.equalsValue(ItemStatus.active) |
                tbl.status.equalsValue(ItemStatus.personal)),
      )
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.dateAdded)]);
    return query.watch();
  }

  Future<int> countByStatus(ItemStatus status) async {
    final countExp = inventoryItems.id.count();
    final query = selectOnly(inventoryItems)
      ..addColumns([countExp])
      ..where(inventoryItems.status.equalsValue(status));
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  Stream<int> watchCountByStatus(ItemStatus status) {
    final countExp = inventoryItems.id.count();
    final query = selectOnly(inventoryItems)
      ..addColumns([countExp])
      ..where(inventoryItems.status.equalsValue(status));
    return query.watch().map((rows) {
      if (rows.isEmpty) return 0;
      return rows.first.read(countExp) ?? 0;
    });
  }

  Future<double> totalCostByStatus(ItemStatus status) async {
    final costExp = inventoryItems.cost.sum();
    final query = selectOnly(inventoryItems)
      ..addColumns([costExp])
      ..where(inventoryItems.status.equalsValue(status));
    final row = await query.getSingle();
    return row.read(costExp) ?? 0.0;
  }

  Stream<double> watchTotalCostByStatus(ItemStatus status) {
    final costExp = inventoryItems.cost.sum();
    final query = selectOnly(inventoryItems)
      ..addColumns([costExp])
      ..where(inventoryItems.status.equalsValue(status));
    return query.watch().map((rows) {
      if (rows.isEmpty) return 0.0;
      return rows.first.read(costExp) ?? 0.0;
    });
  }

  Future<List<InventoryItem>> getAllForExport() {
    return (select(inventoryItems)..orderBy([(tbl) => OrderingTerm.asc(tbl.dateAdded)])).get();
  }

  Future<void> replaceAll(List<InventoryItemsCompanion> items) async {
    await db.transaction(() async {
      await delete(inventoryItems).go();
      if (items.isNotEmpty) {
        await batch((b) {
          b.insertAll(inventoryItems, items);
        });
      }
    });
  }
}

@DriftAccessor(tables: [Expenses])
class ExpensesDao extends DatabaseAccessor<FlipBinDatabase> with _$ExpensesDaoMixin {
  ExpensesDao(super.db);

  Stream<List<Expense>> watchAll({ExpenseType? typeFilter, DateTime? monthFilter, String? searchQuery}) {
    final query = select(expenses);
    if (typeFilter != null) {
      query.where((tbl) => tbl.expenseType.equalsValue(typeFilter));
    }
    if (monthFilter != null) {
      final startOfMonth = DateTime(monthFilter.year, monthFilter.month, 1);
      final endOfMonth = DateTime(monthFilter.year, monthFilter.month + 1, 1);
      query.where((tbl) => tbl.date.isBiggerOrEqualValue(startOfMonth) & tbl.date.isSmallerThanValue(endOfMonth));
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = '%${searchQuery.trim().toLowerCase()}%';
      query.where((tbl) => tbl.merchant.lower().like(term) | tbl.itemDescription.lower().like(term));
    }
    query.orderBy([(tbl) => OrderingTerm.desc(tbl.date)]);
    return query.watch();
  }

  Future<Expense> getById(int id) {
    return (select(expenses)..where((tbl) => tbl.id.equals(id))).getSingle();
  }

  Future<int> insertExpense(ExpensesCompanion expense) {
    return into(expenses).insert(expense);
  }

  Future<bool> updateExpense(Expense expense) {
    return update(expenses).replace(expense);
  }

  Future<int> deleteExpense(int id) {
    return (delete(expenses)..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<double> totalForMonth(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 1);
    final items = await (select(expenses)
      ..where((tbl) => tbl.date.isBiggerOrEqualValue(startOfMonth) & tbl.date.isSmallerThanValue(endOfMonth)))
      .get();
    return items.fold<double>(0.0, (sum, item) => sum + item.total);
  }

  Stream<double> watchTotalForMonth(DateTime month) {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 1);
    final query = select(expenses)
      ..where((tbl) =>
          tbl.date.isBiggerOrEqualValue(startOfMonth) &
          tbl.date.isSmallerThanValue(endOfMonth));
    return query.watch().map(
          (items) => items.fold<double>(0.0, (sum, item) => sum + item.total),
        );
  }

  Future<double> totalAll() async {
    final items = await select(expenses).get();
    return items.fold<double>(0.0, (sum, item) => sum + item.total);
  }

  Stream<double> watchTotalAll() {
    return select(expenses).watch().map(
          (items) => items.fold<double>(0.0, (sum, item) => sum + item.total),
        );
  }

  Future<List<Expense>> getAllForExport() {
    return (select(expenses)..orderBy([(tbl) => OrderingTerm.asc(tbl.date)])).get();
  }

  Future<void> replaceAll(List<ExpensesCompanion> items) async {
    await db.transaction(() async {
      await delete(expenses).go();
      if (items.isNotEmpty) {
        await batch((b) {
          b.insertAll(expenses, items);
        });
      }
    });
  }
}

@DriftAccessor(tables: [BarcodeCacheEntries])
class BarcodeCacheDao extends DatabaseAccessor<FlipBinDatabase> with _$BarcodeCacheDaoMixin {
  BarcodeCacheDao(super.db);

  Future<BarcodeCacheEntry?> lookup(String barcode) {
    return (select(barcodeCacheEntries)..where((tbl) => tbl.barcode.equals(barcode))).getSingleOrNull();
  }

  Future<void> insertOrUpdate(BarcodeCacheEntriesCompanion entry) {
    return into(barcodeCacheEntries).insertOnConflictUpdate(entry);
  }
}

@DriftDatabase(
  tables: [InventoryItems, Expenses, BarcodeCacheEntries],
  daos: [InventoryItemsDao, ExpensesDao, BarcodeCacheDao],
)
class FlipBinDatabase extends _$FlipBinDatabase {
  FlipBinDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return impl.openConnection();
  }
}
