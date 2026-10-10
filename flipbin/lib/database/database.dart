import 'package:drift/drift.dart';
import 'connection/connection.dart' as impl;
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/utils/barcode_normalize.dart';
import 'package:flipbin/utils/cost_field.dart';

part 'database.g.dart';

/// Table for inventory items.
class InventoryItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get dateAdded => dateTime()();
  TextColumn get barcode => text().nullable()();
  TextColumn get itemDescription => text()();
  TextColumn get type => textEnum<ItemType>()();
  /// Line total (sheet `Cost`), derived = round(qty × costPerItem, 2) on user
  /// edits; preserved exactly by system operations (SPEC §3.2).
  RealColumn get cost => real()();
  IntColumn get quantity => integer().withDefault(const Constant(1))();

  /// Canonical per-item cost, 4 dp (schema v2). Null only before backfill.
  RealColumn get costPerItem => real().nullable()();

  /// Split child (Sold) → source row id (schema v2).
  IntColumn get parentId => integer().nullable()();
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
  /// Per-item cost, falling back to cost ÷ qty for un-backfilled rows.
  double get cpi => costPerItem ?? cpiFromTotal(cost, quantity);

  int? get daysToSell {
    if (dateSold == null) return null;
    return dateSold!.difference(dateAdded).inDays;
  }
}

/// Extension for computed fields on [Expense].
extension ExpenseExtension on Expense {
  double get total => quantity * unitPrice;
}

