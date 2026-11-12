import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../data/models.dart';
import '../domain/money.dart';
import '../services/export_service.dart';
import '../state/app_state.dart';

enum ReportRange { today, week, month }

/// S9 — Reports dashboard: Today/Week/Month, KPI cards (Revenue, Orders,
/// Avg basket, Profit estimate), revenue bar chart (hourly for today,
/// daily otherwise), top products, low-stock summary, Excel/CSV export.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportRange _range = ReportRange.today;
  ReportData? _data;
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  (DateTime, DateTime) _bounds() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (_range) {
      ReportRange.today => (today, today.add(const Duration(days: 1))),
      ReportRange.week => (
          today.subtract(Duration(days: today.weekday - 1)),
          today
              .subtract(Duration(days: today.weekday - 1))
              .add(const Duration(days: 7)),
        ),
      ReportRange.month => (
          DateTime(now.year, now.month, 1),
          DateTime(now.year, now.month + 1, 1),
        ),
    };
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final (start, end) = _bounds();
    final data = await context.read<AppState>().reports.getReport(start, end);
    if (mounted) {
      setState(() {
        _data = data;
        _loading = false;
      });
    }
  }

  Future<void> _export(bool excel) async {
    final appState = context.read<AppState>();
    final (start, end) = _bounds();
    setState(() => _exporting = true);
    try {
      final rows = await appState.reports.getExportRows(start, end);
      final stamp = DateFormat('yyyyMMdd').format(start);
      final rangeName = _range.name;
      if (excel) {
        final bytes = ExportService.buildSalesXlsx(
            rows, appState.settings.currencyCode);
        await ExportService.shareBytes(
          bytes,
          'sales-$rangeName-$stamp.xlsx',
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          subject: 'Sales report ($rangeName)',
        );
      } else {
        await ExportService.shareText(
          ExportService.buildSalesCsv(rows),
          'sales-$rangeName-$stamp.csv',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final cur = appState.settings.currencyCode;
    final theme = Theme.of(context);
    final data = _data;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: SegmentedButton<ReportRange>(
                segments: const [
                  ButtonSegment(value: ReportRange.today, label: Text('Today')),
                  ButtonSegment(value: ReportRange.week, label: Text('Week')),
                  ButtonSegment(value: ReportRange.month, label: Text('Month')),
                ],
                selected: {_range},
                onSelectionChanged: (s) {
                  setState(() => _range = s.first);
                  _load();
                },
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: 'Export',
              enabled: !_exporting,
              icon: _exporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.ios_share),
              onSelected: (v) => _export(v == 'excel'),
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: 'excel',
                    child: ListTile(
                      leading: Icon(Icons.table_chart_outlined),
                      title: Text('Export as Excel (.xlsx)'),
                      contentPadding: EdgeInsets.zero,
                    )),
                PopupMenuItem(
                    value: 'csv',
                    child: ListTile(
                      leading: Icon(Icons.description_outlined),
                      title: Text('Export as CSV'),
                      contentPadding: EdgeInsets.zero,
                    )),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loading || data == null)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (data.orderCount == 0 && data.lowStockProducts.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Column(
              children: [
                Icon(Icons.bar_chart_outlined,
                    size: 64,
                    color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text('No sales in this period yet',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Complete a sale and it will show up here instantly.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          )
        else ...[
          if (data.lowStockProducts.isNotEmpty)
            Card(
              color: AppConfig.accentColor.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber,
                        color: AppConfig.accentColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Low stock alert — ${data.lowStockProducts.length} product${data.lowStockProducts.length == 1 ? '' : 's'} running low: '
                        '${data.lowStockProducts.take(2).map((p) => '${p.name} (${p.stockQty} left)').join(', ')}'
                        '${data.lowStockProducts.length > 2 ? '…' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.9,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              _KpiCard(
                label: 'Revenue',
                value: Money.format(data.revenueCents, cur),
                icon: Icons.payments_outlined,
              ),
              _KpiCard(
                label: 'Orders',
                value: '${data.orderCount}',
                icon: Icons.receipt_long_outlined,
              ),
              _KpiCard(
                label: 'Avg basket',
                value: Money.format(data.avgBasketCents, cur),
                icon: Icons.shopping_basket_outlined,
              ),
              _KpiCard(
                label: 'Profit estimate',
                value: Money.format(data.profitCents, cur),
                icon: Icons.trending_up,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _range == ReportRange.today
                        ? 'Revenue by hour'
                        : 'Revenue by day',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  _BarChart(buckets: data.buckets, currencyCode: cur),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Top products',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (data.topProducts.isEmpty)
            Text('No product sales in this period.',
                style: theme.textTheme.bodyMedium)
          else
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < data.topProducts.length; i++)
                    ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        child: Text('${i + 1}',
                            style: const TextStyle(fontSize: 13)),
                      ),
                      title: Text(data.topProducts[i].productName,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle:
                          Text('${data.topProducts[i].qtySold} units sold'),
                      trailing: Text(
                        Money.format(data.topProducts[i].revenueCents, cur),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _KpiCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                Icon(icon, size: 18, color: theme.colorScheme.primary),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<ReportBucket> buckets;
  final String currencyCode;
  const _BarChart({required this.buckets, required this.currencyCode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = buckets.fold<int>(
        0, (m, b) => b.revenueCents > m ? b.revenueCents : m);
    if (max == 0) {
      return const SizedBox(
        height: 80,
        child: Center(child: Text('No revenue in this period.')),
      );
    }
    final peak = buckets.reduce(
        (a, b) => b.revenueCents > a.revenueCents ? b : a);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Peak: ${peak.label} · ${Money.format(peak.revenueCents, currencyCode)}',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 130,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final bucket in buckets)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: FractionallySizedBox(
                            heightFactor: max == 0
                                ? 0
                                : (bucket.revenueCents / max).clamp(0.02, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: bucket.revenueCents == max
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.primary
                                        .withValues(alpha: 0.35),
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          bucket.label,
                          style: theme.textTheme.labelSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
