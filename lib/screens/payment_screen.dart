import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../data/models.dart';
import '../domain/money.dart';
import '../state/app_state.dart';
import '../state/cart_provider.dart';
import '../state/catalog_provider.dart';
import '../widgets/money_rows.dart';
import 'payment_success_screen.dart';

/// S2 — Payment. Total due (huge), tender type cards, cash keypad + quick
/// chips, change due with denomination breakdown, insufficient-tender
/// block. Confirming persists the sale and decrements stock atomically.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  PaymentMethod _method = PaymentMethod.cash;
  String _tenderedText = ''; // digits being typed, in major units
  bool _processing = false;

  int get _tenderedCents {
    if (_tenderedText.isEmpty) return 0;
    return Money.tryParseToCents(_tenderedText) ?? 0;
  }

  void _pressKey(String key, int totalCents) {
    setState(() {
      if (key == 'C') {
        _tenderedText = '';
      } else if (key == '⌫') {
        if (_tenderedText.isNotEmpty) {
          _tenderedText = _tenderedText.substring(0, _tenderedText.length - 1);
        }
      } else if (key == '.') {
        if (!_tenderedText.contains('.')) {
          _tenderedText = _tenderedText.isEmpty ? '0.' : '$_tenderedText.';
        }
      } else {
        // Cap total length and prevent absurd values.
        if (_tenderedText.replaceAll('.', '').length >= 9) return;
        if (_tenderedText.contains('.')) {
          final decimals = _tenderedText.split('.')[1];
          if (decimals.length >= 2) return;
        }
        _tenderedText += key;
      }
    });
  }

  Future<void> _confirm() async {
    final appState = context.read<AppState>();
    final cart = context.read<CartProvider>();
    final settings = appState.settings;
    final totals = cart.totals(settings);
    setState(() => _processing = true);
    try {
      final sale = await appState.sales.completeSale(
        lines: List.of(cart.lines),
        totals: totals,
        discountType: cart.cart.discountType,
        discountValue: cart.cart.discountValue,
        taxRatePercent: settings.taxRatePercent,
        pricesIncludeTax: settings.pricesIncludeTax,
        paymentMethod: _method,
        tenderedCents: _method == PaymentMethod.cash ? _tenderedCents : null,
      );
      cart.clear();
      if (!mounted) return;
      context.read<CatalogProvider>().reloadAll();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PaymentSuccessScreen(sale: sale)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not complete the sale: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final cart = context.watch<CartProvider>();
    final settings = appState.settings;
    final totals = cart.totals(settings);
    final cur = settings.currencyCode;
    final theme = Theme.of(context);

    final tendered = _tenderedCents;
    final change = tendered - totals.totalCents;
    final insufficient = _method == PaymentMethod.cash && change < 0;
    final breakdown = !insufficient && change > 0
        ? Money.changeBreakdown(change, cur)
        : const <int, int>{};

    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text('TOTAL AMOUNT DUE',
                          style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              letterSpacing: 1.2)),
                      const SizedBox(height: 4),
                      Text(
                        Money.format(totals.totalCents, cur),
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      MoneyRows(
                        totals: totals,
                        currencyCode: cur,
                        taxRatePercent: settings.taxRatePercent,
                        pricesIncludeTax: settings.pricesIncludeTax,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Payment method',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final method in PaymentMethod.values)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            right: method == PaymentMethod.other ? 0 : 8),
                        child: _MethodCard(
                          method: method,
                          selected: _method == method,
                          onTap: () => setState(() {
                            _method = method;
                            if (method != PaymentMethod.cash) {
                              _tenderedText = '';
                            }
                          }),
                        ),
                      ),
                    ),
                ],
              ),
              if (_method == PaymentMethod.cash) ...[
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Cash received',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      _tenderedText.isEmpty
                          ? Money.format(0, cur)
                          : Money.format(tendered, cur),
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('Exact'),
                      onPressed: () => setState(() => _tenderedText =
                          Money.centsToEditText(totals.totalCents)),
                    ),
                    for (final chip in _quickChips(totals.totalCents, cur))
                      ActionChip(
                        label: Text(Money.format(chip, cur)),
                        onPressed: () => setState(
                            () => _tenderedText = Money.centsToEditText(chip)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _Keypad(onKey: (k) => _pressKey(k, totals.totalCents)),
                const SizedBox(height: 16),
                if (insufficient)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppConfig.dangerColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppConfig.dangerColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber,
                            color: AppConfig.dangerColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Still due: ${Money.format(-change, cur)} — add more cash to complete the sale.',
                            style: const TextStyle(
                                color: AppConfig.dangerColor,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (change > 0)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppConfig.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('CHANGE DUE',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1)),
                            Text(Money.format(change, cur),
                                style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                        if (breakdown.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Dispense: ${breakdown.entries.map((e) => '${e.value}× ${Money.formatDenomination(e.key, cur)}').join(', ')}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ],
                    ),
                  ),
              ] else ...[
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _method == PaymentMethod.card
                          ? 'Take the card payment on your external terminal, then confirm. The sale is recorded as paid by card.'
                          : 'Record this sale as paid by another method (bank transfer, wallet, etc.).',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _processing || insufficient || cart.isEmpty
                    ? null
                    : _confirm,
                icon: _processing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.print_outlined),
                label: Text(_method == PaymentMethod.cash && _tenderedText.isEmpty
                    ? 'Enter cash received'
                    : 'Confirm payment & print'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 56),
                  textStyle: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed:
                    _processing ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel payment & return to cart'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sensible quick-tender chips: the total rounded up to the next
  /// bill denominations (e.g. total $22.88 → $25, $40, $50).
  List<int> _quickChips(int totalCents, String currencyCode) {
    final denominations = currencyByCode(currencyCode)
        .denominations
        .where((d) => d >= 500)
        .toList()
      ..sort();
    final values = <int>{};
    for (final d in denominations) {
      final rounded = ((totalCents + d - 1) ~/ d) * d;
      if (rounded > totalCents) values.add(rounded);
    }
    final sorted = values.toList()..sort();
    return sorted.take(3).toList();
  }
}

class _MethodCard extends StatelessWidget {
  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  const _MethodCard(
      {required this.method, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = switch (method) {
      PaymentMethod.cash => Icons.payments_outlined,
      PaymentMethod.card => Icons.credit_card_outlined,
      PaymentMethod.other => Icons.more_horiz,
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          color: selected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
              : null,
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 28,
                color: selected ? theme.colorScheme.primary : null),
            const SizedBox(height: 6),
            Text(method.label,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? theme.colorScheme.primary : null)),
          ],
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  final void Function(String key) onKey;
  const _Keypad({required this.onKey});

  @override
  Widget build(BuildContext context) {
    const keys = [
      '1', '2', '3',
      '4', '5', '6',
      '7', '8', '9',
      'C', '0', '⌫',
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: keys.length + 1,
      itemBuilder: (context, index) {
        if (index == keys.length) {
          return _KeyButton(label: '.', onTap: () => onKey('.'));
        }
        final key = keys[index];
        return _KeyButton(
          label: key,
          isDanger: key == 'C',
          onTap: () => onKey(key),
        );
      },
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String label;
  final bool isDanger;
  final VoidCallback onTap;

  const _KeyButton(
      {required this.label, required this.onTap, this.isDanger = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: isDanger
          ? AppConfig.dangerColor.withValues(alpha: 0.1)
          : theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: isDanger ? AppConfig.dangerColor : null,
            ),
          ),
        ),
      ),
    );
  }
}
