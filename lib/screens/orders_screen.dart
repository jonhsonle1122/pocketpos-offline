import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../data/models.dart';
import '../domain/money.dart';
import '../state/app_state.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_chip.dart';
import 'order_detail_screen.dart';

/// S7 — Orders (sales history): grouped by day with day-total headers,
/// order-number search, payment chips, voided badges.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _searchController = TextEditingController();
  List<Sale> _sales = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    final sales = await appState.sales.getSales(
        search: _searchController.text, withItems: true);
    if (mounted) {
      setState(() {
        _sales = sales;
        _loading = false;
      });
    }
  }

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('EEE, d MMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final cur = appState.settings.currencyCode;
    final theme = Theme.of(context);

    // Group by day, preserving newest-first order.
    final groups = <String, List<Sale>>{};
    for (final sale in _sales) {
      groups.putIfAbsent(_dayLabel(sale.createdAt), () => []).add(sale);
    }
    final todaySales = _sales.where((s) {
      final now = DateTime.now();
      return s.createdAt.year == now.year &&
          s.createdAt.month == now.month &&
          s.createdAt.day == now.day &&
          s.status == SaleStatus.completed;
    }).toList();
    final todayTotal =
        todaySales.fold<int>(0, (sum, s) => sum + s.totalCents);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Today\'s sales',
                          style: theme.textTheme.bodySmall),
                      Text(
                        Money.format(todayTotal, cur),
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                Text('${todaySales.length} orders',
                    style: theme.textTheme.titleSmall),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by order number (e.g. 1042)…',
              prefixIcon: const Icon(Icons.search),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
            onChanged: (_) => _load(),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _sales.isEmpty
                  ? EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No sales yet',
                      message:
                          'Completed sales will appear here, grouped by day.',
                    )
                  : ListView(
                      children: [
                        for (final entry in groups.entries) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(entry.key,
                                    style: theme.textTheme.titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700)),
                                Text(
                                  Money.format(
                                      entry.value
                                          .where((s) =>
                                              s.status == SaleStatus.completed)
                                          .fold<int>(
                                              0, (sum, s) => sum + s.totalCents),
                                      cur),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                          for (final sale in entry.value)
                            ListTile(
                              title: Row(
                                children: [
                                  Text(sale.orderNumber,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(width: 8),
                                  StatusChip(
                                    label: sale.paymentMethod.label,
                                    color: theme.colorScheme.primary,
                                  ),
                                  if (sale.status == SaleStatus.voided) ...[
                                    const SizedBox(width: 6),
                                    const StatusChip(
                                        label: 'VOIDED',
                                        color: AppConfig.dangerColor),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                  '${DateFormat('HH:mm').format(sale.createdAt)} · ${sale.itemCount} item${sale.itemCount == 1 ? '' : 's'}'),
                              trailing: Text(
                                Money.format(sale.totalCents, cur),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  decoration: sale.status == SaleStatus.voided
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          OrderDetailScreen(saleId: sale.id!)),
                                );
                                _load();
                              },
                            ),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
        ),
      ],
    );
  }
}
