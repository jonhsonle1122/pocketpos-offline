import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../state/app_state.dart';

/// S12 — First-run setup. Headline "Sell without internet", a 3-step
/// checklist, inline shop name / currency / tax fields, and the choice:
/// Start selling (empty catalogue) or Explore demo data (seeded shop).
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _shopName = TextEditingController();
  final _taxRate = TextEditingController(text: '0');
  String _currency = AppConfig.defaultCurrencyCode;
  bool _busy = false;

  @override
  void dispose() {
    _shopName.dispose();
    _taxRate.dispose();
    super.dispose();
  }

  Future<void> _start({required bool withDemo}) async {
    setState(() => _busy = true);
    final rate = double.tryParse(_taxRate.text.trim()) ?? 0;
    await context.read<AppState>().completeSetup(
          shopName: _shopName.text,
          currencyCode: _currency,
          taxRatePercent: rate.clamp(0, 100).toDouble(),
          withDemoData: withDemo,
        );
    // AppRoot rebuilds into the home shell when setupComplete flips.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Icon(Icons.point_of_sale,
                  size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                AppConfig.tagline,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'No servers, no accounts, no monthly fees. '
                'Set up your shop in about two minutes.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _TrustItem(icon: Icons.cloud_off_outlined, label: 'Works offline'),
                  _TrustItem(icon: Icons.print_outlined, label: 'Prints receipts'),
                  _TrustItem(icon: Icons.inventory_2_outlined, label: 'Tracks stock'),
                ],
              ),
              const SizedBox(height: 28),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StepRow(number: 1, title: 'Shop info', active: true),
                      _StepRow(number: 2, title: 'Currency & tax', active: true),
                      _StepRow(
                          number: 3,
                          title: 'Add your first product',
                          active: false,
                          last: true),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _shopName,
                        decoration: const InputDecoration(
                          labelText: 'Shop name',
                          hintText: 'e.g. Mini Mart',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _currency,
                              decoration: const InputDecoration(
                                  labelText: 'Currency',
                                  border: OutlineInputBorder()),
                              items: [
                                for (final c in kCurrencies)
                                  DropdownMenuItem(
                                      value: c.code,
                                      child: Text('${c.code} (${c.symbol})')),
                              ],
                              onChanged: (v) =>
                                  setState(() => _currency = v ?? _currency),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _taxRate,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Tax rate (%)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : () => _start(withDemo: false),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Start selling',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : () => _start(withDemo: true),
                child: const Text('Explore with demo data'),
              ),
              const SizedBox(height: 8),
              Text(
                'Demo data loads a sample shop (Mini Mart) with products and '
                'sales, so you can see reports right away.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final int number;
  final String title;
  final bool active;
  final bool last;

  const _StepRow(
      {required this.number,
      required this.title,
      required this.active,
      this.last = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 8 : 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: active
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest,
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: active
                      ? null
                      : theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TrustItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 26),
        const SizedBox(height: 6),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
