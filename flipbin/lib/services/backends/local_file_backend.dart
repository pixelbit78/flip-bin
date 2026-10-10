// QA backend: local XLSX export/import that mirrors the Google sheet's tabs
// and columns via the shared mapping (SPEC §12.6). Never touches Google.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/services/backends/local_file_io.dart' as io;
import 'package:flipbin/services/sheet_mapping.dart';

const String kQaExportFileName = 'FlipBin Export QA.xlsx';

/// Decoded workbook rows (as strings, like Sheets FORMATTED_VALUE).
class WorkbookRows {
  final List<List<Object?>> inventory;
  final List<List<Object?>> expenses;
  final bool hasExpensesTab;
  const WorkbookRows(this.inventory, this.expenses, this.hasExpensesTab);
}

/// Parsed import ready for `replaceAll`.
class LocalImport {
  final InventoryImport inventory;
  final List<ExpensesCompanion> expenses;
  final List<String> report;
  const LocalImport(this.inventory, this.expenses, this.report);
}

/// Builds the XLSX bytes. All cells are written as text.
Uint8List encodeWorkbook(List<InventoryItem> items, List<Expense> expenses) {
  return encodeRows(inventoryToRows(items), expensesToRows(expenses));
}

Uint8List encodeRows(List<List<Object>> inv, List<List<Object>> exp,
    {bool includeInventory = true, bool includeExpenses = true}) {
  final excel = Excel.createExcel();
  final defaultName = excel.getDefaultSheet() ?? 'Sheet1';
  void write(String tab, List<List<Object>> rows) {
    final sheet = excel[tab];
    for (final r in rows) {
      sheet.appendRow([for (final c in r) TextCellValue('$c')]);
    }
  }

  if (includeInventory) write(inventoryTab, inv);
  if (includeExpenses) write(expensesTab, exp);
  final first = includeInventory ? inventoryTab : expensesTab;
  excel.setDefaultSheet(first);
  if (defaultName != inventoryTab && defaultName != expensesTab) {
    excel.delete(defaultName);
  }
  final bytes = excel.encode();
  if (bytes == null) throw StateError('XLSX encode failed');
  return Uint8List.fromList(bytes);
}

String? _cellText(Data? d) {
  final v = d?.value;
  if (v == null) return null;
  return switch (v) {
    TextCellValue t => t.value.toString(),
    IntCellValue i => '${i.value}',
    DoubleCellValue x => '${x.value}',
    _ => v.toString(),
  };
}

/// BUG-01: normalise quirks of openpyxl (and similar writers) that the
/// `excel` package can't read, without touching the data:
///  * absolute part names in `xl/_rels/workbook.xml.rels`
///    (Target="/xl/worksheets/sheet1.xml"); `excel` resolves targets relative
///    to `xl/` so it can't find the sheets;
///  * empty inline-string cells (`<c t="inlineStr"></c>` / `<is/>`), which
///    crash its inline-string parser.
/// A zip that can't be read at all still fails as damaged/truncated.
List<int> normalizeXlsx(List<int> bytes) {
  final archive = ZipDecoder().decodeBytes(bytes, verify: true);
  final emptyInline = RegExp(
      r'(<c\b[^>]*\bt="inlineStr"[^>]*?)(?:/>|>\s*(?:<is\s*/>|<is>\s*</is>)?\s*</c>)');
  final absTarget = RegExp(r'Target="/xl/([^"]+)"');
  var changed = false;
  final out = Archive();
  for (final f in archive.files) {
    final isRels = f.name == 'xl/_rels/workbook.xml.rels';
    final isSheet =
        f.name.startsWith('xl/worksheets/') && f.name.endsWith('.xml');
    if (f.isFile && (isRels || isSheet)) {
      final xml = utf8.decode(f.content as List<int>);
      final fixed = isRels
          ? xml.replaceAllMapped(absTarget, (m) => 'Target="${m[1]}"')
          : xml.replaceAllMapped(
              emptyInline, (m) => '${m[1]}><is><t></t></is></c>');
      if (fixed != xml) {
        changed = true;
        final data = utf8.encode(fixed);
        out.addFile(ArchiveFile(f.name, data.length, data));
        continue;
      }
    }
    out.addFile(f);
  }
  return changed ? ZipEncoder().encode(out)! : bytes;
}

/// Decodes and validates a workbook. Throws [SheetFormatException] with a
/// clear reason; nothing is imported on failure.
WorkbookRows decodeWorkbook(List<int> bytes) {
  if (bytes.isEmpty) throw SheetFormatException('the file is empty');
  // XLSX is a zip: must start with "PK".
  if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
    throw SheetFormatException('the file is not an .xlsx workbook');
  }
  Excel excel;
  try {
    excel = Excel.decodeBytes(normalizeXlsx(bytes));
  } catch (e) {
    throw SheetFormatException('the workbook is damaged or truncated');
  }
  List<List<Object?>> rowsOf(String tab) {
    final t = excel.tables[tab];
    if (t == null) return const [];
    return [
      for (final r in t.rows) [for (final c in r) _cellText(c)],
    ];
  }

  if (!excel.tables.containsKey(inventoryTab)) {
    throw SheetFormatException('missing the "$inventoryTab" tab');
  }
  return WorkbookRows(
    rowsOf(inventoryTab),
    rowsOf(expensesTab),
    excel.tables.containsKey(expensesTab),
  );
}

/// Full local import parse (validation happens before any DB write).
LocalImport parseWorkbook(List<int> bytes) {
  final wb = decodeWorkbook(bytes);
  final inv = rowsToInventory(wb.inventory, strict: true);
  final exp = rowsToExpenses(wb.expenses);
  final report = [
    ...inv.report,
    if (!wb.hasExpensesTab) 'No "$expensesTab" tab — imported 0 expenses',
  ];
  return LocalImport(inv, exp, report);
}

/// QA export/import service. Guaranteed Google-free.
class LocalFileBackend {
  const LocalFileBackend();

  String get label => 'Local file (QA)';

  Future<void> export(FlipBinDatabase db) async {
    final items = await db.inventoryItemsDao.getAllForExport();
    final expenses = await db.expensesDao.getAllForExport();
    await io.downloadBytes(kQaExportFileName, encodeWorkbook(items, expenses));
  }

  /// Picks a file; returns null when cancelled. Throws [SheetFormatException].
  Future<LocalImport?> pickAndParse() async {
    final bytes = await io.pickFileBytes(accept: '.xlsx');
    if (bytes == null) return null;
    return parseWorkbook(bytes);
  }

  Future<void> apply(FlipBinDatabase db, LocalImport data) async {
    await db.transaction(() async {
      await db.inventoryItemsDao.replaceAll(data.inventory.items);
      await db.expensesDao.replaceAll(data.expenses);
    });
  }
}
