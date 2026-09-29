import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/providers/database_provider.dart';
import 'package:flipbin/providers/inventory_provider.dart';
import 'package:flipbin/providers/scanner_provider.dart';
import 'package:flipbin/services/barcode_lookup_service.dart';

class FakeBarcodeLookupService implements BarcodeLookupService {
  final Map<String, Completer<BarcodeResult?>> pendingLookups = {};

  @override
  bool get useSameOriginProxy => false;

  @override
  String? get proxyOrigin => null;

  @override
  Future<BarcodeResult?> lookup(String barcode) {
    final completer = Completer<BarcodeResult?>();
    pendingLookups[barcode] = completer;
    return completer.future;
  }
}

void main() {
  late FlipBinDatabase db;
  late ProviderContainer container;
  late FakeBarcodeLookupService fakeLookupService;

  setUp(() {
    db = FlipBinDatabase(NativeDatabase.memory());
    fakeLookupService = FakeBarcodeLookupService();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        barcodeLookupServiceProvider.overrideWithValue(fakeLookupService),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('inventoryListProvider emits items filtered by status', () async {
    final now = DateTime.now();

    await db.inventoryItemsDao.insertItem(
      InventoryItemsCompanion.insert(
        dateAdded: now,
        itemDescription: 'Active Item 1',
        type: ItemType.game,
        cost: 10.0,
        status: ItemStatus.active,
      ),
    );
    await db.inventoryItemsDao.insertItem(
      InventoryItemsCompanion.insert(
        dateAdded: now,
        itemDescription: 'Active Item 2',
        type: ItemType.dvd,
        cost: 5.0,
        status: ItemStatus.active,
      ),
    );
    await db.inventoryItemsDao.insertItem(
      InventoryItemsCompanion.insert(
        dateAdded: now,
        itemDescription: 'Sold Item',
        type: ItemType.bluray,
        cost: 15.0,
        status: ItemStatus.sold,
      ),
    );

    // StreamProvider watches the DB stream directly
    final activeItems = await container.read(
      inventoryListProvider(
              const InventoryFilter(statusFilter: ItemStatus.active))
          .future,
    );
    expect(activeItems.length, equals(2));

    final soldItems = await container.read(
      inventoryListProvider(
              const InventoryFilter(statusFilter: ItemStatus.sold))
          .future,
    );
    expect(soldItems.length, equals(1));
    expect(soldItems.first.itemDescription, equals('Sold Item'));
  });

  test('inventoryListProvider personal filter lists personal and excludes sold',
      () async {
    final now = DateTime.now();

    await db.inventoryItemsDao.insertItem(
      InventoryItemsCompanion.insert(
        dateAdded: now,
        itemDescription: 'Active Keep',
        type: ItemType.game,
        cost: 10.0,
        status: ItemStatus.active,
      ),
    );
    await db.inventoryItemsDao.insertItem(
      InventoryItemsCompanion.insert(
        dateAdded: now,
        itemDescription: 'Personal Keep',
        type: ItemType.dvd,
        cost: 0.0,
        status: ItemStatus.personal,
      ),
    );
    await db.inventoryItemsDao.insertItem(
      InventoryItemsCompanion.insert(
        dateAdded: now,
        itemDescription: 'Sold Skip',
        type: ItemType.bluray,
        cost: 15.0,
        status: ItemStatus.sold,
      ),
    );

    final personalItems = await container.read(
      inventoryListProvider(
        const InventoryFilter(statusFilter: ItemStatus.personal),
      ).future,
    );
    expect(personalItems.length, equals(1));
    expect(personalItems.first.itemDescription, equals('Personal Keep'));
    expect(personalItems.first.status, equals(ItemStatus.personal));

    final soldItems = await container.read(
      inventoryListProvider(
        const InventoryFilter(statusFilter: ItemStatus.sold),
      ).future,
    );
    expect(soldItems.map((e) => e.itemDescription).toList(),
        equals(['Sold Skip']));

    final allItems = await container.read(
      inventoryListProvider(const InventoryFilter()).future,
    );
    expect(allItems.length, equals(3));
  });

  test('saveInventoryItem inserts and invalidates list', () async {
    final controller = container.read(inventoryControllerProvider);
    const filter = InventoryFilter(statusFilter: ItemStatus.active);

    // Get initial stream emission
    final stream = container.read(inventoryListProvider(filter).future);
    final initialList = await stream;
    expect(initialList, isEmpty);

    // Insert item
    await controller.saveInventoryItem(
      InventoryItemsCompanion.insert(
        dateAdded: DateTime.now(),
        itemDescription: 'New Game',
        type: ItemType.game,
        cost: 20.0,
        status: ItemStatus.active,
      ),
    );

    // The stream auto-updates from the DB; wait for next emission
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final updatedList =
        await container.read(inventoryListProvider(filter).future);
    expect(updatedList.length, equals(1));
    expect(updatedList.first.itemDescription, equals('New Game'));
  });

  test('updateInventoryItem with status=sold auto-fills dateSold', () async {
    final controller = container.read(inventoryControllerProvider);
    final now = DateTime.now();

    final id = await controller.saveInventoryItem(
      InventoryItemsCompanion.insert(
        dateAdded: now,
        itemDescription: 'To Be Sold',
        type: ItemType.game,
        cost: 12.0,
        status: ItemStatus.active,
      ),
    );

    final item = await db.inventoryItemsDao.getById(id);
    expect(item.dateSold, isNull);

    // Update to sold without explicit dateSold
    final updatedItem = item.copyWith(status: ItemStatus.sold);
    await controller.updateInventoryItem(updatedItem);

    // Read directly from DB to verify
    final retrieved = await db.inventoryItemsDao.getById(id);
    expect(retrieved.status, equals(ItemStatus.sold));
    expect(retrieved.dateSold, isNotNull);
  });

  test('scannerProvider replaces result when new barcode scanned during lookup',
      () async {
    final notifier = container.read(scannerProvider.notifier);

    // Scan first barcode
    notifier.onBarcodeDetected('111111');
    expect(container.read(scannerProvider).isLookingUp, isTrue);
    expect(container.read(scannerProvider).rawBarcode, equals('111111'));

    // Scan second barcode while first lookup is in flight
    notifier.onBarcodeDetected('222222');
    expect(container.read(scannerProvider).rawBarcode, equals('222222'));

    // Complete the first lookup (it should be discarded)
    fakeLookupService.pendingLookups['111111']!.complete(
      const BarcodeResult(
          barcode: '111111', productName: 'First Item', source: 'UPC DB'),
    );
    await pumpEventQueue();

    // The first result should NOT overwrite state because a newer scan happened
    expect(container.read(scannerProvider).result, isNull);

    // Complete the second lookup
    fakeLookupService.pendingLookups['222222']!.complete(
      const BarcodeResult(
          barcode: '222222', productName: 'Second Item', source: 'UPC DB'),
    );
    await pumpEventQueue();

    final state = container.read(scannerProvider);
    expect(state.isLookingUp, isFalse);
    expect(state.result, isNotNull);
    expect(state.result!.barcode, equals('222222'));
    expect(state.result!.productName, equals('Second Item'));
  });
}
