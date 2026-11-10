import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mini_pos/core/database/database_schema.dart';
import 'package:mini_pos/features/products/repositories/category_repository.dart';
import 'package:mini_pos/features/products/repositories/product_repository.dart';

void main() {
  late Database database;
  late CategoryRepository categoryRepository;
  late ProductRepository productRepository;
  late int categoryId;

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
      name: 'Makanan',
      description: 'Kategori makanan',
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('ProductRepository', () {
    test('creates and retrieves a product', () async {
      final createdProduct = await productRepository.create(
        categoryId: categoryId,
        name: 'Nasi Goreng',
        sellingPrice: 15000,
        stock: 20,
        imagePath: '/images/nasi_goreng.jpg',
      );

      expect(createdProduct.id, isNotNull);
      expect(createdProduct.name, 'Nasi Goreng');
      expect(createdProduct.sellingPrice, 15000);
      expect(createdProduct.stock, 20);
      expect(createdProduct.imagePath, '/images/nasi_goreng.jpg');
      expect(createdProduct.isActive, isTrue);

      final retrievedProduct = await productRepository.getById(
        createdProduct.id!,
      );

      expect(retrievedProduct, isNotNull);
      expect(retrievedProduct!.name, 'Nasi Goreng');
    });

    test('trims product name before saving', () async {
      final product = await productRepository.create(
        categoryId: categoryId,
        name: '  Es Teh  ',
        sellingPrice: 5000,
        stock: 10,
      );

      expect(product.name, 'Es Teh');
    });

    test('rejects an empty product name', () async {
      await expectLater(
        productRepository.create(
          categoryId: categoryId,
          name: '   ',
          sellingPrice: 5000,
          stock: 10,
        ),
        throwsArgumentError,
      );
    });

    test('rejects a negative selling price', () async {
      await expectLater(
        productRepository.create(
          categoryId: categoryId,
          name: 'Produk Test',
          sellingPrice: -1000,
          stock: 10,
        ),
        throwsArgumentError,
      );
    });

    test('rejects a negative stock quantity', () async {
      await expectLater(
        productRepository.create(
          categoryId: categoryId,
          name: 'Produk Test',
          sellingPrice: 10000,
          stock: -1,
        ),
        throwsArgumentError,
      );
    });

    test('rejects an inactive category', () async {
      await categoryRepository.deactivate(categoryId);

      await expectLater(
        productRepository.create(
          categoryId: categoryId,
          name: 'Produk Test',
          sellingPrice: 10000,
          stock: 10,
        ),
        throwsStateError,
      );
    });

    test('filters products by active status, category, and search', () async {
      await productRepository.create(
        categoryId: categoryId,
        name: 'Nasi Goreng',
        sellingPrice: 15000,
        stock: 20,
      );

      final secondProduct = await productRepository.create(
        categoryId: categoryId,
        name: 'Es Teh',
        sellingPrice: 5000,
        stock: 30,
      );

      await productRepository.deactivate(secondProduct.id!);

      final activeProducts = await productRepository.getAll();

      expect(activeProducts.length, 1);
      expect(activeProducts.first.name, 'Nasi Goreng');

      final searchResults = await productRepository.getAll(searchQuery: 'nasi');

      expect(searchResults.length, 1);
      expect(searchResults.first.name, 'Nasi Goreng');

      final allProducts = await productRepository.getAll(activeOnly: false);

      expect(allProducts.length, 2);
    });

    test('updates product information', () async {
      final originalProduct = await productRepository.create(
        categoryId: categoryId,
        name: 'Kopi Hitam',
        sellingPrice: 8000,
        stock: 15,
      );

      final updatedProduct = await productRepository.update(
        id: originalProduct.id!,
        categoryId: categoryId,
        name: 'Kopi Susu',
        sellingPrice: 12000,
        stock: 25,
      );

      expect(updatedProduct.name, 'Kopi Susu');
      expect(updatedProduct.sellingPrice, 12000);
      expect(updatedProduct.stock, 25);
      expect(updatedProduct.createdAt, originalProduct.createdAt);

      final savedProduct = await productRepository.getById(originalProduct.id!);

      expect(savedProduct!.name, 'Kopi Susu');
    });

    test('deactivates product without deleting its record', () async {
      final product = await productRepository.create(
        categoryId: categoryId,
        name: 'Teh Manis',
        sellingPrice: 5000,
        stock: 10,
      );

      await productRepository.deactivate(product.id!);

      final retrievedProduct = await productRepository.getById(product.id!);

      expect(retrievedProduct, isNotNull);
      expect(retrievedProduct!.isActive, isFalse);

      final activeProducts = await productRepository.getAll();

      expect(activeProducts, isEmpty);
    });

    test('throws when updating a product that does not exist', () async {
      await expectLater(
        productRepository.update(
          id: 999,
          categoryId: categoryId,
          name: 'Produk Test',
          sellingPrice: 10000,
          stock: 10,
        ),
        throwsStateError,
      );
    });
  });
}
