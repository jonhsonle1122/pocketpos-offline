import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../domain/cart.dart';
import '../domain/money.dart';

/// The shared money summary block: Subtotal / Discount / Tax / Total.
class MoneyRows extends StatelessWidget {
  final CartTotals totals;
  final String currencyCode;
  final double taxRatePercent;
  final bool pricesIncludeTax;

  const MoneyRows({
    super.key,
    required this.totals,
    required this.currencyCode,
    required this.taxRatePercent,
    required this.pricesIncludeTax,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget row(String label, String value, {bool bold = false, Color? color}) {
      final style = (bold ? theme.textTheme.titleMedium : theme.textTheme.bodyLarge)
          ?.copyWith(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: color);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: style),
            Text(value, style: style),
          ],
        ),
      );
    }

    final rateLabel = taxRatePercent == taxRatePercent.roundToDouble()
        ? taxRatePercent.toInt().toString()
        : taxRatePercent.toStringAsFixed(2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row('Subtotal', Money.format(totals.subtotalCents, currencyCode)),
        if (totals.discountCents > 0)
          row('Discount', '-${Money.format(totals.discountCents, currencyCode)}',
              color: AppConfig.dangerColor),
        if (taxRatePercent > 0)
          row(
            pricesIncludeTax ? 'Tax (incl. $rateLabel%)' : 'Tax ($rateLabel%)',
            Money.format(totals.taxCents, currencyCode),
          ),
        const Divider(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('TOTAL',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            Text(
              Money.format(totals.totalCents, currencyCode),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
