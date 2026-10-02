import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/providers/expense_provider.dart';
import 'package:flipbin/providers/inventory_provider.dart';
import 'package:flipbin/services/barcode_lookup_service.dart';
import 'package:flipbin/utils/cost_field.dart';
import 'package:flipbin/utils/default_cover.dart';
import 'package:flipbin/utils/proxied_image_url.dart';

const Color _sheetBg = Color(0xFF252830);
const Color _surfaceBg = Color(0xFF1A1D23);
const Color _accent = Color(0xFF2196F3);
const Color _scrim = Color(0x94000000); // ~0.58 alpha

/// Product title used for inventory description / expense prefills.
String scanProductTitle(BarcodeResult scan) {
  final name = (scan.productName ?? scan.description ?? '').trim();
  if (name.isNotEmpty) return name;
  final code = scan.barcode.trim();
  if (code.isNotEmpty) return 'UPC $code';
  return 'Unknown Product';
}

/// Shows the inventory quick-add bottom sheet over the dimmed scanner.
///
/// Returns `true` if an item was saved, `false` if cancelled / dismissed.
Future<bool> showScannerInventoryQuickAdd({
  required BuildContext context,
  required WidgetRef ref,
  required BarcodeResult scan,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: _scrim,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: ScannerInventoryQuickAddSheet(scan: scan),
    ),
  );
  return saved == true;
}

/// Shows the expense quick-add bottom sheet over the dimmed scanner.
///
/// Returns `true` if an expense was saved, `false` if cancelled / dismissed.
Future<bool> showScannerExpenseQuickAdd({
  required BuildContext context,
  required WidgetRef ref,
  required BarcodeResult scan,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: _scrim,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: ScannerExpenseQuickAddSheet(scan: scan),
    ),
  );
  return saved == true;
}

/// Compact non-editable product summary (thumb + title + UPC).
class ScannerProductSummary extends StatelessWidget {
  const ScannerProductSummary({super.key, required this.scan});

  final BarcodeResult scan;

