import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flipbin/providers/database_provider.dart';
import 'package:flipbin/providers/expense_provider.dart';
import 'package:flipbin/providers/inventory_provider.dart';
import 'package:flipbin/services/google_sheets_service.dart';

/// Minimum age of the last successful export before an automatic backup runs.
const Duration kAutoBackupInterval = Duration(hours: 24);

/// State of Google Sheets synchronization.
class SyncState {
  final GoogleSignInAccount? account;
  final String? restoredEmail;
  final String? restoredDisplayName;
  final bool isRestoring;
  final bool isSyncing;
  final bool isImporting;
  final DateTime? lastSyncedAt;
  final DateTime? lastImportedAt;
  final String? error;
  final String? clientId;
  final String? spreadsheetId;
  final bool autoBackupEnabled;
  /// True when Google auth is stale and the user must sign in again before
  /// export/import or silent auto-backup can run.
  final bool needsReauth;
  /// Calm, non-scary notice (e.g. re-auth hint). Shown separately from [error].
  final String? authNotice;

  const SyncState({
    this.account,
    this.restoredEmail,
    this.restoredDisplayName,
    this.isRestoring = false,
    this.isSyncing = false,
    this.isImporting = false,
    this.lastSyncedAt,
    this.lastImportedAt,
    this.error,
    this.clientId,
    this.spreadsheetId,
    this.autoBackupEnabled = false,
    this.needsReauth = false,
    this.authNotice,
  });

  bool get isSignedIn =>
      account != null ||
      (restoredEmail != null && restoredEmail!.isNotEmpty);

  String? get displayEmail => account?.email ?? restoredEmail;

  String? get displayName =>
      account?.displayName ?? restoredDisplayName ?? account?.email;

  SyncState copyWith({
    GoogleSignInAccount? account,
    String? restoredEmail,
    String? restoredDisplayName,
    bool? isRestoring,
    bool? isSyncing,
    bool? isImporting,
    DateTime? lastSyncedAt,
    DateTime? lastImportedAt,
    String? error,
    String? clientId,
    String? spreadsheetId,
    bool? autoBackupEnabled,
    bool? needsReauth,
    String? authNotice,
    bool clearError = false,
    bool clearAccount = false,
    bool clearRestored = false,
    bool clearSpreadsheetId = false,
    bool clearAuthNotice = false,
  }) {
    return SyncState(
      account: clearAccount ? null : (account ?? this.account),
      restoredEmail:
          clearRestored ? null : (restoredEmail ?? this.restoredEmail),
      restoredDisplayName: clearRestored
          ? null
          : (restoredDisplayName ?? this.restoredDisplayName),
      isRestoring: isRestoring ?? this.isRestoring,
      isSyncing: isSyncing ?? this.isSyncing,
      isImporting: isImporting ?? this.isImporting,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      lastImportedAt: lastImportedAt ?? this.lastImportedAt,
      error: clearError ? null : (error ?? this.error),
      clientId: clientId ?? this.clientId,
      spreadsheetId:
          clearSpreadsheetId ? null : (spreadsheetId ?? this.spreadsheetId),
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      needsReauth: needsReauth ?? this.needsReauth,
      authNotice: clearAuthNotice ? null : (authNotice ?? this.authNotice),
    );
  }
}

/// Returns true when [error] looks like an expired/invalid Google OAuth session.
bool isGoogleAuthFailure(Object error) {
  final s = error.toString().toLowerCase();
  return s.contains('http 401') ||
      s.contains('(401)') ||
      (s.contains('401') && s.contains('permission denied')) ||
      s.contains('sign out and sign in') ||
      s.contains('sign in again') ||
      s.contains('could not authenticate') ||
      s.contains('please sign in with google');
}

/// Provider for [GoogleSheetsService].
final googleSheetsServiceProvider = Provider<GoogleSheetsService>((ref) {
  return GoogleSheetsService();
});

/// Notifier managing Google Sheets sign-in and export sync.
class SyncNotifier extends StateNotifier<SyncState> {
  final GoogleSheetsService _sheetsService;
  final Ref _ref;

  SyncNotifier(this._sheetsService, this._ref) : super(const SyncState()) {
    // Fire-and-forget cold-start restore (GIS silent + cached token).
    restoreSession();
  }

  void setClientId(String clientId) {
    _sheetsService.configureClientId(clientId);
    state = state.copyWith(clientId: clientId, clearError: true);
  }

