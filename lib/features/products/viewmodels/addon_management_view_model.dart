import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:sqflite/sqflite.dart';

import '../models/addon.dart';
import '../repositories/addon_repository.dart';

class AddonManagementViewModel extends ChangeNotifier {
  AddonManagementViewModel(this._addonRepository);

  final AddonRepository _addonRepository;

  List<Addon> _addons = [];
  List<Addon> _inactiveAddons = [];

  String _searchQuery = '';

  bool _isLoading = false;
  bool _isLoadingAssignments = false;
  bool _isSaving = false;
  bool _hasLoaded = false;

  String? _errorMessage;
  String? _successMessage;

  // ---------------------------------------------------
  // GETTERS
  // ---------------------------------------------------

  List<Addon> get addons => List.unmodifiable(_filterByQuery(_addons));

  List<Addon> get availableAddons => List.unmodifiable(_addons);

  List<Addon> get inactiveAddons =>
      List.unmodifiable(_filterByQuery(_inactiveAddons));

  String get searchQuery => _searchQuery;

  bool get isLoading => _isLoading;

  bool get isLoadingAssignments => _isLoadingAssignments;

  bool get isSaving => _isSaving;

  bool get hasLoaded => _hasLoaded;

  String? get errorMessage => _errorMessage;

  String? get successMessage => _successMessage;

  // ---------------------------------------------------
  // SEARCH
  // ---------------------------------------------------

  List<Addon> _filterByQuery(List<Addon> source) {
    if (_searchQuery.isEmpty) {
      return source;
    }

    final query = _searchQuery.toLowerCase();

    return source
        .where((addon) => addon.name.toLowerCase().contains(query))
        .toList();
  }

  void setSearchQuery(String query) {
    final normalizedQuery = query.trim();

    if (_searchQuery == normalizedQuery) {
      return;
    }

    _searchQuery = normalizedQuery;
    notifyListeners();
  }

  // ---------------------------------------------------
  // LOAD DATA
  // ---------------------------------------------------

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _fetchData();
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

  Future<void> _fetchData() async {
    final allAddons = await _addonRepository.getAll(activeOnly: false);

    _addons = allAddons.where((addon) => addon.isActive).toList();

    _inactiveAddons = allAddons.where((addon) => !addon.isActive).toList();
  }

  Future<void> refresh() async {
    await load();
  }

  // ---------------------------------------------------
  // ADD-ON CRUD
  // ---------------------------------------------------

  Future<bool> createAddon({
    required String name,
    required int additionalPrice,
    required int stock,
  }) {
    return _performMutation(
      action: () async {
        await _addonRepository.create(
          name: name,
          additionalPrice: additionalPrice,
          stock: stock,
        );
      },
      successMessage: 'Add-on berhasil ditambahkan.',
    );
  }

  Future<bool> updateAddon({
    required int id,
    required String name,
    required int additionalPrice,
    required int stock,
  }) {
    return _performMutation(
      action: () async {
        await _addonRepository.update(
          id: id,
          name: name,
          additionalPrice: additionalPrice,
          stock: stock,
        );
      },
      successMessage: 'Add-on berhasil diperbarui.',
    );
  }

  Future<bool> deactivateAddon(int id) {
    return _performMutation(
      action: () async {
        await _addonRepository.deactivate(id);
      },
      successMessage: 'Add-on berhasil dinonaktifkan.',
    );
  }

  Future<bool> activateAddon(int id) {
    return _performMutation(
      action: () async {
        await _addonRepository.activate(id);
      },
      successMessage: 'Add-on berhasil diaktifkan kembali.',
    );
  }

  // ---------------------------------------------------
  // PRODUCT ADD-ON ASSIGNMENT
  // ---------------------------------------------------

  Future<List<Addon>> getAssignedAddons(int productId) async {
    _isLoadingAssignments = true;
    notifyListeners();

    try {
      return await _addonRepository.getForProduct(
        productId: productId,
        activeOnly: true,
      );
    } finally {
      _isLoadingAssignments = false;
      notifyListeners();
    }
  }

  Future<bool> assignAddonsToProduct({
    required int productId,
    required List<int> addonIds,
  }) {
    return _performMutation(
      action: () async {
        await _addonRepository.setForProduct(
          productId: productId,
          addonIds: addonIds,
        );
      },
      successMessage: 'Pilihan add-on produk berhasil diperbarui.',
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

      await _fetchData();
      _hasLoaded = true;

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

      if (message.contains('addons.name')) {
        return 'Nama add-on sudah digunakan.';
      }

      if (message.contains('UNIQUE constraint')) {
        return 'Data tersebut sudah digunakan.';
      }
    }

    return 'Terjadi kesalahan. Silakan coba lagi.';
  }
}
