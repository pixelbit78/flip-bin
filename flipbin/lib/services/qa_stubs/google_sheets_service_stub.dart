// QA-build replacement for lib/services/google_sheets_service.dart.
//
// scripts/vercel-build-qa.sh copies this file over google_sheets_service.dart
// and removes google_sign_in / googleapis / extension_google_sign_in_as_googleapis_auth
// from pubspec.yaml, so the QA web build contains NO Google plugin (the
// google_sign_in_web plugin otherwise injects accounts.google.com/gsi/client
// at startup during plugin registration). SPEC §12.2.
//
// Same public API surface as the prod file; every Google entry point throws.
// ignore_for_file: avoid_unused_constructor_parameters
import 'package:flipbin/config/env.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/services/google_session_store.dart';
import 'package:flipbin/services/sheet_mapping.dart' as mapping;

Never _disabled() =>
    throw StateError('Google disabled in $kFlipBinEnv build');

/// Minimal stand-in for google_sign_in's account type.
abstract class GoogleSignInAccount {
  String get email;
  String? get displayName;
}

/// Stand-in for googleapis' sheets ValueRange.
class ValueRange {
  final String? range;
  final List<List<Object?>>? values;
  ValueRange({this.range, this.values});
}

abstract class SheetsClient {
  Future<String?> findSpreadsheetId(String title);
  Future<String> createSpreadsheet(String title, List<String> sheetTitles);
  Future<void> clearSheet(String spreadsheetId, String range);
  Future<void> batchUpdateValues(String spreadsheetId, List<ValueRange> data);
  Future<List<List<Object?>>?> getValues(String spreadsheetId, String range);
}

class DemoGoogleSignInAccount implements GoogleSignInAccount {
  @override
  String get email => 'demo.reseller@gmail.com';
  @override
  String? get displayName => 'Demo Reseller';
}

class GoogleSheetsService {
  static const exportTitle = 'FlipBin Export';
  static const inventoryHeaders = mapping.inventoryHeaders;
  static const expenseHeaders = mapping.expenseHeaders;
  static const defaultClientId = '';
  static const List<String> oauthScopes = [];

  GoogleSheetsService({
    Object? googleSignIn,
    SheetsClient? sheetsClient,
    String? clientId,
    GoogleSessionStore? sessionStore,
  }) {
    _disabled();
  }

  GoogleSignInAccount? get currentUser => _disabled();
  GoogleSessionStore get sessionStore => _disabled();
  void configureClientId(String? clientId) => _disabled();
  Future<GoogleSignInAccount?> signIn() => _disabled();
  Future<GoogleSignInAccount?> signInSilently() => _disabled();
  Future<bool> ensureUsableCredential() => _disabled();
  Future<void> invalidateStaleCredential() => _disabled();
  Future<void> signOut() => _disabled();
  Future<String?> syncToSheets(List<InventoryItem> items, List<Expense> expenses,
          {String? existingSpreadsheetId}) =>
      _disabled();
  Future<SheetsImportData> importFromSheets({String? existingSpreadsheetId}) =>
      _disabled();
}

class SheetsImportData {
  final List<InventoryItemsCompanion> items;
  final List<ExpensesCompanion> expenses;
  final String? spreadsheetId;
  final List<String> report;

  const SheetsImportData({
    required this.items,
    required this.expenses,
    this.spreadsheetId,
    this.report = const [],
  });
}
