import 'package:flutter/material.dart';

import '../data/models.dart';
import '../services/receipt_builder.dart';

/// Thermal-paper styled receipt preview card (monospaced lines), used on
/// the payment-success screen and the order detail screen.
class ReceiptPreview extends StatelessWidget {
  final Sale sale;
  final AppSettings settings;

  const ReceiptPreview({super.key, required this.sale, required this.settings});

  @override
  Widget build(BuildContext context) {
    final lines = ReceiptBuilder.buildTextLines(sale, settings);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: SelectableText(
        lines.join('\n'),
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12.5,
          height: 1.45,
          color: Colors.black87,
        ),
      ),
    );
  }
}
