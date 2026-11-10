import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  SessionService(this._preferences);

  final SharedPreferences _preferences;

  static const String _userIdKey = 'session_user_id';

  // Menyimpan ID pengguna yang sedang login.
  Future<void> saveUserId(int userId) async {
    if (userId <= 0) {
      throw ArgumentError('ID pengguna tidak valid.');
    }

    final saved = await _preferences.setInt(_userIdKey, userId);

    if (!saved) {
      throw StateError('Gagal menyimpan sesi pengguna.');
    }
  }

  // Mengambil ID pengguna yang tersimpan.
  int? getUserId() {
    return _preferences.getInt(_userIdKey);
  }

  // Memeriksa apakah ada sesi tersimpan.
  bool get hasSession => getUserId() != null;

  // Menghapus sesi pengguna.
  Future<void> clearSession() async {
    await _preferences.remove(_userIdKey);
  }
}
