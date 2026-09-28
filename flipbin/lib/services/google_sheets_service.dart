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

/// Service handling Google authentication and synchronization to Google Sheets.
class GoogleSheetsService {
  final GoogleSignIn _googleSignIn;
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

  GoogleSheetsService({
    GoogleSignIn? googleSignIn,
    SheetsClient? sheetsClient,
  })  : _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: [
                'https://www.googleapis.com/auth/spreadsheets',
                'https://www.googleapis.com/auth/drive.file',
              ],
            ),
        _sheetsClient = sheetsClient;

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

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
      throw StateError('Sheets client not configured for active session');
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
