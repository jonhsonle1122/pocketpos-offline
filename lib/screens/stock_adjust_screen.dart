import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../data/models.dart';
import '../data/repositories/product_repository.dart';
import '../state/app_state.dart';

/// S6 — Stock adjustment: product summary, current stock, in/out toggle,
/// quantity stepper, reason chips, optional note, resulting-stock preview.
/// Stock can never go below zero (enforced here and in the repository).
class StockAdjustScreen extends StatefulWidget {
  final Product product;
  const StockAdjustScreen({super.key, required this.product});

  @override
  State<StockAdjustScreen> createState() => _StockAdjustScreenState();
}

class _StockAdjustScreenState extends State<StockAdjustScreen> {
  bool _stockIn = true;
  int _qty = 1;
  String _reason = kStockReasons.first;
  final _noteController = TextEditingController();
  late int _currentQty;
  List<StockMovement> _history = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _currentQty = widget.product.stockQty;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    final fresh = await appState.products.getById(widget.product.id!);
    final history =
        await appState.products.getMovements(productId: widget.product.id);
    if (mounted) {
      setState(() {
        if (fresh != null) _currentQty = fresh.stockQty;
        _history = history;
      });
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  int get _resultingQty => _currentQty + (_stockIn ? _qty : -_qty);
  bool get _belowZero => _resultingQty < 0;

  Future<void> _save() async {
    if (_qty <= 0 || _belowZero) return;
    setState(() => _saving = true);
    try {
      await context.read<AppState>().products.adjustStock(
            productId: widget.product.id!,
            delta: _stockIn ? _qty : -_qty,
            reason: _reason,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on StockBelowZeroException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Stock adjustment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.product.name,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        if (widget.product.barcode != null)
                          Text('Barcode ${widget.product.barcode}',
                              style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Current stock',
                          style: theme.textTheme.bodySmall),
                      Text('$_currentQty',
                          style: theme.textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                  value: true,
                  icon: Icon(Icons.add_box_outlined),
                  label: Text('Stock in')),
              ButtonSegment(
                  value: false,
                  icon: Icon(Icons.indeterminate_check_box_outlined),
                  label: Text('Stock out')),
            ],
            selected: {_stockIn},
            onSelectionChanged: (s) => setState(() => _stockIn = s.first),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                icon: const Icon(Icons.remove),
                iconSize: 28,
                onPressed:
                    _qty > 1 ? () => setState(() => _qty--) : null,
              ),
              SizedBox(
                width: 110,
                child: TextFormField(
                  key: ValueKey(_qty),
                  initialValue: _qty.toString(),
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                  decoration: const InputDecoration(border: InputBorder.none),
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n >= 0) setState(() => _qty = n);
                  },
                ),
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.add),
                iconSize: 28,
                onPressed: () => setState(() => _qty++),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Reason',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final reason in kStockReasons)
                ChoiceChip(
                  label: Text(reason),
                  selected: _reason == reason,
                  onSelected: (_) => setState(() => _reason = reason),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              hintText: 'e.g. Supplier invoice #221',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _belowZero
                  ? AppConfig.dangerColor.withValues(alpha: 0.1)
                  : theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('New stock after adjustment',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Text('$_resultingQty units',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          if (_belowZero) ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.warning_amber,
                    size: 18, color: AppConfig.dangerColor),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Stock cannot go below zero. Reduce the quantity or switch to Stock in.',
                    style: TextStyle(color: AppConfig.dangerColor),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: (_saving || _qty <= 0 || _belowZero) ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
            child: const Text('Save adjustment'),
          ),
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text('Recent movements',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final m in _history.take(10))
              ListTile(
                dense: true,
                leading: Icon(
                  m.delta >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  color: m.delta >= 0
                      ? theme.colorScheme.primary
                      : AppConfig.dangerColor,
                ),
                title: Text(
                    '${m.delta >= 0 ? '+' : ''}${m.delta} · ${m.reason}'),
                subtitle: Text(
                    '${m.createdAt.day}/${m.createdAt.month} ${m.createdAt.hour.toString().padLeft(2, '0')}:${m.createdAt.minute.toString().padLeft(2, '0')} · stock after: ${m.resultingQty}${m.note != null ? ' · ${m.note}' : ''}'),
              ),
          ],
        ],
      ),
    );
  }
}
