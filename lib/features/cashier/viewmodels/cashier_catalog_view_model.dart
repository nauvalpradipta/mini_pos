import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:sqflite/sqflite.dart';

import '../../products/models/category.dart';
import '../../products/models/product.dart';
import '../../products/repositories/category_repository.dart';
import '../../products/repositories/product_repository.dart';

class CashierCatalogViewModel extends ChangeNotifier {
  CashierCatalogViewModel(this._categoryRepository, this._productRepository);

  final CategoryRepository _categoryRepository;
  final ProductRepository _productRepository;

  List<Category> _categories = [];
  List<Product> _products = [];

  int? _selectedCategoryId;
  String _searchQuery = '';

  bool _isLoading = false;
  bool _hasLoaded = false;

  String? _errorMessage;

  // ---------------------------------------------------
  // GETTERS
  // ---------------------------------------------------

  List<Category> get categories => List.unmodifiable(_categories);

  List<Product> get products => List.unmodifiable(_products);

  int? get selectedCategoryId => _selectedCategoryId;

  String get searchQuery => _searchQuery;

  bool get isLoading => _isLoading;

  bool get hasLoaded => _hasLoaded;

  String? get errorMessage => _errorMessage;

  // ---------------------------------------------------
  // LOAD DATA
  // ---------------------------------------------------

  Future<void> load() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _fetchCategories();
      await _fetchProducts();

      _hasLoaded = true;
    } catch (error) {
      _errorMessage = _readableError(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> ensureLoaded() async {
    if (_hasLoaded || _isLoading) return;

    await load();
  }

  Future<void> refresh() async {
    await load();
  }

  Future<void> _fetchCategories() async {
    _categories = await _categoryRepository.getAll(activeOnly: true);

    if (_selectedCategoryId != null &&
        !_categories.any((category) => category.id == _selectedCategoryId)) {
      _selectedCategoryId = null;
    }
  }

  Future<void> _fetchProducts() async {
    _products = await _productRepository.getAll(
      activeOnly: true,
      categoryId: _selectedCategoryId,
      searchQuery: _searchQuery,
    );
  }

  // ---------------------------------------------------
  // SEARCH AND FILTER
  // ---------------------------------------------------

  Future<void> setSearchQuery(String query) async {
    final normalizedQuery = query.trim();

    if (_searchQuery == normalizedQuery) return;

    _searchQuery = normalizedQuery;

    await _refreshProducts();
  }

  Future<void> setCategoryFilter(int? categoryId) async {
    if (_selectedCategoryId == categoryId) return;

    _selectedCategoryId = categoryId;

    await _refreshProducts();
  }

  Future<void> clearFilters() async {
    if (_searchQuery.isEmpty && _selectedCategoryId == null) {
      return;
    }

    _searchQuery = '';
    _selectedCategoryId = null;

    await _refreshProducts();
  }

  Future<void> _refreshProducts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _fetchProducts();
    } catch (error) {
      _errorMessage = _readableError(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------
  // ERROR HANDLING
  // ---------------------------------------------------

  String _readableError(Object error) {
    if (error is DatabaseException) {
      return 'Gagal memuat katalog produk. Silakan coba lagi.';
    }

    if (error is StateError) {
      return error.toString().replaceFirst('Bad state: ', '');
    }

    return 'Terjadi kesalahan. Silakan coba lagi.';
  }
}
