import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/providers/database_provider.dart';

/// Total cost KPI: sum(cost × qty) for ALL Active items.
final activeTotalCostTimesQtyProvider = StreamProvider<double>((ref) {
  final db = ref.watch(databaseProvider);
  return db.inventoryItemsDao
      .watchTotalCostTimesQtyByStatus(ItemStatus.active);
});

/// Total active KPI: count of Active inventory items.
final activeItemCountProvider = StreamProvider<int>((ref) {
  final db = ref.watch(databaseProvider);
  return db.inventoryItemsDao.watchCountByStatus(ItemStatus.active);
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

/// Last 6 calendar months of sold-item counts by `dateSold`, oldest first.
final monthlySoldProvider =
    StreamProvider<List<MonthlyInventoryCount>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.inventoryItemsDao.watchMonthlySoldCounts();
});

/// Last 6 calendar months of listed-item counts by `dateAdded`, oldest first.
final monthlyListedProvider =
    StreamProvider<List<MonthlyInventoryCount>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.inventoryItemsDao.watchMonthlyListedCounts();
});

/// Exact currency for the Home **Total cost** KPI (`$1,847.32`).
///
/// Always shows dollars with grouping commas and two cent digits.
String formatDashboardTotalCost(double value) {
  return NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(value);
}

/// Compact currency for non-KPI dashboard money (`$840`, `$1.6k`).
///
/// Used by aging capital row amounts and monthly expense bar labels —
/// not the Total cost KPI.
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
