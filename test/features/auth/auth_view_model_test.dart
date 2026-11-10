import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mini_pos/core/database/database_schema.dart';
import 'package:mini_pos/features/auth/repositories/auth_repository.dart';
import 'package:mini_pos/features/auth/services/password_hasher.dart';
import 'package:mini_pos/features/auth/services/session_service.dart';
import 'package:mini_pos/features/auth/viewmodels/auth_view_model.dart';

void main() {
  late Database database;
  late AuthRepository authRepository;
  late SessionService sessionService;
  late AuthViewModel authViewModel;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

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

    final preferences = await SharedPreferences.getInstance();

    final passwordHasher = PasswordHasher(
      algorithm: Argon2id(
        parallelism: 1,
        memory: 1024,
        iterations: 1,
        hashLength: 32,
      ),
    );

    authRepository = AuthRepository(database, passwordHasher);

    sessionService = SessionService(preferences);

    authViewModel = AuthViewModel(authRepository, sessionService);
  });

  tearDown(() async {
    authViewModel.dispose();
    await database.close();
  });

  group('AuthViewModel', () {
    test('starts with initial status', () {
      expect(authViewModel.status, AuthStatus.initial);
      expect(authViewModel.currentUser, isNull);
      expect(authViewModel.isAuthenticated, isFalse);
      expect(authViewModel.isLoading, isFalse);
    });

    test('restores unauthenticated state when no session exists', () async {
      await authViewModel.restoreSession();

      expect(authViewModel.status, AuthStatus.unauthenticated);
      expect(authViewModel.currentUser, isNull);
      expect(authViewModel.isAuthenticated, isFalse);
    });

    test('restores authenticated user from existing session', () async {
      final user = await authRepository.register(
        fullName: 'Test Cashier',
        username: 'cashier',
        password: 'password123',
      );

      await sessionService.saveUserId(user.id);

      await authViewModel.restoreSession();

      expect(authViewModel.status, AuthStatus.authenticated);
      expect(authViewModel.currentUser!.id, user.id);
      expect(authViewModel.currentUser!.username, 'cashier');
      expect(authViewModel.isAuthenticated, isTrue);
    });

    test('clears session when stored user is inactive', () async {
      final user = await authRepository.register(
        fullName: 'Test Cashier',
        username: 'cashier',
        password: 'password123',
      );

      await sessionService.saveUserId(user.id);

      await database.update(
        'users',
        {'is_active': 0},
        where: 'id = ?',
        whereArgs: [user.id],
      );

      await authViewModel.restoreSession();

      expect(authViewModel.status, AuthStatus.unauthenticated);
      expect(authViewModel.currentUser, isNull);
      expect(sessionService.hasSession, isFalse);
    });

    test('logs in successfully and saves session', () async {
      await authRepository.register(
        fullName: 'Test Cashier',
        username: 'cashier',
        password: 'password123',
      );

      final success = await authViewModel.login(
        username: 'cashier',
        password: 'password123',
      );

      expect(success, isTrue);
      expect(authViewModel.status, AuthStatus.authenticated);
      expect(authViewModel.currentUser!.username, 'cashier');
      expect(sessionService.hasSession, isTrue);
    });

    test('returns false when login credentials are incorrect', () async {
      await authRepository.register(
        fullName: 'Test Cashier',
        username: 'cashier',
        password: 'password123',
      );

      final success = await authViewModel.login(
        username: 'cashier',
        password: 'wrongpassword',
      );

      expect(success, isFalse);
      expect(authViewModel.status, AuthStatus.unauthenticated);
      expect(authViewModel.currentUser, isNull);
      expect(authViewModel.errorMessage, isNotNull);
      expect(sessionService.hasSession, isFalse);
    });

    test('registers a user and automatically authenticates', () async {
      final success = await authViewModel.register(
        fullName: 'New Cashier',
        username: 'newcashier',
        password: 'password123',
      );

      expect(success, isTrue);
      expect(authViewModel.status, AuthStatus.authenticated);
      expect(authViewModel.currentUser!.fullName, 'New Cashier');
      expect(authViewModel.currentUser!.username, 'newcashier');
      expect(sessionService.hasSession, isTrue);
    });

    test('handles registration failure', () async {
      await authRepository.register(
        fullName: 'Existing Cashier',
        username: 'cashier',
        password: 'password123',
      );

      final success = await authViewModel.register(
        fullName: 'Another Cashier',
        username: 'cashier',
        password: 'password456',
      );

      expect(success, isFalse);
      expect(authViewModel.status, AuthStatus.unauthenticated);
      expect(authViewModel.currentUser, isNull);
      expect(authViewModel.errorMessage, isNotNull);
    });

    test('logs out and clears session', () async {
      await authViewModel.register(
        fullName: 'Test Cashier',
        username: 'cashier',
        password: 'password123',
      );

      await authViewModel.logout();

      expect(authViewModel.status, AuthStatus.unauthenticated);
      expect(authViewModel.currentUser, isNull);
      expect(sessionService.hasSession, isFalse);
    });

    test('clears authentication error message', () async {
      await authViewModel.login(username: 'unknown', password: 'wrongpassword');

      expect(authViewModel.errorMessage, isNotNull);

      authViewModel.clearError();

      expect(authViewModel.errorMessage, isNull);
    });
  });
}
