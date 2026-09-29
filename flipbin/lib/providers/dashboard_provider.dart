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

/// Live inventory summary (composes Drift-backed stream providers).
final dashboardInventorySummaryProvider =
    Provider<AsyncValue<InventorySummaryMetrics>>((ref) {
  final activeCount = ref.watch(inventoryCountProvider(ItemStatus.active));
  final soldCount = ref.watch(inventoryCountProvider(ItemStatus.sold));
  final totalInvested =
      ref.watch(inventoryTotalCostProvider(ItemStatus.active));

  if (activeCount.hasError) {
    return AsyncValue.error(activeCount.error!, activeCount.stackTrace!);
  }
  if (soldCount.hasError) {
    return AsyncValue.error(soldCount.error!, soldCount.stackTrace!);
  }
  if (totalInvested.hasError) {
    return AsyncValue.error(totalInvested.error!, totalInvested.stackTrace!);
  }
  if (!activeCount.hasValue || !soldCount.hasValue || !totalInvested.hasValue) {
    return const AsyncValue.loading();
  }

  return AsyncValue.data(
    InventorySummaryMetrics(
      activeCount: activeCount.requireValue,
      soldCount: soldCount.requireValue,
      totalInvested: totalInvested.requireValue,
    ),
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

/// Live expense summary (composes Drift-backed stream providers).
final dashboardExpenseSummaryProvider =
    Provider<AsyncValue<ExpenseSummaryMetrics>>((ref) {
  final now = DateTime.now();
  final currentMonth = DateTime(now.year, now.month, 1);
  final monthTotal = ref.watch(expenseMonthTotalProvider(currentMonth));
  final allTimeTotal = ref.watch(expenseTotalProvider);

  if (monthTotal.hasError) {
    return AsyncValue.error(monthTotal.error!, monthTotal.stackTrace!);
  }
  if (allTimeTotal.hasError) {
    return AsyncValue.error(allTimeTotal.error!, allTimeTotal.stackTrace!);
  }
  if (!monthTotal.hasValue || !allTimeTotal.hasValue) {
    return const AsyncValue.loading();
  }

  return AsyncValue.data(
    ExpenseSummaryMetrics(
      monthTotal: monthTotal.requireValue,
      allTimeTotal: allTimeTotal.requireValue,
    ),
  );
});
