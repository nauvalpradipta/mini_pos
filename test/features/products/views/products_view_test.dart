import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mini_pos/core/database/database_schema.dart';
import 'package:mini_pos/features/products/models/product.dart';
import 'package:mini_pos/features/products/repositories/category_repository.dart';
import 'package:mini_pos/features/products/repositories/product_repository.dart';
import 'package:mini_pos/features/products/services/product_image_service.dart';
import 'package:mini_pos/features/products/viewmodels/product_management_view_model.dart';
import 'package:mini_pos/features/products/views/products_view.dart';
import 'package:mini_pos/features/products/repositories/addon_repository.dart';
import 'package:mini_pos/features/products/viewmodels/addon_management_view_model.dart';

void main() {
  late Database database;
  late CategoryRepository categoryRepository;
  late ProductRepository productRepository;
  late ProductManagementViewModel viewModel;
  late ProductImageService imageService;
  late Directory temporaryDirectory;
  late AddonRepository addonRepository;
  late AddonManagementViewModel addonViewModel;

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

    viewModel = ProductManagementViewModel(
      categoryRepository,
      productRepository,
    );

    temporaryDirectory = await Directory.systemTemp.createTemp(
      'products_view_test_',
    );

    imageService = ProductImageService(
      documentsDirectoryProvider: () async => temporaryDirectory,
    );
  });

  tearDown(() async {
    viewModel.dispose();
    addonViewModel.dispose();
    await database.close();

    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  Future<T> runDb<T>(WidgetTester tester, Future<T> Function() action) async {
    final result = await tester.runAsync<T>(action);
    return result as T;
  }

  Future<void> createCategories(WidgetTester tester) async {
    foodCategoryId = await runDb(
      tester,
      () => categoryRepository.create(
        name: 'Makanan',
        description: 'Produk makanan',
      ),
    );

    drinkCategoryId = await runDb(
      tester,
      () => categoryRepository.create(
        name: 'Minuman',
        description: 'Produk minuman',
      ),
    );
  }

  Widget buildTestApp() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ProductManagementViewModel>.value(
          value: viewModel,
        ),
        ChangeNotifierProvider<AddonManagementViewModel>.value(
          value: addonViewModel,
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ProductsView(loadOnInit: false, imageService: imageService),
        ),
      ),
    );
  }

  Future<void> pumpProductsView(WidgetTester tester) async {
    await tester.runAsync(() async {
      await viewModel.load();
      await addonViewModel.load();
    });

    expect(viewModel.isLoading, isFalse);

    await tester.pumpWidget(buildTestApp());
    await tester.pump();
  }

  Future<void> waitForSaving(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (
        var attempt = 0;
        attempt < 500 && (viewModel.isCheckingDuplicate || viewModel.isSaving);
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });

    await tester.pump();

    expect(
      viewModel.isCheckingDuplicate,
      isFalse,
      reason: 'Duplicate checking did not finish within 5 seconds.',
    );

    expect(
      viewModel.isSaving,
      isFalse,
      reason: 'Product mutation did not finish within 5 seconds.',
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
      reason: 'Assignment loading did not finish within 5 seconds.',
    );

    await tester.pumpAndSettle();
  }

  Future<void> waitForDuplicateCheck(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (
        var attempt = 0;
        attempt < 500 && viewModel.isCheckingDuplicate;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });

    await tester.pump();

    expect(
      viewModel.isCheckingDuplicate,
      isFalse,
      reason: 'Duplicate checking did not finish within 5 seconds.',
    );

    await tester.pumpAndSettle();
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
      reason: 'Product filtering did not finish within 5 seconds.',
    );
  }

  group('ProductsView', () {
    testWidgets('shows category prompt when no categories exist', (
      tester,
    ) async {
      await pumpProductsView(tester);

      expect(find.text('Product Management'), findsOneWidget);
      expect(find.text('Daftar Produk'), findsOneWidget);
      expect(find.text('Belum ada kategori'), findsOneWidget);
      expect(find.text('Tambah Kategori'), findsOneWidget);
    });

    testWidgets('shows empty product state when categories exist', (
      tester,
    ) async {
      await createCategories(tester);
      await pumpProductsView(tester);

      expect(find.text('Belum ada produk'), findsOneWidget);
      expect(find.text('Tambah Produk'), findsOneWidget);
      expect(find.text('Makanan'), findsOneWidget);
      expect(find.text('Minuman'), findsOneWidget);
    });

    testWidgets('displays products with their category and price', (
      tester,
    ) async {
      await createCategories(tester);

      await runDb(tester, () {
        return productRepository.create(
          categoryId: drinkCategoryId,
          name: 'Kopi Susu',
          sellingPrice: 15000,
          stock: 20,
        );
      });

      await pumpProductsView(tester);

      expect(find.text('Kopi Susu'), findsOneWidget);
      // Nama kategori muncul pada filter chip dan kartu produk.
      expect(find.text('Minuman'), findsNWidgets(2));
      expect(find.text('Rp15.000'), findsOneWidget);
      expect(find.text('Stok: 20'), findsOneWidget);
    });

    testWidgets('filters products by search query', (tester) async {
      await createCategories(tester);

      await runDb(tester, () async {
        await productRepository.create(
          categoryId: drinkCategoryId,
          name: 'Kopi Susu',
          sellingPrice: 15000,
          stock: 20,
        );

        await productRepository.create(
          categoryId: foodCategoryId,
          name: 'Roti Bakar',
          sellingPrice: 12000,
          stock: 10,
        );
      });

      await pumpProductsView(tester);

      await tester.enterText(
        find.byKey(const ValueKey('product-search-field')),
        'Kopi',
      );

      await waitForLoading(tester);

      expect(find.text('Kopi Susu'), findsOneWidget);
      expect(find.text('Roti Bakar'), findsNothing);
    });

    testWidgets('filters products by selected category', (tester) async {
      await createCategories(tester);

      await runDb(tester, () async {
        await productRepository.create(
          categoryId: drinkCategoryId,
          name: 'Kopi Susu',
          sellingPrice: 15000,
          stock: 20,
        );

        await productRepository.create(
          categoryId: foodCategoryId,
          name: 'Roti Bakar',
          sellingPrice: 12000,
          stock: 10,
        );
      });

      await pumpProductsView(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Makanan'));

      await waitForLoading(tester);

      expect(find.text('Roti Bakar'), findsOneWidget);
      expect(find.text('Kopi Susu'), findsNothing);
    });

    testWidgets('creates a new product', (tester) async {
      await createCategories(tester);
      await pumpProductsView(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Tambah').last);
      await tester.pumpAndSettle();

      // Teks muncul pada empty-state di belakang dialog dan judul dialog.
      expect(find.text('Tambah Produk'), findsNWidgets(2));

      await tester.enterText(find.byType(TextFormField).at(0), 'Es Teh');

      await tester.enterText(find.byType(TextFormField).at(1), '5000');

      await tester.enterText(find.byType(TextFormField).at(2), '30');

      await tester.tap(find.widgetWithText(FilledButton, 'Tambah').last);
      await tester.pump();

      await waitForSaving(tester);
      await tester.pumpAndSettle();

      expect(find.text('Es Teh'), findsOneWidget);
      expect(find.text('Rp5.000'), findsOneWidget);
      expect(find.text('Stok: 30'), findsOneWidget);
    });

    testWidgets('edits an existing product', (tester) async {
      await createCategories(tester);

      final product = await runDb<Product>(
        tester,
        () => productRepository.create(
          categoryId: foodCategoryId,
          name: 'Roti Bakar',
          sellingPrice: 12000,
          stock: 10,
        ),
      );

      await pumpProductsView(tester);

      await tester.ensureVisible(find.byTooltip('Edit produk'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Edit produk'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Produk'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'Roti Cokelat');

      await tester.enterText(find.byType(TextFormField).at(1), '18000');

      await tester.enterText(find.byType(TextFormField).at(2), '15');

      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await tester.pump();

      await waitForSaving(tester);
      await tester.pumpAndSettle();

      final updatedProduct = await runDb<Product?>(
        tester,
        () => productRepository.getById(product.id!),
      );

      expect(updatedProduct, isNotNull);
      expect(updatedProduct!.name, 'Roti Cokelat');
      expect(updatedProduct.sellingPrice, 18000);
      expect(updatedProduct.stock, 15);

      expect(find.text('Roti Cokelat'), findsOneWidget);
      expect(find.text('Roti Bakar'), findsNothing);
    });

    testWidgets('cancels creating a duplicate product', (tester) async {
      await createCategories(tester);

      await runDb(
        tester,
        () => productRepository.create(
          categoryId: foodCategoryId,
          name: 'Es Teh',
          sellingPrice: 5000,
          stock: 30,
        ),
      );

      await pumpProductsView(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Tambah').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Es Teh');
      await tester.enterText(find.byType(TextFormField).at(1), '5000');
      await tester.enterText(find.byType(TextFormField).at(2), '30');

      await tester.tap(find.widgetWithText(FilledButton, 'Tambah').last);
      await tester.pump();

      await waitForDuplicateCheck(tester);

      expect(find.text('Produk dengan nama sama sudah ada'), findsOneWidget);

      expect(find.text('Tetap Tambahkan'), findsOneWidget);

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      final products = await runDb(tester, () => productRepository.getAll());

      expect(products.length, 1);
      expect(products.first.name, 'Es Teh');
    });

    testWidgets('confirms creating a duplicate product', (tester) async {
      await createCategories(tester);

      await runDb(
        tester,
        () => productRepository.create(
          categoryId: foodCategoryId,
          name: 'Es Teh',
          sellingPrice: 5000,
          stock: 30,
        ),
      );

      await pumpProductsView(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Tambah').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Es Teh');
      await tester.enterText(find.byType(TextFormField).at(1), '6000');
      await tester.enterText(find.byType(TextFormField).at(2), '20');

      await tester.tap(find.widgetWithText(FilledButton, 'Tambah').last);
      await tester.pump();

      await waitForDuplicateCheck(tester);

      expect(find.text('Produk dengan nama sama sudah ada'), findsOneWidget);

      await tester.tap(find.text('Tetap Tambahkan'));
      await tester.pump();

      await waitForSaving(tester);
      await tester.pumpAndSettle();

      final products = await runDb(tester, () => productRepository.getAll());

      expect(products.length, 2);
      expect(products.every((product) => product.name == 'Es Teh'), isTrue);
      expect(products.map((product) => product.sellingPrice).toSet(), {
        5000,
        6000,
      });
    });

    testWidgets('assigns add-ons to a product through UI', (tester) async {
      await createCategories(tester);

      final product = await runDb<Product>(
        tester,
        () => productRepository.create(
          categoryId: foodCategoryId,
          name: 'Kopi Susu',
          sellingPrice: 15000,
          stock: 20,
        ),
      );

      final extraShot = await runDb(
        tester,
        () => addonRepository.create(
          name: 'Extra Shot',
          additionalPrice: 5000,
          stock: 20,
        ),
      );

      await pumpProductsView(tester);

      final assignmentButton = find.byTooltip('Atur add-on');

      await tester.ensureVisible(assignmentButton);
      await tester.pumpAndSettle();

      await tester.tap(assignmentButton);
      await tester.pump();

      await waitForAssignmentLoading(tester);

      expect(find.text('Atur Add-on Produk'), findsOneWidget);
      expect(find.text('Kopi Susu'), findsNWidgets(2));
      expect(find.text('Extra Shot'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('addon-option-${extraShot.id}')));
      await tester.pump();

      await tester.tap(find.text('Simpan'));
      await tester.pump();

      await waitForSaving(tester);
      await tester.pumpAndSettle();

      final assignedAddons = await runDb(
        tester,
        () => addonRepository.getForProduct(productId: product.id!),
      );

      expect(assignedAddons.length, 1);
      expect(assignedAddons.first.id, extraShot.id);
    });

    testWidgets('preserves assignments when assignment dialog is canceled', (
      tester,
    ) async {
      await createCategories(tester);

      final product = await runDb<Product>(
        tester,
        () => productRepository.create(
          categoryId: foodCategoryId,
          name: 'Kopi Susu',
          sellingPrice: 15000,
          stock: 20,
        ),
      );

      final extraShot = await runDb(
        tester,
        () => addonRepository.create(
          name: 'Extra Shot',
          additionalPrice: 5000,
          stock: 20,
        ),
      );

      final caramel = await runDb(
        tester,
        () => addonRepository.create(
          name: 'Caramel',
          additionalPrice: 2000,
          stock: 15,
        ),
      );

      // Simpan relasi awal hanya dengan Extra Shot.
      await runDb(
        tester,
        () => addonRepository.setForProduct(
          productId: product.id!,
          addonIds: [extraShot.id!],
        ),
      );

      await pumpProductsView(tester);

      final assignmentButton = find.byTooltip('Atur add-on');

      await tester.ensureVisible(assignmentButton);
      await tester.pumpAndSettle();

      await tester.tap(assignmentButton);
      await tester.pump();

      await waitForAssignmentLoading(tester);

      expect(find.text('Atur Add-on Produk'), findsOneWidget);

      // Tambahkan Caramel hanya pada pilihan sementara di dialog.
      await tester.tap(find.byKey(ValueKey('addon-option-${caramel.id}')));
      await tester.pump();

      // Batalkan perubahan.
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      final assignedAddons = await runDb(
        tester,
        () => addonRepository.getForProduct(productId: product.id!),
      );

      expect(assignedAddons.length, 1);
      expect(assignedAddons.first.id, extraShot.id);
      expect(assignedAddons.any((addon) => addon.id == caramel.id), isFalse);
    });

    testWidgets('deactivates a product', (tester) async {
      await createCategories(tester);

      final product = await runDb<Product>(
        tester,
        () => productRepository.create(
          categoryId: foodCategoryId,
          name: 'Roti Bakar',
          sellingPrice: 12000,
          stock: 10,
        ),
      );

      await pumpProductsView(tester);

      await tester.ensureVisible(find.byTooltip('Nonaktifkan produk'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Nonaktifkan produk'));
      await tester.pumpAndSettle();

      expect(find.text('Nonaktifkan produk?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Nonaktifkan'));
      await tester.pump();

      await waitForSaving(tester);

      expect(find.text('Roti Bakar'), findsNothing);

      final updatedProduct = await runDb<Product?>(
        tester,
        () => productRepository.getById(product.id!),
      );

      expect(updatedProduct, isNotNull);
      expect(updatedProduct!.isActive, isFalse);
    });

    testWidgets('opens add-on management from product management', (
      tester,
    ) async {
      await pumpProductsView(tester);

      await tester.tap(find.byTooltip('Kelola Add-on'));
      await tester.pumpAndSettle();

      expect(find.text('Kelola Add-on'), findsOneWidget);
      expect(find.text('Belum ada add-on'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });
}
