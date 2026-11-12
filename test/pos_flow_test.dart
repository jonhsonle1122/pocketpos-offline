import 'package:flutter_test/flutter_test.dart';
import 'package:pocketpos_offline/data/app_database.dart';
import 'package:pocketpos_offline/data/models.dart';
import 'package:pocketpos_offline/data/repositories/product_repository.dart';
import 'package:pocketpos_offline/data/repositories/report_repository.dart';
import 'package:pocketpos_offline/data/repositories/sale_repository.dart';
import 'package:pocketpos_offline/data/repositories/settings_repository.dart';
import 'package:pocketpos_offline/domain/cart.dart';
import 'package:pocketpos_offline/services/backup_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<AppDatabase> createTestDb() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: AppDatabase.schemaVersion,
      onCreate: (db, _) => AppDatabase.createSchema(db),
    ),
  );
  return AppDatabase(db);
}

Future<CartTotals> totalsFor(Cart cart) async =>
    cart.totals(taxRatePercent: 0, pricesIncludeTax: false);

void main() {
  group('Sale completion & void (ffi in-memory DB)', () {
    late AppDatabase database;
    late ProductRepository products;
    late SaleRepository sales;
    late Product widget;

    setUp(() async {
      database = await createTestDb();
      products = ProductRepository(database);
      sales = SaleRepository(database);
      widget = await products.upsertProduct(const Product(
        name: 'Widget',
        costCents: 400,
        priceCents: 1000,
        stockQty: 10,
      ));
    });

    tearDown(() => database.close());

    test('completing a sale decrements stock and writes movements', () async {
      final cart = Cart()..add(widget);
      cart.setQty(widget.id, 3);
      final sale = await sales.completeSale(
        lines: cart.lines,
        totals: await totalsFor(cart),
        discountType: DiscountType.none,
        discountValue: 0,
        taxRatePercent: 0,
        pricesIncludeTax: false,
        paymentMethod: PaymentMethod.cash,
        tenderedCents: 5000,
      );
      expect(sale.totalCents, 3000);
      expect(sale.changeCents, 2000);
      expect(sale.orderNumber, startsWith('#'));

      final after = await products.getById(widget.id!);
      expect(after!.stockQty, 7);

      final movements = await products.getMovements(productId: widget.id);
      expect(movements.length, 1);
      expect(movements.first.delta, -3);
      expect(movements.first.reason, 'Sale');
      expect(movements.first.resultingQty, 7);
    });

    test('voiding a sale restores stock and keeps the audit row', () async {
      final cart = Cart()..add(widget);
      cart.setQty(widget.id, 4);
      final sale = await sales.completeSale(
        lines: cart.lines,
        totals: await totalsFor(cart),
        discountType: DiscountType.none,
        discountValue: 0,
        taxRatePercent: 0,
        pricesIncludeTax: false,
        paymentMethod: PaymentMethod.card,
      );
      expect((await products.getById(widget.id!))!.stockQty, 6);

      final voided = await sales.voidSale(sale.id!);
      expect(voided.status, SaleStatus.voided);
      expect((await products.getById(widget.id!))!.stockQty, 10);

      final stored = await sales.getSale(sale.id!);
      expect(stored!.status, SaleStatus.voided);

      final movements = await products.getMovements(productId: widget.id);
      expect(movements.map((m) => m.reason),
          containsAll(['Sale', 'Void reversal']));

      // Voiding twice is rejected.
      expect(() => sales.voidSale(sale.id!), throwsStateError);
    });

    test('insufficient cash tender is rejected', () async {
      final cart = Cart()..add(widget);
      final totals = await totalsFor(cart);
      expect(
        () => sales.completeSale(
          lines: cart.lines,
          totals: totals,
          discountType: DiscountType.none,
          discountValue: 0,
          taxRatePercent: 0,
          pricesIncludeTax: false,
          paymentMethod: PaymentMethod.cash,
          tenderedCents: 500, // total is 1000
        ),
        throwsArgumentError,
      );
      expect((await products.getById(widget.id!))!.stockQty, 10);
    });

    test('stock adjustment never goes below zero', () async {
      expect(
        () => products.adjustStock(
            productId: widget.id!, delta: -11, reason: 'Damaged'),
        throwsA(isA<StockBelowZeroException>()),
      );
      final qty = await products.adjustStock(
          productId: widget.id!, delta: 5, reason: 'Restock purchase');
      expect(qty, 15);
      final qty2 = await products.adjustStock(
          productId: widget.id!, delta: -15, reason: 'Correction');
      expect(qty2, 0);
    });
  });

  group('Report aggregation for a seeded day', () {
    test('revenue, orders, profit, buckets and top products', () async {
      final database = await createTestDb();
      final products = ProductRepository(database);
      final sales = SaleRepository(database);
      final reports = ReportRepository(database);

      final a = await products.upsertProduct(const Product(
          name: 'Alpha', costCents: 600, priceCents: 1000, stockQty: 100));
      final b = await products.upsertProduct(const Product(
          name: 'Beta', costCents: 200, priceCents: 500, stockQty: 100));

      final today = DateTime.now();
      DateTime at(int hour) =>
          DateTime(today.year, today.month, today.day, hour, 15);

      // Sale 1 at 09:15 — Alpha x2 -> revenue 2000, profit 800.
      var cart = Cart()..add(a);
      cart.setQty(a.id, 2);
      await sales.completeSale(
        lines: cart.lines,
        totals: await totalsFor(cart),
        discountType: DiscountType.none,
        discountValue: 0,
        taxRatePercent: 0,
        pricesIncludeTax: false,
        paymentMethod: PaymentMethod.cash,
        createdAt: at(9),
      );

      // Sale 2 at 11:15 — Beta x3 with 10% discount -> 1500 - 150 = 1350.
      cart = Cart()..add(b);
      cart.setQty(b.id, 3);
      cart.setDiscount(DiscountType.percent, 10);
      await sales.completeSale(
        lines: cart.lines,
        totals: await totalsFor(cart),
        discountType: DiscountType.percent,
        discountValue: 10,
        taxRatePercent: 0,
        pricesIncludeTax: false,
        paymentMethod: PaymentMethod.card,
        createdAt: at(11),
      );

      // Sale 3 — voided, must not count.
      cart = Cart()..add(a);
      final voidedSale = await sales.completeSale(
        lines: cart.lines,
        totals: await totalsFor(cart),
        discountType: DiscountType.none,
        discountValue: 0,
        taxRatePercent: 0,
        pricesIncludeTax: false,
        paymentMethod: PaymentMethod.cash,
        createdAt: at(12),
      );
      await sales.voidSale(voidedSale.id!);

      final start = DateTime(today.year, today.month, today.day);
      final report = await reports.getReport(
          start, start.add(const Duration(days: 1)));

      expect(report.orderCount, 2);
      expect(report.revenueCents, 3350);
      expect(report.avgBasketCents, 1675);
      // Profit: (1000-600)*2 + (500-200)*3 - 150 discount = 800+900-150.
      expect(report.profitCents, 1550);

      final bucket9 = report.buckets.firstWhere((b) => b.label == '9a');
      final bucket11 = report.buckets.firstWhere((b) => b.label == '11a');
      expect(bucket9.revenueCents, 2000);
      expect(bucket11.revenueCents, 1350);

      expect(report.topProducts.first.productName, 'Alpha');
      expect(report.topProducts.first.revenueCents, 2000);

      await database.close();
    });
  });

  group('Backup export -> import roundtrip', () {
    test('data survives export, wipe and re-import identically', () async {
      final db1 = await createTestDb();
      final products1 = ProductRepository(db1);
      final sales1 = SaleRepository(db1);
      final settings1 = SettingsRepository(db1);
      final backup1 = BackupService(db1);

      await settings1.save(const AppSettings(
        shopName: 'Roundtrip Shop',
        currencyCode: 'EUR',
        taxRatePercent: 19,
        setupComplete: true,
      ));
      final cat = await products1.ensureCategory('Drinks');
      final p = await products1.upsertProduct(Product(
        name: 'Cola',
        categoryId: cat.id,
        barcode: '12345',
        costCents: 50,
        priceCents: 150,
        stockQty: 20,
      ));
      final cart = Cart()..add(p);
      cart.setQty(p.id, 2);
      await sales1.completeSale(
        lines: cart.lines,
        totals: await totalsFor(cart),
        discountType: DiscountType.none,
        discountValue: 0,
        taxRatePercent: 0,
        pricesIncludeTax: false,
        paymentMethod: PaymentMethod.cash,
        tenderedCents: 500,
      );
      await products1.adjustStock(
          productId: p.id!, delta: 5, reason: 'Restock purchase');

      final exported = await backup1.exportData();
      final json = await backup1.exportJson();

      // Import into a fresh, empty database (the "wipe").
      final db2 = await createTestDb();
      final backup2 = BackupService(db2);
      await backup2.importJson(json);
      final reExported = await backup2.exportData();

      Map<String, dynamic> normalize(Map<String, dynamic> data) {
        final copy = Map<String, dynamic>.from(data)..remove('exportedAt');
        for (final key in [
          'categories',
          'products',
          'sales',
          'saleItems',
          'stockMovements'
        ]) {
          final rows = (copy[key] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          rows.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
          copy[key] = rows;
        }
        return copy;
      }

      expect(normalize(reExported), normalize(exported));

      // Spot-check the restored state through the repositories.
      final products2 = ProductRepository(db2);
      final restored = await products2.getByBarcode('12345');
      expect(restored, isNotNull);
      expect(restored!.stockQty, 23); // 20 - 2 sold + 5 restocked
      final settings2 = SettingsRepository(db2);
      final restoredSettings = await settings2.load();
      expect(restoredSettings.shopName, 'Roundtrip Shop');
      expect(restoredSettings.currencyCode, 'EUR');

      // Invalid payloads are rejected with a FormatException.
      expect(() => BackupService.decodeAndValidate('{"version": 99}'),
          throwsFormatException);
      expect(() => BackupService.decodeAndValidate('not json'),
          throwsFormatException);

      await db1.close();
      await db2.close();
    });
  });
}
