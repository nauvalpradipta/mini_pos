import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mini_pos/core/database/database_schema.dart';
import 'package:mini_pos/features/products/repositories/category_repository.dart';
import 'package:mini_pos/features/products/repositories/product_repository.dart';
import 'package:mini_pos/features/cashier/viewmodels/cashier_catalog_view_model.dart';
import 'package:mini_pos/features/cashier/views/cashier_view.dart';
import 'package:mini_pos/features/products/repositories/addon_repository.dart';
import 'package:mini_pos/features/cashier/viewmodels/cart_view_model.dart';
import 'package:mini_pos/features/products/viewmodels/addon_management_view_model.dart';

void main() {
  late Database database;
  late CategoryRepository categoryRepository;
  late ProductRepository productRepository;
  late CashierCatalogViewModel viewModel;
  late AddonRepository addonRepository;
  late AddonManagementViewModel addonViewModel;
  late CartViewModel cartViewModel;

  late int foodCategoryId;
  late int drinkCategoryId;

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
    addonViewModel = AddonManagementViewModel(addonRepository);
    cartViewModel = CartViewModel();

    foodCategoryId = await categoryRepository.create(
      name: 'Makanan',
      description: 'Produk makanan',
    );

    drinkCategoryId = await categoryRepository.create(
      name: 'Minuman',
      description: 'Produk minuman',
    );

    viewModel = CashierCatalogViewModel(categoryRepository, productRepository);
  });

  tearDown(() async {
    viewModel.dispose();
    addonViewModel.dispose();
    cartViewModel.dispose();
    await database.close();
  });

  Future<T> runDb<T>(WidgetTester tester, Future<T> Function() action) async {
    final result = await tester.runAsync<T>(action);
    return result as T;
  }

  void setViewport(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpCashierView(WidgetTester tester) async {
    await tester.runAsync(() async {
      await viewModel.load();
      await addonViewModel.load();
    });

    expect(viewModel.isLoading, isFalse);
    expect(addonViewModel.isLoading, isFalse);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CashierCatalogViewModel>.value(
            value: viewModel,
          ),
          ChangeNotifierProvider<AddonManagementViewModel>.value(
            value: addonViewModel,
          ),
          ChangeNotifierProvider<CartViewModel>.value(value: cartViewModel),
        ],
        child: const MaterialApp(
          home: Scaffold(body: CashierView(loadOnInit: false)),
        ),
      ),
    );

    await tester.pump();
  }

  Future<void> waitForLoading(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 500 && viewModel.isLoading; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });

    await tester.pump();

    expect(
      viewModel.isLoading,
      isFalse,
      reason: 'Catalog loading did not finish within 5 seconds.',
    );
  }

  Future<void> waitForAssignmentLoading(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (
        var attempt = 0;
        attempt < 500 && addonViewModel.isLoadingAssignments;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });

    await tester.pump();

    expect(
      addonViewModel.isLoadingAssignments,
      isFalse,
      reason: 'Assigned add-ons did not finish loading within 5 seconds.',
    );

    await tester.pumpAndSettle();
  }

  Future<void> seedProducts(WidgetTester tester) async {
    await runDb(tester, () async {
      await productRepository.create(
        categoryId: drinkCategoryId,
        name: 'Kopi Susu',
        sellingPrice: 15000,
        stock: 20,
      );

      await productRepository.create(
        categoryId: drinkCategoryId,
        name: 'Kopi Hitam',
        sellingPrice: 10000,
        stock: 0,
      );

      await productRepository.create(
        categoryId: foodCategoryId,
        name: 'Roti Bakar',
        sellingPrice: 12000,
        stock: 10,
      );
    });
  }

  group('CashierView', () {
    testWidgets('shows an empty catalog message', (tester) async {
      await pumpCashierView(tester);

      expect(find.text('Pilih Produk'), findsOneWidget);
      expect(find.text('Belum ada produk'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('cashier-search-field')),
        findsOneWidget,
      );
    });

    testWidgets('displays active products with category and price', (
      tester,
    ) async {
      await seedProducts(tester);
      await pumpCashierView(tester);

      expect(find.text('Kopi Susu'), findsOneWidget);
      expect(find.text('Kopi Hitam'), findsOneWidget);
      expect(find.text('Roti Bakar'), findsOneWidget);

      expect(find.text('Rp15.000'), findsOneWidget);
      expect(find.text('Rp10.000'), findsOneWidget);
      expect(find.text('Rp12.000'), findsOneWidget);

      expect(find.text('Minuman'), findsNWidgets(3));
      expect(find.text('Makanan'), findsNWidgets(2));
    });

    testWidgets('shows an out-of-stock indicator', (tester) async {
      await seedProducts(tester);
      await pumpCashierView(tester);

      expect(find.text('Stok habis'), findsOneWidget);
      expect(find.text('Stok: 20'), findsOneWidget);
    });

    testWidgets('searches products by name', (tester) async {
      await seedProducts(tester);
      await pumpCashierView(tester);

      await tester.enterText(
        find.byKey(const ValueKey('cashier-search-field')),
        'Kopi',
      );

      await tester.pump();

      await waitForLoading(tester);
      await tester.pumpAndSettle();

      expect(find.text('Kopi Susu'), findsOneWidget);
      expect(find.text('Kopi Hitam'), findsOneWidget);
      expect(find.text('Roti Bakar'), findsNothing);
    });

    testWidgets('filters products by category', (tester) async {
      await seedProducts(tester);
      await pumpCashierView(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Makanan'));

      await tester.pump();

      await waitForLoading(tester);
      await tester.pumpAndSettle();

      expect(find.text('Roti Bakar'), findsOneWidget);
      expect(find.text('Kopi Susu'), findsNothing);
      expect(find.text('Kopi Hitam'), findsNothing);
    });

    testWidgets('combines search and category filters', (tester) async {
      await seedProducts(tester);
      await pumpCashierView(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Minuman'));

      await tester.pump();

      await waitForLoading(tester);

      await tester.enterText(
        find.byKey(const ValueKey('cashier-search-field')),
        'Hitam',
      );

      await tester.pump();

      await waitForLoading(tester);
      await tester.pumpAndSettle();

      expect(find.text('Kopi Hitam'), findsOneWidget);
      expect(find.text('Kopi Susu'), findsNothing);
      expect(find.text('Roti Bakar'), findsNothing);
    });

    testWidgets('clears search and category filters', (tester) async {
      await seedProducts(tester);
      await pumpCashierView(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Makanan'));

      await tester.pump();

      await waitForLoading(tester);

      await tester.enterText(
        find.byKey(const ValueKey('cashier-search-field')),
        'Roti',
      );

      await tester.pump();

      await waitForLoading(tester);

      await tester.enterText(
        find.byKey(const ValueKey('cashier-search-field')),
        'Tidak Ada',
      );

      await tester.pump();

      await waitForLoading(tester);
      await tester.pumpAndSettle();

      expect(find.text('Produk tidak ditemukan'), findsOneWidget);

      await tester.tap(find.byTooltip('Hapus pencarian'));
      await tester.pump();

      await waitForLoading(tester);
      await tester.pumpAndSettle();

      expect(find.text('Kopi Susu'), findsOneWidget);
      expect(find.text('Roti Bakar'), findsOneWidget);
      expect(viewModel.selectedCategoryId, isNull);
    });

    testWidgets('adds a product without add-ons to cart', (tester) async {
      await seedProducts(tester);
      await pumpCashierView(tester);

      await tester.tap(find.byKey(const ValueKey('cashier-product-1')));
      await tester.pump();

      await waitForAssignmentLoading(tester);

      expect(find.text('Pilih Add-on'), findsOneWidget);
      expect(
        find.text('Tidak ada add-on tersedia untuk produk ini.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Tambahkan ke Keranjang'));
      await tester.pumpAndSettle();

      expect(cartViewModel.uniqueItemCount, 1);
      expect(cartViewModel.itemCount, 1);
      expect(cartViewModel.items.first.productName, 'Kopi Susu');
      expect(cartViewModel.subtotal, 15000);
    });

    testWidgets('adds a product with selected add-ons to cart', (tester) async {
      await seedProducts(tester);

      final products = await runDb(tester, () => productRepository.getAll());

      final product = products.firstWhere((item) => item.name == 'Kopi Susu');

      final extraShot = await runDb(
        tester,
        () => addonRepository.create(
          name: 'Extra Shot',
          additionalPrice: 5000,
          stock: 30,
        ),
      );

      await runDb(
        tester,
        () => addonRepository.setForProduct(
          productId: product.id!,
          addonIds: [extraShot.id!],
        ),
      );

      await pumpCashierView(tester);

      await tester.tap(find.byKey(ValueKey('cashier-product-${product.id}')));
      await tester.pump();

      await waitForAssignmentLoading(tester);

      expect(find.text('Extra Shot'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('selection-addon-${extraShot.id}')));
      await tester.pump();

      await tester.tap(find.text('Tambahkan ke Keranjang'));
      await tester.pumpAndSettle();

      expect(cartViewModel.uniqueItemCount, 1);
      expect(cartViewModel.items.first.productName, 'Kopi Susu');
      expect(cartViewModel.items.first.addons.length, 1);
      expect(cartViewModel.items.first.addons.first.addonId, extraShot.id);

      expect(cartViewModel.productSubtotal, 15000);
      expect(cartViewModel.addonsSubtotal, 5000);
      expect(cartViewModel.subtotal, 20000);
    });

    testWidgets('does not add product when selection dialog is canceled', (
      tester,
    ) async {
      await seedProducts(tester);

      final products = await runDb(tester, () => productRepository.getAll());

      final product = products.firstWhere((item) => item.name == 'Kopi Susu');

      final extraShot = await runDb(
        tester,
        () => addonRepository.create(
          name: 'Extra Shot',
          additionalPrice: 5000,
          stock: 30,
        ),
      );

      await runDb(
        tester,
        () => addonRepository.setForProduct(
          productId: product.id!,
          addonIds: [extraShot.id!],
        ),
      );

      await pumpCashierView(tester);

      await tester.tap(find.byKey(ValueKey('cashier-product-${product.id}')));
      await tester.pump();

      await waitForAssignmentLoading(tester);

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      expect(cartViewModel.items, isEmpty);
      expect(cartViewModel.subtotal, 0);
    });

    testWidgets('hides mobile cart summary when cart is empty', (tester) async {
      setViewport(tester, const Size(800, 900));

      await seedProducts(tester);
      await pumpCashierView(tester);

      expect(find.byKey(const ValueKey('open-cart-button')), findsNothing);
      expect(find.byKey(const ValueKey('desktop-cart-panel')), findsNothing);
    });

    testWidgets('opens cart bottom sheet on mobile layout', (tester) async {
      setViewport(tester, const Size(800, 900));

      await seedProducts(tester);

      final products = await runDb(tester, () => productRepository.getAll());

      final product = products.firstWhere((item) => item.name == 'Kopi Susu');

      cartViewModel.addProduct(product);

      await pumpCashierView(tester);

      expect(find.byKey(const ValueKey('open-cart-button')), findsOneWidget);
      expect(find.byKey(const ValueKey('desktop-cart-panel')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('open-cart-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('cart-panel')), findsOneWidget);
      expect(find.byKey(const ValueKey('cart-item-0')), findsOneWidget);

      await tester.tap(find.byTooltip('Tutup keranjang'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('cart-panel')), findsNothing);
      expect(find.byKey(const ValueKey('open-cart-button')), findsOneWidget);
    });

    testWidgets('displays cart panel beside catalog on desktop layout', (
      tester,
    ) async {
      setViewport(tester, const Size(1280, 900));

      await seedProducts(tester);

      final products = await runDb(tester, () => productRepository.getAll());

      final product = products.firstWhere((item) => item.name == 'Kopi Susu');

      cartViewModel.addProduct(product);

      await pumpCashierView(tester);

      expect(find.byKey(const ValueKey('desktop-cart-panel')), findsOneWidget);

      expect(find.byKey(const ValueKey('cart-item-0')), findsOneWidget);

      expect(find.byKey(const ValueKey('open-cart-button')), findsNothing);
    });
  });
}
