import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import 'package:flipbin/database/database.dart';
import 'package:flipbin/config/env.dart';
import 'package:flipbin/services/sheet_mapping.dart' as mapping;
import 'package:flipbin/services/google_session_store.dart';

/// Abstract client interface for Google Sheets API operations.
abstract class SheetsClient {
  Future<String?> findSpreadsheetId(String title);
  Future<String> createSpreadsheet(String title, List<String> sheetTitles);
  Future<void> clearSheet(String spreadsheetId, String range);
  Future<void> batchUpdateValues(String spreadsheetId, List<sheets.ValueRange> data);
  Future<List<List<Object?>>?> getValues(String spreadsheetId, String range);
}

/// An HTTP client that attaches authentication headers (OAuth Bearer token).
class AuthHeadersClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  AuthHeadersClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

/// Concrete implementation of [SheetsClient] utilizing real Google Sheets and Drive APIs.
class RealSheetsClient implements SheetsClient {
  final sheets.SheetsApi _sheetsApi;
  final drive.DriveApi _driveApi;

  RealSheetsClient(http.Client client)
      : _sheetsApi = sheets.SheetsApi(client),
        _driveApi = drive.DriveApi(client);

  static const _sheetMime = 'application/vnd.google-apps.spreadsheet';

  @override
  Future<String?> findSpreadsheetId(String title) async {
    // Escape single quotes / backslashes per Drive query syntax.
    final escaped = title.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
    final target = title.trim().toLowerCase();

    Future<drive.FileList> query(String q, {String corpora = 'user'}) {
      return _driveApi.files.list(
        q: q,
        $fields: 'files(id, name, mimeType, modifiedTime)',
        spaces: 'drive',
        corpora: corpora,
        includeItemsFromAllDrives: true,
        supportsAllDrives: true,
        pageSize: 25,
        orderBy: 'modifiedTime desc',
      );
    }

    String? pick(List<drive.File>? files, {bool exactOnly = false}) {
      if (files == null || files.isEmpty) return null;
      for (final f in files) {
        final name = (f.name ?? '').trim().toLowerCase();
        final id = f.id;
        if (id == null || id.isEmpty) continue;
        if (exactOnly) {
          if (name == target) return id;
        } else if (name == target || name.contains(target)) {
          return id;
        }
      }
      // Query already constrained — take newest match.
      return files.first.id;
    }

    Future<String?> tryQuery(
      String q, {
      String corpora = 'user',
      bool exactOnly = false,
    }) async {
      try {
        final list = await query(q, corpora: corpora);
        return pick(list.files, exactOnly: exactOnly);
      } on drive.DetailedApiRequestError catch (e) {
        if (e.status == 401 || e.status == 403) {
          throw Exception(
            'Google Drive permission denied while searching for "$title" '
            '(HTTP ${e.status}). Sign out and sign in again, then approve '
            'Drive access when prompted so FlipBin can find your spreadsheet.',
          );
        }
        // Non-auth failures (e.g. corpora unsupported) — try next strategy.
        return null;
      }
    }

    // 1) Exact name + Sheets mime in My Drive.
    var id = await tryQuery(
      "name = '$escaped' and mimeType = '$_sheetMime' and trashed = false",
      exactOnly: true,
    );
    if (id != null) return id;

    // 2) Same exact query across all drives (shared drives / shared-with-me).
    id = await tryQuery(
      "name = '$escaped' and mimeType = '$_sheetMime' and trashed = false",
      corpora: 'allDrives',
      exactOnly: true,
    );
    if (id != null) return id;

    // 3) contains — catches trailing spaces / slight title drift.
    id = await tryQuery(
      "name contains '$escaped' and mimeType = '$_sheetMime' and trashed = false",
      corpora: 'allDrives',
    );
    if (id != null) return id;

    // 4) Name only (no mime filter) — e.g. uploaded .xlsx converted later.
    id = await tryQuery(
      "name = '$escaped' and trashed = false",
      corpora: 'allDrives',
      exactOnly: true,
    );
    return id;
  }

  @override
  Future<String> createSpreadsheet(String title, List<String> sheetTitles) async {
    final spreadsheet = sheets.Spreadsheet(
      properties: sheets.SpreadsheetProperties(title: title),
      sheets: sheetTitles
          .map((name) => sheets.Sheet(
                properties: sheets.SheetProperties(title: name),
              ))
          .toList(),
    );
    final result = await _sheetsApi.spreadsheets.create(spreadsheet);
    return result.spreadsheetId!;
  }

