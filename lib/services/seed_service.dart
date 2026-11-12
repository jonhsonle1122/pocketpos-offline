import '../domain/cart.dart';
import '../data/models.dart';
import '../data/repositories/product_repository.dart';
import '../data/repositories/sale_repository.dart';

/// Demo data for "Explore demo data" on the welcome screen: a small shop
/// ("Mini Mart") with 12 products in 4 categories and backdated sales for
/// today and yesterday, so Reports is alive immediately.
class SeedService {
  final ProductRepository _products;
  final SaleRepository _sales;

  SeedService(this._products, this._sales);

  static const String demoShopName = 'Mini Mart';

  Future<void> seedDemo(AppSettings settings) async {
    final existing = await _products.getProducts();
    if (existing.isNotEmpty) return; // Never seed twice.

    final drinks = await _products.ensureCategory('Drinks');
    final snacks = await _products.ensureCategory('Snacks');
    final accessories = await _products.ensureCategory('Accessories');
    final household = await _products.ensureCategory('Household');

    // name, category, barcode, cost, price, FINAL stock (after demo sales)
    final specs = <(String, int?, String, int, int, int)>[
      ('Organic Cold Brew 12oz', drinks.id, '850011', 260, 450, 24),
      ('Sparkling Lime Soda', drinks.id, '850012', 90, 175, 30),
      ('Orange Juice 1L', drinks.id, '850013', 180, 325, 18),
      ('Sea Salt Kettle Chips', snacks.id, '850014', 110, 225, 40),
      ('Roasted Salted Almonds', snacks.id, '850015', 220, 375, 15),
      ('Dark Chocolate Bar', snacks.id, '850016', 70, 150, 50),
      ('USB-C Fast Cable 1m', accessories.id, '850017', 450, 999, 12),
      ('Heavy Duty Phone Mount', accessories.id, '850018', 390, 799, 3),
      ('Wireless Earphones', accessories.id, '850019', 1100, 1999, 8),
      ('Tempered Glass Screen Protector', accessories.id, '850020', 300, 1250, 0),
      ('AA Batteries 4-Pack', household.id, '850021', 280, 549, 22),
      ('LED Light Bulb 9W', household.id, '850022', 310, 625, 14),
    ];

    // Demo sale plan: (product index, qty) lines per sale.
    final yesterdayPlan = <({List<(int, int)> lines, PaymentMethod method, DiscountType discountType, double discountValue})>[
      (lines: [(0, 2), (3, 1)], method: PaymentMethod.cash, discountType: DiscountType.none, discountValue: 0),
      (lines: [(6, 1), (10, 2)], method: PaymentMethod.card, discountType: DiscountType.percent, discountValue: 10),
      (lines: [(1, 4), (5, 2)], method: PaymentMethod.cash, discountType: DiscountType.none, discountValue: 0),
    ];
    final todayPlan = <({List<(int, int)> lines, PaymentMethod method, DiscountType discountType, double discountValue})>[
      (lines: [(0, 3), (4, 1)], method: PaymentMethod.cash, discountType: DiscountType.none, discountValue: 0),
      (lines: [(6, 2), (3, 3)], method: PaymentMethod.cash, discountType: DiscountType.none, discountValue: 0),
      (lines: [(8, 1), (7, 1)], method: PaymentMethod.card, discountType: DiscountType.none, discountValue: 0),
      (lines: [(1, 2), (3, 2), (2, 1)], method: PaymentMethod.cash, discountType: DiscountType.none, discountValue: 0),
    ];

    // Total sold per product index, so initial stock = final + sold.
    final sold = List<int>.filled(specs.length, 0);
    for (final sale in [...yesterdayPlan, ...todayPlan]) {
      for (final (idx, qty) in sale.lines) {
        sold[idx] += qty;
      }
    }

    final stored = <Product>[];
    for (var i = 0; i < specs.length; i++) {
      final (name, categoryId, barcode, cost, price, finalStock) = specs[i];
      stored.add(await _products.upsertProduct(Product(
        name: name,
        categoryId: categoryId,
        barcode: barcode,
        costCents: cost,
        priceCents: price,
        stockQty: finalStock + sold[i],
        lowStockThreshold: 5,
        active: true,
      )));
    }

    Future<void> recordSale(
      ({List<(int, int)> lines, PaymentMethod method, DiscountType discountType, double discountValue}) plan,
      DateTime at,
    ) async {
      final cart = Cart();
      for (final (idx, qty) in plan.lines) {
        final product = stored[idx];
        // Temporarily ignore the cart stock cap by constructing lines from
        // the stored product (stock includes these demo quantities).
        cart.lines.add(CartLine(product: product, qty: qty));
      }
      cart.setDiscount(plan.discountType, plan.discountValue);
      final totals = cart.totals(
        taxRatePercent: settings.taxRatePercent,
        pricesIncludeTax: settings.pricesIncludeTax,
      );
      await _sales.completeSale(
        lines: cart.lines,
        totals: totals,
        discountType: plan.discountType,
        discountValue: plan.discountValue,
        taxRatePercent: settings.taxRatePercent,
        pricesIncludeTax: settings.pricesIncludeTax,
        paymentMethod: plan.method,
        tenderedCents: plan.method == PaymentMethod.cash
            ? totals.totalCents + 500
            : null,
        createdAt: at,
      );
    }

    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final yesterdayTimes = [
      DateTime(yesterday.year, yesterday.month, yesterday.day, 10, 15),
      DateTime(yesterday.year, yesterday.month, yesterday.day, 13, 40),
      DateTime(yesterday.year, yesterday.month, yesterday.day, 16, 50),
    ];
    for (var i = 0; i < yesterdayPlan.length; i++) {
      await recordSale(yesterdayPlan[i], yesterdayTimes[i]);
    }

    final todayCandidates = [
      DateTime(now.year, now.month, now.day, 9, 5),
      DateTime(now.year, now.month, now.day, 11, 30),
      DateTime(now.year, now.month, now.day, 13, 15),
      DateTime(now.year, now.month, now.day, 15, 45),
    ].where((t) => t.isBefore(now)).toList();
    if (todayCandidates.isEmpty) {
      todayCandidates.add(now.subtract(const Duration(minutes: 10)));
    }
    for (var i = 0; i < todayPlan.length; i++) {
      final at = todayCandidates[i % todayCandidates.length]
          .add(Duration(minutes: i * 7));
      await recordSale(todayPlan[i], at.isAfter(now) ? now : at);
    }
  }
}
