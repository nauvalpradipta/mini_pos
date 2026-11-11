import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mini_pos/core/database/database_schema.dart';
import 'package:mini_pos/features/products/repositories/category_repository.dart';
import 'package:mini_pos/features/products/repositories/product_repository.dart';
import 'package:mini_pos/features/products/viewmodels/product_management_view_model.dart';

void main() {
  late Database database;
  late CategoryRepository categoryRepository;
  late ProductManagementViewModel viewModel;

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

    viewModel = ProductManagementViewModel(
      categoryRepository,
      ProductRepository(database),
    );
  });

  tearDown(() async {
    viewModel.dispose();
    await database.close();
  });

  group('CategoryRepository activation', () {
    test('reactivates category with the same ID and name', () async {
      final categoryId = await categoryRepository.create(
        name: 'Minuman',
        description: 'Kategori minuman',
      );

      await categoryRepository.deactivate(categoryId);

      final inactiveCategory = await categoryRepository.getById(categoryId);

      expect(inactiveCategory, isNotNull);
      expect(inactiveCategory!.isActive, isFalse);

      await categoryRepository.activate(categoryId);

      final activeCategory = await categoryRepository.getById(categoryId);

      expect(activeCategory, isNotNull);
      expect(activeCategory!.id, categoryId);
      expect(activeCategory.name, 'Minuman');
      expect(activeCategory.description, 'Kategori minuman');
      expect(activeCategory.isActive, isTrue);
    });

    test('prevents duplicate name after deactivation', () async {
      final categoryId = await categoryRepository.create(name: 'Minuman');

      await categoryRepository.deactivate(categoryId);

      await expectLater(
        categoryRepository.create(name: 'Minuman'),
        throwsA(isA<DatabaseException>()),
      );

      await categoryRepository.activate(categoryId);

      final category = await categoryRepository.getById(categoryId);

      expect(category, isNotNull);
      expect(category!.isActive, isTrue);
    });

    test('throws when activating a nonexistent category', () async {
      await expectLater(
        categoryRepository.activate(999),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('ProductManagementViewModel category activation', () {
    test('separates active and inactive categories when loading', () async {
      final activeId = await categoryRepository.create(name: 'Makanan');

      final inactiveId = await categoryRepository.create(name: 'Minuman');

      await categoryRepository.deactivate(inactiveId);

      await viewModel.load();

      expect(viewModel.categories.length, 1);
      expect(viewModel.categories.first.id, activeId);

      expect(viewModel.inactiveCategories.length, 1);
      expect(viewModel.inactiveCategories.first.id, inactiveId);
    });

    test('moves category to active list after reactivation', () async {
      final categoryId = await categoryRepository.create(name: 'Minuman');

      await categoryRepository.deactivate(categoryId);

      await viewModel.load();

      expect(viewModel.categories, isEmpty);
      expect(viewModel.inactiveCategories.length, 1);

      final success = await viewModel.activateCategory(categoryId);

      expect(success, isTrue);
      expect(viewModel.categories.length, 1);
      expect(viewModel.categories.first.id, categoryId);
      expect(viewModel.categories.first.name, 'Minuman');
      expect(viewModel.inactiveCategories, isEmpty);
      expect(viewModel.successMessage, 'Kategori berhasil diaktifkan kembali.');
    });

    test('returns failure when category does not exist', () async {
      await viewModel.load();

      final success = await viewModel.activateCategory(999);

      expect(success, isFalse);
      expect(viewModel.errorMessage, 'Category not found.');
    });
  });
}
