import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flipbin/providers/database_provider.dart';
import 'package:flipbin/services/google_sheets_service.dart';

/// State of Google Sheets synchronization.
class SyncState {
  final GoogleSignInAccount? account;
  final bool isSyncing;
  final DateTime? lastSyncedAt;
  final String? error;

  const SyncState({
    this.account,
    this.isSyncing = false,
    this.lastSyncedAt,
    this.error,
  });

  SyncState copyWith({
    GoogleSignInAccount? account,
    bool? isSyncing,
    DateTime? lastSyncedAt,
    String? error,
    bool clearError = false,
    bool clearAccount = false,
  }) {
    return SyncState(
      account: clearAccount ? null : (account ?? this.account),
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      error: clearError ? null : (error ?? this.error),
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

  Future<void> signIn() async {
    try {
      final account = await _sheetsService.signIn();
      state = state.copyWith(account: account, clearError: true);
    } catch (e) {
      state = state.copyWith(error: 'Sign in failed: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _sheetsService.signOut();
      state = state.copyWith(clearAccount: true, clearError: true);
    } catch (e) {
      state = state.copyWith(error: 'Sign out failed: $e');
    }
  }

  Future<void> sync() async {
    if (state.isSyncing) return;

    state = state.copyWith(isSyncing: true, clearError: true);
    try {
      final db = _ref.read(databaseProvider);
      final items = await db.inventoryItemsDao.getAllForExport();
      final expenses = await db.expensesDao.getAllForExport();

      await _sheetsService.syncToSheets(items, expenses);

      state = state.copyWith(
        isSyncing: false,
        lastSyncedAt: DateTime.now(),
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        error: 'Sync failed: $e',
      );
    }
  }
}

/// Provider for sync state and actions.
final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  final service = ref.watch(googleSheetsServiceProvider);
  return SyncNotifier(service, ref);
});
