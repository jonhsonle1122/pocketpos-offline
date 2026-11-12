import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../domain/money.dart';
import '../state/app_state.dart';
import '../state/catalog_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_chip.dart';
import 'product_form_screen.dart';
import 'stock_adjust_screen.dart';

/// S4 — Products (inventory list): search, category filter, low-stock
/// filter, stock badges; FAB adds a product; tapping a row opens the
/// product form; the stock button opens the adjustment screen.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CatalogProvider>().refresh();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openForm({Product? product}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
    );
    if (saved == true && mounted) {
      context.read<CatalogProvider>().refresh();
    }
  }

  Future<void> _openAdjust(Product product) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => StockAdjustScreen(product: product)),
    );
    if (saved == true && mounted) {
      context.read<CatalogProvider>().refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final catalog = context.watch<CatalogProvider>();
    final settings = appState.settings;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add product'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products…',
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
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: catalog.categoryId == null && !catalog.lowStockOnly,
                    onSelected: (_) {
                      catalog.setLowStockOnly(false);
                      catalog.setCategory(null);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('Low stock'),
                    selected: catalog.lowStockOnly,
                    onSelected: (v) => catalog.setLowStockOnly(v),
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
                        title: 'No products found',
                        message:
                            'Add your first product, or clear the search/filter.',
                        actionLabel: 'Add product',
                        onAction: () => _openForm(),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount: catalog.products.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final product = catalog.products[index];
                          return ListTile(
                            leading: _LeadingThumb(product: product),
                            title: Text(product.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              [
                                catalog.categoryName(product.categoryId),
                                if (product.barcode != null &&
                                    product.barcode!.isNotEmpty)
                                  'Barcode ${product.barcode}',
                                Money.format(
                                    product.priceCents, settings.currencyCode),
                              ].join(' · '),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                StockChip(product: product),
                                IconButton(
                                  tooltip: 'Adjust stock',
                                  icon: const Icon(Icons.inventory_outlined),
                                  onPressed: () => _openAdjust(product),
                                ),
                              ],
                            ),
                            onTap: () => _openForm(product: product),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _LeadingThumb extends StatelessWidget {
  final Product product;
  const _LeadingThumb({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photo = product.photoPath;
    if (photo != null && File(photo).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(File(photo),
            width: 48, height: 48, fit: BoxFit.cover),
      );
    }
    final initials = product.name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(initials,
          style: TextStyle(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onPrimaryContainer)),
    );
  }
}
