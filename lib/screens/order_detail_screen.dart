import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../data/models.dart';
import '../domain/money.dart';
import '../state/app_state.dart';
import '../state/catalog_provider.dart';
import '../widgets/receipt_preview.dart';

/// S8 — Order detail: full money breakdown, receipt preview, reprint,
/// and Void sale (confirm dialog only — restores stock, keeps the audit
/// row, shows a VOIDED banner afterwards).
class OrderDetailScreen extends StatefulWidget {
  final int saleId;
  const OrderDetailScreen({super.key, required this.saleId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Sale? _sale;
  String? _printStatus;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final sale = await context.read<AppState>().sales.getSale(widget.saleId);
    if (mounted) setState(() => _sale = sale);
  }

  Future<void> _reprint() async {
    final sale = _sale;
    if (sale == null) return;
    final appState = context.read<AppState>();
    setState(() => _busy = true);
    final result = await appState.printer.printSale(sale, appState.settings);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _printStatus = result.message;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _void() async {
    final sale = _sale;
    if (sale == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Void sale ${sale.orderNumber}?'),
        content: const Text(
            'The sale will be marked VOIDED and its items returned to stock. '
            'The record is kept for audit. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep sale')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppConfig.dangerColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Void sale'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final updated =
          await context.read<AppState>().sales.voidSale(sale.id!);
      if (!mounted) return;
      setState(() {
        _sale = updated;
        _busy = false;
      });
      context.read<CatalogProvider>().reloadAll();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Sale ${sale.orderNumber} voided — stock restored.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not void: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final settings = appState.settings;
    final cur = settings.currencyCode;
    final sale = _sale;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(sale?.orderNumber ?? 'Order')),
      body: sale == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEE, d MMM yyyy · HH:mm')
                                .format(sale.createdAt),
                            style: theme.textTheme.bodyLarge,
                          ),
                          Text(
                            'Paid by ${sale.paymentMethod.label}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: (sale.status == SaleStatus.voided
                                ? AppConfig.dangerColor
                                : theme.colorScheme.primary)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        sale.status == SaleStatus.voided ? 'VOIDED' : 'PAID',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: sale.status == SaleStatus.voided
                              ? AppConfig.dangerColor
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (sale.status == SaleStatus.voided) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppConfig.dangerColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.block, color: AppConfig.dangerColor),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              'This sale was voided. Its items were returned to stock and it is excluded from reports.'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final item in sale.items)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                      '${item.productName} × ${item.qty}'),
                                ),
                                Text(Money.format(
                                    item.lineTotalCents, cur)),
                              ],
                            ),
                          ),
                        const Divider(height: 20),
                        _moneyLine('Subtotal', sale.subtotalCents, cur),
                        if (sale.discountCents > 0)
                          _moneyLine(
                              'Discount', -sale.discountCents, cur,
                              color: AppConfig.dangerColor),
                        if (sale.taxRatePercent > 0)
                          _moneyLine(
                              sale.pricesIncludeTax
                                  ? 'Tax (included)'
                                  : 'Tax',
                              sale.taxCents,
                              cur),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('TOTAL',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16)),
                            Text(Money.format(sale.totalCents, cur),
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    color: theme.colorScheme.primary)),
                          ],
                        ),
                        if (sale.paymentMethod == PaymentMethod.cash &&
                            sale.tenderedCents != null) ...[
                          const SizedBox(height: 6),
                          _moneyLine(
                              'Cash received', sale.tenderedCents!, cur),
                          _moneyLine('Change', sale.changeCents, cur),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ReceiptPreview(sale: sale, settings: settings),
                if (_printStatus != null) ...[
                  const SizedBox(height: 10),
                  Text(_printStatus!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _busy ? null : _reprint,
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Reprint receipt'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52)),
                ),
                if (sale.status == SaleStatus.completed) ...[
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: _busy ? null : _void,
                    icon: const Icon(Icons.block,
                        color: AppConfig.dangerColor),
                    label: const Text('Void this sale',
                        style: TextStyle(color: AppConfig.dangerColor)),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _moneyLine(String label, int cents, String cur, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            cents < 0
                ? '-${Money.format(-cents, cur)}'
                : Money.format(cents, cur),
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }
}
