import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'database_schema.dart';

/// Manages the local SQLite database connection.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const String _databaseName = 'kasirku_pos.db';
  static const int _databaseVersion = 1;

  Future<Database>? _databaseFuture;

  /// Returns the single database instance.
  Future<Database> get database async {
    _databaseFuture ??= _openDatabase();

    try {
      return await _databaseFuture!;
    } catch (_) {
      _databaseFuture = null;
      rethrow;
    }
  }

  /// Opens or creates the local database.
  Future<Database> _openDatabase() async {
    final databaseDirectory = await getDatabasesPath();

    final databasePath = path.join(databaseDirectory, _databaseName);

    return openDatabase(
      databasePath,
      version: _databaseVersion,

      // Enable foreign key constraints.
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },

      // Create all tables for a new database.
      onCreate: _onCreate,
    );
  }

  /// Creates the database schema for a new database.
  Future<void> _onCreate(Database db, int version) async {
    await DatabaseSchema.create(db);
  }

  /// Retrieves the names of application tables.
  /// Useful for database diagnostics.
  Future<List<String>> getTableNames() async {
    final db = await database;

    final result = await db.rawQuery('''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table'
      AND name NOT LIKE 'sqlite_%'
      ORDER BY name
    ''');

    return result.map((row) => row['name'] as String).toList();
  }

  /// Closes the database connection.
  Future<void> close() async {
    final future = _databaseFuture;

    if (future == null) {
      return;
    }

    final db = await future;

    await db.close();

    _databaseFuture = null;
  }
}
