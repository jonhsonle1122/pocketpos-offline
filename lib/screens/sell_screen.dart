import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../domain/money.dart';
import '../state/app_state.dart';
import '../state/cart_provider.dart';
import '../state/catalog_provider.dart';
import '../widgets/barcode_scan_screen.dart';
import '../widgets/cart_panel.dart';
import '../widgets/empty_state.dart';
import '../widgets/product_tile.dart';
import 'payment_screen.dart';

/// S1 — Checkout / Sell. Product grid + cart panel on wide screens;
/// grid + mini cart bar (opening a cart sheet) on phones. Opens ready
/// to sell; the app always starts here.
class SellScreen extends StatefulWidget {
  const SellScreen({super.key});

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CatalogProvider>().refresh(activeOnly: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _scanToAdd() async {
    final appState = context.read<AppState>();
    final cart = context.read<CartProvider>();
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
    );
    if (code == null || !mounted) return;
    final product = await appState.products.getByBarcode(code);
    if (!mounted) return;
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No product found with barcode $code')),
      );
      return;
    }
    final added = cart.add(product);
    if (!added) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} is out of stock')),
      );
    }
  }

  void _goToPayment() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PaymentScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final catalog = context.watch<CatalogProvider>();
    final cart = context.watch<CartProvider>();
    final settings = appState.settings;
    final wide = MediaQuery.of(context).size.width >= 720;

    final productArea = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search products or barcode…',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              catalog.setSearch('');
                            },
                          ),
                  ),
                  onChanged: catalog.setSearch,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: _scanToAdd,
                icon: const Icon(Icons.barcode_reader),
                label: const Text('Scan'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('All'),
                  selected: catalog.categoryId == null,
                  onSelected: (_) => catalog.setCategory(null),
                ),
              ),
              for (final Category category in catalog.categories)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(category.name),
                    selected: catalog.categoryId == category.id,
                    onSelected: (_) => catalog.setCategory(category.id),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: catalog.loading && catalog.products.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : catalog.products.isEmpty
                  ? EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'No products yet',
                      message:
                          'Add your first product to start selling, or filter is hiding everything.',
                      actionLabel: 'Add product',
                      onAction: () async {
                        // Jump to the Products tab's add flow via a pushed form.
                        final added = await Navigator.of(context).pushNamed('/product-form');
                        if (added == true) catalog.refresh(activeOnly: true);
                      },
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: wide ? 210 : 180,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.78,
                      ),
                      itemCount: catalog.products.length,
                      itemBuilder: (context, index) {
                        final product = catalog.products[index];
                        return ProductTile(
                          product: product,
                          currencyCode: settings.currencyCode,
                          onTap: () {
                            final ok = cart.add(product);
                            if (!ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'No more ${product.name} in stock')),
                              );
                            }
                          },
                        );
                      },
                    ),
        ),
      ],
    );

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: productArea),
          const VerticalDivider(width: 1),
          SizedBox(
            width: 380,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: CartPanel(onCharge: _goToPayment),
            ),
          ),
        ],
      );
    }

    final totals = cart.totals(settings);
    return Column(
      children: [
        Expanded(child: productArea),
        Material(
          elevation: 6,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: cart.isEmpty
                          ? null
                          : () => showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) => SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.75,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: CartPanel(onCharge: () {
                                      Navigator.of(context).pop();
                                      _goToPayment();
                                    }),
                                  ),
                                ),
                              ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            cart.isEmpty
                                ? 'Cart is empty'
                                : '${totals.itemCount} item${totals.itemCount == 1 ? '' : 's'} — tap to review',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            Money.format(totals.totalCents, settings.currencyCode),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (cart.hasHeldSale)
                    IconButton(
                      tooltip: 'Resume held sale',
                      icon: const Icon(Icons.pause_circle),
                      onPressed: () {
                        final ok = cart.resumeHeld();
                        if (!ok) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'Clear the current sale before resuming the held one.')));
                        }
                      },
                    ),
                  FilledButton(
                    onPressed: cart.isEmpty ? null : _goToPayment,
                    style: FilledButton.styleFrom(
                        minimumSize: const Size(120, 52)),
                    child: const Text('Charge'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
