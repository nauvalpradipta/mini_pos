import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mini_pos/app/theme/app_theme.dart';
import 'package:mini_pos/features/auth/models/auth_user.dart';
import 'package:mini_pos/features/auth/repositories/auth_repository.dart';
import 'package:mini_pos/features/auth/services/session_service.dart';
import 'package:mini_pos/features/auth/viewmodels/auth_view_model.dart';
import 'package:mini_pos/features/auth/views/login_view.dart';
import 'package:mini_pos/features/auth/views/register_view.dart';

// Fake repository untuk menguji UI tanpa SQLite dan Argon2id.
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
  late AuthViewModel authViewModel;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    final preferences = await SharedPreferences.getInstance();

    authViewModel = AuthViewModel(
      FakeAuthRepository(),
      SessionService(preferences),
    );
  });

  tearDown(() {
    authViewModel.dispose();
  });

  Widget buildTestApp(Widget home) {
    return ChangeNotifierProvider<AuthViewModel>.value(
      value: authViewModel,
      child: MaterialApp(theme: AppTheme.lightTheme, home: home),
    );
  }

  group('LoginView', () {
    testWidgets('displays login form', (tester) async {
      await tester.pumpWidget(buildTestApp(const LoginView()));

      expect(find.text('KASIRKU POS'), findsOneWidget);
      expect(find.text('Selamat datang kembali'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Masuk'), findsOneWidget);
    });

    testWidgets('validates empty login fields', (tester) async {
      await tester.pumpWidget(buildTestApp(const LoginView()));

      await tester.tap(find.text('Masuk'));
      await tester.pump();

      expect(find.text('Username wajib diisi.'), findsOneWidget);
      expect(find.text('Password wajib diisi.'), findsOneWidget);
    });

    testWidgets('opens register screen', (tester) async {
      await tester.pumpWidget(buildTestApp(const LoginView()));

      await tester.ensureVisible(find.text('Daftar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Daftar'));
      await tester.pumpAndSettle();

      expect(find.byType(RegisterView), findsOneWidget);
      expect(find.text('Buat akun kasir'), findsOneWidget);
    });

    testWidgets('shows error for incorrect login credentials', (tester) async {
      await authViewModel.register(
        fullName: 'Test Cashier',
        username: 'cashier',
        password: 'password123',
      );

      await authViewModel.logout();

      await tester.pumpWidget(buildTestApp(const LoginView()));

      await tester.enterText(find.byType(TextFormField).at(0), 'cashier');

      await tester.enterText(find.byType(TextFormField).at(1), 'wrongpassword');

      await tester.tap(find.text('Masuk'));
      await tester.pumpAndSettle();

      expect(find.text('Username atau password salah.'), findsOneWidget);
    });
  });

  group('RegisterView', () {
    testWidgets('displays registration form', (tester) async {
      await tester.pumpWidget(buildTestApp(const RegisterView()));

      expect(find.text('Buat akun kasir'), findsOneWidget);
      expect(find.text('Nama lengkap'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Konfirmasi password'), findsOneWidget);
      expect(find.text('Buat akun'), findsOneWidget);
    });

    testWidgets('validates empty registration fields', (tester) async {
      await tester.pumpWidget(buildTestApp(const RegisterView()));

      await tester.ensureVisible(find.text('Buat akun'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Buat akun'));
      await tester.pump();

      expect(find.text('Nama lengkap wajib diisi.'), findsOneWidget);
      expect(find.text('Username wajib diisi.'), findsOneWidget);
      expect(find.text('Password wajib diisi.'), findsOneWidget);
      expect(find.text('Konfirmasi password wajib diisi.'), findsOneWidget);
    });

    testWidgets('rejects mismatched password confirmation', (tester) async {
      await tester.pumpWidget(buildTestApp(const RegisterView()));

      await tester.enterText(find.byType(TextFormField).at(0), 'Test Cashier');

      await tester.enterText(find.byType(TextFormField).at(1), 'cashier');

      await tester.enterText(find.byType(TextFormField).at(2), 'password123');

      await tester.enterText(find.byType(TextFormField).at(3), 'password456');

      await tester.ensureVisible(find.text('Buat akun'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Buat akun'));
      await tester.pump();

      expect(find.text('Password tidak cocok.'), findsOneWidget);
      expect(authViewModel.isAuthenticated, isFalse);
    });

    testWidgets('registers a user and returns to login route', (tester) async {
      await tester.pumpWidget(buildTestApp(const LoginView()));

      await tester.ensureVisible(find.text('Daftar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Daftar'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Test Cashier');

      await tester.enterText(find.byType(TextFormField).at(1), 'cashier');

      await tester.enterText(find.byType(TextFormField).at(2), 'password123');

      await tester.enterText(find.byType(TextFormField).at(3), 'password123');

      await tester.ensureVisible(find.text('Buat akun'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Buat akun'));
      await tester.pumpAndSettle();

      expect(authViewModel.isAuthenticated, isTrue);
      expect(authViewModel.currentUser!.username, 'cashier');

      expect(find.byType(LoginView), findsOneWidget);
      expect(find.byType(RegisterView), findsNothing);
    });
  });
}
