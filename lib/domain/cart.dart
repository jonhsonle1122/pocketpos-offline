import '../data/models.dart';

/// One line of the cart: a product plus quantity.
class CartLine {
  final Product product;
  int qty;

  CartLine({required this.product, this.qty = 1});

  int get lineTotalCents => product.priceCents * qty;

  CartLine copy() => CartLine(product: product, qty: qty);
}

/// The money result of a cart, all in integer cents.
class CartTotals {
  final int subtotalCents;
  final int discountCents;
  final int taxCents;
  final int totalCents;
  final int itemCount;

  const CartTotals({
    required this.subtotalCents,
    required this.discountCents,
    required this.taxCents,
    required this.totalCents,
    required this.itemCount,
  });

  static const zero = CartTotals(
    subtotalCents: 0,
    discountCents: 0,
    taxCents: 0,
    totalCents: 0,
    itemCount: 0,
  );

  @override
  bool operator ==(Object other) =>
      other is CartTotals &&
      other.subtotalCents == subtotalCents &&
      other.discountCents == discountCents &&
      other.taxCents == taxCents &&
      other.totalCents == totalCents &&
      other.itemCount == itemCount;

  @override
  int get hashCode =>
      Object.hash(subtotalCents, discountCents, taxCents, totalCents, itemCount);
}

/// Pure cart state + totals math (no Flutter, no DB — fully unit-testable).
///
/// Stock rule: a line can never exceed the product's available stock, and an
/// out-of-stock product cannot be added. Sales therefore never drive stock
/// negative from the Sell screen.
class Cart {
  final List<CartLine> lines = [];
  DiscountType discountType = DiscountType.none;

  /// Percent value (e.g. 10 = 10%) when [discountType] is percent, or a
  /// fixed amount in cents when it is fixed.
  double discountValue = 0;

  bool get isEmpty => lines.isEmpty;

  CartLine? lineFor(int? productId) {
    for (final line in lines) {
      if (line.product.id == productId) return line;
    }
    return null;
  }

  /// Adds [qty] of [product]. Returns false when nothing could be added
  /// (out of stock, inactive, or already at the stock limit).
  bool add(Product product, [int qty = 1]) {
    if (!product.active || product.stockQty <= 0) return false;
    final existing = lineFor(product.id);
    if (existing != null) {
      final room = product.stockQty - existing.qty;
      if (room <= 0) return false;
      existing.qty += qty.clamp(1, room);
      // Refresh snapshot so price edits mid-sale apply consistently.
      final idx = lines.indexOf(existing);
      lines[idx] = CartLine(product: product, qty: existing.qty);
      return true;
    }
    lines.add(CartLine(product: product, qty: qty.clamp(1, product.stockQty)));
    return true;
  }

  /// Sets the quantity of a line, clamped to [1, available stock].
  /// A qty of 0 removes the line.
  void setQty(int? productId, int qty) {
    final line = lineFor(productId);
    if (line == null) return;
    if (qty <= 0) {
      lines.remove(line);
      return;
    }
    line.qty = qty.clamp(1, line.product.stockQty < 1 ? 1 : line.product.stockQty);
  }

  void removeLine(int? productId) =>
      lines.removeWhere((l) => l.product.id == productId);

  void clear() {
    lines.clear();
    discountType = DiscountType.none;
    discountValue = 0;
  }

  void setDiscount(DiscountType type, double value) {
    discountType = type;
    discountValue = value < 0 ? 0 : value;
  }

  Cart copy() {
    final c = Cart();
    c.lines.addAll(lines.map((l) => l.copy()));
    c.discountType = discountType;
    c.discountValue = discountValue;
    return c;
  }

  int get subtotalCents =>
      lines.fold(0, (sum, l) => sum + l.lineTotalCents);

  int get itemCount => lines.fold(0, (sum, l) => sum + l.qty);

  int get discountCents {
    final subtotal = subtotalCents;
    return switch (discountType) {
      DiscountType.none => 0,
      DiscountType.percent =>
        (subtotal * (discountValue.clamp(0, 100) / 100)).round(),
      DiscountType.fixed =>
        discountValue.round().clamp(0, subtotal),
    };
  }

  /// Full totals for the current cart contents.
  ///
  /// Tax modes:
  /// - exclusive ([pricesIncludeTax] = false): tax is added on top of the
  ///   discounted subtotal.
  /// - inclusive: the discounted subtotal already contains the tax; the
  ///   [CartTotals.taxCents] reports the tax portion inside the total.
  CartTotals totals({
    required double taxRatePercent,
    required bool pricesIncludeTax,
  }) {
    final subtotal = subtotalCents;
    final discount = discountCents;
    final base = subtotal - discount;
    final rate = taxRatePercent < 0 ? 0.0 : taxRatePercent;
    final int tax;
    final int total;
    if (pricesIncludeTax) {
      total = base;
      tax = rate == 0 ? 0 : (base - base / (1 + rate / 100)).round();
    } else {
      tax = (base * rate / 100).round();
      total = base + tax;
    }
    return CartTotals(
      subtotalCents: subtotal,
      discountCents: discount,
      taxCents: tax,
      totalCents: total,
      itemCount: itemCount,
    );
  }
}
