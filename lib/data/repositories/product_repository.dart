import 'package:sqflite/sqflite.dart';

import '../app_database.dart';
import '../models.dart';

/// Thrown when a stock adjustment would drive stock below zero.
class StockBelowZeroException implements Exception {
  final int currentQty;
  final int delta;
  StockBelowZeroException(this.currentQty, this.delta);

  @override
  String toString() =>
      'Stock cannot go below zero (current: $currentQty, change: $delta).';
}

class ProductRepository {
  final AppDatabase _database;
  ProductRepository(this._database);

  Database get _db => _database.db;

  // ── Categories ──────────────────────────────────────────────────────────

  Future<List<Category>> getCategories() async {
    final rows = await _db.query('categories', orderBy: 'name ASC');
    return rows.map(Category.fromMap).toList();
  }

  /// Returns the existing category with [name] or creates it.
  Future<Category> ensureCategory(String name) async {
    final trimmed = name.trim();
    final existing = await _db.query(
      'categories',
      where: 'name = ?',
      whereArgs: [trimmed],
      limit: 1,
    );
    if (existing.isNotEmpty) return Category.fromMap(existing.first);
    final id = await _db.insert('categories', {'name': trimmed});
    return Category(id: id, name: trimmed);
  }

  // ── Products ────────────────────────────────────────────────────────────

  Future<List<Product>> getProducts({
    String? search,
    int? categoryId,
    bool activeOnly = false,
    bool lowStockOnly = false,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (activeOnly) {
      where.add('active = 1');
    }
    if (categoryId != null) {
      where.add('category_id = ?');
      args.add(categoryId);
    }
    if (lowStockOnly) {
      where.add('stock_qty > 0 AND stock_qty <= low_stock_threshold');
    }
    if (search != null && search.trim().isNotEmpty) {
      where.add('(name LIKE ? OR barcode LIKE ?)');
      final like = '%${search.trim()}%';
      args.addAll([like, like]);
    }
    final rows = await _db.query(
      'products',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name ASC',
    );
    return rows.map(Product.fromMap).toList();
  }

  Future<Product?> getById(int id) async {
    final rows =
        await _db.query('products', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Product.fromMap(rows.first);
  }

  Future<Product?> getByBarcode(String barcode) async {
    final rows = await _db.query(
      'products',
      where: 'barcode = ? AND active = 1',
      whereArgs: [barcode.trim()],
      limit: 1,
    );
    return rows.isEmpty ? null : Product.fromMap(rows.first);
  }

  Future<int> lowStockCount() async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM products '
      'WHERE active = 1 AND stock_qty <= low_stock_threshold',
    );
    return (rows.first['c'] as num).toInt();
  }

  /// Inserts (id == null) or updates a product. Returns the stored product.
  Future<Product> upsertProduct(Product product) async {
    final map = product.toMap();
    if (product.id == null) {
      final id = await _db.insert('products', map);
      return product.copyWith(id: id);
    }
    await _db.update('products', map, where: 'id = ?', whereArgs: [product.id]);
    return product;
  }

  Future<void> deleteProduct(int id) async {
    await _db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  // ── Stock ───────────────────────────────────────────────────────────────

  /// Applies a signed stock [delta] to a product inside a transaction and
  /// writes an audit movement. Throws [StockBelowZeroException] when the
  /// result would be negative. Returns the new quantity.
  Future<int> adjustStock({
    required int productId,
    required int delta,
    required String reason,
    String? note,
    DateTime? at,
  }) async {
    return _db.transaction((txn) async {
      final rows = await txn.query(
        'products',
        columns: ['stock_qty', 'name'],
        where: 'id = ?',
        whereArgs: [productId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Product $productId not found');
      }
      final current = (rows.first['stock_qty'] as num).toInt();
      final next = current + delta;
      if (next < 0) throw StockBelowZeroException(current, delta);
      await txn.update(
        'products',
        {'stock_qty': next},
        where: 'id = ?',
        whereArgs: [productId],
      );
      await txn.insert('stock_movements', {
        'product_id': productId,
        'product_name': rows.first['name'],
        'delta': delta,
        'reason': reason,
        'note': note,
        'resulting_qty': next,
        'created_at': (at ?? DateTime.now()).toIso8601String(),
      });
      return next;
    });
  }

  Future<List<StockMovement>> getMovements({int? productId, int limit = 100}) async {
    final rows = await _db.query(
      'stock_movements',
      where: productId != null ? 'product_id = ?' : null,
      whereArgs: productId != null ? [productId] : null,
      orderBy: 'id DESC',
      limit: limit,
    );
    return rows.map(StockMovement.fromMap).toList();
  }
}
