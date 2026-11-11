import 'package:sqflite/sqflite.dart';

import '../models/addon.dart';

class AddonRepository {
  AddonRepository(this._database);

  final Database _database;

  void _validateAddon({
    required String name,
    required int additionalPrice,
    required int stock,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Nama add-on tidak boleh kosong.');
    }

    if (additionalPrice < 0) {
      throw ArgumentError('Harga tambahan tidak boleh negatif.');
    }

    if (stock < 0) {
      throw ArgumentError('Stok add-on tidak boleh negatif.');
    }
  }

  Future<Addon> create({
    required String name,
    required int additionalPrice,
    required int stock,
  }) async {
    final normalizedName = name.trim();

    _validateAddon(
      name: normalizedName,
      additionalPrice: additionalPrice,
      stock: stock,
    );

    final now = DateTime.now().millisecondsSinceEpoch;

    final addon = Addon(
      name: normalizedName,
      additionalPrice: additionalPrice,
      stock: stock,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    final id = await _database.insert('addons', addon.toMap());

    return Addon(
      id: id,
      name: addon.name,
      additionalPrice: addon.additionalPrice,
      stock: addon.stock,
      isActive: addon.isActive,
      createdAt: addon.createdAt,
      updatedAt: addon.updatedAt,
    );
  }

  Future<List<Addon>> getAll({bool activeOnly = true}) async {
    final results = await _database.query(
      'addons',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return results.map(Addon.fromMap).toList();
  }

  Future<Addon?> getById(int id) async {
    final results = await _database.query(
      'addons',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) {
      return null;
    }

    return Addon.fromMap(results.first);
  }

  Future<Addon> update({
    required int id,
    required String name,
    required int additionalPrice,
    required int stock,
  }) async {
    final normalizedName = name.trim();

    _validateAddon(
      name: normalizedName,
      additionalPrice: additionalPrice,
      stock: stock,
    );

    final existingAddon = await getById(id);

    if (existingAddon == null) {
      throw StateError('Add-on tidak ditemukan.');
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    await _database.update(
      'addons',
      {
        'name': normalizedName,
        'additional_price': additionalPrice,
        'stock_quantity': stock,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    return Addon(
      id: id,
      name: normalizedName,
      additionalPrice: additionalPrice,
      stock: stock,
      isActive: existingAddon.isActive,
      createdAt: existingAddon.createdAt,
      updatedAt: now,
    );
  }

  Future<void> deactivate(int id) async {
    await _database.transaction((transaction) async {
      final addons = await transaction.query(
        'addons',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (addons.isEmpty) {
        throw StateError('Add-on tidak ditemukan.');
      }

      final now = DateTime.now().millisecondsSinceEpoch;

      await transaction.update(
        'addons',
        {'is_active': 0, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  /// Reactivates a previously deactivated add-on.
  Future<void> activate(int id) async {
    await _database.transaction((transaction) async {
      final addons = await transaction.query(
        'addons',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (addons.isEmpty) {
        throw StateError('Add-on tidak ditemukan.');
      }

      await transaction.update(
        'addons',
        {'is_active': 1, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  // Mengatur seluruh add-on yang tersedia untuk suatu produk.
  Future<void> setForProduct({
    required int productId,
    required List<int> addonIds,
  }) async {
    final uniqueAddonIds = addonIds.toSet();

    if (uniqueAddonIds.length != addonIds.length) {
      throw ArgumentError('Daftar add-on tidak boleh duplikat.');
    }

    await _database.transaction((transaction) async {
      // Pastikan produk tersedia dan masih aktif.
      final products = await transaction.query(
        'products',
        columns: ['id'],
        where: 'id = ? AND is_active = 1',
        whereArgs: [productId],
        limit: 1,
      );

      if (products.isEmpty) {
        throw StateError('Produk tidak ditemukan atau sudah dinonaktifkan.');
      }

      // Pastikan semua add-on tersedia dan masih aktif.
      for (final addonId in uniqueAddonIds) {
        final addons = await transaction.query(
          'addons',
          columns: ['id'],
          where: 'id = ? AND is_active = 1',
          whereArgs: [addonId],
          limit: 1,
        );

        if (addons.isEmpty) {
          throw StateError(
            'Add-on dengan ID $addonId tidak ditemukan atau tidak aktif.',
          );
        }
      }

      // Hapus relasi lama hanya setelah seluruh validasi berhasil.
      await transaction.delete(
        'product_addons',
        where: 'product_id = ?',
        whereArgs: [productId],
      );

      final now = DateTime.now().millisecondsSinceEpoch;

      // Simpan relasi baru.
      for (final addonId in uniqueAddonIds) {
        await transaction.insert('product_addons', {
          'product_id': productId,
          'addon_id': addonId,
          'created_at': now,
        });
      }
    });
  }

  // Mengambil add-on yang terhubung dengan suatu produk.
  Future<List<Addon>> getForProduct({
    required int productId,
    bool activeOnly = true,
  }) async {
    final activeCondition = activeOnly ? 'AND a.is_active = 1' : '';

    final results = await _database.rawQuery(
      '''
      SELECT a.*
      FROM addons a
      INNER JOIN product_addons pa
        ON pa.addon_id = a.id
      WHERE pa.product_id = ?
      $activeCondition
      ORDER BY a.name COLLATE NOCASE ASC
      ''',
      [productId],
    );

    return results.map(Addon.fromMap).toList();
  }
}
