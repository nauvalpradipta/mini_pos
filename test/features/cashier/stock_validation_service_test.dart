import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mini_pos/core/database/database_schema.dart';
import 'package:mini_pos/features/cashier/models/cart_item.dart';
import 'package:mini_pos/features/cashier/services/stock_validation_service.dart';
import 'package:mini_pos/features/products/repositories/addon_repository.dart';
import 'package:mini_pos/features/products/repositories/category_repository.dart';
import 'package:mini_pos/features/products/repositories/product_repository.dart';

void main() {
  late Database database;

  late CategoryRepository categoryRepository;
  late ProductRepository productRepository;
  late AddonRepository addonRepository;
  late StockValidationService stockValidationService;

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

    stockValidationService = StockValidationService(database);

    categoryId = await categoryRepository.create(
      name: 'Minuman',
      description: 'Kategori minuman',
    );

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

  group('StockValidationService', () {
    test('calculates cart item subtotal correctly', () {
      final item = CartItem(
        productId: 1,
        productName: 'Kopi Susu',
        unitPrice: 15000,
        quantity: 2,
        addons: [
          CartItemAddon(
            addonId: 1,
            addonName: 'Extra Shot',
            additionalPrice: 5000,
            quantityPerProduct: 2,
          ),
        ],
      );

      expect(item.productSubtotal, 30000);
      expect(item.addonsSubtotal, 20000);
      expect(item.lineTotal, 50000);
    });

    test('rejects an empty cart', () async {
      final result = await stockValidationService.validate([]);

      expect(result.isValid, isFalse);
      expect(result.issues.length, 1);
      expect(result.issues.first.type, StockIssueType.emptyCart);
    });

    test('aggregates stock requirements for the same product', () async {
      final cartItems = [
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
          quantity: 9,
        ),
      ];

      final result = await stockValidationService.validate(cartItems);

      expect(result.isValid, isFalse);
      expect(
        result.issues.any(
          (issue) => issue.type == StockIssueType.insufficientProductStock,
        ),
        isTrue,
      );

      final productIssue = result.issues.firstWhere(
        (issue) => issue.type == StockIssueType.insufficientProductStock,
      );

      expect(productIssue.requestedQuantity, 21);
      expect(productIssue.availableQuantity, 20);
    });

    test('accepts product quantity within available stock', () async {
      final cartItems = [
        CartItem(
          productId: productId,
          productName: 'Kopi Susu',
          unitPrice: 15000,
          quantity: 10,
        ),
      ];

      final result = await stockValidationService.validate(cartItems);

      expect(result.isValid, isTrue);
      expect(result.issues, isEmpty);
    });

    test('aggregates add-on consumption across cart lines', () async {
      final addon = await addonRepository.create(
        name: 'Extra Shot',
        additionalPrice: 5000,
        stock: 5,
      );

      await addonRepository.setForProduct(
        productId: productId,
        addonIds: [addon.id!],
      );

      final cartItems = [
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
        CartItem(
          productId: productId,
          productName: 'Kopi Susu',
          unitPrice: 15000,
          quantity: 1,
          addons: [
            CartItemAddon(
              addonId: addon.id!,
              addonName: 'Extra Shot',
              additionalPrice: 5000,
              quantityPerProduct: 2,
            ),
          ],
        ),
      ];

      final result = await stockValidationService.validate(cartItems);

      expect(result.isValid, isFalse);

      final addonIssue = result.issues.firstWhere(
        (issue) => issue.type == StockIssueType.insufficientAddonStock,
      );

      // (2 × 2) + (1 × 2) = 6.
      expect(addonIssue.requestedQuantity, 6);
      expect(addonIssue.availableQuantity, 5);
    });

    test('detects an inactive product', () async {
      await productRepository.deactivate(productId);

      final cartItems = [
        CartItem(
          productId: productId,
          productName: 'Kopi Susu',
          unitPrice: 15000,
          quantity: 1,
        ),
      ];

      final result = await stockValidationService.validate(cartItems);

      expect(result.isValid, isFalse);
      expect(
        result.issues.any(
          (issue) => issue.type == StockIssueType.unavailableProduct,
        ),
        isTrue,
      );
    });

    test('detects an inactive add-on', () async {
      final addon = await addonRepository.create(
        name: 'Extra Shot',
        additionalPrice: 5000,
        stock: 10,
      );

      await addonRepository.setForProduct(
        productId: productId,
        addonIds: [addon.id!],
      );

      await addonRepository.deactivate(addon.id!);

      final cartItems = [
        CartItem(
          productId: productId,
          productName: 'Kopi Susu',
          unitPrice: 15000,
          quantity: 1,
          addons: [
            CartItemAddon(
              addonId: addon.id!,
              addonName: 'Extra Shot',
              additionalPrice: 5000,
              quantityPerProduct: 1,
            ),
          ],
        ),
      ];

      final result = await stockValidationService.validate(cartItems);

      expect(result.isValid, isFalse);
      expect(
        result.issues.any(
          (issue) => issue.type == StockIssueType.unavailableAddon,
        ),
        isTrue,
      );
    });

    test('rejects an add-on not assigned to the product', () async {
      final addon = await addonRepository.create(
        name: 'Extra Cheese',
        additionalPrice: 3000,
        stock: 10,
      );

      final cartItems = [
        CartItem(
          productId: productId,
          productName: 'Kopi Susu',
          unitPrice: 15000,
          quantity: 1,
          addons: [
            CartItemAddon(
              addonId: addon.id!,
              addonName: 'Extra Cheese',
              additionalPrice: 3000,
              quantityPerProduct: 1,
            ),
          ],
        ),
      ];

      final result = await stockValidationService.validate(cartItems);

      expect(result.isValid, isFalse);
      expect(
        result.issues.any(
          (issue) => issue.type == StockIssueType.addonNotAssignedToProduct,
        ),
        isTrue,
      );
    });

    test('accepts a valid product with an assigned add-on', () async {
      final addon = await addonRepository.create(
        name: 'Extra Shot',
        additionalPrice: 5000,
        stock: 10,
      );

      await addonRepository.setForProduct(
        productId: productId,
        addonIds: [addon.id!],
      );

      final cartItems = [
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
      ];

      final result = await stockValidationService.validate(cartItems);

      expect(result.isValid, isTrue);
      expect(result.issues, isEmpty);
    });

    test('rejects duplicate add-ons within one cart item', () {
      expect(
        () => CartItem(
          productId: 1,
          productName: 'Kopi Susu',
          unitPrice: 15000,
          quantity: 1,
          addons: [
            CartItemAddon(
              addonId: 1,
              addonName: 'Extra Shot',
              additionalPrice: 5000,
              quantityPerProduct: 1,
            ),
            CartItemAddon(
              addonId: 1,
              addonName: 'Extra Shot',
              additionalPrice: 5000,
              quantityPerProduct: 1,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });
  });
}
