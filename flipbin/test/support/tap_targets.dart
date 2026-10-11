import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every enabled, on-screen tappable (Material buttons, IconButton, InkWell /
/// InkResponse with a handler) must render at least [min]×[min].
void expectAllTappablesAtLeast(WidgetTester t, {double min = 44}) {
  final small = <String>[];
  var checked = 0;
  for (final e in find.byWidgetPredicate((w) {
    if (w is ButtonStyleButton) return w.onPressed != null || w.onLongPress != null;
    if (w is IconButton) return w.onPressed != null;
    // Chips: the padded tap target is the RawChip's own size.
    if (w is RawChip) return w.onPressed != null || w.onSelected != null;
    if (w is InkResponse) return w.onTap != null;
    if (w is GestureDetector) return w.onTap != null;
    return false;
  }, skipOffstage: true).evaluate()) {
    final ro = e.renderObject;
    if (ro is! RenderBox || !ro.hasSize || !ro.attached) continue;
    // Ink responses inside a button are measured via the button itself.
    if (e.widget is InkResponse &&
        e.findAncestorWidgetOfExactType<IconButton>() != null) {
      continue;
    }
    if (e.widget is InkResponse || e.widget is GestureDetector) {
      var inButton = false;
      e.visitAncestorElements((a) {
        if (a.widget is ButtonStyleButton ||
            a.widget is IconButton ||
            a.widget is RawChip ||
            a.widget is InkResponse) {
          inButton = true;
        }
        return !inButton;
      });
      if (inButton) continue;
    }
    checked++;
    final s = ro.size;
    if (s.height < min - 0.01 || s.width < min - 0.01) {
      final label = e.widget.key ?? e.widget.runtimeType;
      final text = find
          .descendant(of: find.byElementPredicate((x) => x == e), matching: find.byType(Text))
          .evaluate()
          .map((x) => (x.widget as Text).data)
          .where((d) => d != null)
          .join('/');
      small.add('$label "$text" ${s.width.toStringAsFixed(0)}×${s.height.toStringAsFixed(0)}');
    }
  }
  expect(checked, greaterThan(0), reason: 'no tappables found');
  expect(small, isEmpty, reason: 'tappables under ${min}px');
}
