import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/providers/expense_provider.dart';
import 'package:flipbin/services/barcode_lookup_service.dart';

/// Screen for adding or editing a business expense.
class ExpenseDetailScreen extends ConsumerStatefulWidget {
  final String expenseId;

  /// Optional barcode lookup result from the scanner (go_router `extra`).
  final BarcodeResult? scanPrefill;

  const ExpenseDetailScreen({
    super.key,
    required this.expenseId,
    this.scanPrefill,
  });

  bool get isNew => expenseId == 'new';

  @override
  ConsumerState<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends ConsumerState<ExpenseDetailScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _merchantController;
  late TextEditingController _descController;
  late TextEditingController _upcController;
  late TextEditingController _priceController;
  late TextEditingController _taxController;

  DateTime _date = DateTime.now();
  int _quantity = 1;
  ExpenseType _expenseType = ExpenseType.shipping;
  String? _receiptImagePath;
  bool _initialized = false;

  bool _prefillApplied = false;

  @override
  void initState() {
    super.initState();
    _merchantController = TextEditingController();
    _descController = TextEditingController();
    _upcController = TextEditingController();
    _priceController = TextEditingController(text: '0.00');
    _taxController = TextEditingController();

    if (widget.isNew && widget.scanPrefill != null) {
      _applyScanPrefill(widget.scanPrefill!);
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
      _upcController.text = result.barcode.trim();
    }
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _descController.dispose();
    _upcController.dispose();
    _priceController.dispose();
    _taxController.dispose();
    super.dispose();
  }

  void _populateFromExpense(Expense expense) {
    if (_initialized) return;
    _initialized = true;
    _merchantController.text = expense.merchant;
    _descController.text = expense.itemDescription;
    _upcController.text = expense.upc ?? '';
    _priceController.text = expense.unitPrice.toStringAsFixed(2);
    _taxController.text = expense.taxAmount?.toStringAsFixed(2) ?? '';
    _date = expense.date;
    _quantity = expense.quantity;
    _expenseType = expense.expenseType;
    _receiptImagePath = expense.receiptImagePath;
  }

  double get _computedTotal {
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    return _quantity * price;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final tax = _taxController.text.trim().isNotEmpty
        ? double.tryParse(_taxController.text.trim())
        : null;
    final controller = ref.read(expenseControllerProvider);

    if (widget.isNew) {
      await controller.saveExpense(
        ExpensesCompanion.insert(
          date: _date,
          merchant: _merchantController.text.trim(),
          itemDescription: _descController.text.trim(),
          quantity: Value(_quantity),
          unitPrice: price,
          expenseType: _expenseType,
          receiptImagePath: Value(_receiptImagePath),
          upc: Value(_upcController.text.trim().isEmpty ? null : _upcController.text.trim()),
          taxAmount: Value(tax),
        ),
      );
    } else {
      final id = int.parse(widget.expenseId);
      await controller.updateExpense(
        Expense(
          id: id,
          date: _date,
          merchant: _merchantController.text.trim(),
          itemDescription: _descController.text.trim(),
          quantity: _quantity,
          unitPrice: price,
          expenseType: _expenseType,
          receiptImagePath: _receiptImagePath,
          upc: _upcController.text.trim().isEmpty ? null : _upcController.text.trim(),
          taxAmount: tax,
        ),
      );
    }

    if (mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/expenses');
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
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
      final id = int.parse(widget.expenseId);
      await ref.read(expenseControllerProvider).deleteExpense(id);
      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/expenses');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isNew) {
      final id = int.tryParse(widget.expenseId);
      if (id != null) {
        final expenseAsync = ref.watch(expenseItemProvider(id));
        expenseAsync.whenData((expense) => _populateFromExpense(expense));
      }
    }

    final dateFormat = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'Add Expense' : 'Edit Expense'),
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
              TextFormField(
                controller: _merchantController,
                decoration: const InputDecoration(labelText: 'Merchant *'),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Merchant is required';
                  }
                  return null;
                },
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
              DropdownButtonFormField<ExpenseType>(
                initialValue: _expenseType,
                decoration: const InputDecoration(labelText: 'Expense Type'),
                items: ExpenseType.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _expenseType = val);
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Unit Price (\$)',
                        prefixText: '\$ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Price is required';
                        }
                        if (double.tryParse(val.trim()) == null) {
                          return 'Enter valid number';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
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
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Computed Total:', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      'Total: \$${_computedTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _upcController,
                decoration: const InputDecoration(labelText: 'UPC / Barcode (optional)'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _taxController,
                decoration: const InputDecoration(
                  labelText: 'Tax Amount (optional)',
                  prefixText: '\$ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date'),
                subtitle: Text(dateFormat.format(_date)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
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
