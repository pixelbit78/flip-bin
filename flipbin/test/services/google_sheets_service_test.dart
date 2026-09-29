import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    registerFallbackValue(<sheets.ValueRange>[]);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
        'Image URL',
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
    verify(() => mockClient.clearSheet(existingId, 'Inventory!A:M')).called(1);
    verify(() => mockClient.clearSheet(existingId, 'Expenses!A:J')).called(1);
    verify(() => mockClient.batchUpdateValues(existingId, any())).called(1);
  });

  test('sync prefers renamed sheet by name over stale stored ID', () async {
    const staleId = 'deleted-old-id';
    const renamedId = 'renamed-sheet-id';
    when(() => mockClient.findSpreadsheetId('FlipBin Export'))
        .thenAnswer((_) async => renamedId);
    when(() => mockClient.clearSheet(any(), any())).thenAnswer((_) async {});
    when(() => mockClient.batchUpdateValues(any(), any()))
        .thenAnswer((_) async {});

    final id = await service.syncToSheets(
      [],
      [],
      existingSpreadsheetId: staleId,
    );

    expect(id, equals(renamedId));
    verify(() => mockClient.findSpreadsheetId('FlipBin Export')).called(1);
    verifyNever(() => mockClient.getValues(staleId, any()));
    verify(() => mockClient.batchUpdateValues(renamedId, any())).called(1);
  });

  test('export recovers when prior file ID is deleted and name missing', () async {
    const staleId = 'gone-id';
    when(() => mockClient.findSpreadsheetId('FlipBin Export'))
        .thenAnswer((_) async => null);
    when(() => mockClient.getValues(staleId, 'Inventory!A1'))
        .thenThrow(Exception('404 File not found'));
    when(() => mockClient.createSpreadsheet('FlipBin Export', any()))
        .thenAnswer((_) async => 'fresh-id');
    when(() => mockClient.batchUpdateValues(any(), any()))
        .thenAnswer((_) async {});

    final id = await service.syncToSheets(
      [],
      [],
      existingSpreadsheetId: staleId,
    );

    expect(id, equals('fresh-id'));
    verify(() => mockClient.createSpreadsheet('FlipBin Export', ['Inventory', 'Expenses']))
        .called(1);
    verify(() => mockClient.batchUpdateValues('fresh-id', any())).called(1);
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

  test('importFromSheets parses inventory and expense rows accurately', () async {
    const sheetId = 'test-sheet-789';
    when(() => mockClient.findSpreadsheetId('FlipBin Export'))
        .thenAnswer((_) async => sheetId);
    when(() => mockClient.getValues(sheetId, 'Inventory!A1:M')).thenAnswer(
      (_) async => [
        GoogleSheetsService.inventoryHeaders,
        [
          '01/15/2026',
          '012345678905',
          'Super Mario Odyssey',
          'Game',
          '29.99',
          'eBay',
          'Sold',
          '02/01/2026',
          '',
          '17',
          'Great condition',
          'SALE-101',
          'https://example.com/mario.jpg',
        ],
        [
          '02/10/2026',
          '',
          'The Matrix Blu-ray',
          'Blu-ray',
          '5.00',
          'Mercari',
          'Active',
          '',
          '',
          '',
          '',
          '',
        ],
      ],
    );
    when(() => mockClient.getValues(sheetId, 'Expenses!A1:J')).thenAnswer(
      (_) async => [
        GoogleSheetsService.expenseHeaders,
        [
          '01/20/2026',
          'USPS',
          '/images/receipt1.png',
          '999888777666',
          'Shipping Boxes',
          '5',
          '2.50',
          '12.50',
          'Shipping',
          '0.85',
        ],
      ],
    );

    final data = await service.importFromSheets();

    expect(data.items.length, equals(2));
    expect(data.spreadsheetId, equals(sheetId));
    final item1 = data.items[0];
    expect(item1.itemDescription.value, equals('Super Mario Odyssey'));
    expect(item1.barcode.value, equals('012345678905'));
    expect(item1.type.value, equals(ItemType.game));
    expect(item1.cost.value, equals(29.99));
    expect(item1.platform.value, equals('eBay'));
    expect(item1.status.value, equals(ItemStatus.sold));
    expect(item1.dateSold.value, equals(DateTime(2026, 2, 1)));
    expect(item1.comments.value, equals('Great condition'));
    expect(item1.saleNumber.value, equals('SALE-101'));
    expect(item1.imageUrl.value, equals('https://example.com/mario.jpg'));

    final item2 = data.items[1];
    expect(item2.itemDescription.value, equals('The Matrix Blu-ray'));
    expect(item2.type.value, equals(ItemType.bluray));
    expect(item2.status.value, equals(ItemStatus.active));

    expect(data.expenses.length, equals(1));
    final exp1 = data.expenses[0];
    expect(exp1.merchant.value, equals('USPS'));
    expect(exp1.itemDescription.value, equals('Shipping Boxes'));
    expect(exp1.quantity.value, equals(5));
    expect(exp1.unitPrice.value, equals(2.50));
    expect(exp1.expenseType.value, equals(ExpenseType.shipping));
    expect(exp1.taxAmount.value, equals(0.85));
  });

  test('import finds renamed sheet by name ignoring stale stored ID', () async {
    const staleId = 'old-deleted-id';
    const renamedId = 'new-renamed-id';
    when(() => mockClient.findSpreadsheetId('FlipBin Export'))
        .thenAnswer((_) async => renamedId);
    when(() => mockClient.getValues(renamedId, 'Inventory!A1:M'))
        .thenAnswer((_) async => [GoogleSheetsService.inventoryHeaders]);
    when(() => mockClient.getValues(renamedId, 'Expenses!A1:J'))
        .thenAnswer((_) async => [GoogleSheetsService.expenseHeaders]);

    final data = await service.importFromSheets(existingSpreadsheetId: staleId);

    expect(data.spreadsheetId, equals(renamedId));
    verify(() => mockClient.findSpreadsheetId('FlipBin Export')).called(1);
    verifyNever(() => mockClient.getValues(staleId, any()));
    verify(() => mockClient.getValues(renamedId, 'Inventory!A1:M')).called(1);
  });

  test('import throws when spreadsheet missing by name and stored ID', () async {
    when(() => mockClient.findSpreadsheetId('FlipBin Export'))
        .thenAnswer((_) async => null);
    when(() => mockClient.getValues('stale', 'Inventory!A1'))
        .thenThrow(Exception('404'));

    expect(
      () => service.importFromSheets(existingSpreadsheetId: 'stale'),
      throwsA(
        predicate(
          (e) =>
              e is Exception &&
              e.toString().contains('FlipBin Export') &&
              e.toString().contains('was not found'),
        ),
      ),
    );
  });

  test('syncToSheets exports Image URL column', () async {
    when(() => mockClient.findSpreadsheetId('FlipBin Export'))
        .thenAnswer((_) async => 'sheet-img');
    when(() => mockClient.clearSheet(any(), any())).thenAnswer((_) async {});
    when(() => mockClient.batchUpdateValues(any(), any()))
        .thenAnswer((_) async {});

    final items = [
      InventoryItem(
        id: 1,
        dateAdded: DateTime(2026, 3, 1),
        itemDescription: 'Covered Game',
        type: ItemType.game,
        cost: 10.0,
        quantity: 1,
        status: ItemStatus.active,
        imageUrl: 'https://cdn.example.com/cover.jpg',
      ),
    ];

    await service.syncToSheets(items, []);

    final captured = verify(
      () => mockClient.batchUpdateValues('sheet-img', captureAny()),
    ).captured.single as List<sheets.ValueRange>;
    final inventory = captured.first.values!;
    expect(inventory.first, equals(GoogleSheetsService.inventoryHeaders));
    expect(inventory[1].last, equals('https://cdn.example.com/cover.jpg'));
  });

  test('importFromSheets skips rows with empty descriptions', () async {
    const sheetId = 'test-sheet-789';
    when(() => mockClient.findSpreadsheetId('FlipBin Export'))
        .thenAnswer((_) async => sheetId);
    when(() => mockClient.getValues(sheetId, 'Inventory!A1:M')).thenAnswer(
      (_) async => [
        GoogleSheetsService.inventoryHeaders,
        ['01/15/2026', '', '', '', '', '', '', '', '', '', '', '', ''],
      ],
    );
    when(() => mockClient.getValues(sheetId, 'Expenses!A1:J')).thenAnswer(
      (_) async => [
        GoogleSheetsService.expenseHeaders,
        ['', '', '', '', '', '', '', '', '', ''],
      ],
    );

    final data = await service.importFromSheets();
    expect(data.items, isEmpty);
    expect(data.expenses, isEmpty);
  });

  test('resolveExportSpreadsheet prefers name then creates when missing', () async {
    when(() => mockClient.findSpreadsheetId('FlipBin Export'))
        .thenAnswer((_) async => null);
    when(() => mockClient.getValues('stale', 'Inventory!A1'))
        .thenThrow(Exception('gone'));
    when(() => mockClient.createSpreadsheet('FlipBin Export', any()))
        .thenAnswer((_) async => 'created');

    final resolved = await service.resolveExportSpreadsheet(
      mockClient,
      existingId: 'stale',
      createIfMissing: true,
    );
    expect(resolved.id, 'created');
    expect(resolved.created, isTrue);
  });
}
