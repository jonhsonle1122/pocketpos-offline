import 'package:sqflite/sqflite.dart';

import '../../domain/cart.dart';
import '../app_database.dart';
import '../models.dart';

class SaleRepository {
  final AppDatabase _database;
  SaleRepository(this._database);

  Database get _db => _database.db;

  /// Persists a completed sale atomically: sale row + items + stock
  /// decrements + audit movements, all in one transaction.
  ///
  /// [createdAt] and [orderNumber] overrides exist for demo seeding and
  /// tests; normal checkouts leave them null.
  Future<Sale> completeSale({
    required List<CartLine> lines,
    required CartTotals totals,
    required DiscountType discountType,
    required double discountValue,
    required double taxRatePercent,
    required bool pricesIncludeTax,
    required PaymentMethod paymentMethod,
    int? tenderedCents,
    DateTime? createdAt,
    String? orderNumber,
  }) async {
    if (lines.isEmpty) {
      throw ArgumentError('Cannot complete a sale with no items');
    }
    final at = createdAt ?? DateTime.now();
    final tendered = paymentMethod == PaymentMethod.cash
        ? tenderedCents
        : totals.totalCents;
    final change =
        tendered != null ? tendered - totals.totalCents : 0;
    if (paymentMethod == PaymentMethod.cash &&
        tendered != null &&
        tendered < totals.totalCents) {
      throw ArgumentError('Tendered amount is less than the total');
    }

    return _db.transaction((txn) async {
      final saleId = await txn.insert('sales', {
        'order_number': orderNumber ?? '',
        'created_at': at.toIso8601String(),
        'subtotal_cents': totals.subtotalCents,
        'discount_cents': totals.discountCents,
        'tax_cents': totals.taxCents,
        'total_cents': totals.totalCents,
        'discount_type': discountType.name,
        'discount_value': discountValue,
        'tax_rate_percent': taxRatePercent,
        'prices_include_tax': pricesIncludeTax ? 1 : 0,
        'payment_method': paymentMethod.name,
        'tendered_cents': tendered,
        'change_cents': change < 0 ? 0 : change,
        'status': SaleStatus.completed.dbValue,
      });
      final number = orderNumber ?? '#${1000 + saleId}';
      if (orderNumber == null) {
        await txn.update(
          'sales',
          {'order_number': number},
          where: 'id = ?',
          whereArgs: [saleId],
        );
      }

      final items = <SaleItem>[];
      for (final line in lines) {
        final product = line.product;
        final itemId = await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': product.id,
          'product_name': product.name,
          'unit_price_cents': product.priceCents,
          'cost_cents': product.costCents,
          'qty': line.qty,
        });
        items.add(SaleItem(
          id: itemId,
          saleId: saleId,
          productId: product.id,
          productName: product.name,
          unitPriceCents: product.priceCents,
          costCents: product.costCents,
          qty: line.qty,
        ));
        if (product.id != null) {
          final rows = await txn.query(
            'products',
            columns: ['stock_qty'],
            where: 'id = ?',
            whereArgs: [product.id],
            limit: 1,
          );
          if (rows.isNotEmpty) {
            final current = (rows.first['stock_qty'] as num).toInt();
            final next = current - line.qty;
            await txn.update(
              'products',
              {'stock_qty': next},
              where: 'id = ?',
              whereArgs: [product.id],
            );
            await txn.insert('stock_movements', {
              'product_id': product.id,
              'product_name': product.name,
              'delta': -line.qty,
              'reason': 'Sale',
              'note': 'Order $number',
              'resulting_qty': next,
              'created_at': at.toIso8601String(),
            });
          }
        }
      }

      return Sale(
        id: saleId,
        orderNumber: number,
        createdAt: at,
        subtotalCents: totals.subtotalCents,
        discountCents: totals.discountCents,
        taxCents: totals.taxCents,
        totalCents: totals.totalCents,
        discountType: discountType,
        discountValue: discountValue,
        taxRatePercent: taxRatePercent,
        pricesIncludeTax: pricesIncludeTax,
        paymentMethod: paymentMethod,
        tenderedCents: tendered,
        changeCents: change < 0 ? 0 : change,
        status: SaleStatus.completed,
        items: items,
      );
    });
  }

  /// Voids a sale: marks it VOIDED (the audit row is kept) and restores the
  /// stock of every item. Returns the updated sale.
  Future<Sale> voidSale(int saleId) async {
    return _db.transaction((txn) async {
      final rows = await txn.query(
        'sales',
        where: 'id = ?',
        whereArgs: [saleId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Sale $saleId not found');
      final sale = Sale.fromMap(rows.first);
      if (sale.status == SaleStatus.voided) {
        throw StateError('Sale ${sale.orderNumber} is already voided');
      }
      final itemRows = await txn.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );
      final items = itemRows.map(SaleItem.fromMap).toList();
      final now = DateTime.now();
      for (final item in items) {
        if (item.productId == null) continue;
        final pRows = await txn.query(
          'products',
          columns: ['stock_qty'],
          where: 'id = ?',
          whereArgs: [item.productId],
          limit: 1,
        );
        if (pRows.isEmpty) continue;
        final current = (pRows.first['stock_qty'] as num).toInt();
        final next = current + item.qty;
        await txn.update(
          'products',
          {'stock_qty': next},
          where: 'id = ?',
          whereArgs: [item.productId],
        );
        await txn.insert('stock_movements', {
          'product_id': item.productId,
          'product_name': item.productName,
          'delta': item.qty,
          'reason': 'Void reversal',
          'note': 'Order ${sale.orderNumber} voided',
          'resulting_qty': next,
          'created_at': now.toIso8601String(),
        });
      }
      await txn.update(
        'sales',
        {'status': SaleStatus.voided.dbValue},
        where: 'id = ?',
        whereArgs: [saleId],
      );
      return sale.copyWith(status: SaleStatus.voided, items: items);
    });
  }

  Future<Sale?> getSale(int id, {bool withItems = true}) async {
    final rows =
        await _db.query('sales', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    final items = withItems ? await getItems(id) : const <SaleItem>[];
    return Sale.fromMap(rows.first, items: items);
  }

  Future<List<SaleItem>> getItems(int saleId) async {
    final rows = await _db.query(
      'sale_items',
      where: 'sale_id = ?',
      whereArgs: [saleId],
      orderBy: 'id ASC',
    );
    return rows.map(SaleItem.fromMap).toList();
  }

  /// Sales newest first, optionally filtered by order-number search.
  Future<List<Sale>> getSales({
    String? search,
    DateTime? from,
    DateTime? to,
    bool withItems = false,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (search != null && search.trim().isNotEmpty) {
      where.add('order_number LIKE ?');
      args.add('%${search.trim()}%');
    }
    if (from != null) {
      where.add('created_at >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('created_at < ?');
      args.add(to.toIso8601String());
    }
    final rows = await _db.query(
      'sales',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC, id DESC',
    );
    final sales = <Sale>[];
    for (final row in rows) {
      final sale = Sale.fromMap(row);
      sales.add(withItems
          ? sale.copyWith(items: await getItems(sale.id!))
          : sale);
    }
    return sales;
  }
}
