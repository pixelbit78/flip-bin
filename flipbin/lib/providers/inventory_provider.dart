import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/drilldown_query.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/providers/database_provider.dart';

/// Filter parameters for the inventory list provider.
class InventoryFilter {
  final ItemStatus? statusFilter;
  final String? searchQuery;

  /// Inclusive age band (days since dateAdded). Matching [AgingBuckets].
  final int? ageMinDays;
  final int? ageMaxDays;

  /// Keep items whose `dateSold` is on/after now − this many days.
  final int? soldWithinDays;

  /// Keep items whose `dateAdded` is on/after now − this many days.
  final int? addedWithinDays;

  /// Calendar month for `dateSold` (day ignored).
  final DateTime? soldMonth;

  /// Calendar month for `dateAdded` (day ignored).
  final DateTime? addedMonth;

  const InventoryFilter({
    this.statusFilter,
    this.searchQuery,
    this.ageMinDays,
    this.ageMaxDays,
    this.soldWithinDays,
    this.addedWithinDays,
    this.soldMonth,
    this.addedMonth,
  });

  factory InventoryFilter.fromDrillDown(DrillDownQuery q) {
    return InventoryFilter(
      statusFilter: q.status,
      ageMinDays: q.ageMinDays,
      ageMaxDays: q.ageMaxDays,
      soldWithinDays: q.soldWithinDays,
      addedWithinDays: q.addedWithinDays,
      soldMonth: q.soldMonth,
      addedMonth: q.addedMonth,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryFilter &&
          runtimeType == other.runtimeType &&
          statusFilter == other.statusFilter &&
          searchQuery == other.searchQuery &&
          ageMinDays == other.ageMinDays &&
          ageMaxDays == other.ageMaxDays &&
          soldWithinDays == other.soldWithinDays &&
          addedWithinDays == other.addedWithinDays &&
          soldMonth == other.soldMonth &&
          addedMonth == other.addedMonth;

  @override
  int get hashCode => Object.hash(
        statusFilter,
        searchQuery,
        ageMinDays,
        ageMaxDays,
        soldWithinDays,
        addedWithinDays,
        soldMonth,
        addedMonth,
      );
}

/// Reactive list of inventory items filtered by status and search query.
final inventoryListProvider =
    StreamProvider.family<List<InventoryItem>, InventoryFilter>((ref, filter) {
  final db = ref.watch(databaseProvider);
  return db.inventoryItemsDao.watchAll(
    statusFilter: filter.statusFilter,
    searchQuery: filter.searchQuery,
    ageMinDays: filter.ageMinDays,
    ageMaxDays: filter.ageMaxDays,
    soldWithinDays: filter.soldWithinDays,
    addedWithinDays: filter.addedWithinDays,
    soldMonth: filter.soldMonth,
    addedMonth: filter.addedMonth,
  );
});

/// Live count of inventory items by status (Drift stream).
final inventoryCountProvider =
    StreamProvider.family<int, ItemStatus>((ref, status) {
  final db = ref.watch(databaseProvider);
  return db.inventoryItemsDao.watchCountByStatus(status);
});

/// Live total cost of inventory items by status (Drift stream).
final inventoryTotalCostProvider =
    StreamProvider.family<double, ItemStatus>((ref, status) {
  final db = ref.watch(databaseProvider);
  return db.inventoryItemsDao.watchTotalCostByStatus(status);
});

/// Live active/personal inventory rows matching a scanned/manual UPC.
final inventoryMatchesByBarcodeProvider =
    StreamProvider.family<List<InventoryItem>, String>((ref, barcode) {
  final db = ref.watch(databaseProvider);
  return db.inventoryItemsDao.watchByBarcodeActiveOrPersonal(barcode);
});

/// Single inventory item by ID.
final inventoryItemProvider =
    FutureProvider.family<InventoryItem, int>((ref, id) {
  final db = ref.watch(databaseProvider);
  return db.inventoryItemsDao.getById(id);
});

/// Controller for inventory CRUD operations.
class InventoryController {
  final Ref _ref;
  final FlipBinDatabase _db;

  InventoryController(this._ref, this._db);

  Future<int> saveInventoryItem(InventoryItemsCompanion item) async {
    final id = await _db.inventoryItemsDao.insertItem(item);
    _invalidateAll();
    return id;
  }

  Future<void> updateInventoryItem(InventoryItem item) async {
    var updated = item;
    // Auto-fill dateSold when status changes to sold and dateSold is not set
    if (item.status == ItemStatus.sold && item.dateSold == null) {
      updated = item.copyWith(dateSold: Value(DateTime.now()));
    }
    await _db.inventoryItemsDao.updateItem(updated);
    _invalidateAll();
  }

  Future<void> deleteInventoryItem(int id) async {
    await _db.inventoryItemsDao.deleteItem(id);
    _invalidateAll();
  }

  void _invalidateAll() {
    // Streams already live-update from Drift; keep invalidation as a thin
    // backup for any remaining FutureProviders / family caches.
    for (final status in ItemStatus.values) {
      _ref.invalidate(inventoryCountProvider(status));
      _ref.invalidate(inventoryTotalCostProvider(status));
    }
  }
}

/// Provider for inventory CRUD controller.
final inventoryControllerProvider = Provider<InventoryController>((ref) {
  final db = ref.watch(databaseProvider);
  return InventoryController(ref, db);
});
