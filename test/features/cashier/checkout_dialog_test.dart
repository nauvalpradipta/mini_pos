import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mini_pos/core/database/database_schema.dart';
import 'package:mini_pos/features/cashier/models/cart_item.dart';
import 'package:mini_pos/features/cashier/models/checkout.dart';
import 'package:mini_pos/features/cashier/repositories/transaction_repository.dart';
import 'package:mini_pos/features/cashier/viewmodels/checkout_view_model.dart';
import 'package:mini_pos/features/cashier/views/checkout_dialog.dart';
import 'package:mini_pos/features/products/repositories/category_repository.dart';
import 'package:mini_pos/features/products/repositories/product_repository.dart';

void main() {
  late Database database;
  late CategoryRepository categoryRepository;
  late ProductRepository productRepository;
  late TransactionRepository transactionRepository;
  late CheckoutViewModel checkoutViewModel;

  late int cashierId;
  late int productId;

  CheckoutResult? dialogResult;

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

    checkoutViewModel = CheckoutViewModel(transactionRepository);

    dialogResult = null;

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
      stock: 20,
    );

    productId = product.id!;
  });

  tearDown(() async {
    checkoutViewModel.dispose();
    await database.close();
  });

  CartItem buildCartItem({int quantity = 2}) {
    return CartItem(
      productId: productId,
      productName: 'Kopi Susu',
      unitPrice: 15000,
      quantity: quantity,
    );
  }

  Widget buildSubject({int quantity = 2}) {
    final cartItems = [buildCartItem(quantity: quantity)];

    return ChangeNotifierProvider<CheckoutViewModel>.value(
      value: checkoutViewModel,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Center(
                child: FilledButton(
                  key: const ValueKey('open-checkout-test'),
                  onPressed: () async {
                    dialogResult = await showDialog<CheckoutResult>(
                      context: context,
                      builder: (_) => CheckoutDialog(
                        cashierId: cashierId,
                        cartItems: cartItems,
                      ),
                    );
                  },
                  child: const Text('Buka pembayaran'),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('open-checkout-test')));
    await tester.pumpAndSettle();

    expect(find.text('Pembayaran'), findsOneWidget);
  }

  Future<void> waitForSubmission(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (
        var attempt = 0;
        attempt < 500 && checkoutViewModel.isSubmitting;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });

    await tester.pump();

    expect(
      checkoutViewModel.isSubmitting,
      isFalse,
      reason: 'Checkout did not finish within 5 seconds.',
    );

    await tester.pumpAndSettle();
  }

  Future<void> selectDiscountType(
    WidgetTester tester,
    DiscountType type,
  ) async {
    final label = switch (type) {
      DiscountType.none => 'Tanpa diskon',
      DiscountType.percentage => 'Persentase (%)',
      DiscountType.fixed => 'Nominal (Rp)',
    };

    await tester.ensureVisible(
      find.byKey(const ValueKey('checkout-discount-type')),
    );

    await tester.tap(find.byKey(const ValueKey('checkout-discount-type')));

    await tester.pumpAndSettle();

    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> enterDiscount(WidgetTester tester, String value) async {
    final finder = find.byKey(const ValueKey('checkout-discount-field'));

    await tester.ensureVisible(finder);
    await tester.enterText(finder, value);
    await tester.pump();
  }

  Future<void> enterCash(WidgetTester tester, String value) async {
    final finder = find.byKey(const ValueKey('checkout-cash-field'));

    await tester.ensureVisible(finder);
    await tester.enterText(finder, value);
    await tester.pump();
  }

  Future<void> submitCheckout(WidgetTester tester) async {
    final finder = find.byKey(const ValueKey('checkout-submit-button'));

    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();

    await tester.tap(finder);
    await tester.pump();

    await waitForSubmission(tester);
  }

  group('CheckoutDialog', () {
    testWidgets('displays transaction summary and disables payment initially', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await openDialog(tester);

      expect(find.text('Rp30.000'), findsWidgets);

      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('checkout-submit-button')),
      );

      expect(button.onPressed, isNull);
      expect(find.text('Uang diterima'), findsOneWidget);
    });

    testWidgets('calculates percentage discount correctly', (tester) async {
      await tester.pumpWidget(buildSubject());
      await openDialog(tester);

      await selectDiscountType(tester, DiscountType.percentage);
      await enterDiscount(tester, '10');

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('checkout-total'))).data,
        'Rp27.000',
      );

      await enterCash(tester, '30000');

      expect(find.text('Kembalian: Rp3.000'), findsOneWidget);

      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('checkout-submit-button')),
      );

      expect(button.onPressed, isNotNull);
    });

    testWidgets('calculates fixed discount correctly', (tester) async {
      await tester.pumpWidget(buildSubject());
      await openDialog(tester);

      await selectDiscountType(tester, DiscountType.fixed);
      await enterDiscount(tester, '5000');

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('checkout-total'))).data,
        'Rp25.000',
      );

      await enterCash(tester, '25000');

      expect(find.text('Kembalian: Rp0'), findsOneWidget);
    });

    testWidgets('rejects discount percentage above 100 percent', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await openDialog(tester);

      await selectDiscountType(tester, DiscountType.percentage);
      await enterDiscount(tester, '150');

      expect(find.text('Diskon persentase maksimal 100%.'), findsOneWidget);

      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('checkout-submit-button')),
      );

      expect(button.onPressed, isNull);
    });

    testWidgets('submits payment and closes dialog after success', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await openDialog(tester);

      await enterCash(tester, '50000');

      await submitCheckout(tester);

      expect(find.text('Pembayaran'), findsNothing);
      expect(dialogResult, isNotNull);

      expect(dialogResult!.subtotal, 30000);
      expect(dialogResult!.total, 30000);
      expect(dialogResult!.cashReceived, 50000);
      expect(dialogResult!.changeAmount, 20000);

      final sales = await tester.runAsync(() => database.query('sales'));

      expect(sales!.length, 1);

      final products = await tester.runAsync(
        () => database.query(
          'products',
          columns: ['stock_quantity'],
          where: 'id = ?',
          whereArgs: [productId],
        ),
      );

      expect(products!.first['stock_quantity'], 18);
    });

    testWidgets('keeps dialog open when product stock is insufficient', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(quantity: 21));
      await openDialog(tester);

      await enterCash(tester, '400000');

      await submitCheckout(tester);

      expect(find.text('Pembayaran'), findsOneWidget);
      expect(
        find.text(
          'Stok Kopi Susu tidak mencukupi. '
          'Diminta 21, tersedia 20.',
        ),
        findsOneWidget,
      );

      expect(dialogResult, isNull);

      final sales = await tester.runAsync(() => database.query('sales'));

      expect(sales, isEmpty);
    });

    testWidgets('closes dialog without creating a transaction when canceled', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await openDialog(tester);

      final cancelButton = find.byKey(const ValueKey('checkout-cancel-button'));

      // Scroll dialog sampai tombol Batal terlihat.
      await tester.ensureVisible(cancelButton);
      await tester.pumpAndSettle();

      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      expect(find.text('Pembayaran'), findsNothing);
      expect(dialogResult, isNull);

      final sales = await tester.runAsync(() => database.query('sales'));

      expect(sales, isEmpty);
    });
  });
}