  @override
  Future<void> clearSheet(String spreadsheetId, String range) async {
    await _sheetsApi.spreadsheets.values.clear(
      sheets.ClearValuesRequest(),
      spreadsheetId,
      range,
    );
  }

  @override
  Future<void> batchUpdateValues(
    String spreadsheetId,
    List<sheets.ValueRange> data,
  ) async {
    final request = sheets.BatchUpdateValuesRequest(
      data: data,
      valueInputOption: 'USER_ENTERED',
    );
    await _sheetsApi.spreadsheets.values.batchUpdate(request, spreadsheetId);
  }

  @override
  Future<List<List<Object?>>?> getValues(String spreadsheetId, String range) async {
    final response = await _sheetsApi.spreadsheets.values.get(spreadsheetId, range);
    return response.values;
  }
}

/// Simulated demo account for local testing.
class DemoGoogleSignInAccount implements GoogleSignInAccount {
  @override
  final String displayName = 'Demo Reseller';
  @override
  final String email = 'demo.reseller@gmail.com';
  @override
  final String id = 'demo-12345';
  @override
  final String? photoUrl = null;
  @override
  final String? serverAuthCode = null;

  @override
  Future<GoogleSignInAuthentication> get authentication =>
      Future.value(DemoGoogleSignInAuthentication());

  @override
  Future<Map<String, String>> get authHeaders => Future.value({});

  @override
  Future<void> clearAuthCache() async {}
}

class DemoGoogleSignInAuthentication implements GoogleSignInAuthentication {
  @override
  final String? accessToken = 'demo-access-token';
  @override
  final String? idToken = 'demo-id-token';
  @override
  final String? serverAuthCode = null;
}

/// Service handling Google authentication and synchronization to Google Sheets.
class GoogleSheetsService {
  GoogleSignIn _googleSignIn;
  final SheetsClient? _sheetsClient;
  final GoogleSessionStore _sessionStore;
  String? _restoredAccessToken;

  static const exportTitle = 'FlipBin Export';

  static const inventoryHeaders = mapping.inventoryHeaders;

  static const expenseHeaders = mapping.expenseHeaders;

  static const defaultClientId =
      '300135141102-ijqefa0enb2pm08i5kkgdnfbmpgp46tb.apps.googleusercontent.com';

