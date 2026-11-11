import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/database/app_database.dart';
import 'features/auth/repositories/auth_repository.dart';
import 'features/auth/services/password_hasher.dart';
import 'features/auth/services/session_service.dart';
import 'features/auth/viewmodels/auth_view_model.dart';
import 'features/products/repositories/category_repository.dart';
import 'features/products/repositories/product_repository.dart';
import 'features/products/viewmodels/product_management_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize SQLite.
  final database = await AppDatabase.instance.database;

  // 2. Initialize SharedPreferences.
  final preferences = await SharedPreferences.getInstance();

  // 3. Initialize authentication dependencies.
  final passwordHasher = PasswordHasher();

  final authRepository = AuthRepository(database, passwordHasher);

  final sessionService = SessionService(preferences);

  // 4. Initialize product management repositories.
  final categoryRepository = CategoryRepository(database);
  final productRepository = ProductRepository(database);

  // 5. Create ViewModels.
  final authViewModel = AuthViewModel(authRepository, sessionService);

  // 6. Run application with multiple Providers.
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthViewModel>.value(value: authViewModel),
        ChangeNotifierProvider<ProductManagementViewModel>(
          create: (_) =>
              ProductManagementViewModel(categoryRepository, productRepository),
        ),
      ],
      child: const KasirkuApp(),
    ),
  );
}
