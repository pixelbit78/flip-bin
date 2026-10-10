import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/providers/inventory_provider.dart';
import 'package:flipbin/services/barcode_lookup_service.dart';
import 'package:flipbin/utils/cost_field.dart';
import 'package:flipbin/utils/default_cover.dart';
import 'package:flipbin/utils/proxied_image_url.dart';
import 'package:flipbin/widgets/sell_quantity_sheet.dart';

/// Screen for adding or editing an inventory item.
class ItemDetailScreen extends ConsumerStatefulWidget {
  final String itemId;

  /// Optional barcode lookup result from the scanner (go_router `extra`).
  final BarcodeResult? scanPrefill;

  const ItemDetailScreen({
    super.key,
    required this.itemId,
    this.scanPrefill,
  });

  bool get isNew => itemId == 'new';

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _descController;
  late TextEditingController _barcodeController;
  late TextEditingController _platformController;
  late TextEditingController _costController;
  late TextEditingController _saleNumberController;
  late TextEditingController _commentsController;
  late FocusNode _costFocusNode;

  ItemType _type = ItemType.game;
  ItemStatus _status = ItemStatus.active;
  int _quantity = 1;
  DateTime _dateAdded = DateTime.now();
  DateTime? _dateSold;
  String? _imageUrl;
  bool _initialized = false;
  bool _saving = false;
  InventoryItem? _loaded;
  String _initialCostText = '';
  int _initialQty = 1;
  bool _prefillApplied = false;

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController();
    _barcodeController = TextEditingController();
    _platformController = TextEditingController();
    _costController = TextEditingController(text: '0.00');
    _saleNumberController = TextEditingController();
    _commentsController = TextEditingController();
    _costFocusNode = FocusNode();
    _costFocusNode.addListener(_onCostFocusChange);

