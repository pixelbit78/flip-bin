import 'package:drift/drift.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/services/google_session_store.dart';

/// Abstract client interface for Google Sheets API operations.
abstract class SheetsClient {
  Future<String?> findSpreadsheetId(String title);
  Future<String> createSpreadsheet(String title, List<String> sheetTitles);
  Future<void> clearSheet(String spreadsheetId, String range);
  Future<void> batchUpdateValues(
      String spreadsheetId, List<sheets.ValueRange> data);
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
  Future<String> createSpreadsheet(
      String title, List<String> sheetTitles) async {
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
  Future<List<List<Object?>>?> getValues(
      String spreadsheetId, String range) async {
    final response =
        await _sheetsApi.spreadsheets.values.get(spreadsheetId, range);
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

  static const inventoryHeaders = [
    'Date Added',
    'Barcode UPC',
    'Item Description',
    'Type',
    'Cost',
    'Platform',
    'Status',
    'Date Sold',
    'Personal Use Date',
    'DaysToSell',
    'Comments',
    'Sale Nbr',
    'Image URL',
  ];

  static const expenseHeaders = [
    'Date',
    'Merchant',
    'Receipt Image',
    'UPC',
    'Item Desc',
    'Qty',
    'Price',
    'Total',
    'Type',
    'With Tax',
  ];

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
  })  : _googleSignIn = googleSignIn ??
            GoogleSignIn(
              clientId: (clientId != null && clientId.trim().isNotEmpty)
                  ? clientId.trim()
                  : defaultClientId,
              scopes: oauthScopes,
            ),
        _sheetsClient = sheetsClient,
        _sessionStore = sessionStore ?? GoogleSessionStore();

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  GoogleSessionStore get sessionStore => _sessionStore;

  void configureClientId(String? clientId) {
    _googleSignIn = GoogleSignIn(
      clientId: (clientId != null && clientId.trim().isNotEmpty)
          ? clientId.trim()
          : null,
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
      if (authHeader != null &&
          authHeader.toLowerCase().startsWith('bearer ')) {
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
        await client.clearSheet(spreadsheetId, 'Inventory!A:M');
        await client.clearSheet(spreadsheetId, 'Expenses!A:J');
      } catch (_) {
        // Prior file may have been deleted between resolve and clear — recover.
        final recovered = await resolveExportSpreadsheet(
          client,
          existingId: null,
          createIfMissing: true,
        );
        spreadsheetId = recovered.id;
        if (!recovered.created) {
          await client.clearSheet(spreadsheetId, 'Inventory!A:M');
          await client.clearSheet(spreadsheetId, 'Expenses!A:J');
        }
      }
    }

    final dateFormat = DateFormat('MM/dd/yyyy');

    final inventoryValues = <List<Object>>[
      inventoryHeaders,
      ...items.map((item) {
        final days = item.daysToSell;
        return [
          dateFormat.format(item.dateAdded),
          item.barcode ?? '',
          item.itemDescription,
          item.type.label,
          item.cost.toStringAsFixed(2),
          item.platform ?? '',
          item.status.label,
          item.dateSold != null ? dateFormat.format(item.dateSold!) : '',
          item.status == ItemStatus.personal
              ? dateFormat.format(item.dateSold ?? item.dateAdded)
              : '',
          days != null ? '$days' : '',
          item.comments ?? '',
          item.saleNumber ?? '',
          item.imageUrl ?? '',
        ];
      }),
    ];

    final expenseValues = <List<Object>>[
      expenseHeaders,
      ...expenses.map((exp) {
        return [
          dateFormat.format(exp.date),
          exp.merchant,
          exp.receiptImagePath ?? '',
          exp.upc ?? '',
          exp.itemDescription,
          exp.quantity,
          exp.unitPrice.toStringAsFixed(2),
          exp.total.toStringAsFixed(2),
          exp.expenseType.label,
          exp.taxAmount != null ? exp.taxAmount!.toStringAsFixed(2) : '',
        ];
      }),
    ];

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

  static DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    final s = val.toString().trim();
    if (s.isEmpty) return null;
    try {
      return DateFormat('MM/dd/yyyy').parse(s);
    } catch (_) {
      return DateTime.tryParse(s);
    }
  }

  static double _parseDouble(dynamic val, [double defaultVal = 0.0]) {
    if (val == null) return defaultVal;
    final s = val.toString().replaceAll('\$', '').replaceAll(',', '').trim();
    return double.tryParse(s) ?? defaultVal;
  }

  static int _parseInt(dynamic val, [int defaultVal = 1]) {
    if (val == null) return defaultVal;
    final s = val.toString().trim();
    return int.tryParse(s) ?? defaultVal;
  }

  static String? _parseString(dynamic val) {
    if (val == null) return null;
    final s = val.toString().trim();
    return s.isEmpty ? null : s;
  }