  Future<void> setAutoBackupEnabled(bool enabled) async {
    await _sheetsService.sessionStore.saveAutoBackupEnabled(enabled);
    state = state.copyWith(autoBackupEnabled: enabled);
    if (enabled) {
      await maybeRunAutoBackup();
    }
  }

  /// Runs Sheets export when auto-backup is on, Google auth is confirmed valid,
  /// and the last successful export is at least [kAutoBackupInterval] old.
  ///
  /// Skips quietly when signed out, disabled, already fresh, busy, or auth is
  /// not ready. On stale auth, sets [SyncState.needsReauth] with a calm notice
  /// — never surfaces a red Drive 401 export banner from this silent path.
  /// Intended for app start / resume (PWA); Settings must not be the trigger.
  Future<void> maybeRunAutoBackup({DateTime? now}) async {
    if (!state.autoBackupEnabled) return;
    if (!state.isSignedIn) return;
    if (state.isSyncing || state.isImporting || state.isRestoring) return;

    final clock = now ?? DateTime.now();
    final last = state.lastSyncedAt;
    if (last != null && clock.difference(last) < kAutoBackupInterval) {
      return;
    }

    final ready = await _ensureAuthReady();
    if (!ready) {
      _markNeedsReauth(
        notice:
            'Sign in again to keep backups running. Your Google session expired.',
      );
      return;
    }

    await sync(fromAutoBackup: true);
  }

  /// Validates / silently refreshes Google credentials before any Drive call.
  /// Returns false when the session is stale so callers can prompt re-auth
  /// without opening a popup from this method.
  Future<bool> _ensureAuthReady() async {
    try {
      final ok = await _sheetsService.ensureUsableCredential();
      if (ok) {
        // Live account may have been refreshed silently.
        final user = _sheetsService.currentUser;
        if (user != null) {
          state = state.copyWith(
            account: user,
            restoredEmail: user.email,
            restoredDisplayName: user.displayName,
            needsReauth: false,
            clearAuthNotice: true,
            clearError: true,
          );
        } else {
          state = state.copyWith(
            needsReauth: false,
            clearAuthNotice: true,
          );
        }
        return true;
      }
    } catch (_) {
      // Treat as not ready.
    }
    return false;
  }

  void _markNeedsReauth({required String notice}) {
    state = state.copyWith(
      needsReauth: true,
      authNotice: notice,
      isSyncing: false,
      clearError: true,
      clearAccount: state.account != null,
    );
  }

  Future<void> restoreSession() async {
    state = state.copyWith(isRestoring: true, clearError: true);
    try {
      final autoBackup =
          await _sheetsService.sessionStore.loadAutoBackupEnabled();
      final persisted = await _sheetsService.sessionStore.load();
      if (persisted != null) {
        state = state.copyWith(
          restoredEmail: persisted.email,
          restoredDisplayName: persisted.displayName,
          spreadsheetId: persisted.spreadsheetId,
          lastSyncedAt: persisted.lastSyncedAt,
          lastImportedAt: persisted.lastImportedAt,
          autoBackupEnabled: autoBackup,
        );
      } else {
        state = state.copyWith(autoBackupEnabled: autoBackup);
      }

      final account = await _sheetsService.signInSilently();
      if (account != null) {
        state = state.copyWith(
          account: account,
          restoredEmail: account.email,
          restoredDisplayName: account.displayName,
          isRestoring: false,
          clearError: true,
        );
      } else {
        state = state.copyWith(isRestoring: false);
      }

      // Cold-start auto-backup check (web PWA has no reliable OS job).
      await maybeRunAutoBackup();
    } catch (e) {
      state = state.copyWith(
        isRestoring: false,
        error: 'Session restore failed: $e',
      );
    }
  }

  Future<void> signIn() async {
    try {
      final account = await _sheetsService.signIn();
      state = state.copyWith(
        account: account,
        restoredEmail: account?.email,
        restoredDisplayName: account?.displayName,
        needsReauth: false,
        clearError: true,
        clearAuthNotice: true,
      );
      await maybeRunAutoBackup();
    } catch (e) {
      state = state.copyWith(
        error:
            'Google Sign-In failed: $e\n\nTip: On Web, Google Sign-In requires an OAuth Client ID from Google Cloud Console with your site origin authorized.',
      );
    }
  }

  void signInDemo() {
    state = state.copyWith(
      account: DemoGoogleSignInAccount(),
      restoredEmail: 'demo.reseller@gmail.com',
      restoredDisplayName: 'Demo Reseller',
      clearError: true,
    );
  }

