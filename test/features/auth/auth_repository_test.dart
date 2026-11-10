import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mini_pos/core/database/database_schema.dart';
import 'package:mini_pos/features/auth/repositories/auth_repository.dart';
import 'package:mini_pos/features/auth/services/password_hasher.dart';

void main() {
  late Database database;
  late AuthRepository authRepository;
  late PasswordHasher passwordHasher;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await DatabaseSchema.create(db);
        },
      ),
    );

    // Gunakan parameter ringan agar test lebih cepat.
    passwordHasher = PasswordHasher(
      algorithm: Argon2id(
        parallelism: 1,
        memory: 1024,
        iterations: 1,
        hashLength: 32,
      ),
    );

    authRepository = AuthRepository(database, passwordHasher);
  });

  tearDown(() async {
    await database.close();
  });

  group('AuthRepository', () {
    test('registers a new user', () async {
      final user = await authRepository.register(
        fullName: 'Nauval Pradipta',
        username: 'nauval',
        password: 'password123',
      );

      expect(user.id, greaterThan(0));
      expect(user.fullName, 'Nauval Pradipta');
      expect(user.username, 'nauval');
      expect(user.isActive, isTrue);

      final users = await database.query(
        'users',
        where: 'id = ?',
        whereArgs: [user.id],
      );

      expect(users.length, 1);

      // Password asli tidak boleh tersimpan.
      expect(users.first['password_hash'], isNot('password123'));

      expect(users.first['password_hash'], isNotEmpty);
      expect(users.first['password_salt'], isNotEmpty);
    });

    test('trims full name and username during registration', () async {
      final user = await authRepository.register(
        fullName: '  Test Cashier  ',
        username: '  cashier  ',
        password: 'password123',
      );

      expect(user.fullName, 'Test Cashier');
      expect(user.username, 'cashier');
    });

    test('rejects an empty full name', () async {
      await expectLater(
        authRepository.register(
          fullName: '   ',
          username: 'cashier',
          password: 'password123',
        ),
        throwsArgumentError,
      );
    });

    test('rejects an empty username', () async {
      await expectLater(
        authRepository.register(
          fullName: 'Test Cashier',
          username: '   ',
          password: 'password123',
        ),
        throwsArgumentError,
      );
    });

    test('rejects a password shorter than eight characters', () async {
      await expectLater(
        authRepository.register(
          fullName: 'Test Cashier',
          username: 'cashier',
          password: '1234567',
        ),
        throwsArgumentError,
      );
    });

    test('rejects duplicate usernames regardless of letter case', () async {
      await authRepository.register(
        fullName: 'First Cashier',
        username: 'cashier',
        password: 'password123',
      );

      await expectLater(
        authRepository.register(
          fullName: 'Second Cashier',
          username: 'CASHIER',
          password: 'password456',
        ),
        throwsStateError,
      );
    });

    test('logs in with correct credentials', () async {
      await authRepository.register(
        fullName: 'Test Cashier',
        username: 'cashier',
        password: 'password123',
      );

      final user = await authRepository.login(
        username: 'cashier',
        password: 'password123',
      );

      expect(user, isNotNull);
      expect(user!.fullName, 'Test Cashier');
      expect(user.username, 'cashier');
      expect(user.isActive, isTrue);
    });

    test('rejects an incorrect password', () async {
      await authRepository.register(
        fullName: 'Test Cashier',
        username: 'cashier',
        password: 'password123',
      );

      final user = await authRepository.login(
        username: 'cashier',
        password: 'wrongpassword',
      );

      expect(user, isNull);
    });

    test('rejects a nonexistent username', () async {
      final user = await authRepository.login(
        username: 'unknown',
        password: 'password123',
      );

      expect(user, isNull);
    });

    test('supports case-insensitive username login', () async {
      await authRepository.register(
        fullName: 'Test Cashier',
        username: 'cashier',
        password: 'password123',
      );

      final user = await authRepository.login(
        username: 'CASHIER',
        password: 'password123',
      );

      expect(user, isNotNull);
      expect(user!.username, 'cashier');
    });

    test('rejects login for an inactive account', () async {
      final user = await authRepository.register(
        fullName: 'Test Cashier',
        username: 'cashier',
        password: 'password123',
      );

      await database.update(
        'users',
        {'is_active': 0},
        where: 'id = ?',
        whereArgs: [user.id],
      );

      final loginResult = await authRepository.login(
        username: 'cashier',
        password: 'password123',
      );

      expect(loginResult, isNull);
    });

    test('gets an active user by ID', () async {
      final createdUser = await authRepository.register(
        fullName: 'Test Cashier',
        username: 'cashier',
        password: 'password123',
      );

      final user = await authRepository.getActiveUserById(createdUser.id);

      expect(user, isNotNull);
      expect(user!.id, createdUser.id);
      expect(user.username, 'cashier');
    });

    test('returns null when user does not exist', () async {
      final user = await authRepository.getActiveUserById(999);

      expect(user, isNull);
    });

    test('returns null when user is inactive', () async {
      final createdUser = await authRepository.register(
        fullName: 'Test Cashier',
        username: 'cashier',
        password: 'password123',
      );

      await database.update(
        'users',
        {'is_active': 0},
        where: 'id = ?',
        whereArgs: [createdUser.id],
      );

      final user = await authRepository.getActiveUserById(createdUser.id);

      expect(user, isNull);
    });
  });
}
