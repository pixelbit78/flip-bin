import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/app/theme.dart';
import 'package:flipbin/widgets/sell_quantity_sheet.dart';

// Web on desktop: compact density + shrink-wrapped targets (QA saw 32px).
final desktopTheme = FlipBinTheme.dark.copyWith(
  visualDensity: VisualDensity.compact,
  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

void main() {
  void expectMin44(WidgetTester t) {
    final finders = [
      find.byType(IconButton),
      find.byType(TextButton),
      find.byType(OutlinedButton),
      find.byType(ElevatedButton),
      find.byType(SegmentedButton<int>),
    ];
    var n = 0;
    for (final f in finders) {
      for (final e in f.evaluate()) {
        final size = t.getSize(find.byWidget(e.widget).first);
        expect(size.height, greaterThanOrEqualTo(44), reason: '${e.widget.runtimeType}');
        expect(size.width, greaterThanOrEqualTo(44), reason: '${e.widget.runtimeType}');
        n++;
      }
    }
    expect(n, greaterThan(2));
  }

  testWidgets('BUG-05: How many sold? row controls are >= 44px', (t) async {
    await t.pumpWidget(MaterialApp(
      theme: desktopTheme,
      home: Scaffold(body: HowManySoldRow(qty: 5, value: 3, onChanged: (_) {})),
    ));
    expectMin44(t);
  });

  testWidgets('BUG-05: sell sheet controls are >= 44px', (t) async {
    final item = InventoryItem(
      id: 1,
      dateAdded: DateTime(2026, 7, 1),
      itemDescription: 'VHS bulk',
      type: ItemType.vhs,
      cost: 15,
      quantity: 10,
      costPerItem: 1.5,
      status: ItemStatus.active,
    );
    t.view.physicalSize = const Size(1200, 2400);
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      theme: desktopTheme,
      home: Scaffold(body: SellQuantitySheet(item: item)),
    ));
    await t.pump();
    expectMin44(t);
  });
}
