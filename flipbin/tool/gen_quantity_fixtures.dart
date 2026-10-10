// Generates XLSX fixtures + expected_*.json for the quantity feature
// (SPEC §12.6). Headers come from the shared constants so they can't drift.
//
//   cd flipbin && dart run tool/gen_quantity_fixtures.dart
import 'dart:convert';
import 'dart:io';

import 'package:flipbin/services/backends/local_file_backend.dart';
import 'package:flipbin/services/sheet_mapping.dart';

const outDir = 'test/fixtures/quantity';

List<Object> blankInv() => List<Object>.filled(inventoryHeaders.length, '');

List<Object> inv({
  required String date,
  required String desc,
  String type = 'Book',
  required String cost,
  String status = 'Active',
  String sold = '',
  String qty = '',
  String cpi = '',
  String parent = '',
}) {
  final r = blankInv();
  r[0] = date;
  r[2] = desc;
  r[3] = type;
  r[4] = cost;
  r[6] = status;
  r[7] = sold;
  r[13] = qty;
  r[14] = cpi;
  r[15] = parent;
  return r;
}

final expenseRows = <List<Object>>[
  expenseHeaders,
  ['10/01/2026', 'QA Supplies', '', '', 'Bubble mailers', '2', '4.50', '9.00', 'Shipping', ''],
];

Map<String, Object?> expected(List<int> bytes) {
  final parsed = parseWorkbook(bytes);
  return {
    'items': [
      for (final c in parsed.inventory.items)
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
    'expenses': parsed.expenses.length,
    'report': parsed.report,
  };
}

void write(String name, List<int> bytes, {bool withExpected = true}) {
  File('$outDir/$name.xlsx').writeAsBytesSync(bytes);
  if (withExpected) {
    File('$outDir/expected_$name.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(expected(bytes)));
  }
}

void main() {
  Directory(outDir).createSync(recursive: true);

  // Legacy A–M only.
  final legacyHeaders = inventoryHeaders.sublist(0, 13);
  write(
    'legacy_no_qty',
    encodeRows([
      legacyHeaders,
      ['09/01/2026', '', '95 comics from 7miletreasures', 'Book', '108.30', '', 'Active', '', '', '', '', '', ''],
      ['09/02/2026', '', '17 comics', 'Book', '4.65', '', 'Active', '', '', '', '', '', ''],
      ['09/03/2026', '', 'QA single', 'Game', '10.00', '', 'Sold', '09/20/2026', '', '17', '', '', ''],
    ], expenseRows),
  );

  // v4 full: TEST_PLAN §2 fixture (anchor 10/01/2026), split B/B′.
  write(
    'v4_full',
    encodeRows([
      inventoryHeaders,
      inv(date: '09/21/2026', desc: 'Halo 3', type: 'Game', cost: '10.00', qty: '1', cpi: '10.00'),
      inv(date: '08/22/2026', desc: 'DVD lot', type: 'DVD', cost: '6.00', qty: '3', cpi: '2.00'),
      inv(date: '08/22/2026', desc: 'DVD lot', type: 'DVD', cost: '4.00', status: 'Sold', sold: '09/26/2026', qty: '2', cpi: '2.00', parent: '3'),
      inv(date: '06/23/2026', desc: 'CD set', type: 'CD', cost: '12.00', status: 'Sold', sold: '09/11/2026', qty: '3', cpi: '4.00'),
      inv(date: '06/28/2026', desc: 'VHS bulk', type: 'VHS', cost: '15.00', qty: '10', cpi: '1.50'),
      inv(date: '09/16/2026', desc: 'Book pair', cost: '14.50', status: 'Personal', qty: '2', cpi: '7.25'),
      inv(date: '07/28/2026', desc: 'Blu-ray', type: 'Blu-ray', cost: '12.00', qty: '4', cpi: '3.00'),
    ], expenseRows),
  );

  // Bad values: Qty 0/-1/2.5/abc, >1¢ mismatch, unresolved Parent Row,
  // 1.01¢ boundary.
  write(
    'bad_values',
    encodeRows([
      inventoryHeaders,
      inv(date: '09/01/2026', desc: 'Qty zero', cost: '5.00', qty: '0'),
      inv(date: '09/01/2026', desc: 'Qty negative', cost: '5.00', qty: '-1'),
      inv(date: '09/01/2026', desc: 'Qty decimal', cost: '5.00', qty: '2.5'),
      inv(date: '09/01/2026', desc: 'Qty text', cost: '5.00', qty: 'abc'),
      inv(date: '09/01/2026', desc: 'Mismatch', cost: '10.00', qty: '4', cpi: '3.00'),
      inv(date: '09/01/2026', desc: 'Orphan child', cost: '2.00', status: 'Sold', sold: '09/05/2026', qty: '1', cpi: '2.00', parent: '99'),
      inv(date: '09/01/2026', desc: 'Boundary 1.01c', cost: '1.00', qty: '1', cpi: '1.0101'),
    ], expenseRows),
  );

  // Within tolerance.
  write(
    'within_1c',
    encodeRows([
      inventoryHeaders,
      inv(date: '09/01/2026', desc: 'Boundary exactly 1c', cost: '1.00', qty: '1', cpi: '1.0100'),
      inv(date: '09/01/2026', desc: '17 comics', cost: '4.65', qty: '17', cpi: '0.2735'),
      inv(date: '09/01/2026', desc: 'Blank cost', cost: '', qty: '3', cpi: '2.50'),
      inv(date: '09/01/2026', desc: 'Split remainder', cost: '0.33', qty: '1', cpi: '0.335'),
    ], expenseRows),
  );

  // Corrupt / wrong-format files (QS-08): no expected rows, must error.
  File('$outDir/corrupt_zero_byte.xlsx').writeAsBytesSync(const []);
  final good = File('$outDir/v4_full.xlsx').readAsBytesSync();
  File('$outDir/corrupt_truncated.xlsx')
      .writeAsBytesSync(good.sublist(0, good.length ~/ 2));
  File('$outDir/wrong_format_csv.xlsx')
      .writeAsStringSync('${inventoryHeaders.join(',')}\n09/01/2026,,x,Book,1.00\n');
  File('$outDir/wrong_format_text.xlsx').writeAsStringSync('hello, not a workbook\n');
  write('missing_inventory_tab',
      encodeRows(const [], expenseRows, includeInventory: false),
      withExpected: false);
  write(
    'wrong_headers',
    encodeRows([
      ['Foo', 'Bar', 'Baz'],
      ['1', '2', '3'],
    ], expenseRows),
    withExpected: false,
  );
  stdout.writeln('Fixtures written to $outDir');
}
