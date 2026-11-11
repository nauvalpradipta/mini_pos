import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mini_pos/features/products/models/addon.dart';
import 'package:mini_pos/features/products/models/product.dart';
import 'package:mini_pos/features/products/views/product_addon_assignment_dialog.dart';

void main() {
  late Product product;
  late List<Addon> addons;

  Future<Set<int>?>? dialogResult;

  Future<void> pumpDialog(
    WidgetTester tester, {
    Set<int> initialAddonIds = const {},
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () {
                  dialogResult = showDialog<Set<int>>(
                    context: context,
                    builder: (_) => ProductAddonAssignmentDialog(
                      product: product,
                      addons: addons,
                      initialAddonIds: initialAddonIds,
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
        stock: 20,
        isActive: true,
        createdAt: 100,
        updatedAt: 100,
      ),
      Addon(
        id: 2,
        name: 'Caramel',
        additionalPrice: 2000,
        stock: 15,
        isActive: true,
        createdAt: 100,
        updatedAt: 100,
      ),
    ];
  });

  group('ProductAddonAssignmentDialog', () {
    testWidgets('displays product and available add-ons', (tester) async {
      await pumpDialog(tester);

      expect(find.text('Atur Add-on Produk'), findsOneWidget);
      expect(find.text('Kopi Susu'), findsOneWidget);
      expect(find.text('Extra Shot'), findsOneWidget);
      expect(find.text('Caramel'), findsOneWidget);
      expect(find.text('Rp5.000 • Stok: 20'), findsOneWidget);
      expect(find.text('Rp2.000 • Stok: 15'), findsOneWidget);
    });

    testWidgets('restores previously assigned add-ons', (tester) async {
      await pumpDialog(tester, initialAddonIds: {1});

      final extraShotCheckbox = tester.widget<CheckboxListTile>(
        find.byKey(const ValueKey('addon-option-1')),
      );

      final caramelCheckbox = tester.widget<CheckboxListTile>(
        find.byKey(const ValueKey('addon-option-2')),
      );

      expect(extraShotCheckbox.value, isTrue);
      expect(caramelCheckbox.value, isFalse);
    });

    testWidgets('returns selected add-ons', (tester) async {
      await pumpDialog(tester);

      await tester.tap(find.byKey(const ValueKey('addon-option-1')));
      await tester.pump();

      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      final result = await dialogResult!;

      expect(result, {1});
    });

    testWidgets('removes previously selected add-ons', (tester) async {
      await pumpDialog(tester, initialAddonIds: {1, 2});

      await tester.tap(find.byKey(const ValueKey('addon-option-1')));
      await tester.pump();

      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      final result = await dialogResult!;

      expect(result, {2});
    });

    testWidgets('returns an empty selection when no add-ons are available', (
      tester,
    ) async {
      addons = [];

      await pumpDialog(tester);

      expect(find.text('Belum ada add-on aktif.'), findsOneWidget);

      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      final result = await dialogResult!;

      expect(result, isEmpty);
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
