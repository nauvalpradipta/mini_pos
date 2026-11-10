import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mini_pos/core/database/database_schema.dart';
import 'package:mini_pos/core/database/database_tables.dart';
import 'package:mini_pos/features/products/repositories/category_repository.dart';

void main() {
  late Database database;
  late CategoryRepository repository;
  late Directory temporaryDirectory;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'kasirku_category_test_',
    );

    final databasePath =
        '${temporaryDirectory.path}${Platform.pathSeparator}test.db';

    database = await databaseFactoryFfi.openDatabase(
      databasePath,
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

    repository = CategoryRepository(database);
  });

  tearDown(() async {
    await database.close();
    await temporaryDirectory.delete(recursive: true);
  });

  group('Category Repository', () {
    test('creates and retrieves a category', () async {
      final id = await repository.create(
        name: ' Coffee ',
        description: ' Hot beverages ',
      );

      final category = await repository.getById(id);

      expect(category, isNotNull);
      expect(category!.name, 'Coffee');
      expect(category.description, 'Hot beverages');
      expect(category.isActive, true);
    });

    test('rejects an empty category name', () async {
      expect(() => repository.create(name: '   '), throwsArgumentError);
    });

    test('retrieves only active categories by default', () async {
      final activeId = await repository.create(name: 'Coffee');

      final inactiveId = await repository.create(name: 'Archived');

      // Directly deactivate a category for test setup.
      await database.update(
        DatabaseTables.categories,
        {'is_active': 0},
        where: 'id = ?',
        whereArgs: [inactiveId],
      );

      final categories = await repository.getAll();

      expect(categories.length, 1);
      expect(categories.first.id, activeId);
      expect(categories.first.name, 'Coffee');
    });

    test('updates an existing category', () async {
      final id = await repository.create(name: 'Coffee');

      await repository.update(
        id: id,
        name: 'Hot Coffee',
        description: 'Coffee-based drinks',
      );

      final category = await repository.getById(id);

      expect(category!.name, 'Hot Coffee');
      expect(category.description, 'Coffee-based drinks');
    });

    test('deactivates a category without deleting its record', () async {
      final id = await repository.create(name: 'Archived Category');

      await repository.deactivate(id);

      final category = await repository.getById(id);
      final activeCategories = await repository.getAll();
      final allCategories = await repository.getAll(activeOnly: false);

      expect(category!.isActive, false);
      expect(activeCategories, isEmpty);
      expect(allCategories, hasLength(1));
    });

    test('prevents deactivation when active products exist', () async {
      final categoryId = await repository.create(name: 'Coffee');

      await database.insert(DatabaseTables.products, {
        'category_id': categoryId,
        'name': 'Milk Coffee',
        'selling_price': 18000,
        'stock_quantity': 10,
        'is_active': 1,
        'created_at': 1,
        'updated_at': 1,
      });

      expect(() => repository.deactivate(categoryId), throwsStateError);

      final category = await repository.getById(categoryId);

      expect(category!.isActive, true);
    });

    test('prevents duplicate names regardless of letter case', () async {
      await repository.create(name: 'Coffee');

      await expectLater(
        repository.create(name: 'coffee'),
        throwsA(isA<DatabaseException>()),
      );
    });
  });
}