  Future<void> signOut() async {
    try {
      await _sheetsService.signOut();
      final autoBackup = state.autoBackupEnabled;
      state = SyncState(autoBackupEnabled: autoBackup);
    } catch (e) {
      state = state.copyWith(error: 'Sign out failed: $e');
    }
  }

  Future<void> export() async {
    await sync(fromAutoBackup: false);
  }

  Future<void> sync({bool fromAutoBackup = false}) async {
    if (state.isSyncing || state.isImporting) return;
    if (!state.isSignedIn) {
      if (fromAutoBackup) {
        return;
      }
      state = state.copyWith(error: 'Please sign in with Google first.');
      return;
    }

    final ready = await _ensureAuthReady();
    if (!ready) {
      if (fromAutoBackup) {
        _markNeedsReauth(
          notice:
              'Sign in again to keep backups running. Your Google session expired.',
        );
      } else {
        state = state.copyWith(
          needsReauth: true,
          authNotice:
              'Sign in again to export. Your Google session expired.',
          clearError: true,
          clearAccount: state.account != null,
        );
      }
      return;
    }

    state = state.copyWith(isSyncing: true, clearError: true, clearAuthNotice: true);
    try {
      final db = _ref.read(databaseProvider);
      final items = await db.inventoryItemsDao.getAllForExport();
      final expenses = await db.expensesDao.getAllForExport();

      final sheetId = await _sheetsService.syncToSheets(
        items,
        expenses,
        existingSpreadsheetId: state.spreadsheetId,
      );

      final now = DateTime.now();
      await _sheetsService.sessionStore.saveLastSyncedAt(now);
      if (sheetId != null) {
        await _sheetsService.sessionStore.saveSpreadsheetId(sheetId);
      }

      state = state.copyWith(
        isSyncing: false,
        lastSyncedAt: now,
        spreadsheetId: sheetId,
        needsReauth: false,
        clearError: true,
        clearAuthNotice: true,
      );
    } catch (e) {
      if (fromAutoBackup) {
        // Silent auto path: never show the red "Export failed" banner.
        if (isGoogleAuthFailure(e)) {
          await _sheetsService.invalidateStaleCredential();
          _markNeedsReauth(
            notice:
                'Sign in again to keep backups running. Your Google session expired.',
          );
        } else {
          state = state.copyWith(isSyncing: false, clearError: true);
        }
        return;
      }

      if (isGoogleAuthFailure(e)) {
        await _sheetsService.invalidateStaleCredential();
        state = state.copyWith(
          isSyncing: false,
          needsReauth: true,
          authNotice:
              'Sign in again to export. Your Google session expired.',
          clearError: true,
          clearAccount: true,
        );
        return;
      }

      state = state.copyWith(
        isSyncing: false,
        error: 'Export failed: $e',
      );
    }
  }

  Future<({int itemsCount, int expensesCount})?> import() async {
    if (state.isSyncing || state.isImporting) return null;
    if (!state.isSignedIn) {
      state = state.copyWith(error: 'Please sign in with Google first.');
      return null;
    }

    final ready = await _ensureAuthReady();
    if (!ready) {
      state = state.copyWith(
        needsReauth: true,
        authNotice:
            'Sign in again to import. Your Google session expired.',
        clearError: true,
        clearAccount: state.account != null,
      );
      return null;
    }

    state = state.copyWith(isImporting: true, clearError: true, clearAuthNotice: true);
    try {
      final importData = await _sheetsService.importFromSheets(
        existingSpreadsheetId: state.spreadsheetId,
      );

      final db = _ref.read(databaseProvider);
      await db.inventoryItemsDao.replaceAll(importData.items);
      await db.expensesDao.replaceAll(importData.expenses);

      _ref.invalidate(inventoryListProvider);
      _ref.invalidate(expenseListProvider);

      final now = DateTime.now();
      await _sheetsService.sessionStore.saveLastImportedAt(now);
      if (importData.spreadsheetId != null) {
        await _sheetsService.sessionStore.saveSpreadsheetId(
          importData.spreadsheetId,
        );
      }

      state = state.copyWith(
        isImporting: false,
        lastImportedAt: now,
        spreadsheetId: importData.spreadsheetId ?? state.spreadsheetId,
        clearError: true,
      );

      return (
        itemsCount: importData.items.length,
        expensesCount: importData.expenses.length,
      );
    } catch (e) {
      if (isGoogleAuthFailure(e)) {
        await _sheetsService.invalidateStaleCredential();
        state = state.copyWith(
          isImporting: false,
          needsReauth: true,
          authNotice:
              'Sign in again to import. Your Google session expired.',
          clearError: true,
          clearAccount: true,
        );
        return null;
      }
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
