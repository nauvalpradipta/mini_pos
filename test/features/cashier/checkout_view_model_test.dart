import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mini_pos/core/database/database_schema.dart';
import 'package:mini_pos/features/cashier/models/cart_item.dart';
import 'package:mini_pos/features/cashier/models/checkout.dart';
import 'package:mini_pos/features/cashier/repositories/transaction_repository.dart';
import 'package:mini_pos/features/cashier/viewmodels/checkout_view_model.dart';
import 'package:mini_pos/features/products/repositories/category_repository.dart';
import 'package:mini_pos/features/products/repositories/product_repository.dart';

void main() {
  late Database database;
  late CategoryRepository categoryRepository;
  late ProductRepository productRepository;
  late TransactionRepository transactionRepository;
  late CheckoutViewModel viewModel;

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
    viewModel = CheckoutViewModel(transactionRepository);

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
    viewModel.dispose();
    await database.close();
  });

  CartItem buildCartItem({
    int quantity = 2,
    List<CartItemAddon> addons = const [],
  }) {
    return CartItem(
      productId: productId,
      productName: 'Kopi Susu',
      unitPrice: 15000,
      quantity: quantity,
      addons: addons,
    );
  }

  group('CheckoutViewModel', () {
    // ---------------------------------------------------
    // INITIAL STATE
    // ---------------------------------------------------

    test('has correct initial state', () {
      expect(viewModel.discountType, DiscountType.none);
      expect(viewModel.discountValue, 0);
      expect(viewModel.cashReceived, 0);
      expect(viewModel.isSubmitting, isFalse);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.result, isNull);
      expect(viewModel.hasResult, isFalse);
    });

    // ---------------------------------------------------
    // DISCOUNT
    // ---------------------------------------------------

    test('calculates percentage discount correctly', () {
      viewModel.setDiscountType(DiscountType.percentage);
      viewModel.setDiscountValue(10);

      expect(viewModel.discountAmountFor(30000), 3000);
      expect(viewModel.totalFor(30000), 27000);
      expect(viewModel.discountValidationMessage(30000), isNull);
    });

    test('calculates percentage discount with floor rounding', () {
      viewModel.setDiscountType(DiscountType.percentage);
      viewModel.setDiscountValue(15);

      expect(viewModel.discountAmountFor(10001), 1500);
      expect(viewModel.totalFor(10001), 8501);
    });

    test('calculates fixed discount correctly', () {
      viewModel.setDiscountType(DiscountType.fixed);
      viewModel.setDiscountValue(5000);

      expect(viewModel.discountAmountFor(30000), 5000);
      expect(viewModel.totalFor(30000), 25000);
      expect(viewModel.discountValidationMessage(30000), isNull);
    });

    test('does not apply discount when discount type is none', () {
      viewModel.setDiscountType(DiscountType.none);

      expect(viewModel.discountAmountFor(30000), 0);
      expect(viewModel.totalFor(30000), 30000);
    });

    test('resets discount value when discount type changes to none', () {
      viewModel.setDiscountType(DiscountType.percentage);
      viewModel.setDiscountValue(20);

      viewModel.setDiscountType(DiscountType.none);

      expect(viewModel.discountType, DiscountType.none);
      expect(viewModel.discountValue, 0);
      expect(viewModel.discountAmountFor(30000), 0);
    });

    test('rejects percentage discount above 100 percent', () {
      viewModel.setDiscountType(DiscountType.percentage);
      viewModel.setDiscountValue(101);

      expect(
        viewModel.discountValidationMessage(30000),
        'Diskon persentase maksimal 100%.',
      );

      expect(
        viewModel.canSubmit(subtotal: 30000, hasItems: true, hasCashier: true),
        isFalse,
      );
    });

    test('rejects fixed discount exceeding subtotal', () {
      viewModel.setDiscountType(DiscountType.fixed);
      viewModel.setDiscountValue(35000);

      expect(
        viewModel.discountValidationMessage(30000),
        'Diskon tidak boleh melebihi subtotal.',
      );
    });

    test('clamps negative discount value to zero', () {
      viewModel.setDiscountType(DiscountType.fixed);
      viewModel.setDiscountValue(-5000);

      expect(viewModel.discountValue, 0);
      expect(viewModel.discountValidationMessage(30000), isNull);
    });

    // ---------------------------------------------------
    // PAYMENT PREVIEW
    // ---------------------------------------------------

    test('calculates payment shortfall correctly', () {
      viewModel.setDiscountType(DiscountType.percentage);
      viewModel.setDiscountValue(10);
      viewModel.setCashReceived(25000);

      expect(viewModel.totalFor(30000), 27000);
      expect(viewModel.shortfallFor(30000), 2000);
      expect(viewModel.changeFor(30000), 0);
    });

    test('calculates change correctly', () {
      viewModel.setDiscountType(DiscountType.percentage);
      viewModel.setDiscountValue(10);
      viewModel.setCashReceived(30000);

      expect(viewModel.totalFor(30000), 27000);
      expect(viewModel.shortfallFor(30000), 0);
      expect(viewModel.changeFor(30000), 3000);
    });

    test('does not allow checkout with an invalid payment state', () {
      viewModel.setCashReceived(10000);

      expect(
        viewModel.canSubmit(subtotal: 30000, hasItems: true, hasCashier: true),
        isFalse,
      );

      viewModel.setCashReceived(30000);

      expect(
        viewModel.canSubmit(subtotal: 30000, hasItems: false, hasCashier: true),
        isFalse,
      );

      expect(
        viewModel.canSubmit(subtotal: 30000, hasItems: true, hasCashier: false),
        isFalse,
      );

      expect(
        viewModel.canSubmit(subtotal: 30000, hasItems: true, hasCashier: true),
        isTrue,
      );
    });

    test('clamps negative cash received to zero', () {
      viewModel.setCashReceived(-10000);

      expect(viewModel.cashReceived, 0);
    });

    // ---------------------------------------------------
    // SUCCESSFUL CHECKOUT
    // ---------------------------------------------------

    test('submits transaction with discount and returns change', () async {
      viewModel.setDiscountType(DiscountType.percentage);
      viewModel.setDiscountValue(10);
      viewModel.setCashReceived(30000);

      final result = await viewModel.submit(
        cashierId: cashierId,
        cartItems: [buildCartItem()],
      );

      expect(result, isNotNull);
      expect(viewModel.hasResult, isTrue);
      expect(viewModel.result, same(result));
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.isSubmitting, isFalse);

      expect(result!.subtotal, 30000);
      expect(result.discountType, DiscountType.percentage);
      expect(result.discountValue, 10);
      expect(result.discountAmount, 3000);
      expect(result.total, 27000);
      expect(result.cashReceived, 30000);
      expect(result.changeAmount, 3000);
      expect(result.receiptNumber, isNotEmpty);

      final sales = await database.query('sales');

      expect(sales.length, 1);
      expect(sales.first['subtotal'], 30000);
      expect(sales.first['discount_amount'], 3000);
      expect(sales.first['total'], 27000);
      expect(sales.first['cash_received'], 30000);
      expect(sales.first['change_amount'], 3000);

      final products = await database.query(
        'products',
        columns: ['stock_quantity'],
        where: 'id = ?',
        whereArgs: [productId],
      );

      expect(products.first['stock_quantity'], 18);
    });

    // ---------------------------------------------------
    // FAILED CHECKOUT
    // ---------------------------------------------------

    test('rejects checkout when payment is insufficient', () async {
      viewModel.setCashReceived(20000);

      final result = await viewModel.submit(
        cashierId: cashierId,
        cartItems: [buildCartItem()],
      );

      expect(result, isNull);
      expect(viewModel.errorMessage, contains('Uang pembayaran kurang'));
      expect(viewModel.hasResult, isFalse);
      expect(viewModel.isSubmitting, isFalse);

      final sales = await database.query('sales');
      expect(sales, isEmpty);

      final products = await database.query(
        'products',
        columns: ['stock_quantity'],
        where: 'id = ?',
        whereArgs: [productId],
      );

      expect(products.first['stock_quantity'], 20);
    });

    test('rejects checkout when product stock is insufficient', () async {
      viewModel.setCashReceived(400000);

      final result = await viewModel.submit(
        cashierId: cashierId,
        cartItems: [buildCartItem(quantity: 21)],
      );

      expect(result, isNull);
      expect(
        viewModel.errorMessage,
        contains('Stok Kopi Susu tidak mencukupi'),
      );
      expect(viewModel.isSubmitting, isFalse);

      final sales = await database.query('sales');
      expect(sales, isEmpty);

      final products = await database.query(
        'products',
        columns: ['stock_quantity'],
        where: 'id = ?',
        whereArgs: [productId],
      );

      expect(products.first['stock_quantity'], 20);
    });

    test('rejects checkout with an invalid cashier ID', () async {
      viewModel.setCashReceived(50000);

      final result = await viewModel.submit(
        cashierId: 99999,
        cartItems: [buildCartItem()],
      );

      expect(result, isNull);
      expect(
        viewModel.errorMessage,
        contains('Kasir tidak ditemukan atau sudah dinonaktifkan'),
      );
      expect(viewModel.isSubmitting, isFalse);
    });

    test('rejects checkout with an empty cart', () async {
      viewModel.setCashReceived(50000);

      final result = await viewModel.submit(
        cashierId: cashierId,
        cartItems: [],
      );

      expect(result, isNull);
      expect(viewModel.errorMessage, 'Keranjang masih kosong.');
    });

    test(
      'rejects checkout with invalid cashier ID before submitting',
      () async {
        viewModel.setCashReceived(50000);

        final result = await viewModel.submit(
          cashierId: 0,
          cartItems: [buildCartItem()],
        );

        expect(result, isNull);
        expect(
          viewModel.errorMessage,
          'Sesi kasir tidak valid. Silakan login kembali.',
        );
      },
    );

    // ---------------------------------------------------
    // RESET
    // ---------------------------------------------------

    test('resets checkout state', () {
      viewModel.setDiscountType(DiscountType.fixed);
      viewModel.setDiscountValue(5000);
      viewModel.setCashReceived(50000);

      viewModel.reset();

      expect(viewModel.discountType, DiscountType.none);
      expect(viewModel.discountValue, 0);
      expect(viewModel.cashReceived, 0);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.result, isNull);
      expect(viewModel.isSubmitting, isFalse);
    });
  });
}
