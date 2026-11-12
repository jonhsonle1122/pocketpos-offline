import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite database holder. The schema is created by [createSchema], which is
/// also used by unit tests with an in-memory ffi database.
class AppDatabase {
  final Database db;

  AppDatabase(this.db);

  static const int schemaVersion = 1;
  static const String fileName = 'pocketpos_offline.db';

  static Future<AppDatabase> openDefault() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, fileName);
    final db = await openDatabase(
      path,
      version: schemaVersion,
      onCreate: (db, _) => createSchema(db),
    );
    return AppDatabase(db);
  }

  static Future<void> createSchema(Database db) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )''');
    batch.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category_id INTEGER,
        barcode TEXT,
        cost_cents INTEGER NOT NULL DEFAULT 0,
        price_cents INTEGER NOT NULL DEFAULT 0,
        stock_qty INTEGER NOT NULL DEFAULT 0,
        low_stock_threshold INTEGER NOT NULL DEFAULT 5,
        active INTEGER NOT NULL DEFAULT 1,
        photo_path TEXT,
        created_at TEXT NOT NULL
      )''');
    batch.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_number TEXT NOT NULL,
        created_at TEXT NOT NULL,
        subtotal_cents INTEGER NOT NULL,
        discount_cents INTEGER NOT NULL DEFAULT 0,
        tax_cents INTEGER NOT NULL DEFAULT 0,
        total_cents INTEGER NOT NULL,
        discount_type TEXT NOT NULL DEFAULT 'none',
        discount_value REAL NOT NULL DEFAULT 0,
        tax_rate_percent REAL NOT NULL DEFAULT 0,
        prices_include_tax INTEGER NOT NULL DEFAULT 0,
        payment_method TEXT NOT NULL DEFAULT 'cash',
        tendered_cents INTEGER,
        change_cents INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'COMPLETED'
      )''');
    batch.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER,
        product_name TEXT NOT NULL,
        unit_price_cents INTEGER NOT NULL,
        cost_cents INTEGER NOT NULL DEFAULT 0,
        qty INTEGER NOT NULL
      )''');
    batch.execute('''
      CREATE TABLE stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER,
        product_name TEXT NOT NULL,
        delta INTEGER NOT NULL,
        reason TEXT NOT NULL,
        note TEXT,
        resulting_qty INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )''');
    batch.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )''');
    batch.execute(
        'CREATE INDEX idx_sales_created ON sales(created_at)');
    batch.execute(
        'CREATE INDEX idx_items_sale ON sale_items(sale_id)');
    batch.execute(
        'CREATE INDEX idx_products_barcode ON products(barcode)');
    await batch.commit(noResult: true);
  }

  Future<void> close() => db.close();
}
