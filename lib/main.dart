import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/database/app_database.dart';
import 'features/auth/repositories/auth_repository.dart';
import 'features/auth/services/password_hasher.dart';
import 'features/auth/services/session_service.dart';
import 'features/auth/viewmodels/auth_view_model.dart';

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

  // 4. Create AuthViewModel.
  final authViewModel = AuthViewModel(authRepository, sessionService);

  // 5. Run application with Provider.
  runApp(
    ChangeNotifierProvider<AuthViewModel>.value(
      value: authViewModel,
      child: const KasirkuApp(),
    ),
  );
}
