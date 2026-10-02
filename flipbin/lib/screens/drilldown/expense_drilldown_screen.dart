import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/drilldown_query.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/providers/expense_provider.dart';

/// Home-originated expenses drill-down filtered by expenseDate month.
///
/// No search, no FAB. Bottom nav stays on Home via `/drilldown/expenses`.
class ExpenseDrillDownScreen extends ConsumerWidget {
  const ExpenseDrillDownScreen({super.key, required this.query});

  final ExpenseDrillDownQuery query;

  static const _bg = Color(0xFF1A1D23);
  static const _card = Color(0xFF252830);
  static const _accent = Color(0xFF2196F3);

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _clearMonth(BuildContext context) {
    _goBack(context);
  }

  IconData _iconFor(ExpenseType type) {
    switch (type) {
      case ExpenseType.shipping:
        return Icons.local_shipping_outlined;
      case ExpenseType.equipment:
        return Icons.inventory_2_outlined;
      case ExpenseType.software:
        return Icons.credit_card;
      case ExpenseType.travel:
        return Icons.directions_car_outlined;
      case ExpenseType.other:
        return Icons.receipt_long;
    }
  }

  Color _iconBgFor(ExpenseType type) {
    switch (type) {
      case ExpenseType.shipping:
        return const Color(0xFF00897B);
      case ExpenseType.equipment:
        return const Color(0xFF7E57C2);
      case ExpenseType.software:
        return const Color(0xFFFFA000);
      case ExpenseType.travel:
        return const Color(0xFF2196F3);
      case ExpenseType.other:
        return const Color(0xFF607D8B);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ExpenseFilter(monthFilter: query.month);
    final expensesAsync = ref.watch(expenseListProvider(filter));
    final dateFmt = DateFormat('MMM d');

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 32),
          tooltip: 'Home',
          onPressed: () => _goBack(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              query.title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            expensesAsync.when(
              data: (expenses) {
                final total =
                    expenses.fold<double>(0, (s, e) => s + e.total);
                return Text(
                  '${expenses.length} expenses · \$${total.toStringAsFixed(2)} total',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white54,
                    fontWeight: FontWeight.w400,
                  ),
                );
              },
              loading: () => const Text(
                '…',
                style: TextStyle(fontSize: 13, color: Colors.white54),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
        titleSpacing: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Material(
                color: _accent,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: () => _clearMonth(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          query.monthChipLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: expensesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (expenses) {
                if (expenses.isEmpty) {
                  return const Center(
                    child: Text(
                      'No expenses found',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }
                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: expenses.length,
                  itemBuilder: (context, index) {
                    final expense = expenses[index];
                    return Card(
                      color: _card,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => context.push('/expenses/${expense.id}'),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: _iconBgFor(expense.expenseType)
                                      .withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _iconFor(expense.expenseType),
                                  color: _iconBgFor(expense.expenseType),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      expense.merchant,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      expense.itemDescription,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '\$${expense.total.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    dateFmt.format(expense.date),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white38,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
