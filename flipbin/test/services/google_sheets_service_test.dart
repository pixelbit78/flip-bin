import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/services/google_sheets_service.dart';

class MockSheetsClient extends Mock implements SheetsClient {}

void main() {
  late MockSheetsClient mockClient;
  late GoogleSheetsService service;

  setUpAll(() {
    registerFallbackValue(<sheets.ValueRange>[]);
  });

  setUp(() {
    mockClient = MockSheetsClient();
    service = GoogleSheetsService(sheetsClient: mockClient);
  });

  test('inventory export columns match spec layout', () {
    expect(
      GoogleSheetsService.inventoryHeaders,
      equals([
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
      ]),
    );
  });

  test('expense export columns match spec layout', () {
    expect(
      GoogleSheetsService.expenseHeaders,
      equals([
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
      ]),
    );
  });

  test('syncToSheets creates spreadsheet on first sync', () async {
    when(() => mockClient.findSpreadsheetId('FlipBin Export'))
        .thenAnswer((_) async => null);
    when(() => mockClient.createSpreadsheet('FlipBin Export', any()))
        .thenAnswer((_) async => 'new-sheet-id-123');
    when(() => mockClient.clearSheet(any(), any()))
        .thenAnswer((_) async {});
    when(() => mockClient.batchUpdateValues(any(), any()))
        .thenAnswer((_) async {});

    final items = [
      InventoryItem(
        id: 1,
        dateAdded: DateTime(2026, 1, 15),
        itemDescription: 'Zelda Breath of the Wild',
        type: ItemType.game,
        cost: 35.0,
        quantity: 1,
        status: ItemStatus.active,
      ),
    ];
    final expenses = <Expense>[];

    await service.syncToSheets(items, expenses);

    verify(() => mockClient.createSpreadsheet('FlipBin Export', ['Inventory', 'Expenses'])).called(1);
    verify(() => mockClient.batchUpdateValues('new-sheet-id-123', any())).called(1);
  });

  test('syncToSheets clears and writes data on subsequent sync', () async {
    const existingId = 'existing-sheet-456';
    when(() => mockClient.findSpreadsheetId('FlipBin Export'))
        .thenAnswer((_) async => existingId);
    when(() => mockClient.clearSheet(any(), any()))
        .thenAnswer((_) async {});
    when(() => mockClient.batchUpdateValues(any(), any()))
        .thenAnswer((_) async {});

    final items = [
      InventoryItem(
        id: 1,
        dateAdded: DateTime(2026, 1, 15),
        itemDescription: 'Zelda',
        type: ItemType.game,
        cost: 35.0,
        quantity: 1,
        status: ItemStatus.sold,
        dateSold: DateTime(2026, 2, 1),
      ),
    ];
    final expenses = [
      Expense(
        id: 1,
        date: DateTime(2026, 1, 20),
        merchant: 'USPS',
        itemDescription: 'Box',
        quantity: 1,
        unitPrice: 5.0,
        expenseType: ExpenseType.shipping,
      ),
    ];

    await service.syncToSheets(items, expenses);

    verifyNever(() => mockClient.createSpreadsheet(any(), any()));
    verify(() => mockClient.clearSheet(existingId, 'Inventory!A:L')).called(1);
    verify(() => mockClient.clearSheet(existingId, 'Expenses!A:J')).called(1);
    verify(() => mockClient.batchUpdateValues(existingId, any())).called(1);
  });

  test('sync handles network failure gracefully', () async {
    when(() => mockClient.findSpreadsheetId('FlipBin Export'))
        .thenThrow(Exception('Network connection failed'));

    expect(
      () => service.syncToSheets([], []),
      throwsA(isA<Exception>()),
    );
    verifyNever(() => mockClient.batchUpdateValues(any(), any()));
  });
}
