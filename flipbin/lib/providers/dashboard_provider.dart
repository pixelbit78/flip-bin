import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/providers/database_provider.dart';

/// Mean days-to-sell across Sold items with `dateSold` set. `null` when empty.
final avgDaysToSellProvider = StreamProvider<double?>((ref) {
  final db = ref.watch(databaseProvider);
  return db.inventoryItemsDao.watchAvgDaysToSell();
});

/// Aging capital KPI: Active stock aged ≥ 30 days (cost × qty + count).
final agingCapitalProvider = StreamProvider<AgingCapitalSummary>((ref) {
  final db = ref.watch(databaseProvider);
  return db.inventoryItemsDao.watchAgingCapital();
});

/// Total cost KPI: sum(cost × qty) for ALL Active items.
final activeTotalCostTimesQtyProvider = StreamProvider<double>((ref) {
  final db = ref.watch(databaseProvider);
  return db.inventoryItemsDao
      .watchTotalCostTimesQtyByStatus(ItemStatus.active);
});

/// Aging capital breakdown buckets (Active 30–59 / 60–89 / 90+).
final agingBucketsProvider = StreamProvider<AgingBuckets>((ref) {
  final db = ref.watch(databaseProvider);
  return db.inventoryItemsDao.watchAgingBuckets();
});

/// Sell-through over the trailing 90-day window.
///
/// See [InventoryItemsDao.watchSellThrough] for the cohort definition.
final sellThroughProvider = StreamProvider<SellThroughMetrics>((ref) {
  final db = ref.watch(databaseProvider);
  return db.inventoryItemsDao.watchSellThrough();
});

/// Last 6 calendar months of expense totals (qty × unitPrice), oldest first.
final monthlyExpensesProvider =
    StreamProvider<List<MonthlyExpenseTotal>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.expensesDao.watchMonthlyTotals();
});

/// Top 3 Sold items by fastest days-to-sell.
final topMoversProvider = StreamProvider<List<InventoryItem>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.inventoryItemsDao.watchTopMovers();
});

/// Compact currency for dashboard KPIs (`$840`, `$1.6k`).
String formatDashboardMoney(double value) {
  final abs = value.abs();
  if (abs >= 1000) {
    final k = value / 1000;
    final text = (k == k.roundToDouble())
        ? k.toStringAsFixed(0)
        : k.toStringAsFixed(1);
    return '\$${text}k';
  }
  if (abs >= 100 || value == value.roundToDouble()) {
    return '\$${value.round()}';
  }
  return '\$${value.toStringAsFixed(2)}';
}

/// Formats avg days like `18d`, or `—` when unknown.
String formatAvgDays(double? avg) {
  if (avg == null) return '—';
  return '${avg.round()}d';
}
