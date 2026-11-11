import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mini_pos/core/database/database_schema.dart';
import 'package:mini_pos/features/products/repositories/category_repository.dart';
import 'package:mini_pos/features/products/repositories/product_repository.dart';
import 'package:mini_pos/features/products/viewmodels/product_management_view_model.dart';
import 'package:mini_pos/app/app.dart';
import 'package:mini_pos/features/auth/models/auth_user.dart';
import 'package:mini_pos/features/auth/repositories/auth_repository.dart';
import 'package:mini_pos/features/auth/services/session_service.dart';
import 'package:mini_pos/features/auth/viewmodels/auth_view_model.dart';
import 'package:mini_pos/features/auth/views/login_view.dart';

// Fake repository untuk pengujian integrasi UI.
class FakeAuthRepository implements AuthRepository {
  final Map<String, AuthUser> _users = {};
  final Map<int, String> _passwords = {};

  int _nextId = 1;

  @override
  Future<AuthUser> register({
    required String fullName,
    required String username,
    required String password,
  }) async {
    final normalizedName = fullName.trim();
    final normalizedUsername = username.trim();
    final usernameKey = normalizedUsername.toLowerCase();

    if (normalizedName.isEmpty || normalizedUsername.isEmpty) {
      throw ArgumentError('Nama dan username wajib diisi.');
    }

    if (password.length < 8) {
      throw ArgumentError('Password minimal 8 karakter.');
    }

    if (_users.containsKey(usernameKey)) {
      throw StateError('Username sudah digunakan.');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _nextId++;

    final user = AuthUser(
      id: id,
      fullName: normalizedName,
      username: normalizedUsername,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    _users[usernameKey] = user;
    _passwords[id] = password;

    return user;
  }

  @override
  Future<AuthUser?> login({
    required String username,
    required String password,
  }) async {
    final user = _users[username.trim().toLowerCase()];

    if (user == null || !user.isActive) {
      return null;
    }

    if (_passwords[user.id] != password) {
      return null;
    }

    return user;
  }

  @override
  Future<AuthUser?> getActiveUserById(int id) async {
    for (final user in _users.values) {
      if (user.id == id && user.isActive) {
        return user;
      }
    }

    return null;
  }
}

void main() {
  late FakeAuthRepository fakeRepository;
  late SessionService sessionService;
  late AuthViewModel authViewModel;

  late Database database;
  late ProductManagementViewModel productManagementViewModel;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    final preferences = await SharedPreferences.getInstance();

    fakeRepository = FakeAuthRepository();
    sessionService = SessionService(preferences);

    authViewModel = AuthViewModel(fakeRepository, sessionService);

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

    final categoryRepository = CategoryRepository(database);
    final productRepository = ProductRepository(database);

    productManagementViewModel = ProductManagementViewModel(
      categoryRepository,
      productRepository,
    );
  });

  tearDown(() async {
    authViewModel.dispose();
    productManagementViewModel.dispose();
    await database.close();
  });

  Future<void> pumpApplication(WidgetTester tester) async {
    // Load product data before rendering the application.
    // SQLite FFI requires a real async zone in widget tests.
    await tester.runAsync(() async {
      await productManagementViewModel.load();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthViewModel>.value(value: authViewModel),
          ChangeNotifierProvider<ProductManagementViewModel>.value(
            value: productManagementViewModel,
          ),
        ],
        child: const KasirkuApp(),
      ),
    );

    // AuthGate restores session after the first frame.
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  Future<AuthUser> createTestUser() async {
    return fakeRepository.register(
      fullName: 'Test Cashier',
      username: 'cashier',
      password: 'password123',
    );
  }

  group('Application Authentication Flow', () {
    testWidgets('shows login screen when no session exists', (tester) async {
      await pumpApplication(tester);

      expect(find.byType(LoginView), findsOneWidget);
      expect(find.text('KASIRKU POS'), findsOneWidget);
    });

    testWidgets('restores saved session and opens cashier screen', (
      tester,
    ) async {
      final user = await createTestUser();

      await sessionService.saveUserId(user.id);

      await pumpApplication(tester);

      expect(authViewModel.isAuthenticated, isTrue);
      expect(find.byType(LoginView), findsNothing);

      expect(find.text('Cashier'), findsOneWidget);

      expect(
        find.text('Product catalog, cart, and checkout will be built here.'),
        findsOneWidget,
      );
    });

    testWidgets('can navigate to product management', (tester) async {
      final user = await createTestUser();

      await sessionService.saveUserId(user.id);

      await pumpApplication(tester);

      await tester.tap(find.text('Produk'));
      await tester.pumpAndSettle();

      expect(find.text('Product Management'), findsOneWidget);

      expect(find.text('Kelola produk dan kategori tokomu.'), findsOneWidget);

      expect(find.text('Daftar Produk'), findsOneWidget);
    });

    testWidgets('logs in and opens cashier screen', (tester) async {
      await createTestUser();

      await pumpApplication(tester);

      expect(find.byType(LoginView), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'cashier');

      await tester.enterText(find.byType(TextFormField).at(1), 'password123');

      await tester.tap(find.text('Masuk'));
      await tester.pumpAndSettle();

      expect(authViewModel.isAuthenticated, isTrue);
      expect(find.byType(LoginView), findsNothing);
      expect(find.text('Cashier'), findsOneWidget);
      expect(sessionService.hasSession, isTrue);
    });

    testWidgets('displays cashier profile and logs out', (tester) async {
      final user = await createTestUser();

      await sessionService.saveUserId(user.id);

      await pumpApplication(tester);

      await tester.tap(find.text('Pengaturan'));
      await tester.pumpAndSettle();

      expect(find.text('Akun Kasir'), findsOneWidget);
      expect(find.text('Test Cashier'), findsNWidgets(2));
      expect(find.text('@cashier'), findsOneWidget);

      final logoutButton = find.text('Keluar dari akun');

      await tester.ensureVisible(logoutButton);
      await tester.pumpAndSettle();

      await tester.tap(logoutButton);
      await tester.pumpAndSettle();

      expect(authViewModel.isAuthenticated, isFalse);
      expect(sessionService.hasSession, isFalse);
      expect(find.byType(LoginView), findsOneWidget);
    });

    testWidgets('clears session when stored user does not exist', (
      tester,
    ) async {
      await sessionService.saveUserId(999);

      await pumpApplication(tester);

      expect(authViewModel.isAuthenticated, isFalse);
      expect(sessionService.hasSession, isFalse);
      expect(find.byType(LoginView), findsOneWidget);
    });
  });
}
