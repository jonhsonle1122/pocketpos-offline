import 'package:sqflite/sqflite.dart';

import '../app_database.dart';
import '../models.dart';

/// One sale row for CSV/XLSX export.
class SaleExportRow {
  final String orderNumber;
  final DateTime createdAt;
  final String paymentMethod;
  final String status;
  final int itemCount;
  final int subtotalCents;
  final int discountCents;
  final int taxCents;
  final int totalCents;

  const SaleExportRow({
    required this.orderNumber,
    required this.createdAt,
    required this.paymentMethod,
    required this.status,
    required this.itemCount,
    required this.subtotalCents,
    required this.discountCents,
    required this.taxCents,
    required this.totalCents,
  });
}

class ReportRepository {
  final AppDatabase _database;
  ReportRepository(this._database);

  Database get _db => _database.db;

  /// Aggregates completed (non-voided) sales in [start, end).
  ///
  /// Buckets are hourly when the range is a single day, daily otherwise.
  /// Profit estimate = Σ (sale price − cost) × qty over items, minus the
  /// discounts granted in the range (tax excluded — it is collected for the
  /// state, not earned).
  Future<ReportData> getReport(DateTime start, DateTime end) async {
    final from = start.toIso8601String();
    final to = end.toIso8601String();

    final totalsRows = await _db.rawQuery(
      'SELECT COUNT(*) AS orders, COALESCE(SUM(total_cents), 0) AS revenue, '
      'COALESCE(SUM(discount_cents), 0) AS discounts '
      "FROM sales WHERE status = 'COMPLETED' AND created_at >= ? AND created_at < ?",
      [from, to],
    );
    final orderCount = (totalsRows.first['orders'] as num).toInt();
    final revenue = (totalsRows.first['revenue'] as num).toInt();
    final discounts = (totalsRows.first['discounts'] as num).toInt();

    final profitRows = await _db.rawQuery(
      'SELECT COALESCE(SUM((si.unit_price_cents - si.cost_cents) * si.qty), 0) AS gross '
      'FROM sale_items si JOIN sales s ON s.id = si.sale_id '
      "WHERE s.status = 'COMPLETED' AND s.created_at >= ? AND s.created_at < ?",
      [from, to],
    );
    final grossProfit = (profitRows.first['gross'] as num).toInt();
    final profit = grossProfit - discounts;

    final isSingleDay = end.difference(start).inHours <= 24 &&
        start.day == end.subtract(const Duration(seconds: 1)).day;
    final buckets = isSingleDay
        ? await _hourlyBuckets(start, from, to)
        : await _dailyBuckets(from, to);

    final topRows = await _db.rawQuery(
      'SELECT si.product_name AS name, SUM(si.qty) AS qty, '
      'SUM(si.unit_price_cents * si.qty) AS revenue '
      'FROM sale_items si JOIN sales s ON s.id = si.sale_id '
      "WHERE s.status = 'COMPLETED' AND s.created_at >= ? AND s.created_at < ? "
      'GROUP BY si.product_name ORDER BY revenue DESC LIMIT 5',
      [from, to],
    );
    final topProducts = topRows
        .map((r) => TopProduct(
              productName: r['name'] as String,
              qtySold: (r['qty'] as num).toInt(),
              revenueCents: (r['revenue'] as num).toInt(),
            ))
        .toList();

    final lowRows = await _db.query(
      'products',
      where: 'active = 1 AND stock_qty <= low_stock_threshold',
      orderBy: 'stock_qty ASC, name ASC',
    );
    final lowStock = lowRows.map(Product.fromMap).toList();

    return ReportData(
      start: start,
      end: end,
      revenueCents: revenue,
      orderCount: orderCount,
      profitCents: profit,
      buckets: buckets,
      topProducts: topProducts,
      lowStockProducts: lowStock,
    );
  }

  Future<List<ReportBucket>> _hourlyBuckets(
      DateTime day, String from, String to) async {
    final rows = await _db.rawQuery(
      "SELECT CAST(strftime('%H', created_at) AS INTEGER) AS h, "
      'COALESCE(SUM(total_cents), 0) AS revenue FROM sales '
      "WHERE status = 'COMPLETED' AND created_at >= ? AND created_at < ? "
      'GROUP BY h',
      [from, to],
    );
    final byHour = {
      for (final r in rows) (r['h'] as num).toInt(): (r['revenue'] as num).toInt()
    };
    // Show trading hours 6..22 plus any hour that has sales.
    final hours = <int>{for (var h = 6; h <= 22; h++) h, ...byHour.keys}.toList()
      ..sort();
    return hours
        .map((h) => ReportBucket(
              label: _hourLabel(h),
              revenueCents: byHour[h] ?? 0,
            ))
        .toList();
  }

  Future<List<ReportBucket>> _dailyBuckets(String from, String to) async {
    final rows = await _db.rawQuery(
      "SELECT substr(created_at, 1, 10) AS d, "
      'COALESCE(SUM(total_cents), 0) AS revenue FROM sales '
      "WHERE status = 'COMPLETED' AND created_at >= ? AND created_at < ? "
      'GROUP BY d ORDER BY d ASC',
      [from, to],
    );
    return rows.map((r) {
      final d = DateTime.parse(r['d'] as String);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return ReportBucket(
        label: '${months[d.month - 1]} ${d.day}',
        revenueCents: (r['revenue'] as num).toInt(),
      );
    }).toList();
  }

  String _hourLabel(int hour) {
    if (hour == 0) return '12a';
    if (hour < 12) return '${hour}a';
    if (hour == 12) return '12p';
    return '${hour - 12}p';
  }

  /// Flat sale rows (completed + voided, status column included) for export.
  Future<List<SaleExportRow>> getExportRows(DateTime start, DateTime end) async {
    final rows = await _db.rawQuery(
      'SELECT s.order_number, s.created_at, s.payment_method, s.status, '
      's.subtotal_cents, s.discount_cents, s.tax_cents, s.total_cents, '
      '(SELECT COALESCE(SUM(qty), 0) FROM sale_items si WHERE si.sale_id = s.id) AS items '
      'FROM sales s WHERE s.created_at >= ? AND s.created_at < ? '
      'ORDER BY s.created_at ASC',
      [start.toIso8601String(), end.toIso8601String()],
    );
    return rows
        .map((r) => SaleExportRow(
              orderNumber: r['order_number'] as String,
              createdAt: DateTime.parse(r['created_at'] as String),
              paymentMethod: PaymentMethod.fromName(r['payment_method'] as String?).label,
              status: r['status'] as String,
              itemCount: (r['items'] as num).toInt(),
              subtotalCents: (r['subtotal_cents'] as num).toInt(),
              discountCents: (r['discount_cents'] as num).toInt(),
              taxCents: (r['tax_cents'] as num).toInt(),
              totalCents: (r['total_cents'] as num).toInt(),
            ))
        .toList();
  }
}
