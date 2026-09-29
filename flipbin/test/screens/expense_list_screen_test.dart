import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/providers/expense_provider.dart';
import 'package:flipbin/screens/expenses/expense_detail_screen.dart';
import 'package:flipbin/screens/expenses/expense_list_screen.dart';

void main() {
  final sampleExpenses = [
    Expense(
      id: 1,
      date: DateTime(2026, 3, 10),
      merchant: 'USPS',
      itemDescription: 'Priority Mail Boxes',
      quantity: 2,
      unitPrice: 5.00,
      expenseType: ExpenseType.shipping,
    ),
    Expense(
      id: 2,
      date: DateTime(2026, 3, 15),
      merchant: 'Best Buy',
      itemDescription: 'Label Printer',
      quantity: 1,
      unitPrice: 65.00,
      expenseType: ExpenseType.equipment,
    ),
  ];

  testWidgets('expense list shows items with type badges and totals', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expenseListProvider.overrideWith(
            (ref, filter) => Stream.value(sampleExpenses),
          ),
          expenseMonthTotalProvider.overrideWith(
            (ref, month) => Stream.value(75.00),
          ),
        ],
        child: const MaterialApp(
          home: ExpenseListScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('USPS'), findsOneWidget);
    expect(find.text('Priority Mail Boxes'), findsOneWidget);
    expect(find.text('\$10.00'), findsOneWidget);
    expect(find.text('Best Buy'), findsOneWidget);
    expect(find.text('Label Printer'), findsOneWidget);
    expect(find.text('\$65.00'), findsOneWidget);
    expect(find.text('Shipping'), findsWidgets);
    expect(find.text('Equipment'), findsWidgets);
  });

  testWidgets('month selector filters expenses', (tester) async {
    DateTime? capturedMonth;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expenseListProvider.overrideWith(
            (ref, filter) {
              capturedMonth = filter.monthFilter;
              return Stream.value(sampleExpenses);
            },
          ),
          expenseMonthTotalProvider.overrideWith(
            (ref, month) => Stream.value(75.00),
          ),
        ],
        child: const MaterialApp(
          home: ExpenseListScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final prevMonthButton = find.byIcon(Icons.chevron_left);
    expect(prevMonthButton, findsOneWidget);
    await tester.tap(prevMonthButton);
    await tester.pumpAndSettle();

    expect(capturedMonth, isNotNull);
  });

  testWidgets('running total bar shows correct sum', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expenseListProvider.overrideWith(
            (ref, filter) => Stream.value(sampleExpenses),
          ),
          expenseMonthTotalProvider.overrideWith(
            (ref, month) => Stream.value(75.00),
          ),
        ],
        child: const MaterialApp(
          home: ExpenseListScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Total: \$75.00'), findsOneWidget);
  });

  testWidgets('expense form validates required fields', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ExpenseDetailScreen(expenseId: 'new'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final saveButton = find.widgetWithText(ElevatedButton, 'Save');
    expect(saveButton, findsOneWidget);
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Merchant is required'), findsOneWidget);
    expect(find.text('Description is required'), findsOneWidget);
  });

  testWidgets('expense form computes total from qty × price', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ExpenseDetailScreen(expenseId: 'new'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final priceField = find.widgetWithText(TextFormField, '0.00');
    expect(priceField, findsOneWidget);
    await tester.enterText(priceField, '6.74');
    await tester.pumpAndSettle();

    final addQtyButton = find.byIcon(Icons.add_circle_outline);
    await tester.tap(addQtyButton); // qty becomes 2
    await tester.pumpAndSettle();

    expect(find.text('Total: \$13.48'), findsOneWidget);
  });
}
