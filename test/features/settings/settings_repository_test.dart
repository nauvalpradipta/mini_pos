import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mini_pos/core/database/database_schema.dart';
import 'package:mini_pos/features/settings/repositories/settings_repository.dart';

void main() {
  late Database database;
  late SettingsRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await DatabaseSchema.create(db);
        },
      ),
    );

    repository = SettingsRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('getSettings', () {
    test('returns default store settings', () async {
      final settings = await repository.getSettings();

      expect(settings.id, 1);
      expect(settings.storeName, 'KASIRKU POS');
      expect(settings.address, '');
      expect(settings.phone, '');
      expect(settings.receiptFooter, 'Thank you for your purchase!');
    });

    test('throws StateError when settings record does not exist', () async {
      await database.delete('app_settings', where: 'id = ?', whereArgs: [1]);

      expect(() => repository.getSettings(), throwsStateError);
    });
  });

  group('updateSettings', () {
    test('updates and persists all store information', () async {
      final updatedSettings = await repository.updateSettings(
        storeName: 'Toko Maju',
        address: 'Jl. Malioboro No. 10',
        phone: '081234567890',
        receiptFooter: 'Terima kasih sudah berbelanja!',
      );

      expect(updatedSettings.storeName, 'Toko Maju');
      expect(updatedSettings.address, 'Jl. Malioboro No. 10');
      expect(updatedSettings.phone, '081234567890');
      expect(updatedSettings.receiptFooter, 'Terima kasih sudah berbelanja!');

      final savedSettings = await repository.getSettings();

      expect(savedSettings.storeName, 'Toko Maju');
      expect(savedSettings.address, 'Jl. Malioboro No. 10');
      expect(savedSettings.phone, '081234567890');
      expect(savedSettings.receiptFooter, 'Terima kasih sudah berbelanja!');
    });

    test('trims whitespace from store name', () async {
      final settings = await repository.updateSettings(
        storeName: '  Toko Maju  ',
        address: '',
        phone: '',
        receiptFooter: '',
      );

      expect(settings.storeName, 'Toko Maju');
    });

    test('rejects an empty store name', () async {
      expect(
        () => repository.updateSettings(
          storeName: '   ',
          address: '',
          phone: '',
          receiptFooter: '',
        ),
        throwsArgumentError,
      );
    });

    test('throws StateError when settings record does not exist', () async {
      await database.delete('app_settings', where: 'id = ?', whereArgs: [1]);

      expect(
        () => repository.updateSettings(
          storeName: 'Toko Maju',
          address: '',
          phone: '',
          receiptFooter: '',
        ),
        throwsStateError,
      );
    });
  });
}
