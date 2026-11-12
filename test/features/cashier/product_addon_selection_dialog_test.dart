import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mini_pos/features/products/models/addon.dart';
import 'package:mini_pos/features/products/models/product.dart';
import 'package:mini_pos/features/cashier/views/product_addon_selection_dialog.dart';

void main() {
  late Product product;
  late List<Addon> addons;

  Future<ProductAddonSelectionResult?>? dialogResult;

  Future<void> pumpDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () {
                  dialogResult = showDialog<ProductAddonSelectionResult>(
                    context: context,
                    builder: (_) => ProductAddonSelectionDialog(
                      product: product,
                      addons: addons,
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    dialogResult = null;

    product = Product(
      id: 1,
      categoryId: 1,
      name: 'Kopi Susu',
      sellingPrice: 15000,
      stock: 20,
      isActive: true,
      createdAt: 100,
      updatedAt: 100,
    );

    addons = [
      Addon(
        id: 1,
        name: 'Extra Shot',
        additionalPrice: 5000,
        stock: 30,
        isActive: true,
        createdAt: 100,
        updatedAt: 100,
      ),
      Addon(
        id: 2,
        name: 'Caramel',
        additionalPrice: 2000,
        stock: 20,
        isActive: true,
        createdAt: 100,
        updatedAt: 100,
      ),
    ];
  });

  group('ProductAddonSelectionDialog', () {
    testWidgets('displays product and available add-ons', (tester) async {
      await pumpDialog(tester);

      expect(find.text('Pilih Add-on'), findsOneWidget);
      expect(find.text('Kopi Susu'), findsOneWidget);
      expect(find.text('Extra Shot'), findsOneWidget);
      expect(find.text('Caramel'), findsOneWidget);
      expect(find.text('Rp5.000 • Stok: 30'), findsOneWidget);
      expect(find.text('Rp2.000 • Stok: 20'), findsOneWidget);
    });

    testWidgets('returns selected add-ons with default quantity one', (
      tester,
    ) async {
      await pumpDialog(tester);

      await tester.tap(find.byKey(const ValueKey('selection-addon-1')));
      await tester.pump();

      await tester.tap(find.text('Tambahkan ke Keranjang'));
      await tester.pumpAndSettle();

      final result = await dialogResult!;

      expect(result, isNotNull);
      expect(result!.selectedAddons.length, 1);
      expect(result.selectedAddons.first.id, 1);
      expect(result.addonQuantities, {1: 1});
    });

    testWidgets('increases add-on quantity', (tester) async {
      await pumpDialog(tester);

      await tester.tap(find.byKey(const ValueKey('selection-addon-1')));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('increase-addon-1')));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('increase-addon-1')));
      await tester.pump();

      expect(find.text('3'), findsOneWidget);

      await tester.tap(find.text('Tambahkan ke Keranjang'));
      await tester.pumpAndSettle();

      final result = await dialogResult!;

      expect(result, isNotNull);
      expect(result!.addonQuantities, {1: 3});
    });

    testWidgets('decreases add-on quantity without going below one', (
      tester,
    ) async {
      await pumpDialog(tester);

      await tester.tap(find.byKey(const ValueKey('selection-addon-1')));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('increase-addon-1')));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('decrease-addon-1')));
      await tester.pump();

      expect(find.text('1'), findsOneWidget);

      final decreaseButton = tester.widget<IconButton>(
        find.byKey(const ValueKey('decrease-addon-1')),
      );

      expect(decreaseButton.onPressed, isNull);
    });

    testWidgets('allows selecting multiple add-ons', (tester) async {
      await pumpDialog(tester);

      await tester.tap(find.byKey(const ValueKey('selection-addon-1')));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('selection-addon-2')));
      await tester.pump();

      await tester.tap(find.text('Tambahkan ke Keranjang'));
      await tester.pumpAndSettle();

      final result = await dialogResult!;

      expect(result, isNotNull);
      expect(result!.selectedAddons.length, 2);
      expect(result.addonQuantities, {1: 1, 2: 1});
    });

    testWidgets('does not allow selecting an out-of-stock add-on', (
      tester,
    ) async {
      addons = [
        Addon(
          id: 3,
          name: 'Sold Out Topping',
          additionalPrice: 3000,
          stock: 0,
          isActive: true,
          createdAt: 100,
          updatedAt: 100,
        ),
      ];

      await pumpDialog(tester);

      final checkbox = tester.widget<CheckboxListTile>(
        find.byKey(const ValueKey('selection-addon-3')),
      );

      expect(checkbox.value, isFalse);
      expect(checkbox.onChanged, isNull);
      expect(find.textContaining('Stok habis'), findsOneWidget);
    });

    testWidgets('allows adding product without any add-on', (tester) async {
      await pumpDialog(tester);

      await tester.tap(find.text('Tambahkan ke Keranjang'));
      await tester.pumpAndSettle();

      final result = await dialogResult!;

      expect(result, isNotNull);
      expect(result!.selectedAddons, isEmpty);
      expect(result.addonQuantities, isEmpty);
    });

    testWidgets('returns null when canceled', (tester) async {
      await pumpDialog(tester);

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      final result = await dialogResult!;

      expect(result, isNull);
    });
  });
}
