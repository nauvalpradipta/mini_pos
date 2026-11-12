import 'package:flutter/foundation.dart';

import 'package:mini_pos/features/settings/models/store_settings.dart';
import 'package:mini_pos/features/settings/repositories/settings_repository.dart';

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel(this._repository);

  final SettingsRepository _repository;

  StoreSettings? _settings;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  StoreSettings? get settings => _settings;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;

  Future<void> ensureLoaded() async {
    if (_hasLoaded || _isLoading) return;

    await load();
  }

  Future<void> load() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _settings = await _repository.getSettings();
      _hasLoaded = true;
    } catch (error) {
      _errorMessage = _getErrorMessage(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateSettings({
    required String storeName,
    required String address,
    required String phone,
    required String receiptFooter,
  }) async {
    if (_isSaving) return false;

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _settings = await _repository.updateSettings(
        storeName: storeName,
        address: address,
        phone: phone,
        receiptFooter: receiptFooter,
      );

      _hasLoaded = true;
      return true;
    } catch (error) {
      _errorMessage = _getErrorMessage(error);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage == null) return;

    _errorMessage = null;
    notifyListeners();
  }

  String _getErrorMessage(Object error) {
    if (error is ArgumentError) {
      return error.message?.toString() ?? 'Data pengaturan toko tidak valid.';
    }

    return 'Terjadi kesalahan saat memproses pengaturan toko.';
  }
}
