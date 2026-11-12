import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../domain/money.dart';
import '../state/app_state.dart';
import '../widgets/barcode_scan_screen.dart';
import 'stock_adjust_screen.dart';

/// S5 — Product add/edit form with validation (name + sale price
/// required), category picker with "add new category", barcode field with
/// camera scan, optional photo, active toggle. On the edit variant it also
/// offers stock adjustment, movement history and delete.
class ProductFormScreen extends StatefulWidget {
  final Product? product;
  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _barcode;
  late final TextEditingController _cost;
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late final TextEditingController _threshold;
  List<Category> _categories = [];
  int? _categoryId;
  bool _active = true;
  String? _photoPath;
  bool _saving = false;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _barcode = TextEditingController(text: p?.barcode ?? '');
    _cost = TextEditingController(
        text: p == null ? '' : Money.centsToEditText(p.costCents));
    _price = TextEditingController(
        text: p == null ? '' : Money.centsToEditText(p.priceCents));
    _stock = TextEditingController(text: p?.stockQty.toString() ?? '0');
    _threshold =
        TextEditingController(text: p?.lowStockThreshold.toString() ?? '5');
    _categoryId = p?.categoryId;
    _active = p?.active ?? true;
    _photoPath = p?.photoPath;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCategories());
  }

  Future<void> _loadCategories() async {
    final cats = await context.read<AppState>().products.getCategories();
    if (mounted) setState(() => _categories = cats);
  }

  @override
  void dispose() {
    for (final c in [_name, _barcode, _cost, _price, _stock, _threshold]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _addCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: 'Category name', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Add')),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    final category =
        await context.read<AppState>().products.ensureCategory(name);
    await _loadCategories();
    if (mounted) setState(() => _categoryId = category.id);
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
    );
    if (code != null && mounted) {
      setState(() => _barcode.text = code);
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (file != null && mounted) {
      setState(() => _photoPath = file.path);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final appState = context.read<AppState>();
    final product = Product(
      id: widget.product?.id,
      name: _name.text.trim(),
      categoryId: _categoryId,
      barcode: _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
      costCents: Money.tryParseToCents(_cost.text) ?? 0,
      priceCents: Money.tryParseToCents(_price.text) ?? 0,
      stockQty: _isEdit
          ? widget.product!.stockQty // stock changes go through Adjust
          : int.tryParse(_stock.text.trim()) ?? 0,
      lowStockThreshold: int.tryParse(_threshold.text.trim()) ?? 5,
      active: _active,
      photoPath: _photoPath,
      createdAt: widget.product?.createdAt,
    );
    await appState.products.upsertProduct(product);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final productRepo = context.read<AppState>().products;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
            '"${widget.product!.name}" will be removed from the catalogue. Past sales keep their history.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await productRepo.deleteProduct(widget.product!.id!);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit product' : 'Add product'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: InkWell(
                onTap: _pickPhoto,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _photoPath != null && File(_photoPath!).existsSync()
                      ? Image.file(File(_photoPath!), fit: BoxFit.cover)
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined, size: 32),
                            SizedBox(height: 6),
                            Text('Add photo', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                  labelText: 'Product name *', border: OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    initialValue: _categoryId,
                    decoration: const InputDecoration(
                        labelText: 'Category', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem<int?>(
                          value: null, child: Text('Uncategorised')),
                      for (final c in _categories)
                        DropdownMenuItem<int?>(
                            value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: IconButton.filledTonal(
                    tooltip: 'Add new category',
                    icon: const Icon(Icons.add),
                    onPressed: _addCategory,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _barcode,
              decoration: InputDecoration(
                labelText: 'Barcode',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.barcode_reader),
                  tooltip: 'Scan barcode',
                  onPressed: _scanBarcode,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cost,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Cost price',
                        border: OutlineInputBorder()),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      return Money.tryParseToCents(v) == null
                          ? 'Enter a valid amount'
                          : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Sale price *',
                        border: OutlineInputBorder()),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Price is required';
                      }
                      final cents = Money.tryParseToCents(v);
                      if (cents == null) return 'Enter a valid amount';
                      if (cents <= 0) return 'Price must be above zero';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stock,
                    enabled: !_isEdit,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: _isEdit
                          ? 'Stock (use Adjust stock to change)'
                          : 'Opening stock quantity',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (_isEdit) return null;
                      final n = int.tryParse(v?.trim() ?? '');
                      if (n == null || n < 0) return 'Enter 0 or more';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _threshold,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Low stock alert at',
                        border: OutlineInputBorder()),
                    validator: (v) {
                      final n = int.tryParse(v?.trim() ?? '');
                      if (n == null || n < 0) return 'Enter 0 or more';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Active product'),
              subtitle:
                  const Text('Inactive products cannot be sold'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
              child: Text(_isEdit ? 'Save changes' : 'Save product'),
            ),
            if (_isEdit) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final saved = await navigator.push<bool>(
                    MaterialPageRoute(
                        builder: (_) =>
                            StockAdjustScreen(product: widget.product!)),
                  );
                  if (saved == true && mounted) {
                    navigator.pop(true);
                  }
                },
                icon: const Icon(Icons.inventory_outlined),
                label: const Text('Adjust stock'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52)),
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text('Delete product',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
