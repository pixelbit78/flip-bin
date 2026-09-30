import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/providers/inventory_provider.dart';
import 'package:flipbin/services/barcode_lookup_service.dart';
import 'package:flipbin/utils/cost_field.dart';
import 'package:flipbin/utils/proxied_image_url.dart';

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
    if (_initialized) return;
    _initialized = true;
    _descController.text = item.itemDescription;
    _barcodeController.text = item.barcode ?? '';
    _platformController.text = item.platform ?? '';
    _costController.text = item.cost.toStringAsFixed(2);
    _saleNumberController.text = item.saleNumber ?? '';
    _commentsController.text = item.comments ?? '';
    _type = item.type;
    _status = item.status;
    _quantity = item.quantity;
    _dateAdded = item.dateAdded;
    _dateSold = item.dateSold;
    _imageUrl = item.imageUrl;
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final cost = double.tryParse(_costController.text.trim()) ?? 0.0;
    final controller = ref.read(inventoryControllerProvider);

    if (widget.isNew) {
      await controller.saveInventoryItem(
        InventoryItemsCompanion.insert(
          dateAdded: _dateAdded,
          itemDescription: _descController.text.trim(),
          type: _type,
          cost: cost,
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
      await controller.updateInventoryItem(
        InventoryItem(
          id: id,
          dateAdded: _dateAdded,
          itemDescription: _descController.text.trim(),
          type: _type,
          cost: cost,
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

    if (mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/inventory');
      }
    }
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

  /// Mark sold control: Active/Personal → sold + dateSold=now (form state; Save persists).
  void _markSold() {
    if (_status == ItemStatus.sold) return;
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

  Widget _buildCoverSection() {
    final displayUrl = proxiedImageUrl(_imageUrl);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: displayUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    displayUrl,
                    height: 160,
                    fit: BoxFit.cover,
                    webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                    errorBuilder: (_, __, ___) => _coverPlaceholder(),
                  ),
                )
              : _coverPlaceholder(),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: _editCoverUrl,
              icon: Icon(
                  displayUrl != null ? Icons.edit : Icons.add_photo_alternate),
              label: Text(displayUrl != null ? 'Change cover' : 'Add cover'),
            ),
            if (displayUrl != null)
              TextButton(
                onPressed: () => setState(() => _imageUrl = null),
                child: const Text('Remove'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _coverPlaceholder() {
    return Container(
      height: 120,
      width: 120,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, size: 40, color: Colors.white38),
          SizedBox(height: 4),
          Text(
            'No cover',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
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
                          decoration: const InputDecoration(
                            labelText: 'Cost (\$)',
                            prefixText: '\$ ',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Cost is required';
                            }
                            if (double.tryParse(val.trim()) == null) {
                              return 'Enter valid number';
                            }
                            return null;
                          },
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
                              onPressed: () => setState(() => _quantity++),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
                      onPressed: _save,
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
