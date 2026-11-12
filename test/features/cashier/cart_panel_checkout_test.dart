import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mini_pos/core/database/database_schema.dart';

import 'package:mini_pos/features/auth/repositories/auth_repository.dart';
import 'package:mini_pos/features/auth/services/password_hasher.dart';
import 'package:mini_pos/features/auth/services/session_service.dart';
import 'package:mini_pos/features/auth/viewmodels/auth_view_model.dart';

import 'package:mini_pos/features/cashier/viewmodels/cart_view_model.dart';
import 'package:mini_pos/features/cashier/viewmodels/checkout_view_model.dart';
import 'package:mini_pos/features/cashier/repositories/transaction_repository.dart';
import 'package:mini_pos/features/cashier/views/cart_panel.dart';

import 'package:mini_pos/features/products/repositories/category_repository.dart';
import 'package:mini_pos/features/products/repositories/product_repository.dart';

void main() {
  late Database database;

  late AuthViewModel authViewModel;
  late CartViewModel cartViewModel;
  late CheckoutViewModel checkoutViewModel;

  late CategoryRepository categoryRepository;
  late ProductRepository productRepository;
  late TransactionRepository transactionRepository;

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

    cartViewModel = CartViewModel();
    checkoutViewModel = CheckoutViewModel(transactionRepository);

    final now = DateTime.now().millisecondsSinceEpoch;

    // Buat akun kasir aktif.
    cashierId = await database.insert('users', {
      'full_name': 'Test Cashier',
      'username': 'cashier_test',
      'password_hash': 'test_hash',
      'password_salt': 'test_salt',
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });

    // Siapkan sesi login menggunakan SharedPreferences mock.
    SharedPreferences.setMockInitialValues({'session_user_id': cashierId});

    final preferences = await SharedPreferences.getInstance();

    final authRepository = AuthRepository(database, PasswordHasher());

    final sessionService = SessionService(preferences);

    authViewModel = AuthViewModel(authRepository, sessionService);

    await authViewModel.restoreSession();

    expect(authViewModel.isAuthenticated, isTrue);
    expect(authViewModel.currentUser?.id, cashierId);

    // Buat kategori dan produk.
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
    authViewModel.dispose();
    cartViewModel.dispose();
    checkoutViewModel.dispose();

    await database.close();
  });

  void setViewport(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1100);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget buildSubject() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthViewModel>.value(value: authViewModel),
        ChangeNotifierProvider<CartViewModel>.value(value: cartViewModel),
        ChangeNotifierProvider<CheckoutViewModel>.value(
          value: checkoutViewModel,
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 420, height: 1000, child: const CartPanel()),
          ),
        ),
      ),
    );
  }

  Future<void> openCheckout(WidgetTester tester) async {
    final button = find.byKey(const ValueKey('cart-checkout-button'));

    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('Pembayaran'), findsOneWidget);
  }

  Future<void> enterCash(WidgetTester tester, String amount) async {
    final field = find.byKey(const ValueKey('checkout-cash-field'));

    await tester.ensureVisible(field);
    await tester.enterText(field, amount);
    await tester.pump();
  }

  Future<void> submitCheckout(WidgetTester tester) async {
    final button = find.byKey(const ValueKey('checkout-submit-button'));

    await tester.ensureVisible(button);
    await tester.pumpAndSettle();

    await tester.tap(button);
    await tester.pump();

    // Tunggu operasi SQLite selesai.
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

  group('CartPanel checkout integration', () {
    // ---------------------------------------------------
    // 1. CHECKOUT BERHASIL
    // ---------------------------------------------------

    testWidgets(
      'successful checkout saves transaction, deducts stock, clears cart and displays receipt',
      (tester) async {
        setViewport(tester);

        await tester.runAsync(() async {
          await database.update(
            'app_settings',
            {
              'store_name': 'Kopi Kita',
              'address': 'Jl. Malioboro No. 10',
              'phone': '081234567890',
            },
            where: 'id = ?',
            whereArgs: [1],
          );
        });

        // Tambahkan satu produk ke keranjang.
        final products = await tester.runAsync(
          () => productRepository.getAll(),
        );

        final product = products!.firstWhere((item) => item.id == productId);

        cartViewModel.addProduct(product);

        await tester.pumpWidget(buildSubject());

        expect(cartViewModel.itemCount, 1);
        expect(cartViewModel.subtotal, 15000);

        // Buka dialog pembayaran.
        await openCheckout(tester);

        // Bayar Rp20.000.
        await enterCash(tester, '20000');

        expect(find.text('Kembalian: Rp5.000'), findsOneWidget);

        // Proses transaksi.
        await submitCheckout(tester);

        // Pastikan struk berhasil ditampilkan.
        expect(find.text('Transaksi berhasil'), findsOneWidget);
        expect(find.text('Kopi Kita'), findsOneWidget);
        expect(find.text('Jl. Malioboro No. 10'), findsOneWidget);
        expect(find.text('081234567890'), findsOneWidget);
        expect(find.text('Test Cashier'), findsOneWidget);
        expect(find.text('Rp15.000'), findsWidgets);
        expect(find.text('Rp20.000'), findsOneWidget);
        expect(find.text('Rp5.000'), findsOneWidget);

        // Keranjang sudah dikosongkan setelah transaksi tersimpan.
        expect(cartViewModel.isEmpty, isTrue);
        expect(cartViewModel.subtotal, 0);

        // Pastikan transaksi tersimpan.
        final sales = await tester.runAsync(() => database.query('sales'));

        expect(sales, isNotNull);
        expect(sales!.length, 1);

        expect(sales.first['cashier_id'], cashierId);
        expect(sales.first['subtotal'], 15000);
        expect(sales.first['total'], 15000);
        expect(sales.first['cash_received'], 20000);
        expect(sales.first['change_amount'], 5000);

        // Pastikan stok produk berkurang.
        final updatedProducts = await tester.runAsync(
          () => database.query(
            'products',
            columns: ['stock_quantity'],
            where: 'id = ?',
            whereArgs: [productId],
          ),
        );

        expect(updatedProducts!.first['stock_quantity'], 19);

        // Tutup struk.
        final doneButton = find.byKey(const ValueKey('receipt-done-button'));

        await tester.ensureVisible(doneButton);
        await tester.tap(doneButton);
        await tester.pumpAndSettle();

        expect(find.text('Transaksi berhasil'), findsNothing);
        expect(cartViewModel.isEmpty, isTrue);
      },
    );

    // ---------------------------------------------------
    // 2. CHECKOUT GAGAL KARENA STOK KURANG
    // ---------------------------------------------------

    testWidgets(
      'failed checkout preserves cart and does not save transaction',
      (tester) async {
        setViewport(tester);

        // Ambil produk ketika stok database masih mencukupi.
        final products = await tester.runAsync(
          () => productRepository.getAll(),
        );

        final product = products!.firstWhere((item) => item.id == productId);

        // Masukkan dua unit ke keranjang ketika stok masih mencukupi.
        cartViewModel.addProduct(product);

        final item = cartViewModel.items.first;
        cartViewModel.setQuantity(item, 2);

        expect(cartViewModel.itemCount, 2);

        // Simulasikan stok database berubah setelah produk masuk keranjang.
        await tester.runAsync(() async {
          await database.update(
            'products',
            {'stock_quantity': 1},
            where: 'id = ?',
            whereArgs: [productId],
          );
        });

        await tester.pumpWidget(buildSubject());

        expect(cartViewModel.itemCount, 2);
        expect(cartViewModel.subtotal, 30000);

        await openCheckout(tester);
        await enterCash(tester, '30000');
        await submitCheckout(tester);

        // Dialog tetap terbuka dengan pesan kesalahan.
        expect(find.text('Pembayaran'), findsOneWidget);

        expect(
          find.text(
            'Stok Kopi Susu tidak mencukupi. '
            'Diminta 2, tersedia 1.',
          ),
          findsOneWidget,
        );

        // Keranjang harus tetap utuh.
        expect(cartViewModel.isNotEmpty, isTrue);
        expect(cartViewModel.itemCount, 2);
        expect(cartViewModel.subtotal, 30000);

        // Tidak boleh ada transaksi tersimpan.
        final sales = await tester.runAsync(() => database.query('sales'));
        expect(sales, isEmpty);

        // Stok database tidak boleh berubah.
        final updatedProducts = await tester.runAsync(
          () => database.query(
            'products',
            columns: ['stock_quantity'],
            where: 'id = ?',
            whereArgs: [productId],
          ),
        );

        expect(updatedProducts!.first['stock_quantity'], 1);

        // Tutup dialog pembayaran.
        final cancelButton = find.byKey(
          const ValueKey('checkout-cancel-button'),
        );

        await tester.ensureVisible(cancelButton);
        await tester.tap(cancelButton);
        await tester.pumpAndSettle();

        // Keranjang masih harus utuh setelah dialog ditutup.
        expect(cartViewModel.isNotEmpty, isTrue);
        expect(cartViewModel.itemCount, 2);
      },
    );

    // ---------------------------------------------------
    // 3. PEMBAYARAN DIBATALKAN
    // ---------------------------------------------------

    testWidgets(
      'canceled payment preserves cart and does not create transaction',
      (tester) async {
        setViewport(tester);

        final products = await tester.runAsync(
          () => productRepository.getAll(),
        );

        final product = products!.firstWhere((item) => item.id == productId);

        cartViewModel.addProduct(product);

        await tester.pumpWidget(buildSubject());

        await openCheckout(tester);

        // Batalkan dialog tanpa melakukan pembayaran.
        final cancelButton = find.byKey(
          const ValueKey('checkout-cancel-button'),
        );

        await tester.ensureVisible(cancelButton);
        await tester.tap(cancelButton);
        await tester.pumpAndSettle();

        expect(find.text('Pembayaran'), findsNothing);

        // Keranjang tidak boleh berubah.
        expect(cartViewModel.isNotEmpty, isTrue);
        expect(cartViewModel.itemCount, 1);
        expect(cartViewModel.subtotal, 15000);

        // Database tidak boleh mencatat transaksi.
        final sales = await tester.runAsync(() => database.query('sales'));

        expect(sales, isEmpty);

        // Stok tetap utuh.
        final updatedProducts = await tester.runAsync(
          () => database.query(
            'products',
            columns: ['stock_quantity'],
            where: 'id = ?',
            whereArgs: [productId],
          ),
        );

        expect(updatedProducts!.first['stock_quantity'], 20);
      },
    );
  });
}
