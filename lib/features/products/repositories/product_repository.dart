import 'package:sqflite/sqflite.dart';

import '../models/product.dart';

class ProductRepository {
  ProductRepository(this._database);

  final Database _database;

  void _validateProduct({
    required String name,
    required int sellingPrice,
    required int stock,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Nama produk tidak boleh kosong.');
    }

    if (sellingPrice < 0) {
      throw ArgumentError('Harga jual tidak boleh negatif.');
    }

    if (stock < 0) {
      throw ArgumentError('Stok produk tidak boleh negatif.');
    }
  }

  Future<void> _validateCategory(int categoryId) async {
    final categories = await _database.query(
      'categories',
      columns: ['id'],
      where: 'id = ? AND is_active = 1',
      whereArgs: [categoryId],
      limit: 1,
    );

    if (categories.isEmpty) {
      throw StateError('Kategori tidak ditemukan atau sudah dinonaktifkan.');
    }
  }

  Future<Product> create({
    required int categoryId,
    required String name,
    required int sellingPrice,
    required int stock,
    String? imagePath,
  }) async {
    final normalizedName = name.trim();

    _validateProduct(
      name: normalizedName,
      sellingPrice: sellingPrice,
      stock: stock,
    );

    await _validateCategory(categoryId);

    final now = DateTime.now().millisecondsSinceEpoch;

    final product = Product(
      categoryId: categoryId,
      name: normalizedName,
      sellingPrice: sellingPrice,
      stock: stock,
      imagePath: imagePath,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    final id = await _database.insert('products', product.toMap());

    return Product(
      id: id,
      categoryId: product.categoryId,
      name: product.name,
      sellingPrice: product.sellingPrice,
      stock: product.stock,
      imagePath: product.imagePath,
      isActive: product.isActive,
      createdAt: product.createdAt,
      updatedAt: product.updatedAt,
    );
  }

  Future<List<Product>> getAll({
    bool activeOnly = true,
    int? categoryId,
    String? searchQuery,
  }) async {
    final conditions = <String>[];
    final arguments = <Object?>[];

    if (activeOnly) {
      conditions.add('is_active = 1');
    }

    if (categoryId != null) {
      conditions.add('category_id = ?');
      arguments.add(categoryId);
    }

    final normalizedQuery = searchQuery?.trim();

    if (normalizedQuery != null && normalizedQuery.isNotEmpty) {
      conditions.add('name LIKE ?');
      arguments.add('%$normalizedQuery%');
    }

    final results = await _database.query(
      'products',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: arguments.isEmpty ? null : arguments,
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return results.map(Product.fromMap).toList();
  }

  Future<Product?> getById(int id) async {
    final results = await _database.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) {
      return null;
    }

    return Product.fromMap(results.first);
  }

  /// Finds an active product with the same name and category.
  ///
  /// Name comparison is case-insensitive.
  /// [excludeId] prevents the current product from matching itself during edit.
  Future<Product?> findActiveDuplicate({
    required int categoryId,
    required String name,
    int? excludeId,
  }) async {
    final normalizedName = name.trim();

    if (normalizedName.isEmpty) {
      return null;
    }

    final conditions = [
      'category_id = ?',
      'name = ? COLLATE NOCASE',
      'is_active = 1',
    ];

    final arguments = <Object?>[categoryId, normalizedName];

    if (excludeId != null) {
      conditions.add('id != ?');
      arguments.add(excludeId);
    }

    final results = await _database.query(
      'products',
      where: conditions.join(' AND '),
      whereArgs: arguments,
      orderBy: 'name COLLATE NOCASE ASC',
      limit: 1,
    );

    if (results.isEmpty) {
      return null;
    }

    return Product.fromMap(results.first);
  }

  Future<Product> update({
    required int id,
    required int categoryId,
    required String name,
    required int sellingPrice,
    required int stock,
    String? imagePath,
  }) async {
    final normalizedName = name.trim();

    _validateProduct(
      name: normalizedName,
      sellingPrice: sellingPrice,
      stock: stock,
    );

    final existingProduct = await getById(id);

    if (existingProduct == null) {
      throw StateError('Produk tidak ditemukan.');
    }

    await _validateCategory(categoryId);

    final now = DateTime.now().millisecondsSinceEpoch;

    await _database.update(
      'products',
      {
        'category_id': categoryId,
        'name': normalizedName,
        'selling_price': sellingPrice,
        'stock_quantity': stock,
        'image_path': imagePath,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    return Product(
      id: id,
      categoryId: categoryId,
      name: normalizedName,
      sellingPrice: sellingPrice,
      stock: stock,
      imagePath: imagePath,
      isActive: existingProduct.isActive,
      createdAt: existingProduct.createdAt,
      updatedAt: now,
    );
  }

  Future<void> deactivate(int id) async {
    await _database.transaction((transaction) async {
      final products = await transaction.query(
        'products',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (products.isEmpty) {
        throw StateError('Produk tidak ditemukan.');
      }

      final now = DateTime.now().millisecondsSinceEpoch;

      await transaction.update(
        'products',
        {'is_active': 0, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }
}
