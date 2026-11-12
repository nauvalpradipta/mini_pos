import 'package:flutter_test/flutter_test.dart';

import 'package:mini_pos/features/settings/models/store_settings.dart';
import 'package:mini_pos/features/settings/repositories/settings_repository.dart';
import 'package:mini_pos/features/settings/viewmodels/settings_view_model.dart';

class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository(this.settings);

  StoreSettings settings;

  Object? loadError;
  Object? updateError;

  int getSettingsCalls = 0;
  int updateSettingsCalls = 0;

  @override
  Future<StoreSettings> getSettings() async {
    getSettingsCalls++;

    if (loadError != null) {
      throw loadError!;
    }

    return settings;
  }

  @override
  Future<StoreSettings> updateSettings({
    required String storeName,
    required String address,
    required String phone,
    required String receiptFooter,
  }) async {
    updateSettingsCalls++;

    if (updateError != null) {
      throw updateError!;
    }

    settings = StoreSettings(
      id: settings.id,
      storeName: storeName.trim(),
      address: address,
      phone: phone,
      receiptFooter: receiptFooter,
      createdAt: settings.createdAt,
      updatedAt: settings.updatedAt + 1,
    );

    return settings;
  }
}

StoreSettings createSettings({
  String storeName = 'KASIRKU POS',
  String address = '',
  String phone = '',
  String receiptFooter = 'Thank you for your purchase!',
}) {
  return StoreSettings(
    id: 1,
    storeName: storeName,
    address: address,
    phone: phone,
    receiptFooter: receiptFooter,
    createdAt: 1000,
    updatedAt: 1000,
  );
}

void main() {
  late FakeSettingsRepository repository;
  late SettingsViewModel viewModel;

  setUp(() {
    repository = FakeSettingsRepository(createSettings());
    viewModel = SettingsViewModel(repository);
  });

  tearDown(() {
    viewModel.dispose();
  });

  group('Initial state', () {
    test('has default state before loading', () {
      expect(viewModel.settings, isNull);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.isSaving, isFalse);
      expect(viewModel.hasLoaded, isFalse);
      expect(viewModel.errorMessage, isNull);
    });
  });

  group('load', () {
    test('loads store settings from repository', () async {
      await viewModel.load();

      expect(viewModel.settings?.storeName, 'KASIRKU POS');
      expect(viewModel.hasLoaded, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(repository.getSettingsCalls, 1);
    });

    test('ensureLoaded only loads settings once', () async {
      await viewModel.ensureLoaded();
      await viewModel.ensureLoaded();

      expect(repository.getSettingsCalls, 1);
      expect(viewModel.hasLoaded, isTrue);
    });

    test('stores error when loading fails', () async {
      repository.loadError = Exception('Database error');

      await viewModel.load();

      expect(viewModel.settings, isNull);
      expect(viewModel.hasLoaded, isFalse);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNotNull);
    });
  });

  group('updateSettings', () {
    test('updates store settings successfully', () async {
      await viewModel.load();

      final result = await viewModel.updateSettings(
        storeName: 'Toko Maju',
        address: 'Jl. Malioboro No. 10',
        phone: '081234567890',
        receiptFooter: 'Terima kasih!',
      );

      expect(result, isTrue);
      expect(viewModel.settings?.storeName, 'Toko Maju');
      expect(viewModel.settings?.address, 'Jl. Malioboro No. 10');
      expect(viewModel.settings?.phone, '081234567890');
      expect(viewModel.settings?.receiptFooter, 'Terima kasih!');
      expect(viewModel.isSaving, isFalse);
      expect(viewModel.errorMessage, isNull);
      expect(repository.updateSettingsCalls, 1);
    });

    test('keeps previous settings when update fails', () async {
      await viewModel.load();

      repository.updateError = Exception('Database error');

      final result = await viewModel.updateSettings(
        storeName: 'Toko Baru',
        address: 'Alamat Baru',
        phone: '080000000000',
        receiptFooter: 'Terima kasih!',
      );

      expect(result, isFalse);
      expect(viewModel.settings?.storeName, 'KASIRKU POS');
      expect(viewModel.isSaving, isFalse);
      expect(viewModel.errorMessage, isNotNull);
    });
  });

  group('clearError', () {
    test('clears the current error message', () async {
      repository.loadError = Exception('Database error');

      await viewModel.load();

      expect(viewModel.errorMessage, isNotNull);

      viewModel.clearError();

      expect(viewModel.errorMessage, isNull);
    });
  });
}
