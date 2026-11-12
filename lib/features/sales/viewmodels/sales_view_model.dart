import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../models/sale.dart';
import '../repositories/sales_repository.dart';

class SalesViewModel extends ChangeNotifier {
  SalesViewModel(this._salesRepository);

  final SalesRepository _salesRepository;

  static const int pageSize = 20;

  List<SaleTransaction> _transactions = [];

  SalesSummary? _summary;
  SaleDetail? _selectedDetail;

  DateTime? _startDate;
  DateTime? _endDate;

  String _searchQuery = '';

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isLoadingDetail = false;

  bool _hasLoaded = false;
  bool _hasMore = true;

  String? _errorMessage;
  String? _detailErrorMessage;

  int _requestVersion = 0;

  // ---------------------------------------------------
  // GETTERS
  // ---------------------------------------------------

  List<SaleTransaction> get transactions => List.unmodifiable(_transactions);

  SalesSummary? get summary => _summary;

  SaleDetail? get selectedDetail => _selectedDetail;

  DateTime? get startDate => _startDate;

  DateTime? get endDate => _endDate;

  String get searchQuery => _searchQuery;

  bool get isLoading => _isLoading;

  bool get isLoadingMore => _isLoadingMore;

  bool get isLoadingDetail => _isLoadingDetail;

  bool get hasLoaded => _hasLoaded;

  bool get hasMore => _hasMore;

  String? get errorMessage => _errorMessage;

  String? get detailErrorMessage => _detailErrorMessage;

  bool get isEmpty => _transactions.isEmpty;

  bool get hasTransactions => _transactions.isNotEmpty;

  // ---------------------------------------------------
  // LOAD DATA
  // ---------------------------------------------------

  Future<void> load() async {
    if (_isLoading) return;

    final requestVersion = ++_requestVersion;

    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final summaryFuture = _salesRepository.getSummary(
        startDate: _startDate,
        endDate: _endDate,
      );

      final transactionsFuture = _salesRepository.getTransactions(
        startDate: _startDate,
        endDate: _endDate,
        searchQuery: _searchQuery,
        limit: pageSize,
      );

      final summary = await summaryFuture;
      final transactions = await transactionsFuture;

      if (requestVersion != _requestVersion) return;

      _summary = summary;
      _transactions = transactions;
      _hasMore = transactions.length == pageSize;
      _hasLoaded = true;
    } catch (_) {
      if (requestVersion != _requestVersion) return;

      _errorMessage = 'Gagal memuat data penjualan. Silakan coba lagi.';
    } finally {
      if (requestVersion == _requestVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> ensureLoaded() async {
    if (_hasLoaded || _isLoading) return;

    await load();
  }

  Future<void> refresh() async {
    await load();
  }

  // ---------------------------------------------------
  // SEARCH
  // ---------------------------------------------------

  Future<void> setSearchQuery(String query) async {
    final normalizedQuery = query.trim();

    if (_searchQuery == normalizedQuery) return;

    _searchQuery = normalizedQuery;

    await _loadTransactions(reset: true);
  }

  Future<void> clearSearch() async {
    if (_searchQuery.isEmpty) return;

    _searchQuery = '';

    await _loadTransactions(reset: true);
  }

  // ---------------------------------------------------
  // DATE FILTER
  // ---------------------------------------------------

  Future<void> setDateRange({
    required DateTime? startDate,
    required DateTime? endDate,
  }) async {
    if (startDate != null && endDate != null) {
      final start = _startOfDay(startDate);
      final end = _startOfDay(endDate);

      if (end.isBefore(start)) {
        _errorMessage = 'Tanggal akhir tidak boleh sebelum tanggal awal.';
        notifyListeners();
        return;
      }
    }

    _startDate = startDate;
    _endDate = endDate;

    await load();
  }

  Future<void> clearDateRange() async {
    if (_startDate == null && _endDate == null) return;

    _startDate = null;
    _endDate = null;

    await load();
  }

  // ---------------------------------------------------
  // TRANSACTION PAGINATION
  // ---------------------------------------------------

  Future<void> _loadTransactions({required bool reset}) async {
    if (_isLoadingMore || (_isLoading && !reset)) return;

    final requestVersion = ++_requestVersion;

    if (reset) {
      _isLoading = true;
    }

    _errorMessage = null;
    _hasMore = reset ? true : _hasMore;

    notifyListeners();

    try {
      final newTransactions = await _salesRepository.getTransactions(
        startDate: _startDate,
        endDate: _endDate,
        searchQuery: _searchQuery,
        limit: pageSize,
        offset: reset ? 0 : _transactions.length,
      );

      if (requestVersion != _requestVersion) return;

      if (reset) {
        _transactions = newTransactions;
      } else {
        _transactions = [..._transactions, ...newTransactions];
      }

      _hasMore = newTransactions.length == pageSize;
      _hasLoaded = true;
    } catch (_) {
      if (requestVersion != _requestVersion) return;

      _errorMessage = 'Gagal memuat riwayat transaksi.';
    } finally {
      if (requestVersion == _requestVersion) {
        if (reset) {
          _isLoading = false;
        }

        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (!_hasLoaded || !_hasMore || _isLoading || _isLoadingMore) {
      return;
    }

    _isLoadingMore = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final newTransactions = await _salesRepository.getTransactions(
        startDate: _startDate,
        endDate: _endDate,
        searchQuery: _searchQuery,
        limit: pageSize,
        offset: _transactions.length,
      );

      _transactions = [..._transactions, ...newTransactions];

      _hasMore = newTransactions.length == pageSize;
    } catch (_) {
      _errorMessage = 'Gagal memuat transaksi berikutnya.';
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------
  // TRANSACTION DETAIL
  // ---------------------------------------------------

  Future<SaleDetail?> loadDetail(int saleId) async {
    _isLoadingDetail = true;
    _selectedDetail = null;
    _detailErrorMessage = null;

    notifyListeners();

    try {
      final detail = await _salesRepository.getDetail(saleId);

      _selectedDetail = detail;

      if (detail == null) {
        _detailErrorMessage = 'Transaksi tidak ditemukan.';
      }

      return detail;
    } catch (_) {
      _detailErrorMessage = 'Gagal memuat detail transaksi.';
      return null;
    } finally {
      _isLoadingDetail = false;
      notifyListeners();
    }
  }

  void clearDetail() {
    if (_selectedDetail == null && _detailErrorMessage == null) return;

    _selectedDetail = null;
    _detailErrorMessage = null;

    notifyListeners();
  }

  // ---------------------------------------------------
  // MESSAGE HANDLING
  // ---------------------------------------------------

  void clearError() {
    if (_errorMessage == null) return;

    _errorMessage = null;
    notifyListeners();
  }

  // ---------------------------------------------------
  // HELPERS
  // ---------------------------------------------------

  DateTime _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
