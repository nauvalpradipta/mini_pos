import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_tables.dart';
import '../models/category.dart';

/// Handles all database operations for product categories.
class CategoryRepository {
  final Database _database;

  CategoryRepository(this._database);

  /// Creates a new category.
  Future<int> create({required String name, String? description}) async {
    final normalizedName = name.trim();

    if (normalizedName.isEmpty) {
      throw ArgumentError('Category name cannot be empty.');
    }

    final normalizedDescription = description?.trim();
    final now = DateTime.now();

    final category = Category(
      name: normalizedName,
      description:
          normalizedDescription == null || normalizedDescription.isEmpty
          ? null
          : normalizedDescription,
      createdAt: now,
      updatedAt: now,
    );

    return _database.insert(DatabaseTables.categories, category.toMap());
  }

  /// Retrieves all categories.
  Future<List<Category>> getAll({bool activeOnly = true}) async {
    final result = await _database.query(
      DatabaseTables.categories,
      where: activeOnly ? 'is_active = ?' : null,
      whereArgs: activeOnly ? [1] : null,
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return result.map(Category.fromMap).toList();
  }

  /// Retrieves a category by its ID.
  Future<Category?> getById(int id) async {
    final result = await _database.query(
      DatabaseTables.categories,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return Category.fromMap(result.first);
  }

  /// Updates an existing category.
  Future<void> update({
    required int id,
    required String name,
    String? description,
  }) async {
    final normalizedName = name.trim();

    if (normalizedName.isEmpty) {
      throw ArgumentError('Category name cannot be empty.');
    }

    final normalizedDescription = description?.trim();

    final affectedRows = await _database.update(
      DatabaseTables.categories,
      {
        'name': normalizedName,
        'description':
            normalizedDescription == null || normalizedDescription.isEmpty
            ? null
            : normalizedDescription,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    if (affectedRows == 0) {
      throw StateError('Category not found.');
    }
  }

  /// Soft-deletes a category.
  ///
  /// Categories with active products cannot be deactivated.
  Future<void> deactivate(int id) async {
    await _database.transaction((txn) async {
      final categoryResult = await txn.query(
        DatabaseTables.categories,
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (categoryResult.isEmpty) {
        throw StateError('Category not found.');
      }

      final productResult = await txn.rawQuery(
        '''
        SELECT COUNT(*) AS total
        FROM products
        WHERE category_id = ?
        AND is_active = 1
        ''',
        [id],
      );

      final activeProductCount = productResult.first['total'] as int;

      if (activeProductCount > 0) {
        throw StateError(
          'Move or deactivate active products before deleting this category.',
        );
      }

      await txn.update(
        DatabaseTables.categories,
        {'is_active': 0, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  /// Reactivates a previously deactivated category.
  Future<void> activate(int id) async {
    await _database.transaction((txn) async {
      final categoryResult = await txn.query(
        DatabaseTables.categories,
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (categoryResult.isEmpty) {
        throw StateError('Category not found.');
      }

      await txn.update(
        DatabaseTables.categories,
        {'is_active': 1, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }
}
