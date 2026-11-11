import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mini_pos/core/database/database_schema.dart';
import 'package:mini_pos/features/products/repositories/category_repository.dart';
import 'package:mini_pos/features/products/repositories/product_repository.dart';
import 'package:mini_pos/features/products/viewmodels/product_management_view_model.dart';

void main() {
  late Database database;

  late CategoryRepository categoryRepository;
  late ProductRepository productRepository;
  late ProductManagementViewModel viewModel;

  late int categoryId;
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

    categoryId = await categoryRepository.create(
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

    viewModel = ProductManagementViewModel(
      categoryRepository,
      productRepository,
    );
  });

  tearDown(() async {
    viewModel.dispose();
    await database.close();
  });

  group('ProductManagementViewModel', () {
    test('loads active categories and products', () async {
      await viewModel.load();

      expect(viewModel.categories.length, 1);
      expect(viewModel.categories.first.name, 'Minuman');

      expect(viewModel.products.length, 1);
      expect(viewModel.products.first.name, 'Kopi Susu');

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNull);
    });

    test('filters products by search query', () async {
      await productRepository.create(
        categoryId: categoryId,
        name: 'Es Teh',
        sellingPrice: 5000,
        stock: 15,
      );

      await viewModel.load();
      await viewModel.setSearchQuery('teh');

      expect(viewModel.products.length, 1);
      expect(viewModel.products.first.name, 'Es Teh');
      expect(viewModel.searchQuery, 'teh');
    });

    test('filters products by category', () async {
      final secondCategoryId = await categoryRepository.create(name: 'Makanan');

      await productRepository.create(
        categoryId: secondCategoryId,
        name: 'Nasi Goreng',
        sellingPrice: 20000,
        stock: 10,
      );

      await viewModel.load();

      await viewModel.setCategoryFilter(secondCategoryId);

      expect(viewModel.selectedCategoryId, secondCategoryId);
      expect(viewModel.products.length, 1);
      expect(viewModel.products.first.name, 'Nasi Goreng');
    });

    test('creates a new category', () async {
      await viewModel.load();

      final success = await viewModel.createCategory(
        name: 'Makanan',
        description: 'Kategori makanan',
      );

      expect(success, isTrue);
      expect(viewModel.categories.length, 2);
      expect(
        viewModel.categories.any((category) => category.name == 'Makanan'),
        isTrue,
      );

      expect(viewModel.successMessage, isNotNull);
      expect(viewModel.isSaving, isFalse);
    });

    test('updates an existing category', () async {
      await viewModel.load();

      final success = await viewModel.updateCategory(
        id: categoryId,
        name: 'Minuman Dingin',
        description: 'Minuman siap saji',
      );

      expect(success, isTrue);
      expect(viewModel.categories.first.name, 'Minuman Dingin');
      expect(viewModel.categories.first.description, 'Minuman siap saji');
    });

    test('prevents deactivating category with active products', () async {
      await viewModel.load();

      final success = await viewModel.deactivateCategory(categoryId);

      expect(success, isFalse);
      expect(viewModel.categories.length, 1);
      expect(viewModel.errorMessage, isNotNull);
      expect(viewModel.errorMessage, contains('active products'));
    });

    test('deactivates category when it has no active products', () async {
      await viewModel.load();

      // Nonaktifkan produk terlebih dahulu.
      await productRepository.deactivate(productId);

      final success = await viewModel.deactivateCategory(categoryId);

      expect(success, isTrue);
      expect(viewModel.categories, isEmpty);
      expect(viewModel.products, isEmpty);
    });

    test('creates a new product', () async {
      await viewModel.load();

      final success = await viewModel.createProduct(
        categoryId: categoryId,
        name: 'Es Teh',
        sellingPrice: 5000,
        stock: 15,
      );

      expect(success, isTrue);

      expect(viewModel.products.length, 2);

      expect(
        viewModel.products.any((product) => product.name == 'Es Teh'),
        isTrue,
      );
    });

    test('updates an existing product', () async {
      await viewModel.load();

      final success = await viewModel.updateProduct(
        id: productId,
        categoryId: categoryId,
        name: 'Kopi Susu Gula Aren',
        sellingPrice: 18000,
        stock: 25,
      );

      expect(success, isTrue);
      expect(viewModel.products.length, 1);
      expect(viewModel.products.first.name, 'Kopi Susu Gula Aren');
      expect(viewModel.products.first.sellingPrice, 18000);
      expect(viewModel.products.first.stock, 25);
    });

    test('deactivates a product', () async {
      await viewModel.load();

      final success = await viewModel.deactivateProduct(productId);

      expect(success, isTrue);
      expect(viewModel.products, isEmpty);

      final product = await productRepository.getById(productId);

      expect(product, isNotNull);
      expect(product!.isActive, isFalse);
    });

    test(
      'displays validation errors when creating an invalid product',
      () async {
        await viewModel.load();

        final success = await viewModel.createProduct(
          categoryId: categoryId,
          name: '   ',
          sellingPrice: 15000,
          stock: 10,
        );

        expect(success, isFalse);
        expect(viewModel.errorMessage, isNotNull);
        expect(viewModel.isSaving, isFalse);
        expect(viewModel.products.length, 1);
      },
    );
  });
}
