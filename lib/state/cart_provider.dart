import 'package:flutter/foundation.dart';

import '../data/models.dart';
import '../domain/cart.dart';

/// ChangeNotifier wrapper around the pure [Cart] domain object, plus the
/// single held (parked) sale.
class CartProvider extends ChangeNotifier {
  Cart _cart = Cart();
  Cart? _heldCart;

  Cart get cart => _cart;
  List<CartLine> get lines => _cart.lines;
  bool get isEmpty => _cart.isEmpty;
  bool get hasHeldSale => _heldCart != null;
  int get heldItemCount => _heldCart?.itemCount ?? 0;

  bool add(Product product) {
    final ok = _cart.add(product);
    if (ok) notifyListeners();
    return ok;
  }

  void setQty(int? productId, int qty) {
    _cart.setQty(productId, qty);
    notifyListeners();
  }

  void removeLine(int? productId) {
    _cart.removeLine(productId);
    notifyListeners();
  }

  void setDiscount(DiscountType type, double value) {
    _cart.setDiscount(type, value);
    notifyListeners();
  }

  void clear() {
    _cart.clear();
    notifyListeners();
  }

  /// Parks the current cart. Returns false when a sale is already held or
  /// the cart is empty.
  bool hold() {
    if (_heldCart != null || _cart.isEmpty) return false;
    _heldCart = _cart;
    _cart = Cart();
    notifyListeners();
    return true;
  }

  /// Brings the held sale back. Returns false when nothing is held or the
  /// current cart is not empty (the cashier must finish/clear it first).
  bool resumeHeld() {
    if (_heldCart == null || !_cart.isEmpty) return false;
    _cart = _heldCart!;
    _heldCart = null;
    notifyListeners();
    return true;
  }

  void discardHeld() {
    _heldCart = null;
    notifyListeners();
  }

  CartTotals totals(AppSettings settings) => _cart.totals(
        taxRatePercent: settings.taxRatePercent,
        pricesIncludeTax: settings.pricesIncludeTax,
      );
}
