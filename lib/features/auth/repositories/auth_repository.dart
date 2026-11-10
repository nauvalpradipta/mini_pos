import 'package:sqflite/sqflite.dart';

import '../models/auth_user.dart';
import '../services/password_hasher.dart';

class AuthRepository {
  AuthRepository(this._database, this._passwordHasher);

  final Database _database;
  final PasswordHasher _passwordHasher;

  // ---------------------------------------------------
  // 1. VALIDASI INPUT REGISTRASI
  // ---------------------------------------------------

  void _validateRegistration({
    required String fullName,
    required String username,
    required String password,
  }) {
    if (fullName.trim().isEmpty) {
      throw ArgumentError('Nama lengkap tidak boleh kosong.');
    }

    if (username.trim().isEmpty) {
      throw ArgumentError('Username tidak boleh kosong.');
    }

    if (password.length < 8) {
      throw ArgumentError('Password harus terdiri dari minimal 8 karakter.');
    }
  }

  // ---------------------------------------------------
  // 2. REGISTRASI PENGGUNA
  // ---------------------------------------------------

  Future<AuthUser> register({
    required String fullName,
    required String username,
    required String password,
  }) async {
    final normalizedFullName = fullName.trim();
    final normalizedUsername = username.trim();

    _validateRegistration(
      fullName: normalizedFullName,
      username: normalizedUsername,
      password: password,
    );

    // Periksa apakah username sudah digunakan.
    // Database menggunakan COLLATE NOCASE,
    // sehingga perbedaan huruf besar/kecil diabaikan.
    final existingUsers = await _database.query(
      'users',
      columns: ['id'],
      where: 'username = ?',
      whereArgs: [normalizedUsername],
      limit: 1,
    );

    if (existingUsers.isNotEmpty) {
      throw StateError('Username sudah digunakan.');
    }

    // Hash password sebelum disimpan.
    final passwordResult = await _passwordHasher.hashPassword(password);

    final now = DateTime.now().millisecondsSinceEpoch;

    final id = await _database.insert('users', {
      'full_name': normalizedFullName,
      'username': normalizedUsername,
      'password_hash': passwordResult.hash,
      'password_salt': passwordResult.salt,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });

    return AuthUser(
      id: id,
      fullName: normalizedFullName,
      username: normalizedUsername,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  // ---------------------------------------------------
  // 3. LOGIN
  // ---------------------------------------------------

  Future<AuthUser?> login({
    required String username,
    required String password,
  }) async {
    final normalizedUsername = username.trim();

    if (normalizedUsername.isEmpty || password.isEmpty) {
      return null;
    }

    // Cari akun yang masih aktif.
    final users = await _database.query(
      'users',
      where: 'username = ? AND is_active = 1',
      whereArgs: [normalizedUsername],
      limit: 1,
    );

    if (users.isEmpty) {
      return null;
    }

    final userData = users.first;

    final isPasswordValid = await _passwordHasher.verifyPassword(
      password: password,
      storedHash: userData['password_hash'] as String,
      storedSalt: userData['password_salt'] as String,
    );

    if (!isPasswordValid) {
      return null;
    }

    return AuthUser.fromMap(userData);
  }

  // ---------------------------------------------------
  // 4. MENGAMBIL PENGGUNA AKTIF BERDASARKAN ID
  // ---------------------------------------------------

  Future<AuthUser?> getActiveUserById(int id) async {
    final users = await _database.query(
      'users',
      where: 'id = ? AND is_active = 1',
      whereArgs: [id],
      limit: 1,
    );

    if (users.isEmpty) {
      return null;
    }

    return AuthUser.fromMap(users.first);
  }
}
