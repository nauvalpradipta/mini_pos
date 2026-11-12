import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mini_pos/core/database/database_schema.dart';

import 'package:mini_pos/features/cashier/models/cart_item.dart';
import 'package:mini_pos/features/cashier/models/checkout.dart';
import 'package:mini_pos/features/cashier/repositories/transaction_repository.dart';

import 'package:mini_pos/features/products/repositories/category_repository.dart';
import 'package:mini_pos/features/products/repositories/product_repository.dart';

import 'package:mini_pos/features/sales/repositories/sales_repository.dart';
import 'package:mini_pos/features/sales/viewmodels/sales_view_model.dart';

void main() {
  late Database database;
  late CategoryRepository categoryRepository;
  late ProductRepository productRepository;
  late TransactionRepository transactionRepository;
  late SalesRepository salesRepository;
  late SalesViewModel viewModel;

  late int cashierId;
  late int productId;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await DatabaseSchema.create(db);
        },
      ),
    );

    categoryRepository = CategoryRepository(database);
    productRepository = ProductRepository(database);
    transactionRepository = TransactionRepository(database);
    salesRepository = SalesRepository(database);
    viewModel = SalesViewModel(salesRepository);

    final now = DateTime.now().millisecondsSinceEpoch;

    cashierId = await database.insert('users', {
      'full_name': 'Test Cashier',
      'username': 'cashier_test',
      'password_hash': 'test_hash',
      'password_salt': 'test_salt',
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });

    final categoryId = await categoryRepository.create(
      name: 'Minuman',
      description: 'Kategori minuman',
    );

    final product = await productRepository.create(
      categoryId: categoryId,
      name: 'Kopi Susu',
      sellingPrice: 15000,
      stock: 200,
    );

    productId = product.id!;
  });

  tearDown(() async {
    viewModel.dispose();
    await database.close();
  });

  // ---------------------------------------------------
  // HELPERS
  // ---------------------------------------------------

  Future<CheckoutResult> createSale({
    int quantity = 1,
    DiscountType discountType = DiscountType.none,
    int discountValue = 0,
    int cashReceived = 50000,
  }) {
    return transactionRepository.checkout(
      CheckoutRequest(
        cashierId: cashierId,
        cartItems: [
          CartItem(
            productId: productId,
            productName: 'Kopi Susu',
            unitPrice: 15000,
            quantity: quantity,
          ),
        ],
        discountType: discountType,
        discountValue: discountValue,
        cashReceived: cashReceived,
      ),
    );
  }

  group('SalesViewModel', () {
    // ---------------------------------------------------
    // INITIAL STATE
    // ---------------------------------------------------

    test('has correct initial state', () {
      expect(viewModel.transactions, isEmpty);
      expect(viewModel.summary, isNull);
      expect(viewModel.selectedDetail, isNull);

      expect(viewModel.searchQuery, isEmpty);
      expect(viewModel.startDate, isNull);
      expect(viewModel.endDate, isNull);

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.isLoadingMore, isFalse);
      expect(viewModel.isLoadingDetail, isFalse);

      expect(viewModel.hasLoaded, isFalse);
      expect(viewModel.hasMore, isTrue);

      expect(viewModel.errorMessage, isNull);
      expect(viewModel.detailErrorMessage, isNull);
      expect(viewModel.isEmpty, isTrue);
      expect(viewModel.hasTransactions, isFalse);
    });

    // ---------------------------------------------------
    // LOAD TRANSACTIONS
    // ---------------------------------------------------

    test('loads empty sales data successfully', () async {
      await viewModel.load();

      expect(viewModel.hasLoaded, isTrue);
      expect(viewModel.isLoading, isFalse);

      expect(viewModel.transactions, isEmpty);

      expect(viewModel.summary, isNotNull);
      expect(viewModel.summary!.transactionCount, 0);
      expect(viewModel.summary!.revenue, 0);
      expect(viewModel.summary!.isEmpty, isTrue);

      expect(viewModel.errorMessage, isNull);
    });

    test('loads transaction history and summary', () async {
      await createSale(quantity: 1);
      await createSale(quantity: 2);

      await viewModel.load();

      expect(viewModel.hasLoaded, isTrue);
      expect(viewModel.transactions.length, 2);

      expect(viewModel.summary!.transactionCount, 2);
      expect(viewModel.summary!.revenue, 45000);
      expect(viewModel.summary!.averageTransaction, 22500);

      expect(viewModel.isEmpty, isFalse);
      expect(viewModel.hasTransactions, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNull);
    });

    test('refreshes transaction history', () async {
      await createSale(quantity: 1);

      await viewModel.load();

      expect(viewModel.transactions.length, 1);

      await createSale(quantity: 2);

      await viewModel.refresh();

      expect(viewModel.transactions.length, 2);
      expect(viewModel.summary!.transactionCount, 2);
      expect(viewModel.summary!.revenue, 45000);
    });

    test('ensureLoaded does not reload already loaded data', () async {
      await createSale();

      await viewModel.ensureLoaded();

      expect(viewModel.transactions.length, 1);

      await createSale();

      await viewModel.ensureLoaded();

      // Tidak melakukan reload otomatis jika data sudah dimuat.
      expect(viewModel.transactions.length, 1);

      await viewModel.refresh();

      expect(viewModel.transactions.length, 2);
    });

    // ---------------------------------------------------
    // SEARCH
    // ---------------------------------------------------

    test('searches transaction by receipt number', () async {
      final firstSale = await createSale(quantity: 1);
      await createSale(quantity: 2);

      await viewModel.load();

      expect(viewModel.transactions.length, 2);

      await viewModel.setSearchQuery(firstSale.receiptNumber);

      expect(viewModel.searchQuery, firstSale.receiptNumber);
      expect(viewModel.transactions.length, 1);

      expect(
        viewModel.transactions.first.receiptNumber,
        firstSale.receiptNumber,
      );

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNull);
    });

    test('keeps summary unchanged when searching transactions', () async {
      final firstSale = await createSale(quantity: 1);
      await createSale(quantity: 2);

      await viewModel.load();

      final originalRevenue = viewModel.summary!.revenue;

      await viewModel.setSearchQuery(firstSale.receiptNumber);

      expect(viewModel.transactions.length, 1);

      // Ringkasan mengikuti filter tanggal, bukan pencarian.
      expect(viewModel.summary!.transactionCount, 2);
      expect(viewModel.summary!.revenue, originalRevenue);
    });

    test('clears transaction search', () async {
      final firstSale = await createSale(quantity: 1);
      await createSale(quantity: 2);

      await viewModel.load();

      await viewModel.setSearchQuery(firstSale.receiptNumber);

      expect(viewModel.transactions.length, 1);

      await viewModel.clearSearch();

      expect(viewModel.searchQuery, isEmpty);
      expect(viewModel.transactions.length, 2);
    });

    test('does not reload when search query remains unchanged', () async {
      await createSale();

      await viewModel.load();

      final initialTransactionIds = viewModel.transactions
          .map((sale) => sale.id)
          .toList();

      var notificationCount = 0;

      void listener() {
        notificationCount++;
      }

      viewModel.addListener(listener);

      await viewModel.setSearchQuery('');

      viewModel.removeListener(listener);

      final currentTransactionIds = viewModel.transactions
          .map((sale) => sale.id)
          .toList();

      expect(currentTransactionIds, initialTransactionIds);
      expect(notificationCount, 0);
      expect(viewModel.searchQuery, isEmpty);
    });

    // ---------------------------------------------------
    // DATE FILTER
    // ---------------------------------------------------

    test('filters transactions by date range', () async {
      await createSale(quantity: 1);
      await createSale(quantity: 2);

      final now = DateTime.now();

      final today = DateTime(now.year, now.month, now.day);

      await viewModel.setDateRange(startDate: today, endDate: today);

      expect(viewModel.startDate, today);
      expect(viewModel.endDate, today);

      expect(viewModel.transactions.length, 2);
      expect(viewModel.summary!.transactionCount, 2);
      expect(viewModel.summary!.revenue, 45000);
    });

    test('clears date range filter', () async {
      await createSale(quantity: 1);
      await createSale(quantity: 2);

      final now = DateTime.now();

      final yesterday = DateTime(now.year, now.month, now.day - 1);

      await viewModel.setDateRange(startDate: yesterday, endDate: yesterday);

      expect(viewModel.transactions, isEmpty);
      expect(viewModel.summary!.transactionCount, 0);

      await viewModel.clearDateRange();

      expect(viewModel.startDate, isNull);
      expect(viewModel.endDate, isNull);

      expect(viewModel.transactions.length, 2);
      expect(viewModel.summary!.transactionCount, 2);
    });

    test('rejects an invalid date range', () async {
      final now = DateTime.now();

      final today = DateTime(now.year, now.month, now.day);

      final tomorrow = today.add(const Duration(days: 1));

      await viewModel.setDateRange(startDate: tomorrow, endDate: today);

      expect(
        viewModel.errorMessage,
        'Tanggal akhir tidak boleh sebelum tanggal awal.',
      );

      expect(viewModel.startDate, isNull);
      expect(viewModel.endDate, isNull);
    });

    test('preserves existing date filter when new range is invalid', () async {
      await createSale();

      final now = DateTime.now();

      final today = DateTime(now.year, now.month, now.day);

      final tomorrow = today.add(const Duration(days: 1));

      await viewModel.setDateRange(startDate: today, endDate: today);

      await viewModel.setDateRange(startDate: tomorrow, endDate: today);

      expect(viewModel.startDate, today);
      expect(viewModel.endDate, today);

      expect(viewModel.transactions.length, 1);
      expect(
        viewModel.errorMessage,
        'Tanggal akhir tidak boleh sebelum tanggal awal.',
      );
    });

    // ---------------------------------------------------
    // PAGINATION
    // ---------------------------------------------------

    test('loads transaction history in pages', () async {
      for (var index = 0; index < 25; index++) {
        await createSale();
      }

      await viewModel.load();

      expect(viewModel.transactions.length, 20);
      expect(viewModel.hasMore, isTrue);
      expect(viewModel.isLoadingMore, isFalse);

      await viewModel.loadMore();

      expect(viewModel.transactions.length, 25);
      expect(viewModel.hasMore, isFalse);
      expect(viewModel.isLoadingMore, isFalse);

      final transactionIds = viewModel.transactions
          .map((sale) => sale.id)
          .toSet();

      expect(transactionIds.length, 25);
    });

    test('does not load more before initial data is loaded', () async {
      await createSale();

      await viewModel.loadMore();

      expect(viewModel.hasLoaded, isFalse);
      expect(viewModel.transactions, isEmpty);
    });

    test(
      'does not duplicate transactions when load more is called again',
      () async {
        for (var index = 0; index < 25; index++) {
          await createSale();
        }

        await viewModel.load();

        await viewModel.loadMore();
        await viewModel.loadMore();

        expect(viewModel.transactions.length, 25);

        final ids = viewModel.transactions.map((sale) => sale.id).toSet();

        expect(ids.length, 25);
      },
    );

    // ---------------------------------------------------
    // TRANSACTION DETAIL
    // ---------------------------------------------------

    test('loads transaction detail successfully', () async {
      final result = await createSale(quantity: 2);

      final detail = await viewModel.loadDetail(result.saleId);

      expect(detail, isNotNull);
      expect(viewModel.selectedDetail, same(detail));

      expect(detail!.transaction.receiptNumber, result.receiptNumber);
      expect(detail.items.length, 1);

      expect(detail.items.first.productName, 'Kopi Susu');
      expect(detail.items.first.quantity, 2);
      expect(detail.items.first.lineTotal, 30000);

      expect(viewModel.isLoadingDetail, isFalse);
      expect(viewModel.detailErrorMessage, isNull);
    });

    test('returns error when transaction detail does not exist', () async {
      final detail = await viewModel.loadDetail(99999);

      expect(detail, isNull);
      expect(viewModel.selectedDetail, isNull);
      expect(viewModel.detailErrorMessage, 'Transaksi tidak ditemukan.');
      expect(viewModel.isLoadingDetail, isFalse);
    });

    test('clears selected transaction detail', () async {
      final result = await createSale();

      await viewModel.loadDetail(result.saleId);

      expect(viewModel.selectedDetail, isNotNull);

      viewModel.clearDetail();

      expect(viewModel.selectedDetail, isNull);
      expect(viewModel.detailErrorMessage, isNull);
    });

    // ---------------------------------------------------
    // MESSAGES
    // ---------------------------------------------------

    test('clears error message', () async {
      final now = DateTime.now();

      await viewModel.setDateRange(
        startDate: now.add(const Duration(days: 1)),
        endDate: now,
      );

      expect(viewModel.errorMessage, isNotNull);

      viewModel.clearError();

      expect(viewModel.errorMessage, isNull);
    });
  });
}
