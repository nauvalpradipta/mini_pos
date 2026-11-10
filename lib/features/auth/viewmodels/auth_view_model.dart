import 'package:flutter/foundation.dart';

import '../models/auth_user.dart';
import '../repositories/auth_repository.dart';
import '../services/session_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated }

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._authRepository, this._sessionService);

  final AuthRepository _authRepository;
  final SessionService _sessionService;

  AuthStatus _status = AuthStatus.initial;
  AuthUser? _currentUser;
  String? _errorMessage;

  AuthStatus get status => _status;
  AuthUser? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;

  bool get isLoading => _status == AuthStatus.loading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  // ---------------------------------------------------
  // 1. RESTORE SESSION
  // ---------------------------------------------------

  Future<void> restoreSession() async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final userId = _sessionService.getUserId();

      if (userId == null) {
        _currentUser = null;
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      final user = await _authRepository.getActiveUserById(userId);

      if (user == null) {
        await _sessionService.clearSession();

        _currentUser = null;
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      _currentUser = user;
      _status = AuthStatus.authenticated;
    } catch (error) {
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = _readableError(error);

      await _clearSessionSafely();
    }

    notifyListeners();
  }

  // ---------------------------------------------------
  // 2. LOGIN
  // ---------------------------------------------------

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authRepository.login(
        username: username,
        password: password,
      );

      if (user == null) {
        _status = AuthStatus.unauthenticated;
        _errorMessage = 'Username atau password salah.';
        notifyListeners();
        return false;
      }

      await _sessionService.saveUserId(user.id);

      _currentUser = user;
      _status = AuthStatus.authenticated;

      notifyListeners();
      return true;
    } catch (error) {
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = _readableError(error);

      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------
  // 3. REGISTER
  // ---------------------------------------------------

  Future<bool> register({
    required String fullName,
    required String username,
    required String password,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authRepository.register(
        fullName: fullName,
        username: username,
        password: password,
      );

      // Pengguna langsung masuk setelah registrasi berhasil.
      await _sessionService.saveUserId(user.id);

      _currentUser = user;
      _status = AuthStatus.authenticated;

      notifyListeners();
      return true;
    } catch (error) {
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = _readableError(error);

      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------
  // 4. LOGOUT
  // ---------------------------------------------------

  Future<void> logout() async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _sessionService.clearSession();
    } catch (error) {
      _errorMessage = _readableError(error);
    }

    _currentUser = null;
    _status = AuthStatus.unauthenticated;

    notifyListeners();
  }

  // ---------------------------------------------------
  // 5. CLEAR ERROR MESSAGE
  // ---------------------------------------------------

  void clearError() {
    if (_errorMessage == null) return;

    _errorMessage = null;
    notifyListeners();
  }

  // ---------------------------------------------------
  // 6. ERROR MESSAGE
  // ---------------------------------------------------

  String _readableError(Object error) {
    final message = error.toString();

    if (error is ArgumentError) {
      return message.replaceFirst('Invalid argument(s): ', '');
    }

    if (error is StateError) {
      return message.replaceFirst('Bad state: ', '');
    }

    return 'Terjadi kesalahan. Silakan coba lagi.';
  }

  Future<void> _clearSessionSafely() async {
    try {
      await _sessionService.clearSession();
    } catch (_) {
      // Session tetap ditolak dalam memori jika proses restore gagal.
    }
  }
}
