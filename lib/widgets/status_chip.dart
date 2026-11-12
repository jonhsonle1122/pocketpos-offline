import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../data/models.dart';

/// Small pill chip used for stock and payment statuses.
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusChip({super.key, required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Stock status chip for a product: Out of stock / Low stock (n) / In stock (n).
class StockChip extends StatelessWidget {
  final Product product;
  const StockChip({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    if (product.isOutOfStock) {
      return const StatusChip(label: 'Out of stock', color: AppConfig.dangerColor);
    }
    if (product.isLowStock) {
      return StatusChip(
          label: 'Low stock (${product.stockQty})', color: AppConfig.accentColor);
    }
    return StatusChip(
        label: 'In stock (${product.stockQty})',
        color: Theme.of(context).colorScheme.primary);
  }
}