  /// Sheets read/write + app-created Drive files + metadata search so renamed
  /// spreadsheets (not necessarily created by FlipBin) can be found by title.
  static const List<String> oauthScopes = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive.file',
    'https://www.googleapis.com/auth/drive.metadata.readonly',
  ];

  GoogleSheetsService({
    GoogleSignIn? googleSignIn,
    SheetsClient? sheetsClient,
    String? clientId,
    GoogleSessionStore? sessionStore,
  })  : assert(kIsProd, 'Google disabled in $kFlipBinEnv build'),
        _googleSignIn = _guardProd() ?? googleSignIn ??
            GoogleSignIn(
              clientId: (clientId != null && clientId.trim().isNotEmpty)
                  ? clientId.trim()
                  : defaultClientId,
              scopes: oauthScopes,
            ),
        _sheetsClient = sheetsClient,
        _sessionStore = sessionStore ?? GoogleSessionStore();

  /// SPEC §12.2 layer 2: fail closed outside prod. Returns null in prod.
  static GoogleSignIn? _guardProd() {
    if (!kIsProd) {
      throw StateError('Google disabled in $kFlipBinEnv build');
    }
    return null;
  }

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  GoogleSessionStore get sessionStore => _sessionStore;

  void configureClientId(String? clientId) {
    _googleSignIn = GoogleSignIn(
      clientId: (clientId != null && clientId.trim().isNotEmpty) ? clientId.trim() : null,
      scopes: oauthScopes,
    );
  }

  static const driveMetadataReadonlyScope =
      'https://www.googleapis.com/auth/drive.metadata.readonly';

  Future<GoogleSignInAccount?> signIn() async {
    final account = await _googleSignIn.signIn();
    if (account != null) {
      await _persistAccount(account);
      // Incremental consent for Drive metadata (needed to find sheets by name
      // that FlipBin did not create). Must run after the account is current.
      await _ensureDriveMetadataScope(forceRequest: true);
      await _persistLiveAccessToken(account);
    }
    return account;
  }

  /// Restores GIS identity via One Tap / auto-select when possible, and reapplies
  /// a still-valid cached access token so Sheets calls work after a cold start.
  Future<GoogleSignInAccount?> signInSilently() async {
    final account = await _googleSignIn.signInSilently();
    final persisted = await _sessionStore.load();

    if (account != null) {
      await _persistAccount(account);
      // Prefer a live token; fall back to cached token from prior session.
      final live = await _tryReadLiveAccessToken(account);
      if (live != null) {
        _restoredAccessToken = live;
        await _sessionStore.saveAccessToken(live);
      } else if (persisted?.accessToken != null) {
        _restoredAccessToken = persisted!.accessToken;
      }
      // Best-effort: pick up drive.metadata.readonly if the prior token lacks it.
      await _ensureDriveMetadataScope(forceRequest: false);
      return account;
    }

    // Identity silent-restore failed, but we may still have a cached token + email
    // from this browser. Keep restored token for API use; UI uses persisted email.
    if (persisted?.accessToken != null) {
      _restoredAccessToken = persisted!.accessToken;
    }
    return null;
  }

  /// Returns true when a live or still-valid cached access token is available
  /// for Sheets/Drive calls. Attempts silent GIS refresh first.
  ///
  /// Does not open an interactive sign-in popup — callers prompt via [signIn].
  Future<bool> ensureUsableCredential() async {
    // Demo short-circuit.
    if (currentUser is DemoGoogleSignInAccount) {
      return true;
    }

    // Prefer a live account + fresh access token.
    GoogleSignInAccount? user = currentUser;
    if (user == null) {
      try {
        user = await _googleSignIn.signInSilently();
      } catch (_) {
        user = null;
      }
    }

    if (user != null) {
      await _persistAccount(user);
      final live = await _tryReadLiveAccessToken(user);
      if (live != null) {
        _restoredAccessToken = live;
        await _sessionStore.saveAccessToken(live);
        return true;
      }
      // Account present but no token — try clearing auth cache then re-read.
      try {
        await user.clearAuthCache();
        final retry = await _tryReadLiveAccessToken(user);
        if (retry != null) {
          _restoredAccessToken = retry;
          await _sessionStore.saveAccessToken(retry);
          return true;
        }
      } catch (_) {}
    }

    // Non-expired cached bearer from a prior session (within ~55 min).
    final persisted = await _sessionStore.load();
    if (persisted?.accessToken != null &&
        persisted!.accessToken!.isNotEmpty) {
      _restoredAccessToken = persisted.accessToken;
      return true;
    }

    _restoredAccessToken = null;
    return false;
  }

  /// Drops in-memory and persisted access tokens after a 401/auth failure so
  /// the next export waits for a fresh sign-in instead of retrying a dead bearer.
  Future<void> invalidateStaleCredential() async {
    _restoredAccessToken = null;
    try {
      await _sessionStore.clearAccessTokenOnly();
    } catch (_) {}
    final user = currentUser;
    if (user != null) {
      try {
        await user.clearAuthCache();
      } catch (_) {}
    }
  }

  Future<void> signOut() async {
    _restoredAccessToken = null;
    await _sessionStore.clearAll();
    await _googleSignIn.signOut();
  }

  Future<void> _persistAccount(GoogleSignInAccount account) async {
    await _sessionStore.saveSignedInUser(
      email: account.email,
      displayName: account.displayName,
    );
  }

  Future<String?> _tryReadLiveAccessToken(GoogleSignInAccount account) async {
    try {
      final auth = await account.authentication;
      final token = auth.accessToken;
      if (token != null && token.isNotEmpty) return token;
    } catch (_) {}
    try {
      final headers = await account.authHeaders;
      final authHeader = headers['Authorization'] ?? headers['authorization'];
      if (authHeader != null && authHeader.toLowerCase().startsWith('bearer ')) {
        return authHeader.substring(7).trim();
      }
    } catch (_) {}
    return null;
  }

  Future<void> _persistLiveAccessToken(GoogleSignInAccount account) async {
    final token = await _tryReadLiveAccessToken(account);
    if (token != null) {
      _restoredAccessToken = token;
      await _sessionStore.saveAccessToken(token);
    }
  }

  /// Ensures [driveMetadataReadonlyScope] is on the live token.
  ///
  /// Tokens minted before this scope was added only have drive.file, so
  /// `files.list` by name returns empty for sheets FlipBin did not create —
  /// which surfaces as "FlipBin Export was not found".
  Future<bool> _ensureDriveMetadataScope({required bool forceRequest}) async {
    final user = currentUser;
    final token = _restoredAccessToken ??
        (user != null ? await _tryReadLiveAccessToken(user) : null);

    var hasMeta = false;
    try {
      hasMeta = await _googleSignIn.canAccessScopes(
        const [driveMetadataReadonlyScope],
        accessToken: token,
      );
    } catch (_) {
      hasMeta = false;
    }

    if (hasMeta && !forceRequest) {
      // Still refresh the token so we are not stuck on a stale cached bearer.
      if (user != null) {
        await _persistLiveAccessToken(user);
      }
      return true;
    }

    try {
      final granted = await _googleSignIn.requestScopes(oauthScopes);
      if (granted) {
        final u = currentUser;
        if (u != null) {
          await _persistLiveAccessToken(u);
        }
        return true;
      }
    } catch (_) {
      // Popup blocked / consent deferred.
    }
    return hasMeta;
  }

  Future<SheetsClient> _buildClient() async {
    if (_sheetsClient != null) return _sheetsClient!;

    final user = currentUser;
    if (user == null && _restoredAccessToken == null) {
      throw Exception('Please sign in with Google first.');
    }
    if (user is DemoGoogleSignInAccount) {
      throw _DemoClientSentinel();
    }

    // Always try to attach drive.metadata.readonly before Drive name search.
    // Prefer the freshly minted token over any pre-scope-change cached bearer.
    final scopesOk = await _ensureDriveMetadataScope(forceRequest: true);
    if (!scopesOk && user != null) {
      // One more live-header attempt; import may still work via stored ID.
      try {
        await _persistLiveAccessToken(user);
      } catch (_) {}
    }

    http.Client? httpClient;

    // Prefer live auth headers (reflects latest scopes) over a possibly stale
    // SharedPreferences bearer minted before drive.metadata.readonly existed.
    if (user != null) {
      try {
        final headers = await user.authHeaders;
        if (headers.isNotEmpty) {
          httpClient = AuthHeadersClient(headers);
          await _persistLiveAccessToken(user);
        }
      } catch (_) {}
    }

    if (httpClient == null &&
        _restoredAccessToken != null &&
        _restoredAccessToken!.isNotEmpty) {
      httpClient = AuthHeadersClient({
        'Authorization': 'Bearer $_restoredAccessToken',
      });
    }

    httpClient ??= await _googleSignIn.authenticatedClient();
    if (httpClient == null) {
      await _ensureDriveMetadataScope(forceRequest: true);
      if (_restoredAccessToken != null) {
        httpClient = AuthHeadersClient({
          'Authorization': 'Bearer $_restoredAccessToken',
        });
      }
      httpClient ??= await _googleSignIn.authenticatedClient();
    }

    if (httpClient == null) {
      throw Exception(
        'Could not authenticate with Google API client. Please sign out and sign in again.',
      );
    }
    return RealSheetsClient(httpClient);
  }

  /// Resolves the FlipBin Export spreadsheet.
  ///
  /// Always prefers a live Drive **name** lookup so a deleted prior file ID or a
  /// sheet renamed to [exportTitle] is picked up. Falls back to [existingId]
  /// only when name search finds nothing but the ID still responds. Creates a
  /// new spreadsheet when [createIfMissing] is true.
  Future<({String id, bool created})> resolveExportSpreadsheet(
    SheetsClient client, {
    String? existingId,
    bool createIfMissing = false,
  }) async {
    final byName = await client.findSpreadsheetId(exportTitle);
    if (byName != null) {
      return (id: byName, created: false);
    }

    if (existingId != null && existingId.isNotEmpty) {
      try {
        await client.getValues(existingId, 'Inventory!A1');
        return (id: existingId, created: false);
      } catch (_) {
        // Stale / deleted ID — continue.
      }
    }

    if (createIfMissing) {
      final id = await client.createSpreadsheet(
        exportTitle,
        ['Inventory', 'Expenses'],
      );
      return (id: id, created: true);
    }

    throw Exception(
      'Spreadsheet "$exportTitle" was not found in your Google Drive. '
      'Confirm the file exists (exact name), then sign out and sign in again '
      'so FlipBin can request Drive search permission '
      '(drive.metadata.readonly) and locate it by name.',
    );
  }

  /// Synchronizes full inventory and expenses data to "FlipBin Export" spreadsheet.
  /// Returns the spreadsheet ID on success.
  Future<String?> syncToSheets(
    List<InventoryItem> items,
    List<Expense> expenses, {
    String? existingSpreadsheetId,
  }) async {
    SheetsClient client;
    try {
      client = await _buildClient();
    } on _DemoClientSentinel {
      return 'demo-spreadsheet-id';
    }

    var resolved = await resolveExportSpreadsheet(
      client,
      existingId: existingSpreadsheetId,
      createIfMissing: true,
    );
    var spreadsheetId = resolved.id;

    if (!resolved.created) {
      try {
        await client.clearSheet(spreadsheetId, 'Inventory!${mapping.inventoryRange}');
        await client.clearSheet(spreadsheetId, 'Expenses!${mapping.expensesRange}');
      } catch (_) {
        // Prior file may have been deleted between resolve and clear — recover.
        final recovered = await resolveExportSpreadsheet(
          client,
          existingId: null,
          createIfMissing: true,
        );
        spreadsheetId = recovered.id;
        if (!recovered.created) {
          await client.clearSheet(spreadsheetId, 'Inventory!${mapping.inventoryRange}');
          await client.clearSheet(spreadsheetId, 'Expenses!${mapping.expensesRange}');
        }
      }
    }

    final inventoryValues = mapping.inventoryToRows(items);
    final expenseValues = mapping.expensesToRows(expenses);

    final batchData = [
      sheets.ValueRange(range: 'Inventory!A1', values: inventoryValues),
      sheets.ValueRange(range: 'Expenses!A1', values: expenseValues),
    ];

    try {
      await client.batchUpdateValues(spreadsheetId, batchData);
    } catch (_) {
      // Recover if the file vanished after clear.
      final recovered = await resolveExportSpreadsheet(
        client,
        existingId: null,
        createIfMissing: true,
      );
      spreadsheetId = recovered.id;
      await client.batchUpdateValues(spreadsheetId, batchData);
    }

    try {
      await _sessionStore.saveSpreadsheetId(spreadsheetId);
    } catch (_) {}
    return spreadsheetId;
  }

  /// Parsed inventory rows (SPEC §7 rules via the shared mapping).
  List<InventoryItemsCompanion> parseInventoryRows(List<List<Object?>> rows) =>
      mapping.rowsToInventory(rows).items;

  List<ExpensesCompanion> parseExpenseRows(List<List<Object?>> rows) =>
      mapping.rowsToExpenses(rows);

  /// Imports inventory and expenses from "FlipBin Export" spreadsheet.
  Future<SheetsImportData> importFromSheets({String? existingSpreadsheetId}) async {
    SheetsClient client;
    try {
      client = await _buildClient();
    } on _DemoClientSentinel {
      return const SheetsImportData(items: [], expenses: []);
    }

    final resolved = await resolveExportSpreadsheet(
      client,
      existingId: existingSpreadsheetId,
      createIfMissing: false,
    );
    final spreadsheetId = resolved.id;

    final inventoryRows =
        await client.getValues(spreadsheetId, 'Inventory!A1:P') ?? [];
    final expenseRows =
        await client.getValues(spreadsheetId, 'Expenses!A1:J') ?? [];

    final inv = mapping.rowsToInventory(inventoryRows);
    final items = inv.items;
    final expenses = parseExpenseRows(expenseRows);

    try {
      await _sessionStore.saveSpreadsheetId(spreadsheetId);
    } catch (_) {}

    return SheetsImportData(
      items: items,
      expenses: expenses,
      spreadsheetId: spreadsheetId,
      report: inv.report,
    );
  }
}

/// Internal sentinel so demo accounts short-circuit without a real Sheets client.
class _DemoClientSentinel implements Exception {}

/// Data imported from Google Sheets.
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
