import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/providers/database_provider.dart';
import 'package:flipbin/providers/expense_provider.dart';

void main() {
  late FlipBinDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = FlipBinDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('expenseListProvider emits expenses filtered by type', () async {
    final now = DateTime.now();

    await db.expensesDao.insertExpense(
      ExpensesCompanion.insert(
        date: now,
        merchant: 'USPS',
        itemDescription: 'Boxes',
        unitPrice: 10.0,
        expenseType: ExpenseType.shipping,
      ),
    );
    await db.expensesDao.insertExpense(
      ExpensesCompanion.insert(
        date: now,
        merchant: 'Best Buy',
        itemDescription: 'Label Printer',
        unitPrice: 60.0,
        expenseType: ExpenseType.equipment,
      ),
    );
    await db.expensesDao.insertExpense(
      ExpensesCompanion.insert(
        date: now,
        merchant: 'USPS',
        itemDescription: 'Envelopes',
        unitPrice: 5.0,
        expenseType: ExpenseType.shipping,
      ),
    );

    final shippingExpenses = await container.read(
      expenseListProvider(const ExpenseFilter(typeFilter: ExpenseType.shipping)).future,
    );
    expect(shippingExpenses.length, equals(2));

    final equipExpenses = await container.read(
      expenseListProvider(const ExpenseFilter(typeFilter: ExpenseType.equipment)).future,
    );
    expect(equipExpenses.length, equals(1));
    expect(equipExpenses.first.merchant, equals('Best Buy'));
  });

  test('expenseListProvider filters by month', () async {
    final march = DateTime(2026, 3, 15);
    final april = DateTime(2026, 4, 10);

    await db.expensesDao.insertExpense(
      ExpensesCompanion.insert(
        date: march,
        merchant: 'USPS',
        itemDescription: 'Boxes',
        unitPrice: 10.0,
        expenseType: ExpenseType.shipping,
      ),
    );
    await db.expensesDao.insertExpense(
      ExpensesCompanion.insert(
        date: april,
        merchant: 'Walmart',
        itemDescription: 'Tape',
        unitPrice: 5.0,
        expenseType: ExpenseType.shipping,
      ),
    );

    final marchExpenses = await container.read(
      expenseListProvider(ExpenseFilter(monthFilter: DateTime(2026, 3, 1))).future,
    );
    expect(marchExpenses.length, equals(1));
    expect(marchExpenses.first.merchant, equals('USPS'));

    final aprilExpenses = await container.read(
      expenseListProvider(ExpenseFilter(monthFilter: DateTime(2026, 4, 1))).future,
    );
    expect(aprilExpenses.length, equals(1));
    expect(aprilExpenses.first.merchant, equals('Walmart'));
  });

  test('saveExpense inserts and invalidates list', () async {
    final controller = container.read(expenseControllerProvider);

    final initialList = await container.read(
      expenseListProvider(const ExpenseFilter()).future,
    );
    expect(initialList, isEmpty);

    await controller.saveExpense(
      ExpensesCompanion.insert(
        date: DateTime.now(),
        merchant: 'Amazon',
        itemDescription: 'Bubble Wrap',
        unitPrice: 15.0,
        expenseType: ExpenseType.shipping,
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 50));
    final updatedList = await container.read(
      expenseListProvider(const ExpenseFilter()).future,
    );
    expect(updatedList.length, equals(1));
    expect(updatedList.first.merchant, equals('Amazon'));
  });

  test('expenseMonthTotalProvider returns correct sum', () async {
    final march = DateTime(2026, 3, 15);

    await db.expensesDao.insertExpense(
      ExpensesCompanion.insert(
        date: march,
        merchant: 'USPS',
        itemDescription: 'Boxes',
        unitPrice: 10.0,
        expenseType: ExpenseType.shipping,
      ),
    );
    await db.expensesDao.insertExpense(
      ExpensesCompanion.insert(
        date: march,
        merchant: 'Staples',
        itemDescription: 'Tape',
        unitPrice: 5.0,
        expenseType: ExpenseType.shipping,
      ),
    );

    final total = await container.read(
      expenseMonthTotalProvider(DateTime(2026, 3, 1)).future,
    );
    expect(total, equals(15.0));
  });
}
