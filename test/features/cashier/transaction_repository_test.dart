import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mini_pos/core/database/database_schema.dart';
import 'package:mini_pos/features/cashier/models/cart_item.dart';
import 'package:mini_pos/features/cashier/models/checkout.dart';
import 'package:mini_pos/features/cashier/repositories/transaction_repository.dart';
import 'package:mini_pos/features/products/repositories/addon_repository.dart';
import 'package:mini_pos/features/products/repositories/category_repository.dart';
import 'package:mini_pos/features/products/repositories/product_repository.dart';

void main() {
  late Database database;

  late CategoryRepository categoryRepository;
  late ProductRepository productRepository;
  late AddonRepository addonRepository;
  late TransactionRepository transactionRepository;

  late int cashierId;
  late int categoryId;
  late int productId;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
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

    categoryRepository = CategoryRepository(database);
    productRepository = ProductRepository(database);
    addonRepository = AddonRepository(database);
    transactionRepository = TransactionRepository(database);

    final now = DateTime.now().millisecondsSinceEpoch;

    // Buat akun kasir untuk kebutuhan test.
    cashierId = await database.insert('users', {
      'full_name': 'Test Cashier',
      'username': 'cashier_test',
      'password_hash': 'test_hash',
      'password_salt': 'test_salt',
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });

    // Buat kategori.
    categoryId = await categoryRepository.create(
      name: 'Minuman',
      description: 'Kategori minuman',
    );

    // Buat produk dengan stok 20.
    final product = await productRepository.create(
      categoryId: categoryId,
      name: 'Kopi Susu',
      sellingPrice: 15000,
      stock: 20,
    );

    productId = product.id!;
  });

  tearDown(() async {
    await database.close();
  });

  // Helper untuk membuat keranjang standar.
  CheckoutRequest buildRequest({
    List<CartItem>? items,
    DiscountType discountType = DiscountType.none,
    int discountValue = 0,
    int cashReceived = 50000,
  }) {
    return CheckoutRequest(
      cashierId: cashierId,
      cartItems:
          items ??
          [
            CartItem(
              productId: productId,
              productName: 'Kopi Susu',
              unitPrice: 15000,
              quantity: 2,
            ),
          ],
      discountType: discountType,
      discountValue: discountValue,
      cashReceived: cashReceived,
    );
  }

  group('TransactionRepository', () {
    test('saves transaction and deducts product stock', () async {
      final result = await transactionRepository.checkout(buildRequest());

      expect(result.saleId, greaterThan(0));
      expect(result.receiptNumber, isNotEmpty);

      expect(result.subtotal, 30000);
      expect(result.discountAmount, 0);
      expect(result.total, 30000);
      expect(result.cashReceived, 50000);
      expect(result.changeAmount, 20000);

      final sales = await database.query('sales');

      expect(sales.length, 1);
      expect(sales.first['receipt_number'], result.receiptNumber);

      final saleItems = await database.query('sale_items');

      expect(saleItems.length, 1);
      expect(saleItems.first['quantity'], 2);
      expect(saleItems.first['line_total'], 30000);

      final product = await productRepository.getById(productId);

      expect(product!.stock, 18);
    });

    test('saves add-on snapshots and deducts add-on stock', () async {
      final addon = await addonRepository.create(
        name: 'Extra Shot',
        additionalPrice: 5000,
        stock: 10,
      );

      await addonRepository.setForProduct(
        productId: productId,
        addonIds: [addon.id!],
      );

      final result = await transactionRepository.checkout(
        buildRequest(
          items: [
            CartItem(
              productId: productId,
              productName: 'Kopi Susu',
              unitPrice: 15000,
              quantity: 2,
              addons: [
                CartItemAddon(
                  addonId: addon.id!,
                  addonName: 'Extra Shot',
                  additionalPrice: 5000,
                  quantityPerProduct: 2,
                ),
              ],
            ),
          ],
          cashReceived: 60000,
        ),
      );

      // Produk: 2 x 15.000 = 30.000
      // Add-on: 2 x 2 x 5.000 = 20.000
      expect(result.subtotal, 50000);
      expect(result.total, 50000);
      expect(result.changeAmount, 10000);

      final saleItems = await database.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [result.saleId],
      );

      expect(saleItems.length, 1);
      expect(saleItems.first['addons_subtotal'], 20000);

      final saleItemAddons = await database.query(
        'sale_item_addons',
        where: 'sale_item_id = ?',
        whereArgs: [saleItems.first['id']],
      );

      expect(saleItemAddons.length, 1);
      expect(saleItemAddons.first['addon_name_snapshot'], 'Extra Shot');
      expect(saleItemAddons.first['quantity_per_product'], 2);
      expect(saleItemAddons.first['total_quantity'], 4);
      expect(saleItemAddons.first['subtotal'], 20000);

      final savedAddon = await addonRepository.getById(addon.id!);

      expect(savedAddon!.stock, 6);
    });

    test('applies percentage discount correctly', () async {
      final result = await transactionRepository.checkout(
        buildRequest(
          discountType: DiscountType.percentage,
          discountValue: 10,
          cashReceived: 30000,
        ),
      );

      expect(result.subtotal, 30000);
      expect(result.discountAmount, 3000);
      expect(result.total, 27000);
      expect(result.cashReceived, 30000);
      expect(result.changeAmount, 3000);
    });

    test('applies fixed discount correctly', () async {
      final result = await transactionRepository.checkout(
        buildRequest(
          discountType: DiscountType.fixed,
          discountValue: 5000,
          cashReceived: 30000,
        ),
      );

      expect(result.subtotal, 30000);
      expect(result.discountAmount, 5000);
      expect(result.total, 25000);
      expect(result.changeAmount, 5000);
    });

    test('rejects invalid discount values', () async {
      final invalidRequests = [
        buildRequest(discountType: DiscountType.percentage, discountValue: 101),
        buildRequest(discountType: DiscountType.fixed, discountValue: 30001),
        buildRequest(discountType: DiscountType.none, discountValue: 1),
        buildRequest(discountType: DiscountType.fixed, discountValue: -1),
      ];

      for (final request in invalidRequests) {
        await expectLater(
          transactionRepository.checkout(request),
          throwsA(isA<CheckoutException>()),
        );
      }

      expect(await database.query('sales'), isEmpty);
    });

    test('rejects payment below transaction total', () async {
      await expectLater(
        transactionRepository.checkout(buildRequest(cashReceived: 29999)),
        throwsA(isA<CheckoutException>()),
      );

      expect(await database.query('sales'), isEmpty);

      final product = await productRepository.getById(productId);

      expect(product!.stock, 20);
    });

    test('rejects insufficient product stock', () async {
      await expectLater(
        transactionRepository.checkout(
          buildRequest(
            items: [
              CartItem(
                productId: productId,
                productName: 'Kopi Susu',
                unitPrice: 15000,
                quantity: 21,
              ),
            ],
            cashReceived: 400000,
          ),
        ),
        throwsA(isA<CheckoutException>()),
      );

      expect(await database.query('sales'), isEmpty);

      final product = await productRepository.getById(productId);

      expect(product!.stock, 20);
    });

    test('rejects an empty cart', () async {
      await expectLater(
        transactionRepository.checkout(
          buildRequest(items: [], cashReceived: 0),
        ),
        throwsA(isA<CheckoutException>()),
      );

      expect(await database.query('sales'), isEmpty);
    });

    test('aggregates repeated product lines before deducting stock', () async {
      final result = await transactionRepository.checkout(
        buildRequest(
          items: [
            CartItem(
              productId: productId,
              productName: 'Kopi Susu',
              unitPrice: 15000,
              quantity: 12,
            ),
            CartItem(
              productId: productId,
              productName: 'Kopi Susu',
              unitPrice: 15000,
              quantity: 5,
            ),
          ],
          cashReceived: 300000,
        ),
      );

      expect(result.subtotal, 255000);
      expect(result.total, 255000);
      expect(result.changeAmount, 45000);

      final product = await productRepository.getById(productId);

      expect(product!.stock, 3);

      final saleItems = await database.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [result.saleId],
      );

      expect(saleItems.length, 2);
    });

    test('rejects checkout when product price has changed', () async {
      await productRepository.update(
        id: productId,
        categoryId: categoryId,
        name: 'Kopi Susu',
        sellingPrice: 16000,
        stock: 20,
      );

      // Keranjang masih menggunakan harga lama Rp15.000.
      await expectLater(
        transactionRepository.checkout(buildRequest()),
        throwsA(isA<CheckoutException>()),
      );

      expect(await database.query('sales'), isEmpty);

      final product = await productRepository.getById(productId);

      expect(product!.stock, 20);
    });

    test(
      'preserves historical product, add-on, cashier, and store snapshots',
      () async {
        final addon = await addonRepository.create(
          name: 'Extra Shot',
          additionalPrice: 5000,
          stock: 10,
        );

        await addonRepository.setForProduct(
          productId: productId,
          addonIds: [addon.id!],
        );

        await database.update('app_settings', {
          'store_name': 'Kopi Kita',
          'address': 'Jalan Merdeka No. 10',
          'phone': '08123456789',
        }, where: 'id = 1');

        final result = await transactionRepository.checkout(
          buildRequest(
            items: [
              CartItem(
                productId: productId,
                productName: 'Kopi Susu',
                unitPrice: 15000,
                quantity: 2,
                addons: [
                  CartItemAddon(
                    addonId: addon.id!,
                    addonName: 'Extra Shot',
                    additionalPrice: 5000,
                    quantityPerProduct: 1,
                  ),
                ],
              ),
            ],
            cashReceived: 50000,
          ),
        );

        // Ubah data master setelah transaksi selesai.
        await productRepository.update(
          id: productId,
          categoryId: categoryId,
          name: 'Kopi Susu Baru',
          sellingPrice: 18000,
          stock: 18,
        );

        await addonRepository.update(
          id: addon.id!,
          name: 'Extra Shot XL',
          additionalPrice: 7000,
          stock: 8,
        );

        await database.update(
          'users',
          {'full_name': 'Updated Cashier'},
          where: 'id = ?',
          whereArgs: [cashierId],
        );

        await database.update('app_settings', {
          'store_name': 'Toko Baru',
          'address': 'Alamat Baru',
          'phone': '08999999999',
        }, where: 'id = 1');

        final sales = await database.query(
          'sales',
          where: 'id = ?',
          whereArgs: [result.saleId],
        );

        expect(sales.length, 1);
        expect(sales.first['cashier_name_snapshot'], 'Test Cashier');
        expect(sales.first['store_name_snapshot'], 'Kopi Kita');
        expect(sales.first['store_address_snapshot'], 'Jalan Merdeka No. 10');

        final saleItems = await database.query(
          'sale_items',
          where: 'sale_id = ?',
          whereArgs: [result.saleId],
        );

        expect(saleItems.first['product_name_snapshot'], 'Kopi Susu');
        expect(saleItems.first['unit_price_snapshot'], 15000);

        final saleItemAddons = await database.query(
          'sale_item_addons',
          where: 'sale_item_id = ?',
          whereArgs: [saleItems.first['id']],
        );

        expect(saleItemAddons.first['addon_name_snapshot'], 'Extra Shot');
        expect(saleItemAddons.first['unit_price_snapshot'], 5000);
      },
    );

    test('rejects checkout for an inactive cashier', () async {
      await database.update(
        'users',
        {'is_active': 0},
        where: 'id = ?',
        whereArgs: [cashierId],
      );

      await expectLater(
        transactionRepository.checkout(buildRequest()),
        throwsA(isA<CheckoutException>()),
      );

      expect(await database.query('sales'), isEmpty);
    });

    test('rolls back all changes when stock update fails', () async {
      // Trigger ini sengaja menggagalkan pengurangan stok produk.
      await database.execute('''
        CREATE TRIGGER fail_product_stock_update
        BEFORE UPDATE OF stock_quantity ON products
        BEGIN
          SELECT RAISE(ABORT, 'Simulated stock update failure');
        END;
      ''');

      await expectLater(
        transactionRepository.checkout(buildRequest()),
        throwsA(isA<DatabaseException>()),
      );

      // Header dan detail transaksi harus ikut rollback.
      expect(await database.query('sales'), isEmpty);
      expect(await database.query('sale_items'), isEmpty);
      expect(await database.query('sale_item_addons'), isEmpty);

      // Stok produk harus tetap seperti semula.
      final product = await productRepository.getById(productId);

      expect(product!.stock, 20);
    });

    test('generates unique receipt numbers', () async {
      final firstResult = await transactionRepository.checkout(
        buildRequest(
          items: [
            CartItem(
              productId: productId,
              productName: 'Kopi Susu',
              unitPrice: 15000,
              quantity: 1,
            ),
          ],
          cashReceived: 20000,
        ),
      );

      final secondResult = await transactionRepository.checkout(
        buildRequest(
          items: [
            CartItem(
              productId: productId,
              productName: 'Kopi Susu',
              unitPrice: 15000,
              quantity: 1,
            ),
          ],
          cashReceived: 20000,
        ),
      );

      expect(firstResult.receiptNumber, isNotEmpty);
      expect(secondResult.receiptNumber, isNotEmpty);
      expect(firstResult.receiptNumber, isNot(secondResult.receiptNumber));

      expect(await database.query('sales'), hasLength(2));
    });
  });
}
