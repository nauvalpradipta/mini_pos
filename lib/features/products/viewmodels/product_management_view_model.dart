import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:sqflite/sqflite.dart';

import '../models/category.dart';
import '../models/product.dart';
import '../repositories/category_repository.dart';
import '../repositories/product_repository.dart';

class ProductManagementViewModel extends ChangeNotifier {
  ProductManagementViewModel(this._categoryRepository, this._productRepository);

  final CategoryRepository _categoryRepository;
  final ProductRepository _productRepository;

  List<Category> _categories = [];
  List<Product> _products = [];

  int? _selectedCategoryId;
  String _searchQuery = '';

  bool _isLoading = false;
  bool _isSaving = false;

  String? _errorMessage;
  String? _successMessage;

  // ---------------------------------------------------
  // GETTERS
  // ---------------------------------------------------

  List<Category> get categories => List.unmodifiable(_categories);

  List<Product> get products => List.unmodifiable(_products);

  int? get selectedCategoryId => _selectedCategoryId;

  String get searchQuery => _searchQuery;

  bool get isLoading => _isLoading;

  bool get isSaving => _isSaving;

  String? get errorMessage => _errorMessage;

  String? get successMessage => _successMessage;

  // ---------------------------------------------------
  // LOAD DATA
  // ---------------------------------------------------

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _fetchData();
    } catch (error) {
      _errorMessage = _readableError(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchData() async {
    _categories = await _categoryRepository.getAll(activeOnly: true);

    // Reset filter jika kategori sudah tidak aktif.
    if (_selectedCategoryId != null &&
        !_categories.any((category) => category.id == _selectedCategoryId)) {
      _selectedCategoryId = null;
    }

    await _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    _products = await _productRepository.getAll(
      activeOnly: true,
      categoryId: _selectedCategoryId,
      searchQuery: _searchQuery,
    );
  }

  Future<void> refresh() async {
    await load();
  }

  // ---------------------------------------------------
  // PRODUCT FILTERS
  // ---------------------------------------------------

  Future<void> setCategoryFilter(int? categoryId) async {
    _selectedCategoryId = categoryId;
    await _refreshFilteredProducts();
  }

  Future<void> setSearchQuery(String query) async {
    _searchQuery = query.trim();
    await _refreshFilteredProducts();
  }

  Future<void> _refreshFilteredProducts() async {
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
  // CATEGORY CRUD
  // ---------------------------------------------------

  Future<bool> createCategory({required String name, String? description}) {
    return _performMutation(
      action: () async {
        await _categoryRepository.create(name: name, description: description);
      },
      successMessage: 'Kategori berhasil ditambahkan.',
    );
  }

  Future<bool> updateCategory({
    required int id,
    required String name,
    String? description,
  }) {
    return _performMutation(
      action: () async {
        await _categoryRepository.update(
          id: id,
          name: name,
          description: description,
        );
      },
      successMessage: 'Kategori berhasil diperbarui.',
    );
  }

  Future<bool> deactivateCategory(int id) {
    return _performMutation(
      action: () async {
        await _categoryRepository.deactivate(id);
      },
      successMessage: 'Kategori berhasil dinonaktifkan.',
    );
  }

  // ---------------------------------------------------
  // PRODUCT CRUD
  // ---------------------------------------------------

  Future<bool> createProduct({
    required int categoryId,
    required String name,
    required int sellingPrice,
    required int stock,
    String? imagePath,
  }) {
    return _performMutation(
      action: () async {
        await _productRepository.create(
          categoryId: categoryId,
          name: name,
          sellingPrice: sellingPrice,
          stock: stock,
          imagePath: imagePath,
        );
      },
      successMessage: 'Produk berhasil ditambahkan.',
    );
  }

  Future<bool> updateProduct({
    required int id,
    required int categoryId,
    required String name,
    required int sellingPrice,
    required int stock,
    String? imagePath,
  }) {
    return _performMutation(
      action: () async {
        await _productRepository.update(
          id: id,
          categoryId: categoryId,
          name: name,
          sellingPrice: sellingPrice,
          stock: stock,
          imagePath: imagePath,
        );
      },
      successMessage: 'Produk berhasil diperbarui.',
    );
  }

  Future<bool> deactivateProduct(int id) {
    return _performMutation(
      action: () async {
        await _productRepository.deactivate(id);
      },
      successMessage: 'Produk berhasil dinonaktifkan.',
    );
  }

  // ---------------------------------------------------
  // SHARED MUTATION HANDLER
  // ---------------------------------------------------

  Future<bool> _performMutation({
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await action();

      // Refresh data agar UI menampilkan kondisi database terbaru.
      await _fetchData();

      _successMessage = successMessage;
      return true;
    } catch (error) {
      _errorMessage = _readableError(error);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------
  // MESSAGE HANDLING
  // ---------------------------------------------------

  void clearMessages() {
    if (_errorMessage == null && _successMessage == null) {
      return;
    }

    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  String _readableError(Object error) {
    if (error is ArgumentError) {
      return error.toString().replaceFirst('Invalid argument(s): ', '');
    }

    if (error is StateError) {
      return error.toString().replaceFirst('Bad state: ', '');
    }

    if (error is DatabaseException) {
      final message = error.toString();

      if (message.contains('categories.name')) {
        return 'Nama kategori sudah digunakan.';
      }

      if (message.contains('UNIQUE constraint')) {
        return 'Data tersebut sudah digunakan.';
      }
    }

    return 'Terjadi kesalahan. Silakan coba lagi.';
  }
}
