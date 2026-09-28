import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/providers/expense_provider.dart';
import 'package:flipbin/providers/inventory_provider.dart';

/// Aggregated inventory dashboard metrics.
class InventorySummaryMetrics {
  final int activeCount;
  final int soldCount;
  final double totalInvested;

  const InventorySummaryMetrics({
    required this.activeCount,
    required this.soldCount,
    required this.totalInvested,
  });
}

/// Provider for inventory summary data shown on dashboard.
final dashboardInventorySummaryProvider =
    FutureProvider<InventorySummaryMetrics>((ref) async {
  final activeCount =
      await ref.watch(inventoryCountProvider(ItemStatus.active).future);
  final soldCount =
      await ref.watch(inventoryCountProvider(ItemStatus.sold).future);
  final totalInvested =
      await ref.watch(inventoryTotalCostProvider(ItemStatus.active).future);

  return InventorySummaryMetrics(
    activeCount: activeCount,
    soldCount: soldCount,
    totalInvested: totalInvested,
  );
});

/// Aggregated expense dashboard metrics.
class ExpenseSummaryMetrics {
  final double monthTotal;
  final double allTimeTotal;

  const ExpenseSummaryMetrics({
    required this.monthTotal,
    required this.allTimeTotal,
  });
}

/// Provider for expense summary data shown on dashboard.
final dashboardExpenseSummaryProvider =
    FutureProvider<ExpenseSummaryMetrics>((ref) async {
  final now = DateTime.now();
  final currentMonth = DateTime(now.year, now.month, 1);
  final monthTotal =
      await ref.watch(expenseMonthTotalProvider(currentMonth).future);
  final allTimeTotal = await ref.watch(expenseTotalProvider.future);

  return ExpenseSummaryMetrics(
    monthTotal: monthTotal,
    allTimeTotal: allTimeTotal,
  );
});
