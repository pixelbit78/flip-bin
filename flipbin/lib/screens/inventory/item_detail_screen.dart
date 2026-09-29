import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/providers/inventory_provider.dart';
import 'package:flipbin/utils/proxied_image_url.dart';

/// Screen for adding or editing an inventory item.
class ItemDetailScreen extends ConsumerStatefulWidget {
  final String itemId;

  const ItemDetailScreen({super.key, required this.itemId});

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

  ItemType _type = ItemType.game;
  ItemStatus _status = ItemStatus.active;
  int _quantity = 1;
  DateTime _dateAdded = DateTime.now();
  DateTime? _dateSold;
  String? _imageUrl;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController();
    _barcodeController = TextEditingController();
    _platformController = TextEditingController();
    _costController = TextEditingController(text: '0.00');
    _saleNumberController = TextEditingController();
    _commentsController = TextEditingController();
  }

  @override
  void dispose() {
    _descController.dispose();
    _barcodeController.dispose();
    _platformController.dispose();
    _costController.dispose();
    _saleNumberController.dispose();
    _commentsController.dispose();
    super.dispose();
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
          platform: Value(_platformController.text.trim().isEmpty ? null : _platformController.text.trim()),
          status: _status,
          dateSold: Value(_dateSold),
          saleNumber: Value(_saleNumberController.text.trim().isEmpty ? null : _saleNumberController.text.trim()),
          comments: Value(_commentsController.text.trim().isEmpty ? null : _commentsController.text.trim()),
          imageUrl: Value(_imageUrl),
          barcode: Value(_barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim()),
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
          platform: _platformController.text.trim().isEmpty ? null : _platformController.text.trim(),
          status: _status,
          dateSold: _dateSold,
          saleNumber: _saleNumberController.text.trim().isEmpty ? null : _saleNumberController.text.trim(),
          comments: _commentsController.text.trim().isEmpty ? null : _commentsController.text.trim(),
          imageUrl: _imageUrl,
          barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
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
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (proxiedImageUrl(_imageUrl) != null)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      proxiedImageUrl(_imageUrl)!,
                      height: 160,
                      fit: BoxFit.cover,
                      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description *'),
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
                      initialValue: _type,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: ItemType.values
                          .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _type = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<ItemStatus>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: ItemStatus.values
                          .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _status = val;
                            if (val == ItemStatus.sold && _dateSold == null) {
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
                      decoration: const InputDecoration(
                        labelText: 'Cost (\$)',
                        prefixText: '\$ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                          onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                        ),
                        Text('$_quantity', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                decoration: const InputDecoration(labelText: 'Barcode (UPC)'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _platformController,
                decoration: const InputDecoration(labelText: 'Platform (e.g. PS5, Xbox)'),
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
                subtitle: Text(_dateSold != null ? dateFormat.format(_dateSold!) : 'Not Sold'),
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
                controller: _saleNumberController,
                decoration: const InputDecoration(labelText: 'Sale Number / Order ID'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _commentsController,
                decoration: const InputDecoration(labelText: 'Comments'),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
