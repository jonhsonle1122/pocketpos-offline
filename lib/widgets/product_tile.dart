import 'dart:io';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../domain/money.dart';
import 'status_chip.dart';

/// Product tile for the Sell grid: photo or initials fallback, name, price,
/// stock badge. Out-of-stock tiles are greyed out and disabled.
class ProductTile extends StatelessWidget {
  final Product product;
  final String currencyCode;
  final VoidCallback? onTap;

  const ProductTile({
    super.key,
    required this.product,
    required this.currencyCode,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = product.isOutOfStock || !product.active;
    final initials = product.name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: disabled ? null : onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: product.photoPath != null &&
                        File(product.photoPath!).existsSync()
                    ? Image.file(File(product.photoPath!), fit: BoxFit.cover)
                    : Container(
                        color: theme.colorScheme.primaryContainer,
                        alignment: Alignment.center,
                        child: Text(
                          initials,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                child: Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      Money.format(product.priceCents, currencyCode),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    StockChip(product: product),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
