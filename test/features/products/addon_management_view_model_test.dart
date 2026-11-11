import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mini_pos/core/database/database_schema.dart';
import 'package:mini_pos/features/products/repositories/addon_repository.dart';
import 'package:mini_pos/features/products/viewmodels/addon_management_view_model.dart';
import 'package:mini_pos/features/products/repositories/category_repository.dart';
import 'package:mini_pos/features/products/repositories/product_repository.dart';

void main() {
  late CategoryRepository categoryRepository;
  late ProductRepository productRepository;
  late int productId;
  late Database database;
  late AddonRepository addonRepository;
  late AddonManagementViewModel viewModel;

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

    productId = product.id!;

    viewModel = AddonManagementViewModel(addonRepository);
  });

  tearDown(() async {
    viewModel.dispose();
    await database.close();
  });

  group('AddonManagementViewModel', () {
    test('loads active and inactive add-ons separately', () async {
      final active = await addonRepository.create(
        name: 'Extra Shot',
        additionalPrice: 5000,
        stock: 20,
      );

      final inactive = await addonRepository.create(
        name: 'Extra Cheese',
        additionalPrice: 3000,
        stock: 10,
      );

      await addonRepository.deactivate(inactive.id!);

      await viewModel.load();

      expect(viewModel.hasLoaded, isTrue);
      expect(viewModel.isLoading, isFalse);

      expect(viewModel.addons.length, 1);
      expect(viewModel.addons.first.id, active.id);

      expect(viewModel.inactiveAddons.length, 1);
      expect(viewModel.inactiveAddons.first.id, inactive.id);
    });

    test('creates a new add-on', () async {
      await viewModel.load();

      final success = await viewModel.createAddon(
        name: 'Extra Shot',
        additionalPrice: 5000,
        stock: 30,
      );

      expect(success, isTrue);
      expect(viewModel.addons.length, 1);
      expect(viewModel.addons.first.name, 'Extra Shot');
      expect(viewModel.addons.first.additionalPrice, 5000);
      expect(viewModel.addons.first.stock, 30);

      expect(viewModel.successMessage, 'Add-on berhasil ditambahkan.');
      expect(viewModel.isSaving, isFalse);
    });

    test('updates an existing add-on', () async {
      final addon = await addonRepository.create(
        name: 'Extra Shot',
        additionalPrice: 5000,
        stock: 10,
      );

      await viewModel.load();

      final success = await viewModel.updateAddon(
        id: addon.id!,
        name: 'Double Shot',
        additionalPrice: 8000,
        stock: 25,
      );

      expect(success, isTrue);
      expect(viewModel.addons.length, 1);
      expect(viewModel.addons.first.name, 'Double Shot');
      expect(viewModel.addons.first.additionalPrice, 8000);
      expect(viewModel.addons.first.stock, 25);
      expect(viewModel.addons.first.createdAt, addon.createdAt);

      expect(viewModel.successMessage, 'Add-on berhasil diperbarui.');
    });

    test('deactivates an add-on and moves it to inactive list', () async {
      final addon = await addonRepository.create(
        name: 'Extra Cheese',
        additionalPrice: 3000,
        stock: 10,
      );

      await viewModel.load();

      final success = await viewModel.deactivateAddon(addon.id!);

      expect(success, isTrue);
      expect(viewModel.addons, isEmpty);
      expect(viewModel.inactiveAddons.length, 1);
      expect(viewModel.inactiveAddons.first.id, addon.id);
      expect(viewModel.inactiveAddons.first.isActive, isFalse);

      expect(viewModel.successMessage, 'Add-on berhasil dinonaktifkan.');
    });

    test('reactivates an add-on and moves it to active list', () async {
      final addon = await addonRepository.create(
        name: 'Extra Shot',
        additionalPrice: 5000,
        stock: 20,
      );

      await addonRepository.deactivate(addon.id!);
      await viewModel.load();

      final success = await viewModel.activateAddon(addon.id!);

      expect(success, isTrue);
      expect(viewModel.inactiveAddons, isEmpty);
      expect(viewModel.addons.length, 1);
      expect(viewModel.addons.first.id, addon.id);
      expect(viewModel.addons.first.isActive, isTrue);

      expect(viewModel.successMessage, 'Add-on berhasil diaktifkan kembali.');
    });

    test('searches add-ons case-insensitively', () async {
      await addonRepository.create(
        name: 'Extra Cheese',
        additionalPrice: 3000,
        stock: 10,
      );

      await addonRepository.create(
        name: 'Extra Shot',
        additionalPrice: 5000,
        stock: 20,
      );

      await addonRepository.create(
        name: 'Caramel',
        additionalPrice: 2000,
        stock: 15,
      );

      await viewModel.load();

      viewModel.setSearchQuery('EXTRA');

      expect(viewModel.addons.length, 2);
      expect(viewModel.addons.map((addon) => addon.name).toList(), [
        'Extra Cheese',
        'Extra Shot',
      ]);

      viewModel.setSearchQuery('Caramel');

      expect(viewModel.addons.length, 1);
      expect(viewModel.addons.first.name, 'Caramel');

      viewModel.setSearchQuery('');

      expect(viewModel.addons.length, 3);
    });

    test('searches inactive add-ons', () async {
      final addon = await addonRepository.create(
        name: 'Extra Cheese',
        additionalPrice: 3000,
        stock: 10,
      );

      await addonRepository.deactivate(addon.id!);
      await viewModel.load();

      viewModel.setSearchQuery('cheese');

      expect(viewModel.addons, isEmpty);
      expect(viewModel.inactiveAddons.length, 1);
      expect(viewModel.inactiveAddons.first.name, 'Extra Cheese');
    });

    test('rejects duplicate names with a readable error', () async {
      await viewModel.load();

      final firstSuccess = await viewModel.createAddon(
        name: 'Extra Shot',
        additionalPrice: 5000,
        stock: 20,
      );

      expect(firstSuccess, isTrue);

      final secondSuccess = await viewModel.createAddon(
        name: 'extra shot',
        additionalPrice: 6000,
        stock: 30,
      );

      expect(secondSuccess, isFalse);
      expect(viewModel.errorMessage, 'Nama add-on sudah digunakan.');

      expect(viewModel.addons.length, 1);
    });

    test('returns a readable error when updating nonexistent add-on', () async {
      await viewModel.load();

      final success = await viewModel.updateAddon(
        id: 999,
        name: 'Extra Shot',
        additionalPrice: 5000,
        stock: 20,
      );

      expect(success, isFalse);
      expect(viewModel.errorMessage, 'Add-on tidak ditemukan.');
      expect(viewModel.isSaving, isFalse);
    });

    test('clears error and success messages', () async {
      await viewModel.load();

      await viewModel.createAddon(
        name: 'Extra Shot',
        additionalPrice: 5000,
        stock: 20,
      );

      expect(viewModel.successMessage, isNotNull);

      viewModel.clearMessages();

      expect(viewModel.successMessage, isNull);
      expect(viewModel.errorMessage, isNull);
    });

    test('returns immutable add-on lists', () async {
      await viewModel.load();

      expect(() => viewModel.addons.clear(), throwsUnsupportedError);

      expect(() => viewModel.inactiveAddons.clear(), throwsUnsupportedError);
    });

    test('gets active add-ons assigned to a product', () async {
      final extraShot = await addonRepository.create(
        name: 'Extra Shot',
        additionalPrice: 5000,
        stock: 20,
      );

      final extraCheese = await addonRepository.create(
        name: 'Extra Cheese',
        additionalPrice: 3000,
        stock: 10,
      );

      await addonRepository.setForProduct(
        productId: productId,
        addonIds: [extraShot.id!, extraCheese.id!],
      );

      await addonRepository.deactivate(extraCheese.id!);

      await viewModel.load();

      final assignedAddons = await viewModel.getAssignedAddons(productId);

      expect(assignedAddons.length, 1);
      expect(assignedAddons.first.id, extraShot.id);
    });

    test('assigns selected add-ons to a product', () async {
      final extraShot = await addonRepository.create(
        name: 'Extra Shot',
        additionalPrice: 5000,
        stock: 20,
      );

      final caramel = await addonRepository.create(
        name: 'Caramel',
        additionalPrice: 2000,
        stock: 15,
      );

      await viewModel.load();

      final success = await viewModel.assignAddonsToProduct(
        productId: productId,
        addonIds: [extraShot.id!, caramel.id!],
      );

      expect(success, isTrue);
      expect(
        viewModel.successMessage,
        'Pilihan add-on produk berhasil diperbarui.',
      );

      final assignedAddons = await viewModel.getAssignedAddons(productId);

      expect(assignedAddons.length, 2);
      expect(assignedAddons.map((addon) => addon.id).toSet(), {
        extraShot.id,
        caramel.id,
      });
    });

    test('clears all add-on assignments from a product', () async {
      final addon = await addonRepository.create(
        name: 'Extra Shot',
        additionalPrice: 5000,
        stock: 20,
      );

      await addonRepository.setForProduct(
        productId: productId,
        addonIds: [addon.id!],
      );

      await viewModel.load();

      final success = await viewModel.assignAddonsToProduct(
        productId: productId,
        addonIds: [],
      );

      expect(success, isTrue);

      final assignedAddons = await viewModel.getAssignedAddons(productId);

      expect(assignedAddons, isEmpty);
    });
  });
}
