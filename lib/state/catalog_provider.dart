import 'package:flutter/foundation.dart' hide Category;

import '../data/models.dart';
import '../data/repositories/product_repository.dart';

/// Product catalogue state shared by the Sell and Products screens.
class CatalogProvider extends ChangeNotifier {
  final ProductRepository _repo;
  CatalogProvider(this._repo);

  List<Product> _products = [];
  List<Category> _categories = [];
  String _search = '';
  int? _categoryId;
  bool _lowStockOnly = false;
  bool _loading = false;

  List<Product> get products => _products;
  List<Category> get categories => _categories;
  String get search => _search;
  int? get categoryId => _categoryId;
  bool get lowStockOnly => _lowStockOnly;
  bool get loading => _loading;

  String categoryName(int? id) {
    if (id == null) return 'Uncategorised';
    for (final c in _categories) {
      if (c.id == id) return c.name;
    }
    return 'Uncategorised';
  }

  Future<void> refresh({bool activeOnly = false}) async {
    _loading = true;
    notifyListeners();
    _categories = await _repo.getCategories();
    _products = await _repo.getProducts(
      search: _search,
      categoryId: _categoryId,
      activeOnly: activeOnly,
      lowStockOnly: _lowStockOnly,
    );
    _loading = false;
    notifyListeners();
  }

  /// Unfiltered reload used after data changes elsewhere (sales, restores).
  Future<void> reloadAll() async {
    _categories = await _repo.getCategories();
    _products = await _repo.getProducts(
      search: _search,
      categoryId: _categoryId,
      lowStockOnly: _lowStockOnly,
    );
    notifyListeners();
  }

  void setSearch(String value) {
    _search = value;
    refresh();
  }

  void setCategory(int? id) {
    _categoryId = id;
    refresh();
  }

  void setLowStockOnly(bool value) {
    _lowStockOnly = value;
    refresh();
  }
}
