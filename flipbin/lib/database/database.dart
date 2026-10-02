import 'package:drift/drift.dart';
import 'connection/connection.dart' as impl;
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/utils/barcode_normalize.dart';

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

/// Aging capital KPI: dollars tied up in Active stock at/above a min age.
class AgingCapitalSummary {
  final double totalCostTimesQty;
  final int itemCount;

  const AgingCapitalSummary({
    required this.totalCostTimesQty,
    required this.itemCount,
  });
}

/// One aging-capital bucket (label, dollars, item count).
class AgingBucket {
  final String label;
  final double totalCostTimesQty;
  final int itemCount;

  const AgingBucket({
    required this.label,
    required this.totalCostTimesQty,
    required this.itemCount,
  });
}

/// Active-stock aging buckets for the dashboard breakdown card.
class AgingBuckets {
  final AgingBucket bucket30to59;
  final AgingBucket bucket60to89;
  final AgingBucket bucket90plus;

  const AgingBuckets({
    required this.bucket30to59,
    required this.bucket60to89,
    required this.bucket90plus,
  });

  List<AgingBucket> get asList => [bucket30to59, bucket60to89, bucket90plus];

  double get maxAmount {
    final amounts = asList.map((b) => b.totalCostTimesQty);
    if (amounts.isEmpty) return 0;
    return amounts.reduce((a, b) => a > b ? a : b);
  }
}

/// Sell-through metrics for a trailing window (see [InventoryItemsDao.watchSellThrough]).
class SellThroughMetrics {
  final int listed;
  final int sold;
  final int stillActive;
  final double rate;
  final int windowDays;

  const SellThroughMetrics({
    required this.listed,
    required this.sold,
    required this.stillActive,
    required this.rate,
    required this.windowDays,
  });
}

/// One month's expense total for the monthly-expenses chart.
class MonthlyExpenseTotal {
  final DateTime month;
  final double total;

  const MonthlyExpenseTotal({required this.month, required this.total});
}

/// One month's item count for the Home inventory activity charts.
class MonthlyInventoryCount {
  final DateTime month;
  final int count;

  const MonthlyInventoryCount({required this.month, required this.count});
}


/// Calendar month starts from [start] through [end] (inclusive). Day is ignored.
List<DateTime> _monthsFromTo(DateTime start, DateTime end) {
  var cursor = DateTime(start.year, start.month, 1);
  final endMonth = DateTime(end.year, end.month, 1);
  final out = <DateTime>[];
  while (!cursor.isAfter(endMonth)) {
    out.add(cursor);
    cursor = DateTime(cursor.year, cursor.month + 1, 1);
  }
  return out;
}

/// Resolves the contiguous month axis for Home monthly charts.
///
/// When [monthCount] is set, returns that many months ending at [anchor].
/// Otherwise spans from the earliest data month through [anchor], but never
/// fewer than [minMonthCount] months (zero-fill short history).
List<DateTime> _resolveMonthStarts({
  required DateTime anchor,
  DateTime? earliest,
  int? monthCount,
  int minMonthCount = 6,
}) {
  final end = DateTime(anchor.year, anchor.month, 1);
  if (monthCount != null) {
    if (monthCount <= 0) return const [];
    return [
      for (var i = monthCount - 1; i >= 0; i--)
        DateTime(end.year, end.month - i, 1),
    ];
  }
  final minStart = DateTime(end.year, end.month - (minMonthCount - 1), 1);
  final DateTime start;
  if (earliest == null) {
    start = minStart;
  } else {
    final earliestMonth = DateTime(earliest.year, earliest.month, 1);
    start = earliestMonth.isBefore(minStart) ? earliestMonth : minStart;
  }
  return _monthsFromTo(start, end);
}

@DriftAccessor(tables: [InventoryItems])
class InventoryItemsDao extends DatabaseAccessor<FlipBinDatabase> with _$InventoryItemsDaoMixin {
  InventoryItemsDao(super.db);

