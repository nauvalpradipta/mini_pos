import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mini_pos/core/database/database_schema.dart';

import 'package:mini_pos/features/cashier/models/cart_item.dart';
import 'package:mini_pos/features/cashier/models/checkout.dart';
import 'package:mini_pos/features/cashier/repositories/transaction_repository.dart';

import 'package:mini_pos/features/products/repositories/addon_repository.dart';
import 'package:mini_pos/features/products/repositories/category_repository.dart';
import 'package:mini_pos/features/products/repositories/product_repository.dart';

import 'package:mini_pos/features/sales/repositories/sales_repository.dart';

void main() {
  late Database database;

  late CategoryRepository categoryRepository;
  late ProductRepository productRepository;
  late AddonRepository addonRepository;

  late TransactionRepository transactionRepository;
  late SalesRepository salesRepository;

  late int cashierId;
  late int productId;
  late int addonId;

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
    addonRepository = AddonRepository(database);

    transactionRepository = TransactionRepository(database);
    salesRepository = SalesRepository(database);

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
      stock: 100,
    );

    productId = product.id!;

    final addon = await addonRepository.create(
      name: 'Extra Shot',
      additionalPrice: 5000,
      stock: 100,
    );

    addonId = addon.id!;

    await addonRepository.setForProduct(
      productId: productId,
      addonIds: [addonId],
    );
  });

  tearDown(() async {
    await database.close();
  });

  // ---------------------------------------------------
  // HELPERS
  // ---------------------------------------------------

  CartItem buildCartItem({
    int quantity = 1,
    bool includeAddon = false,
    int addonQuantityPerProduct = 1,
  }) {
    return CartItem(
      productId: productId,
      productName: 'Kopi Susu',
      unitPrice: 15000,
      quantity: quantity,
      addons: includeAddon
          ? [
              CartItemAddon(
                addonId: addonId,
                addonName: 'Extra Shot',
                additionalPrice: 5000,
                quantityPerProduct: addonQuantityPerProduct,
              ),
            ]
          : [],
    );
  }

  Future<CheckoutResult> createSale({
    int quantity = 1,
    DiscountType discountType = DiscountType.none,
    int discountValue = 0,
    int cashReceived = 100000,
    bool includeAddon = false,
    int addonQuantityPerProduct = 1,
  }) {
    return transactionRepository.checkout(
      CheckoutRequest(
        cashierId: cashierId,
        cartItems: [
          buildCartItem(
            quantity: quantity,
            includeAddon: includeAddon,
            addonQuantityPerProduct: addonQuantityPerProduct,
          ),
        ],
        discountType: discountType,
        discountValue: discountValue,
        cashReceived: cashReceived,
      ),
    );
  }

  group('SalesRepository', () {
    // ---------------------------------------------------
    // TRANSACTION HISTORY
    // ---------------------------------------------------

    test('returns an empty transaction history', () async {
      final transactions = await salesRepository.getTransactions();

      expect(transactions, isEmpty);
    });

    test('returns transactions with newest transaction first', () async {
      final firstSale = await createSale(quantity: 1);
      final secondSale = await createSale(quantity: 2);
      final thirdSale = await createSale(quantity: 3);

      final transactions = await salesRepository.getTransactions();

      expect(transactions.length, 3);

      expect(transactions[0].receiptNumber, thirdSale.receiptNumber);
      expect(transactions[1].receiptNumber, secondSale.receiptNumber);
      expect(transactions[2].receiptNumber, firstSale.receiptNumber);
    });

    test('searches transactions by receipt number and cashier name', () async {
      final firstSale = await createSale(quantity: 1);
      await createSale(quantity: 2);

      final byReceipt = await salesRepository.getTransactions(
        searchQuery: firstSale.receiptNumber,
      );

      expect(byReceipt.length, 1);
      expect(byReceipt.first.receiptNumber, firstSale.receiptNumber);

      final byCashier = await salesRepository.getTransactions(
        searchQuery: 'tEsT cAsHiEr',
      );

      expect(byCashier.length, 2);
      expect(
        byCashier.every((sale) => sale.cashierName == 'Test Cashier'),
        isTrue,
      );
    });

    // ---------------------------------------------------
    // DATE FILTER
    // ---------------------------------------------------

    test('filters transactions using inclusive date range', () async {
      await createSale();

      final now = DateTime.now();

      final today = DateTime(now.year, now.month, now.day);

      final yesterday = today.subtract(const Duration(days: 1));

      final todayTransactions = await salesRepository.getTransactions(
        startDate: today,
        endDate: today,
      );

      final yesterdayTransactions = await salesRepository.getTransactions(
        startDate: yesterday,
        endDate: yesterday,
      );

      expect(todayTransactions.length, 1);
      expect(yesterdayTransactions, isEmpty);
    });

    test('rejects a date range where start date is after end date', () async {
      final now = DateTime.now();

      final today = DateTime(now.year, now.month, now.day);

      final tomorrow = today.add(const Duration(days: 1));

      expect(
        () => salesRepository.getTransactions(
          startDate: tomorrow,
          endDate: today,
        ),
        throwsArgumentError,
      );

      expect(
        () => salesRepository.getSummary(startDate: tomorrow, endDate: today),
        throwsArgumentError,
      );
    });

    // ---------------------------------------------------
    // PAGINATION
    // ---------------------------------------------------

    test('paginates transaction history without duplicates', () async {
      final firstSale = await createSale(quantity: 1);
      final secondSale = await createSale(quantity: 2);
      final thirdSale = await createSale(quantity: 3);

      final firstPage = await salesRepository.getTransactions(
        limit: 2,
        offset: 0,
      );

      final secondPage = await salesRepository.getTransactions(
        limit: 2,
        offset: 2,
      );

      expect(firstPage.length, 2);
      expect(secondPage.length, 1);

      expect(firstPage[0].receiptNumber, thirdSale.receiptNumber);

      expect(firstPage[1].receiptNumber, secondSale.receiptNumber);

      expect(secondPage[0].receiptNumber, firstSale.receiptNumber);
    });

    test('rejects invalid pagination parameters', () async {
      expect(
        () => salesRepository.getTransactions(limit: 0),
        throwsArgumentError,
      );

      expect(
        () => salesRepository.getTransactions(offset: -1),
        throwsArgumentError,
      );
    });

    // ---------------------------------------------------
    // SALES SUMMARY
    // ---------------------------------------------------

    test('returns zero summary when no transactions exist', () async {
      final summary = await salesRepository.getSummary();

      expect(summary.transactionCount, 0);
      expect(summary.revenue, 0);
      expect(summary.totalDiscount, 0);
      expect(summary.averageTransaction, 0);
      expect(summary.isEmpty, isTrue);
    });

    test('calculates sales summary correctly', () async {
      // Subtotal Rp30.000, diskon 10% = Rp3.000.
      // Total transaksi pertama = Rp27.000.
      await createSale(
        quantity: 2,
        discountType: DiscountType.percentage,
        discountValue: 10,
        cashReceived: 30000,
      );

      // Subtotal Rp15.000, diskon tetap Rp5.000.
      // Total transaksi kedua = Rp10.000.
      await createSale(
        quantity: 1,
        discountType: DiscountType.fixed,
        discountValue: 5000,
        cashReceived: 15000,
      );

      final summary = await salesRepository.getSummary();

      expect(summary.transactionCount, 2);

      // Omzet bersih = Rp27.000 + Rp10.000.
      expect(summary.revenue, 37000);

      // Total diskon = Rp3.000 + Rp5.000.
      expect(summary.totalDiscount, 8000);

      // Rata-rata = Rp37.000 / 2.
      expect(summary.averageTransaction, 18500);

      expect(summary.isEmpty, isFalse);
    });

    test('calculates summary for selected date range', () async {
      await createSale(quantity: 1);
      await createSale(quantity: 2);

      final now = DateTime.now();

      final today = DateTime(now.year, now.month, now.day);

      final yesterday = today.subtract(const Duration(days: 1));

      final todaySummary = await salesRepository.getSummary(
        startDate: today,
        endDate: today,
      );

      final yesterdaySummary = await salesRepository.getSummary(
        startDate: yesterday,
        endDate: yesterday,
      );

      expect(todaySummary.transactionCount, 2);
      expect(todaySummary.revenue, 45000);

      expect(yesterdaySummary.transactionCount, 0);
      expect(yesterdaySummary.revenue, 0);
    });

    // ---------------------------------------------------
    // TRANSACTION DETAIL
    // ---------------------------------------------------

    test(
      'returns transaction detail with product and add-on snapshots',
      () async {
        final result = await createSale(
          quantity: 2,
          includeAddon: true,
          addonQuantityPerProduct: 2,
          cashReceived: 60000,
        );

        final detail = await salesRepository.getDetail(result.saleId);

        expect(detail, isNotNull);

        final transaction = detail!.transaction;

        expect(transaction.id, result.saleId);
        expect(transaction.receiptNumber, result.receiptNumber);
        expect(transaction.cashierName, 'Test Cashier');

        expect(transaction.storeName, 'KASIRKU POS');

        expect(transaction.subtotal, 50000);
        expect(transaction.discountAmount, 0);
        expect(transaction.total, 50000);
        expect(transaction.cashReceived, 60000);
        expect(transaction.changeAmount, 10000);

        expect(detail.items.length, 1);

        final item = detail.items.first;

        expect(item.productId, productId);
        expect(item.productName, 'Kopi Susu');
        expect(item.unitPrice, 15000);
        expect(item.quantity, 2);
        expect(item.baseSubtotal, 30000);
        expect(item.addonsSubtotal, 20000);
        expect(item.lineTotal, 50000);

        expect(item.addons.length, 1);

        final addon = item.addons.first;

        expect(addon.addonId, addonId);
        expect(addon.addonName, 'Extra Shot');
        expect(addon.unitPrice, 5000);
        expect(addon.quantityPerProduct, 2);
        expect(addon.totalQuantity, 4);
        expect(addon.subtotal, 20000);
      },
    );

    test('returns null when transaction does not exist', () async {
      final detail = await salesRepository.getDetail(99999);

      expect(detail, isNull);
    });

    test('rejects an invalid transaction ID', () async {
      expect(() => salesRepository.getDetail(0), throwsArgumentError);

      expect(() => salesRepository.getDetail(-1), throwsArgumentError);
    });
  });
}
