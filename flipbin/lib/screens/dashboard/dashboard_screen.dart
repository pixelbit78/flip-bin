import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/providers/expense_provider.dart';
import 'package:flipbin/providers/inventory_provider.dart';
import 'package:flipbin/widgets/summary_card.dart';

/// Dashboard home screen displaying inventory & expense summary cards and quick action buttons.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);

    final activeCountAsync = ref.watch(inventoryCountProvider(ItemStatus.active));
    final soldCountAsync = ref.watch(inventoryCountProvider(ItemStatus.sold));
    final totalCostAsync = ref.watch(inventoryTotalCostProvider(ItemStatus.active));
    final monthExpensesAsync = ref.watch(expenseMonthTotalProvider(currentMonth));
    final allExpensesAsync = ref.watch(expenseTotalProvider);

    final activeCount = activeCountAsync.valueOrNull ?? 0;
    final soldCount = soldCountAsync.valueOrNull ?? 0;
    final totalCost = totalCostAsync.valueOrNull ?? 0.0;
    final monthExpenses = monthExpensesAsync.valueOrNull ?? 0.0;
    final allExpenses = allExpensesAsync.valueOrNull ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          children: [
            Text(
              'FlipBin',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Text(
              'Inventory & Expense Tracking',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SummaryCard(
                    title: 'Inventory',
                    rows: [
                      SummaryRow(
                        icon: Icons.inventory_2,
                        label: 'Active',
                        value: '$activeCount',
                      ),
                      SummaryRow(
                        icon: Icons.check_circle_outline,
                        label: 'Sold',
                        value: '$soldCount',
                      ),
                      SummaryRow(
                        icon: Icons.attach_money,
                        label: 'Invested',
                        value: '\$${totalCost.toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SummaryCard(
                    title: 'Expenses',
                    rows: [
                      SummaryRow(
                        icon: Icons.calendar_today,
                        label: 'This Month',
                        value: '\$${monthExpenses.toStringAsFixed(2)}',
                      ),
                      SummaryRow(
                        icon: Icons.receipt_long,
                        label: 'All Time',
                        value: '\$${allExpenses.toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => context.go('/scan'),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Barcode'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => context.go('/inventory/new'),
              icon: const Icon(Icons.add_box),
              label: const Text('Add Item'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => context.go('/expenses/new'),
              icon: const Icon(Icons.post_add),
              label: const Text('Add Expense'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
