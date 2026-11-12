import 'package:flutter_test/flutter_test.dart';
import 'package:pocketpos_offline/data/models.dart';
import 'package:pocketpos_offline/domain/cart.dart';

Product _product(int id, int priceCents, int stock) => Product(
      id: id,
      name: 'Product $id',
      priceCents: priceCents,
      costCents: priceCents ~/ 2,
      stockQty: stock,
      active: true,
    );

void main() {
  group('Cart totals', () {
    test('percent discount + tax added on top (exclusive)', () {
      final cart = Cart();
      cart.add(_product(1, 999, 10));
      cart.setQty(1, 2);
      cart.add(_product(2, 250, 5));
      expect(cart.subtotalCents, 2248);

      cart.setDiscount(DiscountType.percent, 10);
      final totals =
          cart.totals(taxRatePercent: 8.25, pricesIncludeTax: false);
      expect(totals.subtotalCents, 2248);
      expect(totals.discountCents, 225); // 224.8 rounds to 225
      expect(totals.taxCents, 167); // (2248-225) * 8.25% = 166.90 -> 167
      expect(totals.totalCents, 2248 - 225 + 167);
      expect(totals.itemCount, 3);
    });

    test('fixed discount, capped at subtotal', () {
      final cart = Cart();
      cart.add(_product(1, 999, 10));
      cart.setDiscount(DiscountType.fixed, 500);
      var totals = cart.totals(taxRatePercent: 0, pricesIncludeTax: false);
      expect(totals.discountCents, 500);
      expect(totals.totalCents, 499);

      cart.setDiscount(DiscountType.fixed, 99999);
      totals = cart.totals(taxRatePercent: 0, pricesIncludeTax: false);
      expect(totals.discountCents, 999);
      expect(totals.totalCents, 0);
    });

    test('percent discount clamped to 100%', () {
      final cart = Cart();
      cart.add(_product(1, 1000, 10));
      cart.setDiscount(DiscountType.percent, 150);
      final totals = cart.totals(taxRatePercent: 0, pricesIncludeTax: false);
      expect(totals.discountCents, 1000);
      expect(totals.totalCents, 0);
    });

    test('tax included in prices (inclusive mode)', () {
      final cart = Cart();
      cart.add(_product(1, 999, 10));
      cart.setQty(1, 2);
      cart.add(_product(2, 250, 5));
      final totals =
          cart.totals(taxRatePercent: 10, pricesIncludeTax: true);
      expect(totals.subtotalCents, 2248);
      expect(totals.totalCents, 2248); // total does not grow
      // Tax portion inside 2248 at 10%: 2248 - 2248/1.1 = 204.36 -> 204
      expect(totals.taxCents, 204);
    });

    test('inclusive tax with discount applies to discounted base', () {
      final cart = Cart();
      cart.add(_product(1, 1100, 10));
      cart.setDiscount(DiscountType.fixed, 100);
      final totals =
          cart.totals(taxRatePercent: 10, pricesIncludeTax: true);
      expect(totals.totalCents, 1000);
      // 1000 - 1000/1.1 = 90.9 -> 91
      expect(totals.taxCents, 91);
    });

    test('no tax when rate is zero', () {
      final cart = Cart();
      cart.add(_product(1, 500, 10));
      final totals = cart.totals(taxRatePercent: 0, pricesIncludeTax: false);
      expect(totals.taxCents, 0);
      expect(totals.totalCents, 500);
    });
  });

  group('Cart stock rules', () {
    test('cannot add out-of-stock or inactive products', () {
      final cart = Cart();
      expect(cart.add(_product(1, 100, 0)), isFalse);
      final inactive = Product(
          id: 2, name: 'X', priceCents: 100, stockQty: 5, active: false);
      expect(cart.add(inactive), isFalse);
      expect(cart.isEmpty, isTrue);
    });

    test('quantity is capped at available stock', () {
      final cart = Cart();
      final p = _product(1, 100, 3);
      expect(cart.add(p), isTrue);
      expect(cart.add(p), isTrue);
      expect(cart.add(p), isTrue);
      expect(cart.add(p), isFalse); // already at stock limit
      expect(cart.lines.single.qty, 3);
      cart.setQty(1, 99);
      expect(cart.lines.single.qty, 3);
    });

    test('setQty 0 removes the line; clear resets discount', () {
      final cart = Cart();
      cart.add(_product(1, 100, 5));
      cart.setDiscount(DiscountType.percent, 20);
      cart.setQty(1, 0);
      expect(cart.isEmpty, isTrue);
      cart.add(_product(1, 100, 5));
      cart.clear();
      expect(cart.isEmpty, isTrue);
      expect(cart.discountType, DiscountType.none);
    });
  });
}
