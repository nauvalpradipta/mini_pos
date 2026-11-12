import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mini_pos/core/database/database_schema.dart';

import 'package:mini_pos/features/cashier/models/cart_item.dart';
import 'package:mini_pos/features/cashier/models/checkout.dart';
import 'package:mini_pos/features/cashier/repositories/transaction_repository.dart';

import 'package:mini_pos/features/products/repositories/addon_repository.dart';
import 'package:mini_pos/features/products/repositories/category_repository.dart';
import 'package:mini_pos/features/products/repositories/product_repository.dart';

import 'package:mini_pos/features/sales/repositories/sales_repository.dart';
import 'package:mini_pos/features/sales/viewmodels/sales_view_model.dart';
import 'package:mini_pos/features/sales/views/sales_view.dart';

void main() {
  late Database database;

  late CategoryRepository categoryRepository;
  late ProductRepository productRepository;
  late AddonRepository addonRepository;

  late TransactionRepository transactionRepository;
  late SalesRepository salesRepository;
  late SalesViewModel viewModel;

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

    final addon = await addonRepository.create(
      name: 'Extra Shot',
      additionalPrice: 5000,
      stock: 200,
    );

    addonId = addon.id!;

    await addonRepository.setForProduct(
      productId: productId,
      addonIds: [addonId],
    );
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
    int cashReceived = 100000,
    bool includeAddon = false,
    int addonQuantityPerProduct = 1,
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
          ),
        ],
        discountType: discountType,
        discountValue: discountValue,
        cashReceived: cashReceived,
      ),
    );
  }

  Future<CheckoutResult> runDb(
    WidgetTester tester,
    Future<CheckoutResult> Function() action,
  ) async {
    final result = await tester.runAsync<CheckoutResult>(action);

    if (result == null) {
      throw StateError('Database operation returned no result.');
    }

    return result;
  }

  Future<void> pumpSalesView(WidgetTester tester) async {
    // Muat SQLite di luar FakeAsync sebelum merender UI.
    await tester.runAsync(() async {
      await viewModel.load();
    });

    expect(viewModel.hasLoaded, isTrue);
    expect(viewModel.isLoading, isFalse);

    await tester.pumpWidget(
      ChangeNotifierProvider<SalesViewModel>.value(
        value: viewModel,
        child: const MaterialApp(home: Scaffold(body: SalesView())),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> openHistoryTab(WidgetTester tester) async {
    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sales-search-field')), findsOneWidget);
  }

  Future<void> waitForSalesLoading(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 500 && viewModel.isLoading; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });

    await tester.pump();

    expect(
      viewModel.isLoading,
      isFalse,
      reason: 'Sales loading did not finish within 5 seconds.',
    );

    await tester.pumpAndSettle();
  }

  Future<void> waitForDetailLoading(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (
        var attempt = 0;
        attempt < 500 && viewModel.isLoadingDetail;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });

    await tester.pump();

    expect(
      viewModel.isLoadingDetail,
      isFalse,
      reason: 'Transaction detail did not finish within 5 seconds.',
    );

    await tester.pumpAndSettle();
  }

  group('SalesView', () {
    // ---------------------------------------------------
    // EMPTY STATE
    // ---------------------------------------------------

    testWidgets('shows empty sales summary and history', (tester) async {
      await pumpSalesView(tester);

      expect(find.text('Penjualan'), findsOneWidget);
      expect(find.text('Performa Penjualan'), findsOneWidget);

      expect(
        find.byKey(const ValueKey('sales-metric-Omzet Bersih')),
        findsOneWidget,
      );

      expect(find.text('Belum ada transaksi'), findsOneWidget);

      await openHistoryTab(tester);

      expect(find.text('Belum ada transaksi'), findsOneWidget);

      expect(
        find.byKey(const ValueKey('sales-transaction-list')),
        findsNothing,
      );
    });

    // ---------------------------------------------------
    // SALES SUMMARY
    // ---------------------------------------------------

    testWidgets('displays sales summary metrics correctly', (tester) async {
      await runDb(
        tester,
        () => createSale(
          quantity: 2,
          discountType: DiscountType.percentage,
          discountValue: 10,
          cashReceived: 30000,
        ),
      );

      await runDb(
        tester,
        () => createSale(
          quantity: 1,
          discountType: DiscountType.fixed,
          discountValue: 5000,
          cashReceived: 15000,
        ),
      );

      await pumpSalesView(tester);

      // Total omzet bersih = Rp37.000.
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('sales-metric-Omzet Bersih')),
            )
            .data,
        'Rp37.000',
      );

      // Jumlah transaksi = 2.
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('sales-metric-Transaksi')))
            .data,
        '2',
      );

      // Total diskon = Rp8.000.
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('sales-metric-Total Diskon')),
            )
            .data,
        'Rp8.000',
      );

      // Rata-rata transaksi = Rp18.500.
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('sales-metric-Rata-rata Transaksi')),
            )
            .data,
        'Rp18.500',
      );

      expect(find.text('Transaksi Terbaru'), findsOneWidget);
    });

    // ---------------------------------------------------
    // TRANSACTION HISTORY
    // ---------------------------------------------------

    testWidgets('displays transaction history', (tester) async {
      final firstSale = await runDb(tester, () => createSale(quantity: 1));

      final secondSale = await runDb(tester, () => createSale(quantity: 2));

      await pumpSalesView(tester);
      await openHistoryTab(tester);

      expect(
        find.byKey(ValueKey('sales-transaction-${firstSale.saleId}')),
        findsOneWidget,
      );

      expect(
        find.byKey(ValueKey('sales-transaction-${secondSale.saleId}')),
        findsOneWidget,
      );

      expect(find.text(firstSale.receiptNumber), findsOneWidget);

      expect(find.text(secondSale.receiptNumber), findsOneWidget);

      expect(find.textContaining('Test Cashier'), findsNWidgets(2));
    });

    // ---------------------------------------------------
    // SEARCH
    // ---------------------------------------------------

    testWidgets('searches and clears transaction history', (tester) async {
      final firstSale = await runDb(tester, () => createSale(quantity: 1));

      await runDb(tester, () => createSale(quantity: 2));

      await pumpSalesView(tester);
      await openHistoryTab(tester);

      expect(viewModel.transactions.length, 2);

      final searchField = find.byKey(const ValueKey('sales-search-field'));

      await tester.enterText(searchField, firstSale.receiptNumber);

      await tester.pump();

      await waitForSalesLoading(tester);

      expect(viewModel.transactions.length, 1);

      expect(
        find.byKey(ValueKey('sales-transaction-${firstSale.saleId}')),
        findsOneWidget,
      );

      expect(find.text('Tidak ada transaksi'), findsNothing);
      expect(viewModel.summary!.transactionCount, 2);

      await tester.tap(find.byTooltip('Hapus pencarian'));
      await tester.pump();

      await waitForSalesLoading(tester);

      expect(viewModel.searchQuery, isEmpty);
      expect(viewModel.transactions.length, 2);
    });

    // ---------------------------------------------------
    // DATE FILTER
    // ---------------------------------------------------

    testWidgets('opens date range picker and can cancel it', (tester) async {
      await pumpSalesView(tester);

      await tester.tap(find.byTooltip('Pilih periode tanggal'));

      await tester.pumpAndSettle();

      final datePicker = find.byType(DateRangePickerDialog);

      expect(datePicker, findsOneWidget);

      // Tutup date picker melalui Navigator tanpa memilih tanggal.
      final dialogContext = tester.element(datePicker);

      Navigator.of(dialogContext).pop();

      await tester.pumpAndSettle();

      expect(find.byType(DateRangePickerDialog), findsNothing);
      expect(viewModel.startDate, isNull);
      expect(viewModel.endDate, isNull);
    });

    // ---------------------------------------------------
    // TRANSACTION DETAIL
    // ---------------------------------------------------

    testWidgets('opens transaction detail with product and add-on snapshots', (
      tester,
    ) async {
      final result = await runDb(
        tester,
        () => createSale(
          quantity: 2,
          includeAddon: true,
          addonQuantityPerProduct: 2,
          cashReceived: 60000,
        ),
      );

      await pumpSalesView(tester);
      await openHistoryTab(tester);

      final transactionCard = find.byKey(
        ValueKey('sales-transaction-${result.saleId}'),
      );

      await tester.tap(transactionCard);
      await tester.pump();

      await waitForDetailLoading(tester);

      expect(find.text('Detail Transaksi'), findsOneWidget);
      expect(find.text('KASIRKU POS'), findsOneWidget);
      expect(find.text('Test Cashier'), findsOneWidget);

      expect(find.text('Kopi Susu × 2'), findsOneWidget);
      expect(find.text('+ Extra Shot × 4'), findsOneWidget);

      expect(find.text('Rp30.000'), findsWidgets);
      expect(find.text('Rp20.000'), findsWidgets);
      expect(find.text('Rp50.000'), findsWidgets);
      expect(find.text('Rp60.000'), findsOneWidget);
      expect(find.text('Rp10.000'), findsWidgets);

      final closeButton = find.byKey(const ValueKey('sale-detail-close'));

      await tester.ensureVisible(closeButton);
      await tester.pumpAndSettle();

      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(find.text('Detail Transaksi'), findsNothing);
      expect(viewModel.selectedDetail, isNull);
    });
  });
}
