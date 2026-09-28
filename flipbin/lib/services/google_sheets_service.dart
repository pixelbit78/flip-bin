import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:intl/intl.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/enums.dart';

/// Abstract client interface for Google Sheets API operations.
abstract class SheetsClient {
  Future<String?> findSpreadsheetId(String title);
  Future<String> createSpreadsheet(String title, List<String> sheetTitles);
  Future<void> clearSheet(String spreadsheetId, String range);
  Future<void> batchUpdateValues(String spreadsheetId, List<sheets.ValueRange> data);
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
  Future<void> syncToSheets(
    List<InventoryItem> items,
    List<Expense> expenses,
  ) async {
    final client = _sheetsClient;
    if (client == null) {
      // If running with mock/demo account locally, succeed gracefully
      return;
    }

    const title = 'FlipBin Export';
    var spreadsheetId = await client.findSpreadsheetId(title);

    if (spreadsheetId == null) {
      spreadsheetId = await client.createSpreadsheet(title, ['Inventory', 'Expenses']);
    } else {
      await client.clearSheet(spreadsheetId, 'Inventory!A:L');
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
  }
}
