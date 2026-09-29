import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/providers/database_provider.dart';

/// Filter parameters for the expense list provider.
class ExpenseFilter {
  final ExpenseType? typeFilter;
  final DateTime? monthFilter;
  final String? searchQuery;

  const ExpenseFilter({this.typeFilter, this.monthFilter, this.searchQuery});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseFilter &&
          runtimeType == other.runtimeType &&
          typeFilter == other.typeFilter &&
          monthFilter == other.monthFilter &&
          searchQuery == other.searchQuery;

  @override
  int get hashCode => Object.hash(typeFilter, monthFilter, searchQuery);
}

/// Reactive list of expenses filtered by type, month, and search query.
final expenseListProvider =
    StreamProvider.family<List<Expense>, ExpenseFilter>((ref, filter) {
  final db = ref.watch(databaseProvider);
  return db.expensesDao.watchAll(
    typeFilter: filter.typeFilter,
    monthFilter: filter.monthFilter,
    searchQuery: filter.searchQuery,
  );
});

/// Live total expenses for a given month (Drift stream).
final expenseMonthTotalProvider =
    StreamProvider.family<double, DateTime>((ref, month) {
  final db = ref.watch(databaseProvider);
  return db.expensesDao.watchTotalForMonth(month);
});

/// Live total of all expenses (Drift stream).
final expenseTotalProvider = StreamProvider<double>((ref) {
  final db = ref.watch(databaseProvider);
  return db.expensesDao.watchTotalAll();
});

/// Single expense by ID.
final expenseItemProvider =
    FutureProvider.family<Expense, int>((ref, id) {
  final db = ref.watch(databaseProvider);
  return db.expensesDao.getById(id);
});

/// Controller for expense CRUD operations.
class ExpenseController {
  final Ref _ref;
  final FlipBinDatabase _db;

  ExpenseController(this._ref, this._db);

  Future<int> saveExpense(ExpensesCompanion expense) async {
    final id = await _db.expensesDao.insertExpense(expense);
    _invalidateAll();
    return id;
  }

  Future<void> updateExpense(Expense expense) async {
    await _db.expensesDao.updateExpense(expense);
    _invalidateAll();
  }

  Future<void> deleteExpense(int id) async {
    await _db.expensesDao.deleteExpense(id);
    _invalidateAll();
  }

  void _invalidateAll() {
    // Streams already live-update; thin backup for family caches.
    _ref.invalidate(expenseTotalProvider);
  }
}

/// Provider for expense CRUD controller.
final expenseControllerProvider = Provider<ExpenseController>((ref) {
  final db = ref.watch(databaseProvider);
  return ExpenseController(ref, db);
});
