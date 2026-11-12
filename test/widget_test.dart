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
import 'package:mini_pos/features/products/repositories/addon_repository.dart';
import 'package:mini_pos/features/products/viewmodels/addon_management_view_model.dart';
import 'package:mini_pos/features/cashier/viewmodels/cart_view_model.dart';
import 'package:mini_pos/features/cashier/viewmodels/cashier_catalog_view_model.dart';
import 'package:mini_pos/features/cashier/repositories/transaction_repository.dart';
import 'package:mini_pos/features/cashier/viewmodels/checkout_view_model.dart';
import 'package:mini_pos/features/sales/repositories/sales_repository.dart';
import 'package:mini_pos/features/sales/viewmodels/sales_view_model.dart';
import 'package:mini_pos/features/settings/repositories/settings_repository.dart';
import 'package:mini_pos/features/settings/viewmodels/settings_view_model.dart';

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
  late AddonManagementViewModel addonManagementViewModel;
  late CashierCatalogViewModel cashierCatalogViewModel;
  late CartViewModel cartViewModel;
  late CheckoutViewModel checkoutViewModel;
  late SalesViewModel salesViewModel;
  late SettingsViewModel settingsViewModel;

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

    final settingsRepository = SettingsRepository(database);
    settingsViewModel = SettingsViewModel(settingsRepository);

    final categoryRepository = CategoryRepository(database);
    final productRepository = ProductRepository(database);

    productManagementViewModel = ProductManagementViewModel(
      categoryRepository,
      productRepository,
    );

    cashierCatalogViewModel = CashierCatalogViewModel(
      categoryRepository,
      productRepository,
    );

    cartViewModel = CartViewModel();

    final transactionRepository = TransactionRepository(database);

    checkoutViewModel = CheckoutViewModel(transactionRepository);

    final salesRepository = SalesRepository(database);
    salesViewModel = SalesViewModel(salesRepository);

    final addonRepository = AddonRepository(database);

    addonManagementViewModel = AddonManagementViewModel(addonRepository);
  });

  tearDown(() async {
    authViewModel.dispose();
    productManagementViewModel.dispose();
    addonManagementViewModel.dispose();
    cashierCatalogViewModel.dispose();
    cartViewModel.dispose();
    checkoutViewModel.dispose();
    salesViewModel.dispose();
    settingsViewModel.dispose();
    await database.close();
  });

  Future<void> pumpApplication(WidgetTester tester) async {
    // Load product data before rendering the application.
    // SQLite FFI requires a real async zone in widget tests.
    await tester.runAsync(() async {
      await productManagementViewModel.load();
      await addonManagementViewModel.load();
      await cashierCatalogViewModel.load();
      await salesViewModel.load();
      await settingsViewModel.load();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthViewModel>.value(value: authViewModel),
          ChangeNotifierProvider<ProductManagementViewModel>.value(
            value: productManagementViewModel,
          ),
          ChangeNotifierProvider<AddonManagementViewModel>.value(
            value: addonManagementViewModel,
          ),
          ChangeNotifierProvider<CashierCatalogViewModel>.value(
            value: cashierCatalogViewModel,
          ),
          ChangeNotifierProvider<CartViewModel>.value(value: cartViewModel),
          ChangeNotifierProvider<CheckoutViewModel>.value(
            value: checkoutViewModel,
          ),
          ChangeNotifierProvider<SalesViewModel>.value(value: salesViewModel),
          ChangeNotifierProvider<SettingsViewModel>.value(
            value: settingsViewModel,
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

      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Kasir')),
        findsOneWidget,
      );

      expect(find.text('Pilih Produk'), findsOneWidget);
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

      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Kasir')),
        findsOneWidget,
      );

      expect(find.text('Pilih Produk'), findsOneWidget);

      expect(sessionService.hasSession, isTrue);
    });

    testWidgets('displays store settings, reflects changes, and logs out', (
      tester,
    ) async {
      final user = await createTestUser();

      await sessionService.saveUserId(user.id);

      await pumpApplication(tester);

      // Open Settings page.
      await tester.tap(find.text('Pengaturan'));
      await tester.pumpAndSettle();

      // Verify initial store information.
      expect(find.text('Informasi Toko'), findsOneWidget);
      expect(find.text('KASIRKU POS'), findsNWidgets(2));
      expect(find.text('Thank you for your purchase!'), findsOneWidget);

      // Verify edit dialog can be opened.
      await tester.tap(find.byTooltip('Ubah informasi toko'));
      await tester.pumpAndSettle();

      expect(find.text('Nama Toko'), findsOneWidget);
      expect(find.text('Alamat Toko'), findsOneWidget);
      expect(find.text('Nomor Telepon'), findsOneWidget);
      expect(find.text('Footer Struk'), findsOneWidget);

      // Close dialog.
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      // Update store information using real SQLite operations.
      final updateResult = await tester.runAsync(() async {
        return settingsViewModel.updateSettings(
          storeName: 'Toko Maju',
          address: 'Jl. Diponegoro No. 5',
          phone: '089876543210',
          receiptFooter: 'Terima kasih sudah berbelanja!',
        );
      });

      expect(updateResult, isTrue);

      // Allow the UI to rebuild.
      await tester.pump();

      // Verify updated store information.
      expect(find.text('Toko Maju'), findsNWidgets(2));
      expect(find.text('Jl. Diponegoro No. 5'), findsOneWidget);
      expect(find.text('089876543210'), findsOneWidget);
      expect(find.text('Terima kasih sudah berbelanja!'), findsOneWidget);

      // Verify cashier account information remains available.
      expect(find.text('Akun Kasir'), findsOneWidget);
      expect(find.text('Test Cashier'), findsNWidgets(2));
      expect(find.text('@cashier'), findsOneWidget);

      // Verify logout still works.
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