  @override
  Widget build(BuildContext context) {
    final title = scanProductTitle(scan);
    final upc = scan.barcode.trim();
    final itemType = ItemType.fromCategory(scan.category);
    final image = proxiedImageUrl(scan.imageUrl) ?? scan.imageUrl?.trim();

    return Container(
      key: const Key('scannerProductSummary'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _surfaceBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ItemCoverImage(
            imageUrl: image,
            type: itemType,
            width: 48,
            height: 48,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (upc.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    'UPC: $upc',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared sheet chrome: handle, title, body, Cancel / OK.
class _QuickAddSheetScaffold extends StatelessWidget {
  const _QuickAddSheetScaffold({
    required this.title,
    required this.body,
    required this.onCancel,
    required this.onOk,
    this.saving = false,
  });

  final String title;
  final Widget body;
  final VoidCallback onCancel;
  final VoidCallback onOk;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: _sheetBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x73000000),
            blurRadius: 32,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: body,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('scannerQuickAddCancel'),
                      onPressed: saving ? null : onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      key: const Key('scannerQuickAddOk'),
                      onPressed: saving ? null : onOk,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _accent.withValues(alpha: 0.4),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('OK'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inventory quick-add: Cost + Status (Active/Sold/Personal).
class ScannerInventoryQuickAddSheet extends ConsumerStatefulWidget {
  const ScannerInventoryQuickAddSheet({super.key, required this.scan});

  final BarcodeResult scan;

  @override
  ConsumerState<ScannerInventoryQuickAddSheet> createState() =>
      _ScannerInventoryQuickAddSheetState();
}

class _ScannerInventoryQuickAddSheetState
    extends ConsumerState<ScannerInventoryQuickAddSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _costController;
  late final FocusNode _costFocusNode;
  ItemStatus _status = ItemStatus.active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _costController = TextEditingController();
    _costFocusNode = FocusNode();
    _costFocusNode.addListener(_onCostFocusChange);
  }

  @override
  void dispose() {
    _costFocusNode.removeListener(_onCostFocusChange);
    _costFocusNode.dispose();
    _costController.dispose();
    super.dispose();
  }

  void _onCostFocusChange() {
    if (!_costFocusNode.hasFocus) return;
    if (shouldClearCostOnFocus(_costController.text)) {
      _costController.clear();
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final cost = double.tryParse(_costController.text.trim());
    if (cost == null) return;

    setState(() => _saving = true);
    try {
      final title = scanProductTitle(widget.scan);
      final upc = widget.scan.barcode.trim();
      final type = ItemType.fromCategory(widget.scan.category);
      final image =
          proxiedImageUrl(widget.scan.imageUrl) ?? widget.scan.imageUrl?.trim();
      final now = DateTime.now();
      final dateSold = _status == ItemStatus.sold ? now : null;

      await ref.read(inventoryControllerProvider).saveInventoryItem(
            InventoryItemsCompanion.insert(
              dateAdded: now,
              itemDescription: title,
              type: type,
              cost: cost,
              quantity: const Value(1),
              status: _status,
              dateSold: Value(dateSold),
              imageUrl: Value(
                (image != null && image.isNotEmpty) ? image : null,
              ),
              barcode: Value(upc.isEmpty ? null : upc),
            ),
          );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save item: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _QuickAddSheetScaffold(
      title: 'Add to Inventory',
      saving: _saving,
      onCancel: () => Navigator.of(context).pop(false),
      onOk: _save,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScannerProductSummary(scan: widget.scan),
            const SizedBox(height: 14),
            const Text(
              'Cost *',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              key: const Key('scannerInventoryCost'),
              controller: _costController,
              focusNode: _costFocusNode,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: const InputDecoration(
                prefixText: '\$ ',
                prefixStyle: TextStyle(color: Colors.white54, fontSize: 16),
                hintText: '0.00',
                hintStyle: TextStyle(color: Colors.white38),
                filled: true,
                fillColor: _surfaceBg,
              ),
              validator: (value) {
                final raw = value?.trim() ?? '';
                if (raw.isEmpty) return 'Cost is required';
                final parsed = double.tryParse(raw);
                if (parsed == null) return 'Enter a valid amount';
                if (parsed < 0) return 'Cost cannot be negative';
                return null;
              },
            ),
            const SizedBox(height: 14),
            const Text(
              'Status',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 6),
            _StatusSegmented(
              value: _status,
              onChanged: (s) => setState(() => _status = s),
            ),
            const SizedBox(height: 10),
            const Text(
              'Sold sets Date Sold to today.',
              style: TextStyle(fontSize: 12, color: Colors.white38),
            ),
            const SizedBox(height: 2),
            const Text(
              'Title, UPC, category & cover come from the scan.',
              style: TextStyle(fontSize: 12, color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusSegmented extends StatelessWidget {
  const _StatusSegmented({required this.value, required this.onChanged});

  final ItemStatus value;
  final ValueChanged<ItemStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('scannerInventoryStatus'),
      decoration: BoxDecoration(
        color: _surfaceBg,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          for (final status in ItemStatus.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(status),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == status ? _accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: value == status ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Expense quick-add: Amount, Qty, Date, Description, Type chips.
class ScannerExpenseQuickAddSheet extends ConsumerStatefulWidget {
  const ScannerExpenseQuickAddSheet({super.key, required this.scan});

  final BarcodeResult scan;

  @override
  ConsumerState<ScannerExpenseQuickAddSheet> createState() =>
      _ScannerExpenseQuickAddSheetState();
}

class _ScannerExpenseQuickAddSheetState
    extends ConsumerState<ScannerExpenseQuickAddSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _qtyController;
  late final TextEditingController _descController;
  late final FocusNode _amountFocusNode;
  DateTime _date = DateTime.now();
  ExpenseType _type = ExpenseType.shipping;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _qtyController = TextEditingController(text: '1');
    _descController = TextEditingController(text: scanProductTitle(widget.scan));
    _amountFocusNode = FocusNode();
    _amountFocusNode.addListener(_onAmountFocusChange);
  }

  @override
  void dispose() {
    _amountFocusNode.removeListener(_onAmountFocusChange);
    _amountFocusNode.dispose();
    _amountController.dispose();
    _qtyController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _onAmountFocusChange() {
    if (!_amountFocusNode.hasFocus) return;
    if (shouldClearCostOnFocus(_amountController.text)) {
      _amountController.clear();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null) return;
    final qty = int.tryParse(_qtyController.text.trim()) ?? 1;
    if (qty < 1) return;

    setState(() => _saving = true);
    try {
      final upc = widget.scan.barcode.trim();
      final desc = _descController.text.trim().isEmpty
          ? scanProductTitle(widget.scan)
          : _descController.text.trim();

      await ref.read(expenseControllerProvider).saveExpense(
            ExpensesCompanion.insert(
              date: _date,
              merchant: '',
              itemDescription: desc,
              quantity: Value(qty),
              unitPrice: amount,
              expenseType: _type,
              upc: Value(upc.isEmpty ? null : upc),
            ),
          );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save expense: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat.yMMMd().format(_date);

    return _QuickAddSheetScaffold(
      title: 'Add to Expense',
      saving: _saving,
      onCancel: () => Navigator.of(context).pop(false),
      onOk: _save,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScannerProductSummary(scan: widget.scan),
            const SizedBox(height: 14),
            const Text(
              'Amount (expense cost) *',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              key: const Key('scannerExpenseAmount'),
              controller: _amountController,
              focusNode: _amountFocusNode,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: const InputDecoration(
                prefixText: '\$ ',
                prefixStyle: TextStyle(color: Colors.white54, fontSize: 16),
                hintText: '0.00',
                hintStyle: TextStyle(color: Colors.white38),
                filled: true,
                fillColor: _surfaceBg,
              ),
              validator: (value) {
                final raw = value?.trim() ?? '';
                if (raw.isEmpty) return 'Amount is required';
                final parsed = double.tryParse(raw);
                if (parsed == null) return 'Enter a valid amount';
                if (parsed < 0) return 'Amount cannot be negative';
                return null;
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'Quantity',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              key: const Key('scannerExpenseQuantity'),
              controller: _qtyController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: const InputDecoration(
                filled: true,
                fillColor: _surfaceBg,
              ),
              validator: (value) {
                final parsed = int.tryParse(value?.trim() ?? '');
                if (parsed == null || parsed < 1) {
                  return 'Quantity must be at least 1';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'Date',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 6),
            Material(
              color: _surfaceBg,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                key: const Key('scannerExpenseDate'),
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Colors.transparent,
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    suffixIcon: Icon(Icons.calendar_today, size: 18),
                  ),
                  child: Text(
                    dateLabel,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Description',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              key: const Key('scannerExpenseDescription'),
              controller: _descController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: const InputDecoration(
                filled: true,
                fillColor: _surfaceBg,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Type',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              key: const Key('scannerExpenseTypeChips'),
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in ExpenseType.scannerQuickAdd)
                  FilterChip(
                    label: Text(t.label),
                    selected: _type == t,
                    onSelected: (_) => setState(() => _type = t),
                    selectedColor: _accent.withValues(alpha: 0.28),
                    checkmarkColor: _accent,
                    labelStyle: TextStyle(
                      color: _type == t ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(
                      color: _type == t ? _accent : Colors.white24,
                    ),
                    backgroundColor: _surfaceBg,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'UPC linked from scan when available.',
              style: TextStyle(fontSize: 12, color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }
}
