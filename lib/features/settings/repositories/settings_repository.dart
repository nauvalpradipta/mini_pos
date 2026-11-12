import 'package:sqflite/sqflite.dart';

import '../models/store_settings.dart';

class SettingsRepository {
  SettingsRepository(this._database);

  final Database _database;

  static const int _settingsId = 1;

  // ---------------------------------------------------
  // GET STORE SETTINGS
  // ---------------------------------------------------

  Future<StoreSettings> getSettings() async {
    final results = await _database.query(
      'app_settings',
      where: 'id = ?',
      whereArgs: [_settingsId],
      limit: 1,
    );

    if (results.isEmpty) {
      throw StateError('Pengaturan toko tidak ditemukan.');
    }

    return StoreSettings.fromMap(results.first);
  }

  // ---------------------------------------------------
  // UPDATE STORE SETTINGS
  // ---------------------------------------------------

  Future<StoreSettings> updateSettings({
    required String storeName,
    required String address,
    required String phone,
    required String receiptFooter,
  }) async {
    final normalizedStoreName = storeName.trim();

    if (normalizedStoreName.isEmpty) {
      throw ArgumentError('Nama toko tidak boleh kosong.');
    }

    final existingSettings = await _database.query(
      'app_settings',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [_settingsId],
      limit: 1,
    );

    if (existingSettings.isEmpty) {
      throw StateError('Pengaturan toko tidak ditemukan.');
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    final affectedRows = await _database.update(
      'app_settings',
      {
        'store_name': normalizedStoreName,
        'address': address.trim(),
        'phone': phone.trim(),
        'receipt_footer': receiptFooter.trim(),
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [_settingsId],
    );

    if (affectedRows != 1) {
      throw StateError('Gagal memperbarui pengaturan toko.');
    }

    return getSettings();
  }
}
