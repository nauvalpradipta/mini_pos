import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/database/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local SQLite database.
  await AppDatabase.instance.database;

  final tables = await AppDatabase.instance.getTableNames();

  debugPrint('=== KASIRKU POS DATABASE ===');

  for (final table in tables) {
    debugPrint('Table: $table');
  }

  runApp(const KasirkuApp());
}
