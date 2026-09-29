import 'package:drift/drift.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/enums.dart';

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

  @override
  Future<String?> findSpreadsheetId(String title) async {
    try {
      final list = await _driveApi.files.list(
        q: "name = '$title' and mimeType = 'application/vnd.google-apps.spreadsheet' and trashed = false",
        $fields: 'files(id, name)',
        spaces: 'drive',
      );
      final files = list.files;
      if (files != null && files.isNotEmpty) {
        return files.first.id;
      }
    } catch (_) {
      // In case Drive search encounters permission or scope restriction, fallback
    }
    return null;
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

  GoogleSheetsService({
    GoogleSignIn? googleSignIn,
    SheetsClient? sheetsClient,
    String? clientId,
  })  : _googleSignIn = googleSignIn ??
            GoogleSignIn(
              clientId: (clientId != null && clientId.trim().isNotEmpty)
                  ? clientId.trim()
                  : defaultClientId,
              scopes: [
                'https://www.googleapis.com/auth/spreadsheets',
                'https://www.googleapis.com/auth/drive.file',
              ],
            ),
        _sheetsClient = sheetsClient;

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  void configureClientId(String? clientId) {
    _googleSignIn = GoogleSignIn(
      clientId: (clientId != null && clientId.trim().isNotEmpty) ? clientId.trim() : null,
      scopes: [
        'https://www.googleapis.com/auth/spreadsheets',
        'https://www.googleapis.com/auth/drive.file',
      ],
    );
  }

  Future<GoogleSignInAccount?> signIn() async {
    return _googleSignIn.signIn();
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  /// Synchronizes full inventory and expenses data to "FlipBin Export" spreadsheet.
  /// Returns the spreadsheet ID on success.
  Future<String?> syncToSheets(
    List<InventoryItem> items,
    List<Expense> expenses, {
    String? existingSpreadsheetId,
  }) async {
    SheetsClient client;
    if (_sheetsClient != null) {
      client = _sheetsClient!;
    } else {
      final user = currentUser;
      if (user == null) {
        throw Exception('Please sign in with Google first.');
      }
      if (user is DemoGoogleSignInAccount) {
        return 'demo-spreadsheet-id';
      }

      http.Client? httpClient;
      try {
        final headers = await user.authHeaders;
        if (headers.isNotEmpty) {
          httpClient = AuthHeadersClient(headers);
        }
      } catch (_) {}

      httpClient ??= await _googleSignIn.authenticatedClient();
      if (httpClient == null) {
        throw Exception(
          'Could not authenticate with Google API client. Please sign out and sign in again.',
        );
      }
      client = RealSheetsClient(httpClient);
    }

    const title = 'FlipBin Export';
    var spreadsheetId = existingSpreadsheetId ?? await client.findSpreadsheetId(title);

    if (spreadsheetId == null) {
      spreadsheetId = await client.createSpreadsheet(title, ['Inventory', 'Expenses']);
    } else {
      await client.clearSheet(spreadsheetId, 'Inventory!A:M');
      await client.clearSheet(spreadsheetId, 'Expenses!A:J');
    }

    final dateFormat = DateFormat('MM/dd/yyyy');

    // Build Inventory rows
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
          item.status == ItemStatus.personal ? dateFormat.format(item.dateSold ?? item.dateAdded) : '',
          days != null ? '$days' : '',
          item.comments ?? '',
          item.saleNumber ?? '',
          item.imageUrl ?? '',
        ];
      }),
    ];

    // Build Expense rows
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

    await client.batchUpdateValues(spreadsheetId, batchData);
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
      final status = ItemStatus.fromLabel(_parseString(getCell(statusCol)));
      DateTime? dateSold = _parseDate(getCell(dateSoldCol));
      if (dateSold == null && status == ItemStatus.personal) {
        dateSold = _parseDate(getCell(personalDateCol));
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
  Future<SheetsImportData> importFromSheets({String? existingSpreadsheetId}) async {
    SheetsClient client;
    if (_sheetsClient != null) {
      client = _sheetsClient!;
    } else {
      final user = currentUser;
      if (user == null) {
        throw Exception('Please sign in with Google first.');
      }
      if (user is DemoGoogleSignInAccount) {
        return const SheetsImportData(items: [], expenses: []);
      }

      http.Client? httpClient;
      try {
        final headers = await user.authHeaders;
        if (headers.isNotEmpty) {
          httpClient = AuthHeadersClient(headers);
        }
      } catch (_) {}

      httpClient ??= await _googleSignIn.authenticatedClient();
      if (httpClient == null) {
        throw Exception(
          'Could not authenticate with Google API client. Please sign out and sign in again.',
        );
      }
      client = RealSheetsClient(httpClient);
    }

    const title = 'FlipBin Export';
    final spreadsheetId =
        existingSpreadsheetId ?? await client.findSpreadsheetId(title);
    if (spreadsheetId == null) {
      throw Exception('Spreadsheet "$title" was not found in your Google Drive.');
    }

    final inventoryRows =
        await client.getValues(spreadsheetId, 'Inventory!A1:M') ?? [];
    final expenseRows =
        await client.getValues(spreadsheetId, 'Expenses!A1:J') ?? [];

    final items = parseInventoryRows(inventoryRows);
    final expenses = parseExpenseRows(expenseRows);

    return SheetsImportData(items: items, expenses: expenses);
  }
}

/// Data imported from Google Sheets.
class SheetsImportData {
  final List<InventoryItemsCompanion> items;
  final List<ExpensesCompanion> expenses;

  const SheetsImportData({
    required this.items,
    required this.expenses,
  });
}
