import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mini_pos/features/cashier/viewmodels/cart_view_model.dart';
import 'package:mini_pos/features/cashier/views/cart_panel.dart';
import 'package:mini_pos/features/products/models/product.dart';
import 'package:mini_pos/features/products/models/addon.dart';

void main() {
  late CartViewModel cartViewModel;

  const product = Product(
    id: 1,
    categoryId: 1,
    name: 'Kopi Susu',
    sellingPrice: 15000,
    stock: 20,
    isActive: true,
    createdAt: 1,
    updatedAt: 1,
  );

  const extraShot = Addon(
    id: 1,
    name: 'Extra Shot',
    additionalPrice: 5000,
    stock: 30,
    isActive: true,
    createdAt: 1,
    updatedAt: 1,
  );

  setUp(() {
    cartViewModel = CartViewModel();
  });

  tearDown(() {
    cartViewModel.dispose();
  });

  Widget buildSubject() {
    return ChangeNotifierProvider<CartViewModel>.value(
      value: cartViewModel,
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 380, height: 700, child: const CartPanel()),
        ),
      ),
    );
  }

  group('CartPanel', () {
    testWidgets('shows empty cart state', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Keranjang'), findsOneWidget);
      expect(find.text('Keranjang masih kosong'), findsOneWidget);
      expect(find.byKey(const ValueKey('cart-item-list')), findsNothing);
    });

    testWidgets('displays product and correct totals', (tester) async {
      cartViewModel.addProduct(product);

      await tester.pumpWidget(buildSubject());

      expect(find.text('Kopi Susu'), findsOneWidget);

      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('cart-product-subtotal')))
            .data,
        'Rp15.000',
      );

      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('cart-addons-subtotal')))
            .data,
        'Rp0',
      );

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('cart-total'))).data,
        'Rp15.000',
      );

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('cart-quantity-0'))).data,
        '1',
      );
    });

    testWidgets('increases and decreases product quantity', (tester) async {
      cartViewModel.addProduct(product);

      await tester.pumpWidget(buildSubject());

      await tester.tap(find.byKey(const ValueKey('cart-increase-0')));
      await tester.pump();

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('cart-quantity-0'))).data,
        '2',
      );

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('cart-total'))).data,
        'Rp30.000',
      );

      await tester.tap(find.byKey(const ValueKey('cart-decrease-0')));
      await tester.pump();

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('cart-quantity-0'))).data,
        '1',
      );

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('cart-total'))).data,
        'Rp15.000',
      );

      await tester.tap(find.byKey(const ValueKey('cart-decrease-0')));
      await tester.pump();

      expect(find.text('Keranjang masih kosong'), findsOneWidget);
      expect(cartViewModel.isEmpty, isTrue);
    });

    testWidgets('removes product from cart', (tester) async {
      cartViewModel.addProduct(product);

      await tester.pumpWidget(buildSubject());

      await tester.tap(find.byKey(const ValueKey('cart-remove-0')));
      await tester.pump();

      expect(cartViewModel.isEmpty, isTrue);
      expect(find.text('Keranjang masih kosong'), findsOneWidget);
    });

    testWidgets('clears cart after confirmation', (tester) async {
      cartViewModel.addProduct(product);
      cartViewModel.addProduct(product);

      await tester.pumpWidget(buildSubject());

      expect(cartViewModel.itemCount, 2);

      await tester.tap(find.byKey(const ValueKey('cart-clear-button')));
      await tester.pumpAndSettle();

      expect(find.text('Kosongkan keranjang?'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('cart-clear-confirm')));
      await tester.pumpAndSettle();

      expect(cartViewModel.isEmpty, isTrue);
      expect(find.text('Keranjang masih kosong'), findsOneWidget);
    });

    testWidgets('keeps cart unchanged when clear is canceled', (tester) async {
      cartViewModel.addProduct(product);

      await tester.pumpWidget(buildSubject());

      await tester.tap(find.byKey(const ValueKey('cart-clear-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('cart-clear-cancel')));
      await tester.pumpAndSettle();

      expect(cartViewModel.itemCount, 1);
      expect(cartViewModel.subtotal, 15000);
    });

    testWidgets(
      'displays add-ons and recalculates totals by product quantity',
      (tester) async {
        cartViewModel.addProduct(
          product,
          selectedAddons: [extraShot],
          addonQuantities: {extraShot.id!: 2},
        );

        await tester.pumpWidget(buildSubject());

        // Detail add-on tampil dengan jumlah per produk.
        expect(find.text('+ Extra Shot × 2'), findsOneWidget);

        // Harga produk: Rp15.000.
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('cart-product-subtotal')))
              .data,
          'Rp15.000',
        );

        // Add-on: Rp5.000 × 2 = Rp10.000.
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('cart-addons-subtotal')))
              .data,
          'Rp10.000',
        );

        // Total awal: Rp25.000.
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('cart-line-total-0')))
              .data,
          'Rp25.000',
        );

        expect(
          tester.widget<Text>(find.byKey(const ValueKey('cart-total'))).data,
          'Rp25.000',
        );

        // Tambahkan kuantitas produk menjadi 2.
        await tester.tap(find.byKey(const ValueKey('cart-increase-0')));
        await tester.pump();

        // Harga produk menjadi Rp30.000.
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('cart-product-subtotal')))
              .data,
          'Rp30.000',
        );

        // Add-on ikut dikalikan: Rp10.000 × 2 = Rp20.000.
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('cart-addons-subtotal')))
              .data,
          'Rp20.000',
        );

        // Total akhir: Rp50.000.
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('cart-line-total-0')))
              .data,
          'Rp50.000',
        );

        expect(
          tester.widget<Text>(find.byKey(const ValueKey('cart-total'))).data,
          'Rp50.000',
        );
      },
    );

    testWidgets('shows stock warning when quantity exceeds available stock', (
      tester,
    ) async {
      const limitedProduct = Product(
        id: 2,
        categoryId: 1,
        name: 'Limited Coffee',
        sellingPrice: 15000,
        stock: 1,
        isActive: true,
        createdAt: 1,
        updatedAt: 1,
      );

      cartViewModel.addProduct(limitedProduct);

      await tester.pumpWidget(buildSubject());

      await tester.tap(find.byKey(const ValueKey('cart-increase-0')));
      await tester.pump();

      expect(
        find.text(
          'Stok Limited Coffee tidak mencukupi. Diminta 2, tersedia 1.',
        ),
        findsOneWidget,
      );

      expect(cartViewModel.itemCount, 1);
      expect(cartViewModel.items.first.quantity, 1);
    });
  });
}
