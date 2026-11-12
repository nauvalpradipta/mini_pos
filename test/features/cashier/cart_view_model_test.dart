import 'package:flutter_test/flutter_test.dart';

import 'package:mini_pos/features/cashier/viewmodels/cart_view_model.dart';
import 'package:mini_pos/features/products/models/addon.dart';
import 'package:mini_pos/features/products/models/product.dart';

void main() {
  late CartViewModel viewModel;

  late Product kopiSusu;
  late Product rotiBakar;

  late Addon extraShot;
  late Addon caramel;

  setUp(() {
    viewModel = CartViewModel();

    kopiSusu = Product(
      id: 1,
      categoryId: 1,
      name: 'Kopi Susu',
      sellingPrice: 15000,
      stock: 20,
      isActive: true,
      createdAt: 100,
      updatedAt: 100,
    );

    rotiBakar = Product(
      id: 2,
      categoryId: 2,
      name: 'Roti Bakar',
      sellingPrice: 12000,
      stock: 15,
      isActive: true,
      createdAt: 100,
      updatedAt: 100,
    );

    extraShot = Addon(
      id: 1,
      name: 'Extra Shot',
      additionalPrice: 5000,
      stock: 30,
      isActive: true,
      createdAt: 100,
      updatedAt: 100,
    );

    caramel = Addon(
      id: 2,
      name: 'Caramel',
      additionalPrice: 2000,
      stock: 20,
      isActive: true,
      createdAt: 100,
      updatedAt: 100,
    );
  });

  group('CartViewModel', () {
    test('starts with an empty cart', () {
      expect(viewModel.items, isEmpty);
      expect(viewModel.isEmpty, isTrue);
      expect(viewModel.isNotEmpty, isFalse);
      expect(viewModel.itemCount, 0);
      expect(viewModel.uniqueItemCount, 0);
      expect(viewModel.subtotal, 0);
    });

    test('adds a product to the cart', () {
      viewModel.addProduct(kopiSusu);

      expect(viewModel.items.length, 1);
      expect(viewModel.items.first.productName, 'Kopi Susu');
      expect(viewModel.items.first.quantity, 1);
      expect(viewModel.productSubtotal, 15000);
      expect(viewModel.addonsSubtotal, 0);
      expect(viewModel.subtotal, 15000);
      expect(viewModel.itemCount, 1);
    });

    test('merges the same product with the same add-ons', () {
      viewModel.addProduct(kopiSusu);
      viewModel.addProduct(kopiSusu);

      expect(viewModel.uniqueItemCount, 1);
      expect(viewModel.itemCount, 2);
      expect(viewModel.items.first.quantity, 2);
      expect(viewModel.subtotal, 30000);
    });

    test('keeps different add-on configurations as separate items', () {
      viewModel.addProduct(kopiSusu);

      viewModel.addProduct(kopiSusu, selectedAddons: [extraShot]);

      expect(viewModel.uniqueItemCount, 2);
      expect(viewModel.itemCount, 2);
      expect(viewModel.subtotal, 35000);

      expect(viewModel.items[0].addons, isEmpty);
      expect(viewModel.items[1].addons.length, 1);
    });

    test('calculates product and add-on subtotals correctly', () {
      viewModel.addProduct(
        kopiSusu,
        selectedAddons: [extraShot],
        addonQuantities: {extraShot.id!: 2},
      );

      viewModel.addProduct(
        kopiSusu,
        selectedAddons: [extraShot],
        addonQuantities: {extraShot.id!: 2},
      );

      expect(viewModel.productSubtotal, 30000);
      expect(viewModel.addonsSubtotal, 20000);
      expect(viewModel.subtotal, 50000);
    });

    test('merges identical add-on selections regardless of order', () {
      viewModel.addProduct(kopiSusu, selectedAddons: [extraShot, caramel]);

      viewModel.addProduct(kopiSusu, selectedAddons: [caramel, extraShot]);

      expect(viewModel.uniqueItemCount, 1);
      expect(viewModel.items.first.quantity, 2);
      expect(viewModel.itemCount, 2);
    });

    test('keeps different add-on quantities as separate items', () {
      viewModel.addProduct(
        kopiSusu,
        selectedAddons: [extraShot],
        addonQuantities: {extraShot.id!: 1},
      );

      viewModel.addProduct(
        kopiSusu,
        selectedAddons: [extraShot],
        addonQuantities: {extraShot.id!: 2},
      );

      expect(viewModel.uniqueItemCount, 2);
      expect(viewModel.items[0].addons.first.quantityPerProduct, 1);
      expect(viewModel.items[1].addons.first.quantityPerProduct, 2);
    });

    test('adds multiple different products', () {
      viewModel.addProduct(kopiSusu);
      viewModel.addProduct(rotiBakar);

      expect(viewModel.uniqueItemCount, 2);
      expect(viewModel.itemCount, 2);
      expect(viewModel.subtotal, 27000);
    });

    test(
      'prevents adding a product beyond shared stock across configurations',
      () {
        final limitedProduct = Product(
          id: 10,
          categoryId: 1,
          name: 'Limited Coffee',
          sellingPrice: 15000,
          stock: 2,
          isActive: true,
          createdAt: 100,
          updatedAt: 100,
        );

        viewModel.addProduct(limitedProduct);

        viewModel.addProduct(limitedProduct, selectedAddons: [extraShot]);

        // The same product already consumes 2 units across 2 configurations.
        expect(
          () => viewModel.addProduct(limitedProduct),
          throwsA(isA<CartStockException>()),
        );

        expect(viewModel.itemCount, 2);
        expect(viewModel.uniqueItemCount, 2);
        expect(
          viewModel.items.fold<int>(0, (total, item) => total + item.quantity),
          2,
        );
      },
    );

    test(
      'prevents shared add-on stock from being exceeded across products',
      () {
        final firstProduct = Product(
          id: 10,
          categoryId: 1,
          name: 'Coffee',
          sellingPrice: 15000,
          stock: 5,
          isActive: true,
          createdAt: 100,
          updatedAt: 100,
        );

        final secondProduct = Product(
          id: 11,
          categoryId: 1,
          name: 'Chocolate',
          sellingPrice: 18000,
          stock: 5,
          isActive: true,
          createdAt: 100,
          updatedAt: 100,
        );

        final limitedAddon = Addon(
          id: 10,
          name: 'Limited Extra Shot',
          additionalPrice: 5000,
          stock: 1,
          isActive: true,
          createdAt: 100,
          updatedAt: 100,
        );

        viewModel.addProduct(firstProduct, selectedAddons: [limitedAddon]);

        expect(
          () => viewModel.addProduct(
            secondProduct,
            selectedAddons: [limitedAddon],
          ),
          throwsA(isA<CartStockException>()),
        );

        expect(viewModel.itemCount, 1);
        expect(viewModel.uniqueItemCount, 1);
      },
    );

    test('prevents increasing quantity beyond product stock', () {
      final limitedProduct = Product(
        id: 10,
        categoryId: 1,
        name: 'Limited Coffee',
        sellingPrice: 15000,
        stock: 2,
        isActive: true,
        createdAt: 100,
        updatedAt: 100,
      );

      viewModel.addProduct(limitedProduct);

      viewModel.increaseQuantity(viewModel.items.first);

      expect(viewModel.items.first.quantity, 2);

      expect(
        () => viewModel.increaseQuantity(viewModel.items.first),
        throwsA(isA<CartStockException>()),
      );

      expect(viewModel.items.first.quantity, 2);
    });

    test('prevents increasing quantity beyond add-on stock', () {
      final product = Product(
        id: 10,
        categoryId: 1,
        name: 'Coffee',
        sellingPrice: 15000,
        stock: 5,
        isActive: true,
        createdAt: 100,
        updatedAt: 100,
      );

      final limitedAddon = Addon(
        id: 10,
        name: 'Limited Extra Shot',
        additionalPrice: 5000,
        stock: 1,
        isActive: true,
        createdAt: 100,
        updatedAt: 100,
      );

      viewModel.addProduct(product, selectedAddons: [limitedAddon]);

      expect(
        () => viewModel.increaseQuantity(viewModel.items.first),
        throwsA(isA<CartStockException>()),
      );

      expect(viewModel.items.first.quantity, 1);
    });

    test('prevents setQuantity from exceeding product stock', () {
      final limitedProduct = Product(
        id: 10,
        categoryId: 1,
        name: 'Limited Coffee',
        sellingPrice: 15000,
        stock: 2,
        isActive: true,
        createdAt: 100,
        updatedAt: 100,
      );

      viewModel.addProduct(limitedProduct);

      expect(
        () => viewModel.setQuantity(viewModel.items.first, 3),
        throwsA(isA<CartStockException>()),
      );

      expect(viewModel.items.first.quantity, 1);
    });

    test('increases item quantity', () {
      viewModel.addProduct(kopiSusu);

      final item = viewModel.items.first;

      viewModel.increaseQuantity(item);

      expect(viewModel.items.first.quantity, 2);
      expect(viewModel.subtotal, 30000);
    });

    test('decreases item quantity', () {
      viewModel.addProduct(kopiSusu);
      viewModel.increaseQuantity(viewModel.items.first);
      viewModel.increaseQuantity(viewModel.items.first);

      viewModel.decreaseQuantity(viewModel.items.first);

      expect(viewModel.items.first.quantity, 2);
      expect(viewModel.subtotal, 30000);
    });

    test('removes item when quantity decreases from one to zero', () {
      viewModel.addProduct(kopiSusu);

      viewModel.decreaseQuantity(viewModel.items.first);

      expect(viewModel.items, isEmpty);
      expect(viewModel.subtotal, 0);
    });

    test('sets item quantity directly', () {
      viewModel.addProduct(kopiSusu);

      viewModel.setQuantity(viewModel.items.first, 5);

      expect(viewModel.items.first.quantity, 5);
      expect(viewModel.itemCount, 5);
      expect(viewModel.subtotal, 75000);
    });

    test('rejects zero or negative quantity', () {
      viewModel.addProduct(kopiSusu);

      expect(
        () => viewModel.setQuantity(viewModel.items.first, 0),
        throwsArgumentError,
      );

      expect(
        () => viewModel.setQuantity(viewModel.items.first, -1),
        throwsArgumentError,
      );
    });

    test('removes a product from the cart', () {
      viewModel.addProduct(kopiSusu);
      viewModel.addProduct(rotiBakar);

      viewModel.removeItem(viewModel.items.first);

      expect(viewModel.uniqueItemCount, 1);
      expect(viewModel.items.first.productId, 2);
      expect(viewModel.subtotal, 12000);
    });

    test('clears the entire cart', () {
      viewModel.addProduct(kopiSusu);
      viewModel.addProduct(rotiBakar);

      viewModel.clear();

      expect(viewModel.items, isEmpty);
      expect(viewModel.isEmpty, isTrue);
      expect(viewModel.itemCount, 0);
      expect(viewModel.subtotal, 0);
    });

    test('rejects inactive products', () {
      final inactiveProduct = Product(
        id: 3,
        categoryId: 1,
        name: 'Kopi Lama',
        sellingPrice: 10000,
        stock: 10,
        isActive: false,
        createdAt: 100,
        updatedAt: 100,
      );

      expect(() => viewModel.addProduct(inactiveProduct), throwsArgumentError);

      expect(viewModel.items, isEmpty);
    });

    test('rejects inactive add-ons', () {
      final inactiveAddon = Addon(
        id: 3,
        name: 'Old Topping',
        additionalPrice: 1000,
        stock: 10,
        isActive: false,
        createdAt: 100,
        updatedAt: 100,
      );

      expect(
        () => viewModel.addProduct(kopiSusu, selectedAddons: [inactiveAddon]),
        throwsArgumentError,
      );

      expect(viewModel.items, isEmpty);
    });

    test('rejects invalid add-on quantities', () {
      expect(
        () => viewModel.addProduct(
          kopiSusu,
          selectedAddons: [extraShot],
          addonQuantities: {extraShot.id!: 0},
        ),
        throwsArgumentError,
      );

      expect(viewModel.items, isEmpty);
    });

    test('exposes an immutable item list', () {
      viewModel.addProduct(kopiSusu);

      expect(() => viewModel.items.clear(), throwsUnsupportedError);
    });

    test('notifies listeners when cart changes', () {
      var notificationCount = 0;

      viewModel.addListener(() {
        notificationCount++;
      });

      viewModel.addProduct(kopiSusu);
      viewModel.increaseQuantity(viewModel.items.first);
      viewModel.removeItem(viewModel.items.first);
      viewModel.clear();

      expect(notificationCount, 3);
    });
  });
}