  List<InventoryItemsCompanion> parseInventoryRows(List<List<Object?>> rows) {
    if (rows.length <= 1) return [];
    final items = <InventoryItemsCompanion>[];

    final headerRow =
        rows[0].map((e) => e?.toString().trim().toLowerCase() ?? '').toList();
    int col(String name, int fallback) {
      final idx = headerRow.indexOf(name.toLowerCase());
      return idx >= 0 ? idx : fallback;
    }

    final dateAddedCol = col('Date Added', 0);
    final barcodeCol = col('Barcode UPC', 1);
    final descCol = col('Item Description', 2);
    final typeCol = col('Type', 3);
    final costCol = col('Cost', 4);
    final platformCol = col('Platform', 5);
    final statusCol = col('Status', 6);
    final dateSoldCol = col('Date Sold', 7);
    final personalDateCol = col('Personal Use Date', 8);
    final commentsCol = col('Comments', 10);
    final saleNbrCol = col('Sale Nbr', 11);
    final imageUrlCol = col('Image URL', 12);

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      dynamic getCell(int idx) => idx < row.length ? row[idx] : null;

      final desc = _parseString(getCell(descCol));
      if (desc == null) continue;

      final dateAdded = _parseDate(getCell(dateAddedCol)) ?? DateTime.now();
      final barcode = _parseString(getCell(barcodeCol));
      final type = ItemType.fromLabel(_parseString(getCell(typeCol)));
      final cost = _parseDouble(getCell(costCol));
      final platform = _parseString(getCell(platformCol));
      final statusRaw = _parseString(getCell(statusCol));
      var status = ItemStatus.fromLabel(statusRaw);
      DateTime? dateSold = _parseDate(getCell(dateSoldCol));
      final personalDate = _parseDate(getCell(personalDateCol));
      // Spreadsheet convention: a filled Personal Use Date (with no Date Sold)
      // means personal inventory — even when Status was left Active/blank or used
      // legacy wording. Never reclassify an explicit Sold row from personal date.
      if (status != ItemStatus.sold &&
          dateSold == null &&
          personalDate != null) {
        status = ItemStatus.personal;
      }
      if (dateSold == null && status == ItemStatus.personal) {
        dateSold = personalDate;
      }
      final comments = _parseString(getCell(commentsCol));
      final saleNbr = _parseString(getCell(saleNbrCol));
      final imageUrl = _parseString(getCell(imageUrlCol));

      items.add(
        InventoryItemsCompanion.insert(
          dateAdded: dateAdded,
          barcode: Value(barcode),
          itemDescription: desc,
          type: type,
          cost: cost,
          quantity: const Value(1),
          platform: Value(platform),
          status: status,
          dateSold: Value(dateSold),
          saleNumber: Value(saleNbr),
          comments: Value(comments),
          imageUrl: Value(imageUrl),
        ),
      );
    }
    return items;
  }

  List<ExpensesCompanion> parseExpenseRows(List<List<Object?>> rows) {
    if (rows.length <= 1) return [];
    final expenses = <ExpensesCompanion>[];

    final headerRow =
        rows[0].map((e) => e?.toString().trim().toLowerCase() ?? '').toList();
    int col(String name, int fallback) {
      final idx = headerRow.indexOf(name.toLowerCase());
      return idx >= 0 ? idx : fallback;
    }

    final dateCol = col('Date', 0);
    final merchantCol = col('Merchant', 1);
    final receiptCol = col('Receipt Image', 2);
    final upcCol = col('UPC', 3);
    final descCol = col('Item Desc', 4);
    final qtyCol = col('Qty', 5);
    final priceCol = col('Price', 6);
    final typeCol = col('Type', 8);
    final taxCol = col('With Tax', 9);

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      dynamic getCell(int idx) => idx < row.length ? row[idx] : null;

      final desc = _parseString(getCell(descCol));
      final merchant = _parseString(getCell(merchantCol));
      if (desc == null && merchant == null) continue;

      final date = _parseDate(getCell(dateCol)) ?? DateTime.now();
      final receipt = _parseString(getCell(receiptCol));
      final upc = _parseString(getCell(upcCol));
      final qty = _parseInt(getCell(qtyCol), 1);
      final price = _parseDouble(getCell(priceCol));
      final type = ExpenseType.fromLabel(_parseString(getCell(typeCol)));
      final taxRaw = getCell(taxCol);
      final tax = taxRaw != null && taxRaw.toString().trim().isNotEmpty
          ? _parseDouble(taxRaw)
          : null;

      expenses.add(
        ExpensesCompanion.insert(
          date: date,
          merchant: merchant ?? 'Unknown',
          receiptImagePath: Value(receipt),
          upc: Value(upc),
          itemDescription: desc ?? merchant ?? 'Expense',
          quantity: Value(qty),
          unitPrice: price,
          expenseType: type,
          taxAmount: Value(tax),
        ),
      );
    }
    return expenses;
  }

  /// Imports inventory and expenses from "FlipBin Export" spreadsheet.
  Future<SheetsImportData> importFromSheets(
      {String? existingSpreadsheetId}) async {
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
        await client.getValues(spreadsheetId, 'Inventory!A1:M') ?? [];
    final expenseRows =
        await client.getValues(spreadsheetId, 'Expenses!A1:J') ?? [];

    final items = parseInventoryRows(inventoryRows);
    final expenses = parseExpenseRows(expenseRows);

    try {
      await _sessionStore.saveSpreadsheetId(spreadsheetId);
    } catch (_) {}

    return SheetsImportData(
      items: items,
      expenses: expenses,
      spreadsheetId: spreadsheetId,
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

  const SheetsImportData({
    required this.items,
    required this.expenses,
    this.spreadsheetId,
  });
}
