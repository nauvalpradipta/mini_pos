import 'package:sqflite/sqflite.dart';

import 'database_tables.dart';

/// Responsible for creating the complete database schema.
class DatabaseSchema {
  DatabaseSchema._();

  static Future<void> create(Database db) async {
    // Create all database tables.
    for (final statement in DatabaseTables.createStatements) {
      await db.execute(statement);
    }

    // Create database indexes.
    for (final statement in DatabaseTables.indexStatements) {
      await db.execute(statement);
    }

    // Insert default store configuration.
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert(DatabaseTables.appSettings, {
      'id': 1,
      'store_name': 'KASIRKU POS',
      'address': '',
      'phone': '',
      'receipt_footer': 'Thank you for your purchase!',
      'created_at': now,
      'updated_at': now,
    });
  }
}
