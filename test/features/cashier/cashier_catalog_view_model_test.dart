import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mini_pos/core/database/database_schema.dart';
import 'package:mini_pos/features/products/repositories/category_repository.dart';
import 'package:mini_pos/features/products/repositories/product_repository.dart';
import 'package:mini_pos/features/cashier/viewmodels/cashier_catalog_view_model.dart';

void main() {
  late Database database;
  late CategoryRepository categoryRepository;
  late ProductRepository productRepository;
  late CashierCatalogViewModel viewModel;

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

    foodCategoryId = await categoryRepository.create(
      name: 'Makanan',
      description: 'Produk makanan',
    );

    drinkCategoryId = await categoryRepository.create(
      name: 'Minuman',
      description: 'Produk minuman',
    );

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
      stock: 15,
    );

    await productRepository.create(
      categoryId: foodCategoryId,
      name: 'Roti Bakar',
      sellingPrice: 12000,
      stock: 10,
    );

    viewModel = CashierCatalogViewModel(categoryRepository, productRepository);
  });

  tearDown(() async {
    viewModel.dispose();
    await database.close();
  });

  group('CashierCatalogViewModel', () {
    test('starts with empty catalog state', () {
      expect(viewModel.categories, isEmpty);
      expect(viewModel.products, isEmpty);
      expect(viewModel.selectedCategoryId, isNull);
      expect(viewModel.searchQuery, '');
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.hasLoaded, isFalse);
      expect(viewModel.errorMessage, isNull);
    });

    test('loads active categories and products', () async {
      await viewModel.load();

      expect(viewModel.hasLoaded, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.categories.length, 2);
      expect(viewModel.products.length, 3);

      expect(viewModel.products.map((product) => product.name).toList(), [
        'Kopi Hitam',
        'Kopi Susu',
        'Roti Bakar',
      ]);
    });

    test('only displays active products', () async {
      final products = await productRepository.getAll();

      final inactiveProduct = products.firstWhere(
        (product) => product.name == 'Roti Bakar',
      );

      await productRepository.deactivate(inactiveProduct.id!);

      await viewModel.load();

      expect(viewModel.products.length, 2);
      expect(
        viewModel.products.any((product) => product.name == 'Roti Bakar'),
        isFalse,
      );
    });

    test('searches products by name', () async {
      await viewModel.load();

      await viewModel.setSearchQuery('Kopi');

      expect(viewModel.searchQuery, 'Kopi');
      expect(viewModel.products.length, 2);

      expect(
        viewModel.products.every((product) => product.name.contains('Kopi')),
        isTrue,
      );
    });

    test('searches products case-insensitively', () async {
      await viewModel.load();

      await viewModel.setSearchQuery('KOPI');

      expect(viewModel.products.length, 2);
    });

    test('trims search query before filtering', () async {
      await viewModel.load();

      await viewModel.setSearchQuery('  Roti  ');

      expect(viewModel.searchQuery, 'Roti');
      expect(viewModel.products.length, 1);
      expect(viewModel.products.first.name, 'Roti Bakar');
    });

    test('filters products by category', () async {
      await viewModel.load();

      await viewModel.setCategoryFilter(foodCategoryId);

      expect(viewModel.selectedCategoryId, foodCategoryId);
      expect(viewModel.products.length, 1);
      expect(viewModel.products.first.name, 'Roti Bakar');
    });

    test('combines category filter and search query', () async {
      await viewModel.load();

      await viewModel.setCategoryFilter(drinkCategoryId);
      await viewModel.setSearchQuery('Hitam');

      expect(viewModel.products.length, 1);
      expect(viewModel.products.first.name, 'Kopi Hitam');
    });

    test('clears search and category filters', () async {
      await viewModel.load();

      await viewModel.setCategoryFilter(foodCategoryId);
      await viewModel.setSearchQuery('Roti');

      await viewModel.clearFilters();

      expect(viewModel.searchQuery, '');
      expect(viewModel.selectedCategoryId, isNull);
      expect(viewModel.products.length, 3);
    });

    test('clears filters even when search returns no products', () async {
      await viewModel.load();

      await viewModel.setSearchQuery('Produk Tidak Ada');

      expect(viewModel.products, isEmpty);

      await viewModel.clearFilters();

      expect(viewModel.products.length, 3);
    });

    test('refreshes catalog to show newly added products', () async {
      await viewModel.load();

      expect(viewModel.products.length, 3);

      await productRepository.create(
        categoryId: foodCategoryId,
        name: 'Pisang Goreng',
        sellingPrice: 8000,
        stock: 25,
      );

      await viewModel.refresh();

      expect(viewModel.products.length, 4);
      expect(
        viewModel.products.any((product) => product.name == 'Pisang Goreng'),
        isTrue,
      );
    });

    test('ensureLoaded does not reload an already loaded catalog', () async {
      await viewModel.load();

      await viewModel.setSearchQuery('Kopi');

      await viewModel.ensureLoaded();

      expect(viewModel.hasLoaded, isTrue);
      expect(viewModel.products.length, 2);
      expect(viewModel.searchQuery, 'Kopi');
    });

    test('exposes immutable category and product lists', () async {
      await viewModel.load();

      expect(() => viewModel.categories.clear(), throwsUnsupportedError);

      expect(() => viewModel.products.clear(), throwsUnsupportedError);
    });
  });
}