  Stream<List<InventoryItem>> watchAll({
    ItemStatus? statusFilter,
    String? searchQuery,
    int? ageMinDays,
    int? ageMaxDays,
    int? soldWithinDays,
    int? addedWithinDays,
    DateTime? soldMonth,
    DateTime? addedMonth,
  }) {
    final query = select(inventoryItems);
    if (statusFilter != null) {
      query.where((tbl) => tbl.status.equalsValue(statusFilter));
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final trimmed = searchQuery.trim();
      final term = '%${trimmed.toLowerCase()}%';
      query.where((tbl) {
        Expression<bool> match = tbl.itemDescription.lower().like(term) |
            tbl.barcode.lower().like(term);
        // UPC leading-zero variants: also LIKE on significant digits.
        if (BarcodeNormalize.isNumericUpcLike(trimmed)) {
          final sig = BarcodeNormalize.significantDigits(trimmed);
          if (sig != null) {
            final sigTerm = '%$sig%';
            if (sigTerm != term) {
              match = match | tbl.barcode.lower().like(sigTerm);
            }
          }
        }
        return match;
      });
    }
    if (soldWithinDays != null) {
      final cutoff = DateTime.now().subtract(Duration(days: soldWithinDays));
      query.where(
        (tbl) =>
            tbl.dateSold.isNotNull() &
            tbl.dateSold.isBiggerOrEqualValue(cutoff),
      );
    }
    if (addedWithinDays != null) {
      final cutoff = DateTime.now().subtract(Duration(days: addedWithinDays));
      query.where((tbl) => tbl.dateAdded.isBiggerOrEqualValue(cutoff));
    }
    if (soldMonth != null) {
      final start = DateTime(soldMonth.year, soldMonth.month, 1);
      final end = DateTime(soldMonth.year, soldMonth.month + 1, 1);
      query.where(
        (tbl) =>
            tbl.dateSold.isNotNull() &
            tbl.dateSold.isBiggerOrEqualValue(start) &
            tbl.dateSold.isSmallerThanValue(end),
      );
    }
    if (addedMonth != null) {
      final start = DateTime(addedMonth.year, addedMonth.month, 1);
      final end = DateTime(addedMonth.year, addedMonth.month + 1, 1);
      query.where(
        (tbl) =>
            tbl.dateAdded.isBiggerOrEqualValue(start) &
            tbl.dateAdded.isSmallerThanValue(end),
      );
    }
    query.orderBy([(tbl) => OrderingTerm.desc(tbl.dateAdded)]);
    final stream = query.watch();
    // Age band matches [watchAgingBuckets] (post-filter on dateAdded age).
    if (ageMinDays == null && ageMaxDays == null) return stream;
    return stream.map((items) {
      final now = DateTime.now();
      return items.where((item) {
        final age = now.difference(item.dateAdded).inDays;
        if (ageMinDays != null && age < ageMinDays) return false;
        if (ageMaxDays != null && age > ageMaxDays) return false;
        return true;
      }).toList();
    });
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
  ///
  /// Numeric UPC/EAN codes also match leading-zero variants via significant
  /// digits (SQLite `ltrim` on the stored barcode).
  Stream<List<InventoryItem>> watchByBarcodeActiveOrPersonal(String barcode) {
    final normalized = barcode.trim();
    if (normalized.isEmpty) {
      return Stream.value(const []);
    }
    final query = select(inventoryItems)
      ..where((tbl) {
        Expression<bool> barcodeMatch = tbl.barcode.equals(normalized);
        if (BarcodeNormalize.isNumericUpcLike(normalized)) {
          final sig = BarcodeNormalize.significantDigits(normalized);
          if (sig != null) {
            // Digits-only sig is safe to embed (no quotes / SQL metacharacters).
            barcodeMatch = barcodeMatch |
                tbl.barcode.equals(sig) |
                CustomExpression<bool>(
                  "ltrim(COALESCE(barcode, ''), '0') = '$sig'",
                );
          }
        }
        return barcodeMatch &
            (tbl.status.equalsValue(ItemStatus.active) |
                tbl.status.equalsValue(ItemStatus.personal));
      })
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

  /// Sum of `cost × quantity` for items with [status] (dashboard Total cost KPI).
  ///
  /// Distinct from [watchTotalCostByStatus], which sums `cost` only.
  Stream<double> watchTotalCostTimesQtyByStatus(ItemStatus status) {
    final query = select(inventoryItems)
      ..where((tbl) => tbl.status.equalsValue(status));
    return query.watch().map(
          (items) => items.fold<double>(
            0.0,
            (sum, item) => sum + item.cost * item.quantity,
          ),
        );
  }

  /// Mean of `(dateSold − dateAdded).inDays` for Sold items with [dateSold] set.
  /// Emits `null` when there are no qualifying Sold items.
  Stream<double?> watchAvgDaysToSell() {
    final query = select(inventoryItems)
      ..where((tbl) => tbl.status.equalsValue(ItemStatus.sold));
    return query.watch().map((items) {
      final days = <int>[];
      for (final item in items) {
        final d = item.daysToSell;
        if (d != null) days.add(d);
      }
      if (days.isEmpty) return null;
      return days.reduce((a, b) => a + b) / days.length;
    });
  }

  /// Aging capital for Active stock: sum(`cost × qty`) and item count where age ≥ [minAgeDays].
  Stream<AgingCapitalSummary> watchAgingCapital({int minAgeDays = 30}) {
    final query = select(inventoryItems)
      ..where((tbl) => tbl.status.equalsValue(ItemStatus.active));
    return query.watch().map((items) {
      final now = DateTime.now();
      var total = 0.0;
      var count = 0;
      for (final item in items) {
        final age = now.difference(item.dateAdded).inDays;
        if (age >= minAgeDays) {
          total += item.cost * item.quantity;
          count += 1;
        }
      }
      return AgingCapitalSummary(totalCostTimesQty: total, itemCount: count);
    });
  }

  /// Active-only aging buckets: 30–59 / 60–89 / 90+ with cost×qty and counts.
  Stream<AgingBuckets> watchAgingBuckets() {
    final query = select(inventoryItems)
      ..where((tbl) => tbl.status.equalsValue(ItemStatus.active));
    return query.watch().map((items) {
      final now = DateTime.now();
      var b30 = const AgingBucket(label: '30–59d', totalCostTimesQty: 0, itemCount: 0);
      var b60 = const AgingBucket(label: '60–89d', totalCostTimesQty: 0, itemCount: 0);
      var b90 = const AgingBucket(label: '90d+', totalCostTimesQty: 0, itemCount: 0);
      for (final item in items) {
        final age = now.difference(item.dateAdded).inDays;
        final dollars = item.cost * item.quantity;
        if (age >= 90) {
          b90 = AgingBucket(
            label: b90.label,
            totalCostTimesQty: b90.totalCostTimesQty + dollars,
            itemCount: b90.itemCount + 1,
          );
        } else if (age >= 60) {
          b60 = AgingBucket(
            label: b60.label,
            totalCostTimesQty: b60.totalCostTimesQty + dollars,
            itemCount: b60.itemCount + 1,
          );
        } else if (age >= 30) {
          b30 = AgingBucket(
            label: b30.label,
            totalCostTimesQty: b30.totalCostTimesQty + dollars,
            itemCount: b30.itemCount + 1,
          );
        }
      }
      return AgingBuckets(bucket30to59: b30, bucket60to89: b60, bucket90plus: b90);
    });
  }

  /// Sell-through over a trailing [windowDays] window (default 90).
  ///
  /// Cohort definition:
  /// - **Still active**: Active items with `dateAdded` within the last [windowDays].
  /// - **Sold**: Sold items with `dateSold` within the last [windowDays].
  /// - **Listed**: Still active + Sold.
  /// - **Rate**: Sold / Listed (0 when Listed is 0).
  Stream<SellThroughMetrics> watchSellThrough({int windowDays = 90}) {
    return select(inventoryItems).watch().map((items) {
      final cutoff = DateTime.now().subtract(Duration(days: windowDays));
      var stillActive = 0;
      var sold = 0;
      for (final item in items) {
        if (item.status == ItemStatus.active &&
            !item.dateAdded.isBefore(cutoff)) {
          stillActive += 1;
        } else if (item.status == ItemStatus.sold &&
            item.dateSold != null &&
            !item.dateSold!.isBefore(cutoff)) {
          sold += 1;
        }
      }
      final listed = stillActive + sold;
      final rate = listed == 0 ? 0.0 : sold / listed;
      return SellThroughMetrics(
        listed: listed,
        sold: sold,
        stillActive: stillActive,
        rate: rate,
        windowDays: windowDays,
      );
    });
  }

  /// Item counts by `dateSold`, oldest month first.
  ///
  /// By default includes every calendar month from the earliest sale through
  /// [anchor] (now), zero-filling gaps, and at least [minMonthCount] months.
  /// Pass [monthCount] to force a fixed trailing window instead.
  /// Items without a sale date are excluded.
  Stream<List<MonthlyInventoryCount>> watchMonthlySoldCounts({
    int? monthCount,
    int minMonthCount = 6,
    DateTime? anchor,
  }) {
    return select(inventoryItems).watch().map((items) {
      return _monthlyInventoryCounts(
        items.map((item) => item.dateSold).whereType<DateTime>(),
        monthCount: monthCount,
        minMonthCount: minMonthCount,
        anchor: anchor,
      );
    });
  }

  /// Item counts by `dateAdded`, oldest month first.
  ///
  /// By default includes every calendar month from the earliest add through
  /// [anchor] (now), zero-filling gaps, and at least [minMonthCount] months.
  /// Pass [monthCount] to force a fixed trailing window instead.
  Stream<List<MonthlyInventoryCount>> watchMonthlyListedCounts({
    int? monthCount,
    int minMonthCount = 6,
    DateTime? anchor,
  }) {
    return select(inventoryItems).watch().map((items) {
      return _monthlyInventoryCounts(
        items.map((item) => item.dateAdded),
        monthCount: monthCount,
        minMonthCount: minMonthCount,
        anchor: anchor,
      );
    });
  }

  static List<MonthlyInventoryCount> _monthlyInventoryCounts(
    Iterable<DateTime> dates, {
    int? monthCount,
    int minMonthCount = 6,
    DateTime? anchor,
  }) {
    final dateList = dates.toList();
    DateTime? earliest;
    for (final date in dateList) {
      if (earliest == null || date.isBefore(earliest)) earliest = date;
    }
    final months = _resolveMonthStarts(
      anchor: anchor ?? DateTime.now(),
      earliest: earliest,
      monthCount: monthCount,
      minMonthCount: minMonthCount,
    );
    return [
      for (final monthStart in months)
        MonthlyInventoryCount(
          month: monthStart,
          count: dateList
              .where((date) =>
                  date.year == monthStart.year &&
                  date.month == monthStart.month)
              .length,
        ),
    ];
  }

  /// Top [limit] Sold items by fastest `daysToSell` (ascending). Requires `dateSold`.
  Stream<List<InventoryItem>> watchTopMovers({int limit = 3}) {
    final query = select(inventoryItems)
      ..where((tbl) => tbl.status.equalsValue(ItemStatus.sold));
    return query.watch().map((items) {
      final withDays = items.where((i) => i.daysToSell != null).toList()
        ..sort((a, b) => a.daysToSell!.compareTo(b.daysToSell!));
      if (withDays.length <= limit) return withDays;
      return withDays.sublist(0, limit);
    });
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

  /// Monthly expense totals (`qty × unitPrice`), oldest month first.
  ///
  /// By default includes every calendar month from the earliest expense through
  /// [anchor] (now), zero-filling gaps, and at least [minMonthCount] months.
  /// Pass [monthCount] to force a fixed trailing window instead.
  Stream<List<MonthlyExpenseTotal>> watchMonthlyTotals({
    int? monthCount,
    int minMonthCount = 6,
    DateTime? anchor,
  }) {
    return select(expenses).watch().map((items) {
      DateTime? earliest;
      for (final e in items) {
        if (earliest == null || e.date.isBefore(earliest)) earliest = e.date;
      }
      final months = _resolveMonthStarts(
        anchor: anchor ?? DateTime.now(),
        earliest: earliest,
        monthCount: monthCount,
        minMonthCount: minMonthCount,
      );
      return [
        for (final monthStart in months)
          MonthlyExpenseTotal(
            month: monthStart,
            total: items
                .where((e) =>
                    e.date.year == monthStart.year &&
                    e.date.month == monthStart.month)
                .fold<double>(0.0, (sum, e) => sum + e.total),
          ),
      ];
    });
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