    if (widget.isNew && widget.scanPrefill != null) {
      _applyScanPrefill(widget.scanPrefill!);
    }
  }

  @override
  void dispose() {
    _costFocusNode.removeListener(_onCostFocusChange);
    _costFocusNode.dispose();
    _descController.dispose();
    _barcodeController.dispose();
    _platformController.dispose();
    _costController.dispose();
    _saleNumberController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  /// Clear Cost when focusing a zero / 0.00 value so entry is easy;
  /// keep any value already greater than zero.
  void _onCostFocusChange() {
    if (!_costFocusNode.hasFocus) return;
    if (shouldClearCostOnFocus(_costController.text)) {
      _costController.clear();
    }
  }

  void _applyScanPrefill(BarcodeResult result) {
    if (_prefillApplied) return;
    _prefillApplied = true;
    final name = (result.productName ?? result.description ?? '').trim();
    if (name.isNotEmpty) {
      _descController.text = name;
    }
    if (result.barcode.trim().isNotEmpty) {
      _barcodeController.text = result.barcode.trim();
    }
    final image = proxiedImageUrl(result.imageUrl) ?? result.imageUrl?.trim();
    if (image != null && image.isNotEmpty) {
      _imageUrl = image;
    }
    if (result.category != null && result.category!.trim().isNotEmpty) {
      _type = ItemType.fromCategory(result.category);
    }
  }

  void _populateFromItem(InventoryItem item) {
    if (_initialized) {
      _maybeRefreshFromDb(item);
      return;
    }
    _initialized = true;
    _descController.text = item.itemDescription;
    _barcodeController.text = item.barcode ?? '';
    _platformController.text = item.platform ?? '';
    _loaded = item;
    _costController.text = formatCpiField(item.cpi);
    _initialCostText = _costController.text;
    _initialQty = item.quantity;
    _saleNumberController.text = item.saleNumber ?? '';
    _commentsController.text = item.comments ?? '';
    _type = item.type;
    _status = item.status;
    _quantity = item.quantity;
    _dateAdded = item.dateAdded;
    _dateSold = item.dateSold;
    _imageUrl = item.imageUrl;
  }

  /// Live DB row changed while the form is open (BUG-02): when the user hasn't
  /// touched qty/cost, adopt the fresh values so the form never holds stale
  /// money/units.
  void _maybeRefreshFromDb(InventoryItem item) {
    final base = _loaded;
    if (base == null || _saving) return;
    final changed = item.quantity != base.quantity ||
        toCents(item.cost) != toCents(base.cost) ||
        item.status != base.status;
    if (!changed) return;
    final userEdited = _costController.text.trim() != _initialCostText.trim() ||
        _quantity != _initialQty;
    if (userEdited) return; // save-time guard will refuse
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _loaded = item;
        _quantity = item.quantity;
        _initialQty = item.quantity;
        _costController.text = formatCpiField(item.cpi);
        _initialCostText = _costController.text;
        _status = item.status;
        _dateSold = item.dateSold;
      });
    });
  }

  Future<void> _editCoverUrl() async {
    final controller = TextEditingController(text: _imageUrl ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cover image URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://…',
            helperText:
                'Stores the durable HTTPS URL on the item (and Sheets). '
                'UPCitemdb covers are preferred when available.',
          ),
          keyboardType: TextInputType.url,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(''),
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || result == null) return;
    final trimmed = result.trim();
    setState(() {
      if (trimmed.isEmpty) {
        _imageUrl = null;
      } else {
        _imageUrl = proxiedImageUrl(trimmed) ?? trimmed;
      }
    });
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/inventory');
    }
  }

  Future<void> _markUnsold() async {
    final item = _loaded;
    if (item == null) return;
    await ref.read(inventoryControllerProvider).unsell(item.id);
    if (mounted) _leave();
  }

  Future<void> _save({bool popAfter = true}) async {
    if (_saving) return; // BUG-03 in-flight guard
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _saveInner(popAfter: popAfter);
    } finally {
      if (mounted) setState(() => _saving = false);
      _saving = false;
    }
  }

  Future<void> _saveInner({bool popAfter = true}) async {

    final cpi = round4(double.tryParse(_costController.text.trim()) ?? 0.0);
    final controller = ref.read(inventoryControllerProvider);

    if (widget.isNew) {
      await controller.saveInventoryItem(
        InventoryItemsCompanion.insert(
          dateAdded: _dateAdded,
          itemDescription: _descController.text.trim(),
          type: _type,
          cost: lineTotal(_quantity, cpi),
          costPerItem: Value(cpi),
          quantity: Value(_quantity),
          platform: Value(_platformController.text.trim().isEmpty
              ? null
              : _platformController.text.trim()),
          status: _status,
          dateSold: Value(_dateSold),
          saleNumber: Value(_saleNumberController.text.trim().isEmpty
              ? null
              : _saleNumberController.text.trim()),
          comments: Value(_commentsController.text.trim().isEmpty
              ? null
              : _commentsController.text.trim()),
          imageUrl: Value(_imageUrl),
          barcode: Value(_barcodeController.text.trim().isEmpty
              ? null
              : _barcodeController.text.trim()),
        ),
      );
    } else {
      final id = int.parse(widget.itemId);
      // BUG-02 guard: rebase on the latest DB row. If qty/cost changed under
      // us (e.g. a sale) and the user didn't edit them, take the DB values;
      // if the user did edit them, refuse rather than overwrite.
      final latest = await controller.getById(id);
      final base = _loaded;
      if (base != null &&
          (latest.quantity != base.quantity ||
              toCents(latest.cost) != toCents(base.cost) ||
              latest.status != base.status)) {
        final userEdited = _costController.text.trim() != _initialCostText.trim() ||
            _quantity != _initialQty;
        if (userEdited) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('This item changed (e.g. a sale). Reopen it and try again.'),
            ));
          }
          _saving = false;
          return;
        }
        _quantity = latest.quantity;
        _status = _status == base.status ? latest.status : _status;
        _dateSold = _dateSold == base.dateSold ? latest.dateSold : _dateSold;
        _initialQty = latest.quantity;
      }
      _loaded = latest;
      // Dirty tracking (SPEC §4.3/§8): an unchanged cpi + qty keeps the stored
      // total exactly (e.g. a migrated $4.65 lot); any edit recomputes it.
      final dirty = _costController.text.trim() != _initialCostText.trim() ||
          _quantity != _initialQty ||
          _loaded == null;
      final keptCost = _loaded?.cost ?? lineTotal(_quantity, cpi);
      final keptCpi = _loaded?.cpi ?? cpi;
      await controller.updateInventoryItem(
        InventoryItem(
          id: id,
          dateAdded: _dateAdded,
          itemDescription: _descController.text.trim(),
          type: _type,
          cost: dirty ? lineTotal(_quantity, cpi) : keptCost,
          costPerItem: dirty ? cpi : keptCpi,
          parentId: _loaded?.parentId,
          lookupName: _loaded?.lookupName,
          lookupDescription: _loaded?.lookupDescription,
          quantity: _quantity,
          platform: _platformController.text.trim().isEmpty
              ? null
              : _platformController.text.trim(),
          status: _status,
          dateSold: _dateSold,
          saleNumber: _saleNumberController.text.trim().isEmpty
              ? null
              : _saleNumberController.text.trim(),
          comments: _commentsController.text.trim().isEmpty
              ? null
              : _commentsController.text.trim(),
          imageUrl: _imageUrl,
          barcode: _barcodeController.text.trim().isEmpty
              ? null
              : _barcodeController.text.trim(),
        ),
      );
    }

    if (mounted && popAfter) _leave();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final id = int.parse(widget.itemId);
      await ref.read(inventoryControllerProvider).deleteInventoryItem(id);
      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/inventory');
        }
      }
    }
  }

  /// Mark sold control. qty 1 (or a new item): Active/Personal → sold +
  /// dateSold=now in form state (Save persists). Existing qty > 1: save the
  /// form, then open "How many sold?" and split/sell immediately (SPEC §5.1).
  Future<void> _markSold() async {
    if (_status == ItemStatus.sold) return;
    if (!widget.isNew && _quantity > 1 && _loaded != null) {
      if (!_formKey.currentState!.validate()) return;
      await _save(popAfter: false);
      if (!mounted) return;
      final fresh = await ref
          .read(inventoryControllerProvider)
          .getById(_loaded!.id);
      if (!mounted) return;
      final soldId = await runSellFlow(
          context, ref.read(inventoryControllerProvider), fresh);
      if (soldId != null && mounted) _leave();
      return;
    }
    setState(() {
      _status = ItemStatus.sold;
      _dateSold ??= DateTime.now();
    });
  }

  /// Overlay the price-tag in the live cover↔Description gap without adding
  /// vertical space. The larger Stack bounds keep the overflowed button hit-testable.
  Widget _buildMarkSoldGap() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            _buildCoverSection(),
            const SizedBox(height: 16), // match live cover↔Description spacing
          ],
        ),
        Positioned(
          right: 0,
          bottom: 6, // nestle into natural gap, above Description
          child: _buildMarkSoldButton(),
        ),
      ],
    );
  }

  Widget _buildMarkSoldButton() {
    final alreadySold = _status == ItemStatus.sold;
    // Active (and Personal): orange tappable. Sold: muted no-op.
    const activeBorder = Color(0xFFFF9800);
    const activeFg = Color(0xFFFFB74D);
    final border =
        alreadySold ? Colors.white.withValues(alpha: 0.14) : activeBorder;
    final bg = alreadySold
        ? Colors.white.withValues(alpha: 0.06)
        : activeBorder.withValues(alpha: 0.14);
    final fg = alreadySold ? Colors.white38 : activeFg;

    return Tooltip(
      message: alreadySold ? 'Sold' : 'Mark sold',
      child: Semantics(
        button: !alreadySold,
        label: alreadySold ? 'Sold' : 'Mark sold',
        enabled: !alreadySold,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('markSoldButton'),
            onTap: alreadySold ? null : _markSold,
            borderRadius: BorderRadius.circular(10),
            child: Ink(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: border, width: 1.5),
              ),
              child: Icon(
                Icons.local_offer,
                size: 22,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Read-only Total cost (SPEC §5.1): qty × cost per item, or the stored
  /// total when nothing was edited. Not focusable.
  Widget _buildReadOnlyTotal() {
    final cpi = double.tryParse(_costController.text.trim()) ?? 0.0;
    final unchanged = _loaded != null &&
        _costController.text.trim() == _initialCostText.trim() &&
        _quantity == _initialQty;
    final total = unchanged ? _loaded!.cost : lineTotal(_quantity, cpi);
    return ExcludeFocus(
      child: InputDecorator(
        key: const Key('editTotalCost'),
        isEmpty: false,
        decoration: const InputDecoration(
          labelText: 'Total cost (\$)',
          enabled: false,
        ),
        child: Text(
          '\$ ${total.toStringAsFixed(2)}',
          style: const TextStyle(color: Colors.white54, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildCoverSection() {
    final hasUrl = (_imageUrl ?? '').trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ItemCoverImage(
            imageUrl: _imageUrl,
            type: _type,
            width: 120,
            height: 160,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: _editCoverUrl,
              icon: Icon(hasUrl ? Icons.edit : Icons.add_photo_alternate),
              label: Text(hasUrl ? 'Change cover' : 'Add cover'),
            ),
            if (hasUrl)
              TextButton(
                onPressed: () => setState(() => _imageUrl = null),
                child: const Text('Remove'),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isNew) {
      final id = int.tryParse(widget.itemId);
      if (id != null) {
        final itemAsync = ref.watch(inventoryItemProvider(id));
        itemAsync.whenData((item) => _populateFromItem(item));
      }
    }

    final dateFormat = DateFormat('yyyy-MM-dd');

    // Space for the fixed Save bar so the last field can scroll fully into view.
    const saveBarClearance = 96.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'Add Item' : 'Edit Item'),
        actions: [
          if (!widget.isNew)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: _delete,
            ),
        ],
      ),
      // Nested under ShellRoute bottom nav: Save sits just above the nav while
      // form content scrolls underneath the fixed Save bar.
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, saveBarClearance),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMarkSoldGap(),
                  TextFormField(
                    controller: _descController,
                    decoration:
                        const InputDecoration(labelText: 'Description *'),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Description is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<ItemType>(
                          key: ValueKey('type-$_type'),
                          initialValue: _type,
                          decoration: const InputDecoration(labelText: 'Type'),
                          items: ItemType.values
                              .map((t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t.label),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _type = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<ItemStatus>(
                          key: ValueKey('status-$_status'),
                          initialValue: _status,
                          decoration:
                              const InputDecoration(labelText: 'Status'),
                          items: ItemStatus.values
                              .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s.label),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _status = val;
                                if (val == ItemStatus.sold &&
                                    _dateSold == null) {
                                  _dateSold = DateTime.now();
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _costController,
                          focusNode: _costFocusNode,
                          key: const Key('editCostPerItem'),
                          decoration: InputDecoration(
                            labelText: _quantity > 1
                                ? 'Cost per item (\$)'
                                : 'Cost (\$)',
                            prefixText: '\$ ',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                          ],
                          onChanged: (_) {
                            if (_quantity > 1) setState(() {});
                          },
                          validator: validateCostInput,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          children: [
                            const Text('Qty: '),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: _quantity > 1
                                  ? () => setState(() => _quantity--)
                                  : null,
                            ),
                            Text(
                              '$_quantity',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: _quantity < kMaxQty
                                  ? () => setState(() => _quantity++)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_quantity > 1) ...[
                    const SizedBox(height: 16),
                    _buildReadOnlyTotal(),
                  ],
                  if (!widget.isNew && _status == ItemStatus.sold && _loaded?.status == ItemStatus.sold) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        key: const Key('markUnsoldButton'),
                        onPressed: _markUnsold,
                        icon: const Icon(Icons.undo),
                        label: Text(_loaded?.parentId != null
                            ? 'Mark unsold (merge back)'
                            : 'Mark unsold'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _barcodeController,
                    decoration:
                        const InputDecoration(labelText: 'Barcode (UPC)'),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date Added'),
                    subtitle: Text(dateFormat.format(_dateAdded)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _dateAdded,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _dateAdded = picked);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date Sold'),
                    subtitle: Text(
                      _dateSold != null
                          ? dateFormat.format(_dateSold!)
                          : 'Not Sold',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _dateSold ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _dateSold = picked);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _commentsController,
                    decoration: const InputDecoration(labelText: 'Comments'),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Material(
              elevation: 12,
              color: Theme.of(context).scaffoldBackgroundColor,
              child: SafeArea(
                top: false,
                minimum: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      key: const Key('itemSaveButton'),
                      onPressed: _saving ? null : () => _save(),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Save'),
                    ),
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