/// Review-lots candidate (SPEC §4.3).
class LotSuggestion {
  final InventoryItem item;
  final int suggestedQty;
  const LotSuggestion({required this.item, required this.suggestedQty});
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

/// Sell-through cohort for the trailing window. Single source of truth for
/// both the Home card and its drill-downs (BUG-04): Active rows added in the
/// window, plus Sold rows sold in the window. Personal is never in the cohort.
enum SellThroughBucket { stillActive, sold }

SellThroughBucket? sellThroughBucket(InventoryItem item, DateTime cutoff) {
  if (item.status == ItemStatus.active && !item.dateAdded.isBefore(cutoff)) {
    return SellThroughBucket.stillActive;
  }
  if (item.status == ItemStatus.sold &&
      item.dateSold != null &&
      !item.dateSold!.isBefore(cutoff)) {
    return SellThroughBucket.sold;
  }
  return null;
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
    bool sellThroughCohort = false,
  }) {
    final query = select(inventoryItems);
    final cohortDays = sellThroughCohort ? addedWithinDays : null;
    if (cohortDays != null) addedWithinDays = null;
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
    var stream = query.watch();
    if (cohortDays != null) {
      stream = stream.map((items) {
        final cutoff = DateTime.now().subtract(Duration(days: cohortDays));
        return items.where((i) => sellThroughBucket(i, cutoff) != null).toList();
      });
    }
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

  Stream<InventoryItem> watchById(int id) {
    return (select(inventoryItems)..where((tbl) => tbl.id.equals(id)))
        .watchSingle();
  }

  Future<InventoryItem> getById(int id) {
    return (select(inventoryItems)..where((tbl) => tbl.id.equals(id))).getSingle();
  }

  /// Insert. When [item] carries `costPerItem`, `cost` is derived as
  /// round(qty × cpi, 2) (user input path). Without it, cost is kept and
  /// cpi = round4(cost / qty) (system path). See SPEC §3.2.
  Future<int> insertItem(InventoryItemsCompanion item) {
    return into(inventoryItems).insert(applyCostRulesCompanion(item));
  }

  /// Plain replace; callers that changed qty / cpi should pass the row
  /// through [applyUserCostEdit] first.
  Future<bool> updateItem(InventoryItem item) {
    final safe = item.cost < 0 ? item.copyWith(cost: 0) : item;
    return update(inventoryItems).replace(
      safe.costPerItem == null
          ? safe.copyWith(costPerItem: Value(cpiFromTotal(safe.cost, safe.quantity)))
          : safe,
    );
  }

  /// SPEC §3.2 single write rule for companions.
  static InventoryItemsCompanion applyCostRulesCompanion(
      InventoryItemsCompanion item) {
    var qty = item.quantity.present ? item.quantity.value : 1;
    if (qty < 1) qty = 1;
    if (qty > kMaxQty) qty = kMaxQty;
    final cpiVal = item.costPerItem.present ? item.costPerItem.value : null;
    if (cpiVal != null) {
      final cpi = round4(cpiVal < 0 ? 0 : cpiVal);
      return item.copyWith(
        quantity: Value(qty),
        costPerItem: Value(cpi),
        cost: Value(lineTotal(qty, cpi)),
      );
    }
    final cost = item.cost.present ? item.cost.value : 0.0;
    final c = round2(cost < 0 ? 0 : cost);
    return item.copyWith(
      quantity: Value(qty),
      cost: Value(c),
      costPerItem: Value(cpiFromTotal(c, qty)),
    );
  }

  /// User edited qty and/or cost per item: recompute the line total.
  static InventoryItem applyUserCostEdit(InventoryItem item,
      {required int qty, required double cpi}) {
    final q = qty.clamp(1, kMaxQty);
    final p = round4(cpi < 0 ? 0 : cpi);
    return item.copyWith(
      quantity: q,
      costPerItem: Value(p),
      cost: lineTotal(q, p),
    );
  }

  /// Sell [n] units of row [id] (SPEC §3.4). n == qty flips the row to Sold;
  /// n < qty splits off a Sold child. Returns the id of the Sold row.
  Future<int> sellUnits(int id, int n, {DateTime? date}) {
    return db.transaction(() async {
      final parent = await getById(id);
      if (parent.status == ItemStatus.sold) {
        throw StateError('Item $id is already sold');
      }
      final r = parent.quantity;
      if (n < 1 || n > r) {
        throw ArgumentError.value(n, 'n', 'must be 1..$r');
      }
      final sold = date ?? DateTime.now();
      if (n == r) {
        await update(inventoryItems).replace(parent.copyWith(
          status: ItemStatus.sold,
          dateSold: Value(sold),
          costPerItem: Value(parent.cpi),
        ));
        return id;
      }
      final cpi = parent.cpi;
      final money = splitMoney(parentTotal: parent.cost, cpi: cpi, n: n);
      await update(inventoryItems).replace(parent.copyWith(
        quantity: r - n,
        cost: money.parentCost,
        costPerItem: Value(cpi),
      ));
      return into(inventoryItems).insert(InventoryItemsCompanion.insert(
        dateAdded: parent.dateAdded,
        barcode: Value(parent.barcode),
        itemDescription: parent.itemDescription,
        type: parent.type,
        cost: money.childCost,
        quantity: Value(n),
        costPerItem: Value(cpi),
        parentId: Value(parent.id),
        platform: Value(parent.platform),
        status: ItemStatus.sold,
        dateSold: Value(sold),
        saleNumber: Value(parent.saleNumber),
        comments: Value(parent.comments),
        imageUrl: Value(parent.imageUrl),
        lookupName: Value(parent.lookupName),
        lookupDescription: Value(parent.lookupDescription),
      ));
    });
  }

  /// Un-sell a Sold row. A split child with a live, unsold parent merges back
  /// (qty and totals added; child deleted); otherwise the row flips to Active
  /// and dateSold is cleared. Returns the id of the resulting live row.
  Future<int> unsell(int soldId) {
    return db.transaction(() async {
      final child = await getById(soldId);
      if (child.status != ItemStatus.sold) return soldId;
      final parentId = child.parentId;
      InventoryItem? parent;
      if (parentId != null) {
        parent = await (select(inventoryItems)
              ..where((t) => t.id.equals(parentId)))
            .getSingleOrNull();
      }
      if (parent == null || parent.status == ItemStatus.sold) {
        await update(inventoryItems).replace(child.copyWith(
          status: ItemStatus.active,
          dateSold: const Value(null),
          parentId: const Value(null),
        ));
        return soldId;
      }
      final qty = parent.quantity + child.quantity;
      final costCents = toCents(parent.cost) + toCents(child.cost);
      final sameCpi = toBp(parent.cpi) == toBp(child.cpi);
      final cpi = sameCpi ? parent.cpi : cpiFromTotal(costCents / 100, qty);
      await update(inventoryItems).replace(parent.copyWith(
        quantity: qty > kMaxQty ? kMaxQty : qty,
        cost: centsToDollars(costCents),
        costPerItem: Value(cpi),
      ));
      await deleteItem(soldId);
      return parent.id;
    });
  }

  /// Number of units already split off (Sold children) per parent id.
  Future<Map<int, int>> soldChildUnitsByParent() async {
    final rows = await (select(inventoryItems)
          ..where((t) => t.parentId.isNotNull()))
        .get();
    final out = <int, int>{};
    for (final r in rows) {
      out[r.parentId!] = (out[r.parentId!] ?? 0) + r.quantity;
    }
    return out;
  }

  Stream<Map<int, int>> watchSoldChildUnitsByParent() {
    return (select(inventoryItems)..where((t) => t.parentId.isNotNull()))
        .watch()
        .map((rows) {
      final out = <int, int>{};
      for (final r in rows) {
        out[r.parentId!] = (out[r.parentId!] ?? 0) + r.quantity;
      }
      return out;
    });
  }

  /// Review-lots candidates: qty-1, non-split rows whose description carries
  /// a count (SPEC §4.3). Sold rows included (units history), dismissals
  /// are filtered by the caller.
  Future<List<LotSuggestion>> lotSuggestions() async {
    final rows = await (select(inventoryItems)
          ..where((t) => t.quantity.equals(1) & t.parentId.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.dateAdded)]))
        .get();
    return [
      for (final r in rows)
        if (suggestQtyFromDescription(r.itemDescription) case final n?)
          LotSuggestion(item: r, suggestedQty: n),
    ];
  }

  /// Review lots apply: qty = N, cpi = round4(cost/N), cost unchanged.
  Future<void> applyLotQty(int id, int n) async {
    final item = await getById(id);
    final q = n.clamp(1, kMaxQty);
    await update(inventoryItems).replace(item.copyWith(
      quantity: q,
      costPerItem: Value(cpiFromTotal(item.cost, q)),
    ));
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

  /// Units (Σ qty) with [status].
  Future<int> countByStatus(ItemStatus status) async {
    final countExp = inventoryItems.quantity.sum();
    final query = selectOnly(inventoryItems)
      ..addColumns([countExp])
      ..where(inventoryItems.status.equalsValue(status));
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  /// Units (Σ qty) with [status].
  Stream<int> watchCountByStatus(ItemStatus status) {
    final countExp = inventoryItems.quantity.sum();
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

  /// Mean of `(dateSold − dateAdded).inDays` for Sold items with [dateSold] set.
  /// Emits `null` when there are no qualifying Sold items.
  Stream<double?> watchAvgDaysToSell() {
    final query = select(inventoryItems)
      ..where((tbl) => tbl.status.equalsValue(ItemStatus.sold));
    return query.watch().map((items) {
      var sum = 0;
      var units = 0;
      for (final item in items) {
        final d = item.daysToSell;
        if (d != null) {
          sum += d * item.quantity;
          units += item.quantity;
        }
      }
      if (units == 0) return null;
      return sum / units;
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
          total += item.cost;
          count += item.quantity;
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
        final dollars = item.cost;
        if (age >= 90) {
          b90 = AgingBucket(
            label: b90.label,
            totalCostTimesQty: b90.totalCostTimesQty + dollars,
            itemCount: b90.itemCount + item.quantity,
          );
        } else if (age >= 60) {
          b60 = AgingBucket(
            label: b60.label,
            totalCostTimesQty: b60.totalCostTimesQty + dollars,
            itemCount: b60.itemCount + item.quantity,
          );
        } else if (age >= 30) {
          b30 = AgingBucket(
            label: b30.label,
            totalCostTimesQty: b30.totalCostTimesQty + dollars,
            itemCount: b30.itemCount + item.quantity,
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
        switch (sellThroughBucket(item, cutoff)) {
          case SellThroughBucket.stillActive:
            stillActive += item.quantity;
          case SellThroughBucket.sold:
            sold += item.quantity;
          case null:
            break;
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
        [
          for (final item in items)
            if (item.dateSold != null) (item.dateSold!, item.quantity),
        ],
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
      // Units added per month, all statuses. Split children are excluded as
      // rows and added back to their parent so a lot counts once at full
      // size; orphan children count themselves (SPEC §6).
      final ids = {for (final i in items) i.id};
      final childUnits = <int, int>{};
      for (final i in items) {
        if (i.parentId != null && ids.contains(i.parentId)) {
          childUnits[i.parentId!] = (childUnits[i.parentId!] ?? 0) + i.quantity;
        }
      }
      return _monthlyInventoryCounts(
        [
          for (final item in items)
            if (item.parentId == null || !ids.contains(item.parentId))
              (item.dateAdded, item.quantity + (childUnits[item.id] ?? 0)),
        ],
        monthCount: monthCount,
        minMonthCount: minMonthCount,
        anchor: anchor,
      );
    });
  }

  static List<MonthlyInventoryCount> _monthlyInventoryCounts(
    List<(DateTime, int)> dated, {
    int? monthCount,
    int minMonthCount = 6,
    DateTime? anchor,
  }) {
    DateTime? earliest;
    for (final (date, _) in dated) {
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
          count: dated
              .where((e) =>
                  e.$1.year == monthStart.year &&
                  e.$1.month == monthStart.month)
              .fold<int>(0, (s, e) => s + e.$2),
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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // Additive only: existing values (incl. cost) never change.
            await m.addColumn(inventoryItems, inventoryItems.costPerItem);
            await m.addColumn(inventoryItems, inventoryItems.parentId);
          }
        },
        beforeOpen: (details) async {
          await backfillCostPerItem();
        },
      );

  /// Idempotent backfill (SPEC §4.2): cpi = round4(cost / max(qty,1)) where
  /// cpi IS NULL. Never touches `cost`.
  Future<int> backfillCostPerItem() {
    return customUpdate(
      'UPDATE inventory_items SET cost_per_item = '
      'ROUND(cost * 1.0 / MAX(quantity, 1), 4) WHERE cost_per_item IS NULL',
      updates: {inventoryItems},
    );
  }

  static QueryExecutor _openConnection() {
    return impl.openConnection();
  }
}

/// Schema v1 DDL (pre-quantity), used by migration tests and the QA-only
/// "Load legacy v1 fixture" tool (SPEC §12.9). Matches drift's v1 output.
const List<String> kSchemaV1Ddl = [
  'CREATE TABLE IF NOT EXISTS "inventory_items" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"date_added" INTEGER NOT NULL, "barcode" TEXT NULL, "item_description" TEXT NOT NULL, '
      '"type" TEXT NOT NULL, "cost" REAL NOT NULL, "quantity" INTEGER NOT NULL DEFAULT 1, '
      '"platform" TEXT NULL, "status" TEXT NOT NULL, "date_sold" INTEGER NULL, '
      '"sale_number" TEXT NULL, "comments" TEXT NULL, "image_url" TEXT NULL, '
      '"lookup_name" TEXT NULL, "lookup_description" TEXT NULL)',
  'CREATE TABLE IF NOT EXISTS "expenses" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"date" INTEGER NOT NULL, "merchant" TEXT NOT NULL, "receipt_image_path" TEXT NULL, '
      '"upc" TEXT NULL, "item_description" TEXT NOT NULL, "quantity" INTEGER NOT NULL DEFAULT 1, '
      '"unit_price" REAL NOT NULL, "expense_type" TEXT NOT NULL, "tax_amount" REAL NULL)',
  'CREATE TABLE IF NOT EXISTS "barcode_cache_entries" ("barcode" TEXT NOT NULL, '
      '"product_name" TEXT NULL, "description" TEXT NULL, "image_url" TEXT NULL, '
      '"category" TEXT NULL, "source" TEXT NOT NULL, "fetched_at" INTEGER NOT NULL, '
      'PRIMARY KEY ("barcode"))',
];
