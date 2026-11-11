import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mini_pos/core/database/database_schema.dart';
import 'package:mini_pos/features/products/models/product.dart';
import 'package:mini_pos/features/products/repositories/product_repository.dart';

void main() {
  late Database database;
  late ProductRepository productRepository;

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

    productRepository = ProductRepository(database);

    final foodCategory = await database.insert('categories', {
      'name': 'Makanan',
      'is_active': 1,
      'created_at': 1000,
      'updated_at': 1000,
    });

    final drinkCategory = await database.insert('categories', {
      'name': 'Minuman',
      'is_active': 1,
      'created_at': 1000,
      'updated_at': 1000,
    });

    foodCategoryId = foodCategory;
    drinkCategoryId = drinkCategory;
  });

  tearDown(() async {
    await database.close();
  });

  Future<Product> createTestProduct({
    required String name,
    required int categoryId,
    int sellingPrice = 15000,
    int stock = 20,
  }) {
    return productRepository.create(
      categoryId: categoryId,
      name: name,
      sellingPrice: sellingPrice,
      stock: stock,
    );
  }

  group('ProductRepository duplicate detection', () {
    test('finds duplicate with the same name and category', () async {
      await createTestProduct(name: 'Kopi Susu', categoryId: drinkCategoryId);

      final duplicate = await productRepository.findActiveDuplicate(
        categoryId: drinkCategoryId,
        name: 'Kopi Susu',
      );

      expect(duplicate, isNotNull);
      expect(duplicate!.name, 'Kopi Susu');
      expect(duplicate.categoryId, drinkCategoryId);
    });

    test('matches product names case-insensitively', () async {
      await createTestProduct(name: 'Kopi Susu', categoryId: drinkCategoryId);

      final duplicate = await productRepository.findActiveDuplicate(
        categoryId: drinkCategoryId,
        name: 'kopi susu',
      );

      expect(duplicate, isNotNull);
      expect(duplicate!.name, 'Kopi Susu');
    });

    test('does not detect products in different categories', () async {
      await createTestProduct(name: 'Kopi Susu', categoryId: drinkCategoryId);

      final duplicate = await productRepository.findActiveDuplicate(
        categoryId: foodCategoryId,
        name: 'Kopi Susu',
      );

      expect(duplicate, isNull);
    });

    test('ignores inactive products', () async {
      final product = await createTestProduct(
        name: 'Kopi Susu',
        categoryId: drinkCategoryId,
      );

      await productRepository.deactivate(product.id!);

      final duplicate = await productRepository.findActiveDuplicate(
        categoryId: drinkCategoryId,
        name: 'Kopi Susu',
      );

      expect(duplicate, isNull);
    });

    test('does not match the current product when editing', () async {
      final product = await createTestProduct(
        name: 'Kopi Susu',
        categoryId: drinkCategoryId,
      );

      final duplicate = await productRepository.findActiveDuplicate(
        categoryId: drinkCategoryId,
        name: 'Kopi Susu',
        excludeId: product.id,
      );

      expect(duplicate, isNull);
    });

    test('finds another product when current product is excluded', () async {
      final firstProduct = await createTestProduct(
        name: 'Kopi Susu',
        categoryId: drinkCategoryId,
      );

      final secondProduct = await createTestProduct(
        name: 'Kopi Susu',
        categoryId: drinkCategoryId,
        sellingPrice: 18000,
        stock: 10,
      );

      final duplicate = await productRepository.findActiveDuplicate(
        categoryId: drinkCategoryId,
        name: 'Kopi Susu',
        excludeId: secondProduct.id,
      );

      expect(duplicate, isNotNull);
      expect(duplicate!.id, firstProduct.id);
    });

    test('returns null when no matching product exists', () async {
      final duplicate = await productRepository.findActiveDuplicate(
        categoryId: drinkCategoryId,
        name: 'Es Teh',
      );

      expect(duplicate, isNull);
    });
  });
}
