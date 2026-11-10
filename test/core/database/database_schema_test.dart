import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mini_pos/core/database/database_schema.dart';
import 'package:mini_pos/core/database/database_tables.dart';

void main() {
  late Database database;
  late Directory temporaryDirectory;

  setUpAll(() {
    // Initialize SQLite FFI for Windows testing.
    sqfliteFfiInit();
  });

  setUp(() async {
    // Create an isolated temporary directory.
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'kasirku_database_test_',
    );

    final databasePath = path.join(temporaryDirectory.path, 'test_database.db');

    // Open a fresh database for each test.
    database = await databaseFactoryFfi.openDatabase(
      databasePath,
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
  });

  tearDown(() async {
    await database.close();

    await temporaryDirectory.delete(recursive: true);
  });

  group('Database Schema Tests', () {
    test('creates all nine required tables', () async {
      final result = await database.rawQuery('''
        SELECT name
        FROM sqlite_master
        WHERE type = 'table'
        AND name NOT LIKE 'sqlite_%'
      ''');

      final tableNames = result.map((row) => row['name'] as String).toSet();

      expect(
        tableNames,
        containsAll({
          'users',
          'categories',
          'products',
          'addons',
          'product_addons',
          'sales',
          'sale_items',
          'sale_item_addons',
          'app_settings',
        }),
      );

      expect(tableNames.length, 9);
    });

    test('creates expected database indexes', () async {
      final result = await database.rawQuery('''
        SELECT name
        FROM sqlite_master
        WHERE type = 'index'
      ''');

      final indexNames = result.map((row) => row['name'] as String).toSet();

      expect(
        indexNames,
        containsAll({
          'idx_products_category',
          'idx_products_active',
          'idx_products_name',
          'idx_product_addons_addon',
          'idx_sales_transaction_date',
          'idx_sales_cashier',
          'idx_sale_items_sale',
          'idx_sale_item_addons_item',
        }),
      );
    });

    test('inserts default store settings', () async {
      final result = await database.query(DatabaseTables.appSettings);

      expect(result, hasLength(1));
      expect(result.first['store_name'], 'KASIRKU POS');
    });

    test('rejects negative add-on stock', () async {
      await expectLater(
        database.insert(DatabaseTables.addons, {
          'name': 'Extra Shot',
          'additional_price': 5000,
          'stock_quantity': -1,
          'is_active': 1,
          'created_at': 1,
          'updated_at': 1,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('rejects product with invalid category reference', () async {
      await expectLater(
        database.insert(DatabaseTables.products, {
          'category_id': 999,
          'name': 'Milk Coffee',
          'selling_price': 18000,
          'stock_quantity': 20,
          'is_active': 1,
          'created_at': 1,
          'updated_at': 1,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('preserves historical product snapshot after deletion', () async {
      // Create cashier.
      final cashierId = await database.insert(DatabaseTables.users, {
        'full_name': 'Test Cashier',
        'username': 'testcashier',
        'password_hash': 'test_hash',
        'password_salt': 'test_salt',
        'is_active': 1,
        'created_at': 1,
        'updated_at': 1,
      });

      // Create category.
      final categoryId = await database.insert(DatabaseTables.categories, {
        'name': 'Food',
        'is_active': 1,
        'created_at': 1,
        'updated_at': 1,
      });

      // Create product.
      final productId = await database.insert(DatabaseTables.products, {
        'category_id': categoryId,
        'name': 'Roti Bakar',
        'selling_price': 15000,
        'stock_quantity': 10,
        'is_active': 1,
        'created_at': 1,
        'updated_at': 1,
      });

      // Create sale.
      final saleId = await database.insert(DatabaseTables.sales, {
        'receipt_number': 'POS-TEST-001',
        'cashier_id': cashierId,
        'cashier_name_snapshot': 'Test Cashier',
        'store_name_snapshot': 'KASIRKU POS',
        'store_address_snapshot': '',
        'store_phone_snapshot': '',
        'transaction_at': 1000,
        'subtotal': 15000,
        'discount_type': 'none',
        'discount_value': 0,
        'discount_amount': 0,
        'total': 15000,
        'cash_received': 15000,
        'change_amount': 0,
        'created_at': 1000,
      });

      // Create historical sale item.
      await database.insert(DatabaseTables.saleItems, {
        'sale_id': saleId,
        'product_id': productId,
        'product_name_snapshot': 'Roti Bakar',
        'unit_price_snapshot': 15000,
        'quantity': 1,
        'base_subtotal': 15000,
        'addons_subtotal': 0,
        'line_total': 15000,
        'created_at': 1000,
      });

      // Physically delete the master product.
      await database.delete(
        DatabaseTables.products,
        where: 'id = ?',
        whereArgs: [productId],
      );

      // Verify historical snapshot remains.
      final result = await database.query(
        DatabaseTables.saleItems,
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );

      expect(result, hasLength(1));
      expect(result.first['product_id'], isNull);
      expect(result.first['product_name_snapshot'], 'Roti Bakar');
      expect(result.first['unit_price_snapshot'], 15000);
    });
  });
}
