// Pure row ↔ model mapping shared by the Google Sheets backend (prod) and the
// local XLSX backend (QA). No Google, Flutter UI or IO imports (SPEC §12.6).
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/utils/cost_field.dart';

const List<String> inventoryHeaders = [
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
  'Qty',
  'Cost Per Item',
  'Parent Row',
];

const List<String> expenseHeaders = [
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

const String inventoryTab = 'Inventory';
const String expensesTab = 'Expenses';

/// Fixed clear/read widths so the Google range and XLSX width can't diverge.
const String inventoryRange = 'A:P';
const String expensesRange = 'A:J';

final DateFormat _sheetDate = DateFormat('MM/dd/yyyy');

/// Thrown when a workbook / sheet is not a valid FlipBin export.
class SheetFormatException implements Exception {
  final String reason;
  SheetFormatException(this.reason);
  @override
  String toString() => 'Not a valid FlipBin export: $reason';
}

/// Import outcome with per-row report lines.
class InventoryImport {
  final List<InventoryItemsCompanion> items;
  final List<String> report;
  const InventoryImport(this.items, this.report);
}

String _cpiCell(double cpi) => formatCpiField(cpi);

/// Inventory rows (header first). Parents precede children; Parent Row is the
/// parent's 1-based sheet row.
List<List<Object>> inventoryToRows(List<InventoryItem> input) {
  final items = [...input]..sort((a, b) {
      final c = a.dateAdded.compareTo(b.dateAdded);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  // Ensure every parent precedes its children.
  final byId = {for (final i in items) i.id: i};
  final ordered = <InventoryItem>[];
  final placed = <int>{};
  void place(InventoryItem i) {
    if (placed.contains(i.id)) return;
    final p = i.parentId == null ? null : byId[i.parentId];
    if (p != null) place(p);
    placed.add(i.id);
    ordered.add(i);
  }

  items.forEach(place);
  final rowOf = <int, int>{};
  for (var k = 0; k < ordered.length; k++) {
    rowOf[ordered[k].id] = k + 2; // header is row 1
  }
  return [
    inventoryHeaders,
    for (final item in ordered)
      [
        _sheetDate.format(item.dateAdded),
        item.barcode ?? '',
        item.itemDescription,
        item.type.label,
        item.cost.toStringAsFixed(2),
        item.platform ?? '',
        item.status.label,
        item.dateSold != null ? _sheetDate.format(item.dateSold!) : '',
        item.status == ItemStatus.personal
            ? _sheetDate.format(item.dateSold ?? item.dateAdded)
            : '',
        item.daysToSell != null ? '${item.daysToSell}' : '',
        item.comments ?? '',
        item.saleNumber ?? '',
        item.imageUrl ?? '',
        '${item.quantity}',
        _cpiCell(item.cpi),
        item.parentId != null && rowOf[item.parentId] != null
            ? '${rowOf[item.parentId]}'
            : '',
      ],
  ];
}

List<List<Object>> expensesToRows(List<Expense> expenses) {
  return [
    expenseHeaders,
    for (final exp in expenses)
      [
        _sheetDate.format(exp.date),
        exp.merchant,
        exp.receiptImagePath ?? '',
        exp.upc ?? '',
        exp.itemDescription,
        exp.quantity,
        exp.unitPrice.toStringAsFixed(2),
        exp.total.toStringAsFixed(2),
        exp.expenseType.label,
        exp.taxAmount != null ? exp.taxAmount!.toStringAsFixed(2) : '',
      ],
  ];
}

DateTime? parseSheetDate(Object? val) {
  if (val == null) return null;
  final s = val.toString().trim();
  if (s.isEmpty) return null;
  try {
    return _sheetDate.parse(s);
  } catch (_) {
    return DateTime.tryParse(s);
  }
}

double? parseSheetDouble(Object? val) {
  if (val == null) return null;
  final s = val.toString().replaceAll('\$', '').replaceAll(',', '').trim();
  if (s.isEmpty) return null;
  return double.tryParse(s);
}

String? parseSheetString(Object? val) {
  if (val == null) return null;
  final s = val.toString().trim();
  return s.isEmpty ? null : s;
}

/// Sheet rows → inventory companions per SPEC §7. Companions carry explicit
/// ids (1-based import order) so Parent Row can resolve to `parentId`.
///
/// [strict]: reject a header row lacking `Item Description` (XLSX import,
/// §12.6). Google import keeps the legacy index fallback.
InventoryImport rowsToInventory(List<List<Object?>> rows, {bool strict = false}) {
  final report = <String>[];
  if (rows.isEmpty) {
    if (strict) throw SheetFormatException('Inventory tab is empty');
    return InventoryImport(const [], report);
  }
  final header =
      rows[0].map((e) => e?.toString().trim().toLowerCase() ?? '').toList();
  if (strict && !header.contains('item description')) {
    throw SheetFormatException('Inventory header row has no "Item Description"');
  }
  int col(String name, int fallback) {
    final idx = header.indexOf(name.toLowerCase());
    return idx >= 0 ? idx : fallback;
  }

  int? optCol(String name) {
    final idx = header.indexOf(name.toLowerCase());
    return idx >= 0 ? idx : null;
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
  final qtyCol = optCol('Qty');
  final cpiCol = optCol('Cost Per Item');
  final parentCol = optCol('Parent Row');

  final items = <InventoryItemsCompanion>[];
  final sheetRowToId = <int, int>{};
  final pendingParent = <int, int>{}; // item index → sheet row

  for (var i = 1; i < rows.length; i++) {
    final row = rows[i];
    final sheetRow = i + 1;
    Object? cell(int? idx) => idx != null && idx < row.length ? row[idx] : null;

    final desc = parseSheetString(cell(descCol));
    if (desc == null) continue;

    // 1. Qty
    var qty = 1;
    final qtyRaw = parseSheetString(cell(qtyCol));
    if (qtyRaw != null) {
      final q = int.tryParse(qtyRaw);
      if (q == null || q < 1 || q > kMaxQty) {
        report.add('Row $sheetRow: Qty "$qtyRaw" invalid — used 1');
      } else {
        qty = q;
      }
    }

    // 2/3. Cost vs Cost Per Item
    final costVal = parseSheetDouble(cell(costCol));
    final cpiVal = parseSheetDouble(cell(cpiCol));
    double cost;
    double cpi;
    if (cpiVal != null) {
      cpi = round4(cpiVal < 0 ? 0 : cpiVal);
      final expected = lineTotal(qty, cpi);
      if (costVal == null) {
        cost = expected;
      } else {
        // Compare in ten-thousandths against the unrounded product.
        // T = $0.01 + qty × $0.00005, compared in half-bp units (exact ints).
        final diffBp = (toBp(costVal) - qty * toBp(cpi)).abs();
        if (2 * diffBp <= 200 + qty) {
          cost = round2(costVal);
        } else {
          cost = expected;
          report.add('Row $sheetRow: Cost \$${costVal.toStringAsFixed(2)} ≠ '
              'Qty × Cost Per Item \$${expected.toStringAsFixed(2)} — used '
              '\$${expected.toStringAsFixed(2)}');
        }
      }
    } else {
      cost = round2(costVal ?? 0);
      cpi = cpiFromTotal(cost, qty);
    }
    if (cost < 0) cost = 0;

    final status = ItemStatus.fromLabel(parseSheetString(cell(statusCol)));
    var dateSold = parseSheetDate(cell(dateSoldCol));
    if (dateSold == null && status == ItemStatus.personal) {
      dateSold = parseSheetDate(cell(personalDateCol));
    }
    final id = items.length + 1;
    sheetRowToId[sheetRow] = id;
    final parentRaw = parseSheetString(cell(parentCol));
    if (parentRaw != null) {
      final pr = int.tryParse(parentRaw);
      if (pr == null) {
        report.add('Row $sheetRow: Parent Row "$parentRaw" invalid — dropped');
      } else {
        pendingParent[items.length] = pr;
      }
    }
    items.add(InventoryItemsCompanion.insert(
      id: Value(id),
      dateAdded: parseSheetDate(cell(dateAddedCol)) ?? DateTime.now(),
      barcode: Value(parseSheetString(cell(barcodeCol))),
      itemDescription: desc,
      type: ItemType.fromLabel(parseSheetString(cell(typeCol))),
      cost: cost,
      costPerItem: Value(cpi),
      quantity: Value(qty),
      platform: Value(parseSheetString(cell(platformCol))),
      status: status,
      dateSold: Value(dateSold),
      saleNumber: Value(parseSheetString(cell(saleNbrCol))),
      comments: Value(parseSheetString(cell(commentsCol))),
      imageUrl: Value(parseSheetString(cell(imageUrlCol))),
    ));
  }

  // 4. Parent Row second pass.
  pendingParent.forEach((index, sheetRow) {
    final pid = sheetRowToId[sheetRow];
    final self = items[index].id.value;
    if (pid == null || pid == self) {
      report.add('Row ${_sheetRowOf(sheetRowToId, self)}: Parent Row $sheetRow '
          'not found — dropped');
    } else {
      items[index] = items[index].copyWith(parentId: Value(pid));
    }
  });
  return InventoryImport(items, report);
}

int _sheetRowOf(Map<int, int> m, int id) =>
    m.entries.firstWhere((e) => e.value == id, orElse: () => MapEntry(0, id)).key;

List<ExpensesCompanion> rowsToExpenses(List<List<Object?>> rows) {
  if (rows.length <= 1) return [];
  final header =
      rows[0].map((e) => e?.toString().trim().toLowerCase() ?? '').toList();
  int col(String name, int fallback) {
    final idx = header.indexOf(name.toLowerCase());
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
  final out = <ExpensesCompanion>[];
  for (var i = 1; i < rows.length; i++) {
    final row = rows[i];
    Object? cell(int idx) => idx < row.length ? row[idx] : null;
    final desc = parseSheetString(cell(descCol));
    final merchant = parseSheetString(cell(merchantCol));
    if (desc == null && merchant == null) continue;
    final taxRaw = parseSheetString(cell(taxCol));
    out.add(ExpensesCompanion.insert(
      date: parseSheetDate(cell(dateCol)) ?? DateTime.now(),
      merchant: merchant ?? 'Unknown',
      receiptImagePath: Value(parseSheetString(cell(receiptCol))),
      upc: Value(parseSheetString(cell(upcCol))),
      itemDescription: desc ?? merchant ?? 'Expense',
      quantity: Value(int.tryParse(parseSheetString(cell(qtyCol)) ?? '') ?? 1),
      unitPrice: parseSheetDouble(cell(priceCol)) ?? 0.0,
      expenseType: ExpenseType.fromLabel(parseSheetString(cell(typeCol))),
      taxAmount: Value(taxRaw == null ? null : parseSheetDouble(taxRaw)),
    ));
  }
  return out;
}
