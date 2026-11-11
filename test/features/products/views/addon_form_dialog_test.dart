import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mini_pos/features/products/models/addon.dart';
import 'package:mini_pos/features/products/views/addon_form_dialog.dart';

void main() {
  Future<AddonFormResult?>? dialogResult;

  Future<void> pumpForm(WidgetTester tester, {Addon? addon}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Center(
                child: FilledButton(
                  onPressed: () {
                    dialogResult = showDialog<AddonFormResult>(
                      context: context,
                      builder: (_) => AddonFormDialog(addon: addon),
                    );
                  },
                  child: const Text('Open Form'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Form'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    dialogResult = null;
  });

  group('AddonFormDialog', () {
    testWidgets('creates an add-on with valid input', (tester) async {
      await pumpForm(tester);

      expect(find.text('Tambah Add-on'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('addon-name-field')),
        'Extra Cheese',
      );

      await tester.enterText(
        find.byKey(const ValueKey('addon-price-field')),
        '3000',
      );

      await tester.enterText(
        find.byKey(const ValueKey('addon-stock-field')),
        '20',
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Tambah'));
      await tester.pumpAndSettle();

      final result = await dialogResult!;

      expect(result, isNotNull);
      expect(result!.name, 'Extra Cheese');
      expect(result.additionalPrice, 3000);
      expect(result.stock, 20);
    });

    testWidgets('prefills fields when editing an add-on', (tester) async {
      final addon = Addon(
        id: 1,
        name: 'Extra Shot',
        additionalPrice: 5000,
        stock: 15,
        isActive: true,
        createdAt: 100,
        updatedAt: 200,
      );

      await pumpForm(tester, addon: addon);

      expect(find.text('Edit Add-on'), findsOneWidget);
      expect(find.text('Extra Shot'), findsOneWidget);
      expect(find.text('5000'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('addon-name-field')),
        'Double Shot',
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await tester.pumpAndSettle();

      final result = await dialogResult!;

      expect(result, isNotNull);
      expect(result!.name, 'Double Shot');
      expect(result.additionalPrice, 5000);
      expect(result.stock, 15);
    });

    testWidgets('validates required fields', (tester) async {
      await pumpForm(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Tambah'));
      await tester.pumpAndSettle();

      expect(find.text('Nama add-on wajib diisi.'), findsOneWidget);
      expect(find.text('Harga tambahan wajib diisi.'), findsOneWidget);
      expect(find.text('Stok wajib diisi.'), findsOneWidget);

      // Form remains open because validation failed.
      expect(find.text('Tambah Add-on'), findsOneWidget);
    });

    testWidgets('supports zero price and zero stock', (tester) async {
      await pumpForm(tester);

      await tester.enterText(
        find.byKey(const ValueKey('addon-name-field')),
        'Free Topping',
      );

      await tester.enterText(
        find.byKey(const ValueKey('addon-price-field')),
        '0',
      );

      await tester.enterText(
        find.byKey(const ValueKey('addon-stock-field')),
        '0',
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Tambah'));
      await tester.pumpAndSettle();

      final result = await dialogResult!;

      expect(result, isNotNull);
      expect(result!.additionalPrice, 0);
      expect(result.stock, 0);
    });
  });
}
