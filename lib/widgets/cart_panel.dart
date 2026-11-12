import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../data/models.dart';
import '../domain/money.dart';
import '../state/app_state.dart';
import '../state/cart_provider.dart';
import 'money_rows.dart';

/// The cart panel: line items with quantity steppers, discount editor,
/// money summary, Hold and Charge actions. Used full-height on wide
/// layouts and inside a bottom sheet on phones.
class CartPanel extends StatelessWidget {
  final VoidCallback onCharge;

  const CartPanel({super.key, required this.onCharge});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final cart = context.watch<CartProvider>();
    final settings = appState.settings;
    final totals = cart.totals(settings);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Current sale',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            if (cart.hasHeldSale)
              TextButton.icon(
                onPressed: () {
                  final ok = cart.resumeHeld();
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Finish or clear the current sale before resuming the held one.')));
                  }
                },
                icon: const Icon(Icons.pause_circle_outline, size: 18),
                label: Text('Resume held (${cart.heldItemCount})'),
              ),
            if (!cart.isEmpty)
              IconButton(
                tooltip: 'Clear sale',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Clear current sale?'),
                      content: const Text(
                          'All items in this sale will be removed.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Keep')),
                        FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Clear')),
                      ],
                    ),
                  );
                  if (confirmed == true) cart.clear();
                },
              ),
          ],
        ),
        const Divider(height: 8),
        Expanded(
          child: cart.isEmpty
              ? Center(
                  child: Text(
                    'Cart is empty.\nTap a product or scan a barcode to start a sale.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                )
              : ListView.separated(
                  itemCount: cart.lines.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final line = cart.lines[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(line.product.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                                Text(
                                  Money.format(line.product.priceCents,
                                      settings.currencyCode),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () =>
                                cart.setQty(line.product.id, line.qty - 1),
                          ),
                          SizedBox(
                            width: 28,
                            child: Text('${line.qty}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 16)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () {
                              cart.setQty(line.product.id, line.qty + 1);
                            },
                          ),
                          SizedBox(
                            width: 76,
                            child: Text(
                              Money.format(
                                  line.lineTotalCents, settings.currencyCode),
                              textAlign: TextAlign.right,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        const Divider(height: 8),
        _DiscountEditor(cart: cart, currencyCode: settings.currencyCode),
        const SizedBox(height: 4),
        MoneyRows(
          totals: totals,
          currencyCode: settings.currencyCode,
          taxRatePercent: settings.taxRatePercent,
          pricesIncludeTax: settings.pricesIncludeTax,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: cart.isEmpty
                    ? null
                    : () {
                        final ok = cart.hold();
                        if (!ok) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'Another sale is already on hold. Resume it first.')));
                        }
                      },
                icon: const Icon(Icons.pause),
                label: const Text('Hold sale'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: cart.isEmpty ? null : onCharge,
                icon: const Icon(Icons.payments),
                label: Text(
                    'Charge ${Money.format(totals.totalCents, settings.currencyCode)}'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    textStyle: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DiscountEditor extends StatelessWidget {
  final CartProvider cart;
  final String currencyCode;
  const _DiscountEditor({required this.cart, required this.currencyCode});

  @override
  Widget build(BuildContext context) {
    final current = cart.cart;
    return Row(
      children: [
        const Icon(Icons.local_offer_outlined, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            current.discountType == DiscountType.none
                ? 'No discount'
                : current.discountType == DiscountType.percent
                    ? 'Discount ${current.discountValue.toStringAsFixed(current.discountValue % 1 == 0 ? 0 : 2)}%'
                    : 'Discount ${Money.format(current.discountValue.round(), currencyCode)}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        TextButton(
          onPressed: () => _editDiscount(context),
          child: Text(current.discountType == DiscountType.none
              ? 'Add discount'
              : 'Edit'),
        ),
        if (current.discountType != DiscountType.none)
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Remove discount',
            onPressed: () => cart.setDiscount(DiscountType.none, 0),
          ),
      ],
    );
  }

  Future<void> _editDiscount(BuildContext context) async {
    var type = cart.cart.discountType == DiscountType.none
        ? DiscountType.percent
        : cart.cart.discountType;
    final controller = TextEditingController(
      text: cart.cart.discountType == DiscountType.none
          ? ''
          : cart.cart.discountType == DiscountType.fixed
              ? Money.centsToEditText(cart.cart.discountValue.round())
              : cart.cart.discountValue.toString(),
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Sale discount'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<DiscountType>(
                segments: const [
                  ButtonSegment(
                      value: DiscountType.percent, label: Text('Percent %')),
                  ButtonSegment(
                      value: DiscountType.fixed, label: Text('Fixed amount')),
                ],
                selected: {type},
                onSelectionChanged: (s) => setState(() => type = s.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  labelText:
                      type == DiscountType.percent ? 'Percent' : 'Amount',
                  suffixText: type == DiscountType.percent
                      ? '%'
                      : currencyCode,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Apply')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final raw = double.tryParse(controller.text.trim());
    if (raw == null || raw < 0) return;
    if (type == DiscountType.percent) {
      cart.setDiscount(DiscountType.percent, raw.clamp(0, 100));
    } else {
      cart.setDiscount(DiscountType.fixed, raw * 100);
    }
  }
}

/// Amber/cash colour helper kept in one place for callers that colour
/// totals outside [MoneyRows].
const Color kMoneyAccent = AppConfig.accentColor;
