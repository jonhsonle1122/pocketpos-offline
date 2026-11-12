import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../state/app_state.dart';
import '../state/catalog_provider.dart';
import 'orders_screen.dart';
import 'products_screen.dart';
import 'reports_screen.dart';
import 'sell_screen.dart';
import 'settings_screen.dart';

/// App shell: 5 destinations (Sell, Products, Orders, Reports, Settings)
/// with a navigation rail on wide screens and a bottom bar on phones.
/// Deliberately NO "Sync" destination — this app is offline by design.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _destinations = [
    (icon: Icons.point_of_sale, label: 'Sell'),
    (icon: Icons.inventory_2_outlined, label: 'Products'),
    (icon: Icons.receipt_long_outlined, label: 'Orders'),
    (icon: Icons.bar_chart_outlined, label: 'Reports'),
    (icon: Icons.settings_outlined, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final wide = MediaQuery.of(context).size.width >= 720;

    final pages = [
      const SellScreen(),
      const ProductsScreen(),
      const OrdersScreen(),
      const ReportsScreen(),
      const SettingsScreen(),
    ];

    final appBar = AppBar(
      title: Row(
        children: [
          Text(appState.settings.shopName.isEmpty
              ? AppConfig.appName
              : appState.settings.shopName),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_outlined, size: 13, color: Colors.green),
                SizedBox(width: 4),
                Text('Offline',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green)),
              ],
            ),
          ),
        ],
      ),
    );

    final body = IndexedStack(index: _index, children: pages);

    if (wide) {
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => _select(i),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                      icon: Icon(d.icon), label: Text(d.label)),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(icon: Icon(d.icon), label: d.label),
        ],
      ),
    );
  }

  void _select(int i) {
    setState(() => _index = i);
    // Keep the shared catalogue fresh when returning to Sell/Products.
    if (i == 0 || i == 1) {
      context.read<CatalogProvider>().reloadAll();
    }
  }
}
