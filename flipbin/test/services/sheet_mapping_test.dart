import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/qa/qa_fixtures.dart';
import 'package:flipbin/services/backends/local_file_backend.dart';
import 'package:flipbin/services/google_sheets_service.dart';
import 'package:flipbin/services/sheet_mapping.dart';

const dir = 'test/fixtures/quantity';

Map<String, Object?> snapshot(LocalImport p) => {
      'items': [
        for (final c in p.inventory.items)
          {
            'row_id': c.id.value,
            'description': c.itemDescription.value,
            'qty': c.quantity.value,
            'cost': c.cost.value,
            'cost_per_item': c.costPerItem.value,
            'status': c.status.value.name,
            'parent_id': c.parentId.present ? c.parentId.value : null,
          },
      ],
      'expenses': p.expenses.length,
      'report': p.report,
    };

void main() {
  test('headers: A–M unchanged + N–P; prod re-exports shared constants', () {
    expect(inventoryHeaders.sublist(13), ['Qty', 'Cost Per Item', 'Parent Row']);
    expect(inventoryHeaders.length, 16);
    expect(identical(GoogleSheetsService.inventoryHeaders, inventoryHeaders), isTrue);
    expect(inventoryRange, 'A:P');
  });

  for (final name in ['legacy_no_qty', 'v4_full', 'bad_values', 'within_1c']) {
    test('fixture $name matches expected_$name.json', () {
      final parsed = parseWorkbook(File('$dir/$name.xlsx').readAsBytesSync());
      final expected =
          jsonDecode(File('$dir/expected_$name.json').readAsStringSync());
      expect(jsonDecode(jsonEncode(snapshot(parsed))), expected);
    });
  }

  test('1¢ boundary: exactly 1¢ keeps Cost, 1.01¢ uses Qty × CPI', () {
    final within = parseWorkbook(File('$dir/within_1c.xlsx').readAsBytesSync());
    final byD = {for (final c in within.inventory.items) c.itemDescription.value: c};
    expect(byD['Boundary exactly 1c']!.cost.value, 1.00);
    expect(byD['17 comics']!.cost.value, 4.65);
    expect(byD['Blank cost']!.cost.value, 7.50);
    expect(within.report, isEmpty);
    final bad = parseWorkbook(File('$dir/bad_values.xlsx').readAsBytesSync());
    final b = bad.inventory.items.firstWhere((c) => c.itemDescription.value == 'Boundary 1.01c');
    expect(b.cost.value, 1.01);
  });

  test('legacy sheet: qty 1, cpi = Cost', () {
    final p = parseWorkbook(File('$dir/legacy_no_qty.xlsx').readAsBytesSync());
    expect(p.inventory.items.every((c) => c.quantity.value == 1), isTrue);
    expect(p.inventory.items.first.costPerItem.value, 108.30);
  });

  test('v4_full resolves Parent Row to parent id', () {
    final p = parseWorkbook(File('$dir/v4_full.xlsx').readAsBytesSync());
    final child = p.inventory.items[2];
    expect(child.parentId.value, 2);
    expect(p.report, isEmpty);
  });

  for (final name in [
    'corrupt_zero_byte',
    'corrupt_truncated',
    'wrong_format_csv',
    'wrong_format_text',
    'missing_inventory_tab',
    'wrong_headers',
  ]) {
    test('$name is rejected with a clear error', () {
      expect(
        () => parseWorkbook(File('$dir/$name.xlsx').readAsBytesSync()),
        throwsA(isA<SheetFormatException>().having(
            (e) => e.toString(), 'msg', startsWith('Not a valid FlipBin export:'))),
      );
    });
  }

  test('XLSX round-trip of the §2 fixture is identical (QZ-05)', () async {
    final db = FlipBinDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final t = DateTime(2026, 10, 1);
    await writeV2Sample(db, t);
    final items = await db.inventoryItemsDao.getAllForExport();
    final exps = await db.expensesDao.getAllForExport();
    final bytes = encodeWorkbook(items, exps);
    final parsed = parseWorkbook(bytes);
    expect(parsed.report, isEmpty);
    await const LocalFileBackend().apply(db, parsed);
    final again = await db.inventoryItemsDao.getAllForExport();
    // Pre-existing quirk (unchanged): a Personal row without dateSold exports
    // Personal Use Date = Date Added, which import reads back into dateSold.
    // Everything else, incl. all quantity columns, is identical.
    List<List<Object>> norm(List<List<Object>> rows) => [
          for (final r in rows)
            if (r[6] == 'Personal') ([...r]..[7] = ''..[9] = '') else r,
        ];
    expect(norm(inventoryToRows(again)), norm(inventoryToRows(items)));
    // Second cycle is byte-identical.
    await const LocalFileBackend()
        .apply(db, parseWorkbook(encodeWorkbook(again, exps)));
    final third = await db.inventoryItemsDao.getAllForExport();
    expect(inventoryToRows(third), inventoryToRows(again));
    final wb = decodeWorkbook(bytes);
    expect(wb.inventory.first, inventoryHeaders);
    expect(wb.expenses.first, expenseHeaders);
    // Parents before children; B′ Parent Row = B's sheet row.
    final rows = inventoryToRows(items);
    final bPrime = rows.indexWhere((r) => r[15] != '', 1);
    expect(int.parse(rows[bPrime][15] as String) - 1, lessThan(bPrime + 1));
    expect(rows[bPrime][13], '2');
  });

  test('§2 fixture metrics', () async {
    final db = FlipBinDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await writeV2Sample(db, DateTime.now());
    final dao = db.inventoryItemsDao;
    expect(await dao.watchTotalCostByStatus(ItemStatus.active).first, 43.0);
    expect(await dao.watchCountByStatus(ItemStatus.active).first, 18);
    final st = await dao.watchSellThrough().first;
    expect([st.stillActive, st.sold, st.listed], [8, 5, 13]);
    final ag = await dao.watchAgingBuckets().first;
    expect([ag.bucket30to59.totalCostTimesQty, ag.bucket30to59.itemCount], [6.0, 3]);
    expect([ag.bucket60to89.totalCostTimesQty, ag.bucket60to89.itemCount], [12.0, 4]);
    expect([ag.bucket90plus.totalCostTimesQty, ag.bucket90plus.itemCount], [15.0, 10]);
    expect(await dao.watchAvgDaysToSell().first, closeTo(62.0, 0.01));
    final listed = await dao.watchMonthlyListedCounts().first;
    expect(listed.fold<int>(0, (s, m) => s + m.count), 25);
    // Partial step: sell 1 of D (id 5).
    final child = await dao.sellUnits(5, 1);
    expect((await dao.getById(child)).cost, 1.5);
    expect((await dao.getById(5)).cost, 13.5);
    expect(await dao.watchTotalCostByStatus(ItemStatus.active).first, 41.5);
    final listed2 = await dao.watchMonthlyListedCounts().first;
    expect(listed2.fold<int>(0, (s, m) => s + m.count), 25);
  });

  test('legacy v1 fixture migrates on reopen (QT-02)', () async {
    final f = File('${Directory.systemTemp.createTempSync().path}/qa.sqlite');
    var db = FlipBinDatabase(NativeDatabase(f));
    await db.customSelect('SELECT 1').get(); // open v2
    await writeLegacyV1(db, DateTime.now());
    await db.close();
    db = FlipBinDatabase(NativeDatabase(f));
    addTearDown(db.close);
    final rows = await db.inventoryItemsDao.getAllForExport();
    expect(rows, hasLength(8));
    final q4 = rows.firstWhere((r) => r.quantity == 4);
    expect(q4.cost, 20.0);
    expect(q4.costPerItem, 5.0);
    expect(rows.every((r) => r.costPerItem != null), isTrue);
    final sugg = await db.inventoryItemsDao.lotSuggestions();
    expect(sugg.map((s) => s.suggestedQty).toSet(), {95, 17, 23});
  });
}
