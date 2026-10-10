import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/providers/inventory_provider.dart';
import 'package:flipbin/utils/cost_field.dart';
import 'package:flipbin/utils/default_cover.dart';

/// Result of the "How many sold?" sheet.
class SellChoice {
  final int units;
  final DateTime date;
  const SellChoice(this.units, this.date);
}

/// Shows the "How many sold?" sheet for [item] (qty > 1). Returns null when
/// cancelled. Defaults to All (SPEC §5.5).
Future<SellChoice?> showSellQuantitySheet(
  BuildContext context,
  InventoryItem item,
) {
  return showModalBottomSheet<SellChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1E2229),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => SellQuantitySheet(item: item),
  );
}

class SellQuantitySheet extends StatefulWidget {
  final InventoryItem item;
  const SellQuantitySheet({super.key, required this.item});

  @override
  State<SellQuantitySheet> createState() => _SellQuantitySheetState();
}

class _SellQuantitySheetState extends State<SellQuantitySheet> {
  late int _n = widget.item.quantity;
  DateTime _date = DateTime.now();
  bool _submitted = false;

  int get _r => widget.item.quantity;

  String _preview() {
    final money = splitMoney(
        parentTotal: widget.item.cost, cpi: widget.item.cpi, n: _n);
    final status = widget.item.status.label;
    if (_n == _r) {
      return 'Sell all $_r → becomes Sold (no new row).';
    }
    return 'Sell $_n of $_r → ${_r - _n} stay $status '
        '(\$${money.parentCost.toStringAsFixed(2)}); new Sold row ×$_n, '
        '\$${money.childCost.toStringAsFixed(2)}.';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final today = DateUtils.isSameDay(_date, DateTime.now());
    final dateText =
        '${today ? 'Today · ' : ''}${DateFormat('yyyy-MM-dd').format(_date)}';
    const label = TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Text('How many sold?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            Row(children: [
              ItemCoverImage(
                  imageUrl: item.imageUrl, type: item.type, width: 48, height: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.itemDescription,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      '$_r on hand · ${formatEach(item.cpi)} · Total \$${item.cost.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 16),
            const Text('Quantity sold', style: label),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: SegmentedButton<int>(
                  segments: [
                    const ButtonSegment(value: 1, label: Text('1')),
                    ButtonSegment(value: _r, label: Text('All ($_r)')),
                  ],
                  selected: {if (_n == 1 || _n == _r) _n},
                  emptySelectionAllowed: true,
                  showSelectedIcon: false,
                  onSelectionChanged: (s) {
                    if (s.isNotEmpty) setState(() => _n = s.first);
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const Key('sellQtyMinus'),
                icon: const Icon(Icons.remove),
                onPressed: _n > 1 ? () => setState(() => _n--) : null,
              ),
              Text('$_n',
                  key: const Key('sellQtyValue'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                key: const Key('sellQtyPlus'),
                icon: const Icon(Icons.add),
                onPressed: _n < _r ? () => setState(() => _n++) : null,
              ),
            ]),
            const SizedBox(height: 12),
            const Text('Date sold', style: label),
            const SizedBox(height: 6),
            OutlinedButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: Align(alignment: Alignment.centerLeft, child: Text(dateText)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_preview(), key: const Key('sellPreview')),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  key: const Key('sellConfirm'),
                  onPressed: _submitted
                      ? null
                      : () {
                          setState(() => _submitted = true);
                          Navigator.of(context).pop(SellChoice(_n, _date));
                        },
                  child: Text(_n == _r ? 'Mark all sold' : 'Mark $_n sold'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Inline "How many sold?" row for scanner quick-add (Status = Sold, qty > 1).
class HowManySoldRow extends StatelessWidget {
  final int qty;
  final int value;
  final ValueChanged<int> onChanged;
  const HowManySoldRow(
      {super.key, required this.qty, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('How many sold?',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(children: [
          TextButton(
            onPressed: () => onChanged(qty),
            child: Text('All ($qty)',
                style: TextStyle(
                    fontWeight: value == qty ? FontWeight.bold : FontWeight.normal)),
          ),
          const Spacer(),
          IconButton(
            key: const Key('howManySoldMinus'),
            icon: const Icon(Icons.remove, color: Colors.white),
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
          ),
          Text('$value',
              key: const Key('howManySoldValue'),
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          IconButton(
            key: const Key('howManySoldPlus'),
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: value < qty ? () => onChanged(value + 1) : null,
          ),
        ]),
      ],
    );
  }
}

/// Shared sell flow used by Edit Item, the list chip and scanner match rows.
/// qty 1 sells immediately; qty > 1 opens the sheet. Shows an Undo snackbar.
/// Returns the Sold row id, or null when cancelled.
Future<int?> runSellFlow(
  BuildContext context,
  InventoryController controller,
  InventoryItem item, {
  bool showUndo = true,
}) async {
  var units = 1;
  DateTime? date;
  if (item.quantity > 1) {
    final choice = await showSellQuantitySheet(context, item);
    if (choice == null) return null;
    units = choice.units;
    date = choice.date;
  }
  final soldId = await controller.sellUnits(item.id, units, date: date);
  if (showUndo && context.mounted) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(
      content: Text(units == item.quantity
          ? 'Marked sold'
          : 'Sold $units of ${item.quantity}'),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => controller.unsell(soldId),
      ),
    ));
  }
  return soldId;
}
