import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../domain/money.dart';
import '../state/app_state.dart';
import '../widgets/receipt_preview.dart';

/// S3 — Payment success / receipt. Shows the receipt preview, printer
/// status, auto-prints when enabled and a printer is connected, and
/// offers Reprint / New sale. Without a printer it clearly falls back
/// to the preview ("continue without printing" is the default state).
class PaymentSuccessScreen extends StatefulWidget {
  final Sale sale;
  const PaymentSuccessScreen({super.key, required this.sale});

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  String? _printStatus;
  bool _printing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoPrint());
  }

  Future<void> _maybeAutoPrint() async {
    final appState = context.read<AppState>();
    if (!appState.settings.autoPrint) return;
    if (!appState.printer.hasSavedPrinter) return;
    await _print();
  }

  Future<void> _print() async {
    final appState = context.read<AppState>();
    setState(() {
      _printing = true;
      _printStatus = null;
    });
    final result =
        await appState.printer.printSale(widget.sale, appState.settings);
    if (!mounted) return;
    setState(() {
      _printing = false;
      _printStatus = result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final settings = appState.settings;
    final theme = Theme.of(context);
    final printerName = settings.savedPrinterName;
    final hasPrinter = appState.printer.hasSavedPrinter;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment complete'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Icon(Icons.check_circle,
                  size: 72, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                'Payment complete',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.sale.orderNumber} · ${Money.format(widget.sale.totalCents, settings.currencyCode)}'
                '${widget.sale.paymentMethod == PaymentMethod.cash && widget.sale.changeCents > 0 ? ' · Change ${Money.format(widget.sale.changeCents, settings.currencyCode)}' : ''}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              ReceiptPreview(sale: widget.sale, settings: settings),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: hasPrinter
                      ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                      : Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasPrinter ? Icons.print : Icons.print_disabled_outlined,
                      color: hasPrinter
                          ? theme.colorScheme.primary
                          : Colors.amber.shade800,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _printStatus ??
                            (hasPrinter
                                ? 'Printer: $printerName (${settings.paperMm}mm)'
                                : 'No printer connected — showing the receipt preview. Connect one in Settings → Printer to print.'),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    if (_printing)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _printing ? null : _print,
                      icon: const Icon(Icons.replay),
                      label: const Text('Reprint'),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 52)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('New sale'),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 52)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
