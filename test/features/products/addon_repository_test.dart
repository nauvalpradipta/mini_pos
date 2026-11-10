import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mini_pos/core/database/database_schema.dart';
import 'package:mini_pos/features/products/repositories/addon_repository.dart';
import 'package:mini_pos/features/products/repositories/category_repository.dart';
import 'package:mini_pos/features/products/repositories/product_repository.dart';

void main() {
  late Database database;
  late AddonRepository addonRepository;
  late CategoryRepository categoryRepository;
  late ProductRepository productRepository;

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

    addonRepository = AddonRepository(database);
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
  });

  tearDown(() async {
    await database.close();
  });

  group('AddonRepository', () {
    test('creates and retrieves an add-on', () async {
      final createdAddon = await addonRepository.create(
        name: 'Extra Shot',
        additionalPrice: 5000,
        stock: 30,
      );

      expect(createdAddon.id, isNotNull);
      expect(createdAddon.name, 'Extra Shot');
      expect(createdAddon.additionalPrice, 5000);
      expect(createdAddon.stock, 30);
      expect(createdAddon.isActive, isTrue);

      final retrievedAddon = await addonRepository.getById(createdAddon.id!);

      expect(retrievedAddon, isNotNull);
      expect(retrievedAddon!.name, 'Extra Shot');
    });

    test('trims add-on name before saving', () async {
      final addon = await addonRepository.create(
        name: '  Extra Cheese  ',
        additionalPrice: 3000,
        stock: 10,
      );

      expect(addon.name, 'Extra Cheese');
    });

    test('rejects an empty add-on name', () async {
      await expectLater(
        addonRepository.create(name: '   ', additionalPrice: 3000, stock: 10),
        throwsArgumentError,
      );
    });

    test('rejects a negative additional price', () async {
      await expectLater(
        addonRepository.create(
          name: 'Extra Cheese',
          additionalPrice: -1000,
          stock: 10,
        ),
        throwsArgumentError,
      );
    });

    test('rejects a negative stock quantity', () async {
      await expectLater(
        addonRepository.create(
          name: 'Extra Cheese',
          additionalPrice: 3000,
          stock: -1,
        ),
        throwsArgumentError,
      );
    });

    test('gets only active add-ons by default', () async {
      await addonRepository.create(
        name: 'Extra Cheese',
        additionalPrice: 3000,
        stock: 10,
      );

      final secondAddon = await addonRepository.create(
        name: 'Extra Shot',
        additionalPrice: 5000,
        stock: 20,
      );

      await addonRepository.deactivate(secondAddon.id!);

      final activeAddons = await addonRepository.getAll();

      expect(activeAddons.length, 1);
      expect(activeAddons.first.name, 'Extra Cheese');

      final allAddons = await addonRepository.getAll(activeOnly: false);

      expect(allAddons.length, 2);
    });

    test('updates add-on information', () async {
      final originalAddon = await addonRepository.create(
        name: 'Extra Shot',
        additionalPrice: 5000,
        stock: 10,
      );

      final updatedAddon = await addonRepository.update(
        id: originalAddon.id!,
        name: 'Double Shot',
        additionalPrice: 8000,
        stock: 25,
      );

      expect(updatedAddon.name, 'Double Shot');
      expect(updatedAddon.additionalPrice, 8000);
      expect(updatedAddon.stock, 25);
      expect(updatedAddon.createdAt, originalAddon.createdAt);

      final savedAddon = await addonRepository.getById(originalAddon.id!);

      expect(savedAddon!.name, 'Double Shot');
    });

    test(
      'deactivates add-on without deleting its record or relation',
      () async {
        final addon = await addonRepository.create(
          name: 'Extra Cheese',
          additionalPrice: 3000,
          stock: 10,
        );

        await addonRepository.setForProduct(
          productId: productId,
          addonIds: [addon.id!],
        );

        await addonRepository.deactivate(addon.id!);

        final retrievedAddon = await addonRepository.getById(addon.id!);

        expect(retrievedAddon, isNotNull);
        expect(retrievedAddon!.isActive, isFalse);

        final activeAddons = await addonRepository.getForProduct(
          productId: productId,
        );

        expect(activeAddons, isEmpty);

        final allRelatedAddons = await addonRepository.getForProduct(
          productId: productId,
          activeOnly: false,
        );

        expect(allRelatedAddons.length, 1);
        expect(allRelatedAddons.first.name, 'Extra Cheese');
      },
    );

    test('assigns multiple add-ons to a product', () async {
      final cheese = await addonRepository.create(
        name: 'Extra Cheese',
        additionalPrice: 3000,
        stock: 10,
      );

      final shot = await addonRepository.create(
        name: 'Extra Shot',
        additionalPrice: 5000,
        stock: 20,
      );

      await addonRepository.setForProduct(
        productId: productId,
        addonIds: [cheese.id!, shot.id!],
      );

      final relatedAddons = await addonRepository.getForProduct(
        productId: productId,
      );

      expect(relatedAddons.length, 2);
      expect(relatedAddons.map((addon) => addon.name).toList(), [
        'Extra Cheese',
        'Extra Shot',
      ]);
    });

    test('replaces and clears existing product add-ons', () async {
      final cheese = await addonRepository.create(
        name: 'Extra Cheese',
        additionalPrice: 3000,
        stock: 10,
      );

      final shot = await addonRepository.create(
        name: 'Extra Shot',
        additionalPrice: 5000,
        stock: 20,
      );

      await addonRepository.setForProduct(
        productId: productId,
        addonIds: [cheese.id!, shot.id!],
      );

      await addonRepository.setForProduct(
        productId: productId,
        addonIds: [shot.id!],
      );

      var relatedAddons = await addonRepository.getForProduct(
        productId: productId,
      );

      expect(relatedAddons.length, 1);
      expect(relatedAddons.first.id, shot.id);

      await addonRepository.setForProduct(productId: productId, addonIds: []);

      relatedAddons = await addonRepository.getForProduct(productId: productId);

      expect(relatedAddons, isEmpty);
    });

    test('rejects inactive add-on and preserves existing relations', () async {
      final cheese = await addonRepository.create(
        name: 'Extra Cheese',
        additionalPrice: 3000,
        stock: 10,
      );

      final shot = await addonRepository.create(
        name: 'Extra Shot',
        additionalPrice: 5000,
        stock: 20,
      );

      await addonRepository.setForProduct(
        productId: productId,
        addonIds: [cheese.id!],
      );

      await addonRepository.deactivate(shot.id!);

      await expectLater(
        addonRepository.setForProduct(
          productId: productId,
          addonIds: [cheese.id!, shot.id!],
        ),
        throwsStateError,
      );

      final relatedAddons = await addonRepository.getForProduct(
        productId: productId,
      );

      expect(relatedAddons.length, 1);
      expect(relatedAddons.first.id, cheese.id);
    });

    test('rejects duplicate add-on IDs', () async {
      final addon = await addonRepository.create(
        name: 'Extra Cheese',
        additionalPrice: 3000,
        stock: 10,
      );

      await expectLater(
        addonRepository.setForProduct(
          productId: productId,
          addonIds: [addon.id!, addon.id!],
        ),
        throwsArgumentError,
      );
    });

    test('rejects assigning add-ons to a nonexistent product', () async {
      final addon = await addonRepository.create(
        name: 'Extra Cheese',
        additionalPrice: 3000,
        stock: 10,
      );

      await expectLater(
        addonRepository.setForProduct(productId: 999, addonIds: [addon.id!]),
        throwsStateError,
      );
    });
  });
}
