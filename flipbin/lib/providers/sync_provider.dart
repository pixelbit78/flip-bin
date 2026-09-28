import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flipbin/providers/database_provider.dart';
import 'package:flipbin/providers/expense_provider.dart';
import 'package:flipbin/providers/inventory_provider.dart';
import 'package:flipbin/services/google_sheets_service.dart';

/// State of Google Sheets synchronization.
class SyncState {
  final GoogleSignInAccount? account;
  final bool isSyncing;
  final bool isImporting;
  final DateTime? lastSyncedAt;
  final DateTime? lastImportedAt;
  final String? error;
  final String? clientId;
  final String? spreadsheetId;

  const SyncState({
    this.account,
    this.isSyncing = false,
    this.isImporting = false,
    this.lastSyncedAt,
    this.lastImportedAt,
    this.error,
    this.clientId,
    this.spreadsheetId,
  });

  SyncState copyWith({
    GoogleSignInAccount? account,
    bool? isSyncing,
    bool? isImporting,
    DateTime? lastSyncedAt,
    DateTime? lastImportedAt,
    String? error,
    String? clientId,
    String? spreadsheetId,
    bool clearError = false,
    bool clearAccount = false,
    bool clearSpreadsheetId = false,
  }) {
    return SyncState(
      account: clearAccount ? null : (account ?? this.account),
      isSyncing: isSyncing ?? this.isSyncing,
      isImporting: isImporting ?? this.isImporting,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      lastImportedAt: lastImportedAt ?? this.lastImportedAt,
      error: clearError ? null : (error ?? this.error),
      clientId: clientId ?? this.clientId,
      spreadsheetId:
          clearSpreadsheetId ? null : (spreadsheetId ?? this.spreadsheetId),
    );
  }
}

/// Provider for [GoogleSheetsService].
final googleSheetsServiceProvider = Provider<GoogleSheetsService>((ref) {
  return GoogleSheetsService();
});

/// Notifier managing Google Sheets sign-in and export sync.
class SyncNotifier extends StateNotifier<SyncState> {
  final GoogleSheetsService _sheetsService;
  final Ref _ref;

  SyncNotifier(this._sheetsService, this._ref) : super(const SyncState());

  void setClientId(String clientId) {
    _sheetsService.configureClientId(clientId);
    state = state.copyWith(clientId: clientId, clearError: true);
  }

  Future<void> signIn() async {
    try {
      final account = await _sheetsService.signIn();
      state = state.copyWith(account: account, clearError: true);
    } catch (e) {
      state = state.copyWith(
        error:
            'Google Sign-In failed: $e\n\nTip: On Web, Google Sign-In requires an OAuth Client ID from Google Cloud Console with http://localhost:8080 authorized.',
      );
    }
  }

  void signInDemo() {
    state = state.copyWith(
      account: DemoGoogleSignInAccount(),
      clearError: true,
    );
  }

  Future<void> signOut() async {
    try {
      await _sheetsService.signOut();
      state = state.copyWith(
        clearAccount: true,
        clearError: true,
        clearSpreadsheetId: true,
      );
    } catch (e) {
      state = state.copyWith(error: 'Sign out failed: $e');
    }
  }

  Future<void> export() async {
    await sync();
  }

  Future<void> sync() async {
    if (state.isSyncing || state.isImporting) return;

    state = state.copyWith(isSyncing: true, clearError: true);
    try {
      final db = _ref.read(databaseProvider);
      final items = await db.inventoryItemsDao.getAllForExport();
      final expenses = await db.expensesDao.getAllForExport();

      final sheetId = await _sheetsService.syncToSheets(
        items,
        expenses,
        existingSpreadsheetId: state.spreadsheetId,
      );

      state = state.copyWith(
        isSyncing: false,
        lastSyncedAt: DateTime.now(),
        spreadsheetId: sheetId,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        error: 'Export failed: $e',
      );
    }
  }

  Future<({int itemsCount, int expensesCount})?> import() async {
    if (state.isSyncing || state.isImporting) return null;

    state = state.copyWith(isImporting: true, clearError: true);
    try {
      final importData = await _sheetsService.importFromSheets(
        existingSpreadsheetId: state.spreadsheetId,
      );

      final db = _ref.read(databaseProvider);
      await db.inventoryItemsDao.replaceAll(importData.items);
      await db.expensesDao.replaceAll(importData.expenses);

      // Invalidate stream list providers to immediately update active screens
      _ref.invalidate(inventoryListProvider);
      _ref.invalidate(expenseListProvider);

      state = state.copyWith(
        isImporting: false,
        lastImportedAt: DateTime.now(),
        clearError: true,
      );

      return (
        itemsCount: importData.items.length,
        expensesCount: importData.expenses.length,
      );
    } catch (e) {
      state = state.copyWith(
        isImporting: false,
        error: 'Import failed: $e',
      );
      return null;
    }
  }
}

/// Provider for sync state and actions.
final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  final service = ref.watch(googleSheetsServiceProvider);
  return SyncNotifier(service, ref);
});
