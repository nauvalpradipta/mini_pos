import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mini_pos/features/products/models/category.dart';
import 'package:mini_pos/features/products/models/product.dart';
import 'package:mini_pos/features/products/services/product_image_service.dart';
import 'package:mini_pos/features/products/views/product_form_dialog.dart';

void main() {
  late Directory temporaryDirectory;
  late ProductImageService imageService;
  late Category category;
  ProductFormResult? result;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'product_form_test_',
    );

    imageService = ProductImageService(
      documentsDirectoryProvider: () async => temporaryDirectory,
    );

    category = Category(
      id: 1,
      name: 'Minuman',
      description: null,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    result = null;
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  Future<void> openForm(WidgetTester tester, {Product? product}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async {
                    result = await showDialog<ProductFormResult>(
                      context: context,
                      builder: (_) => ProductFormDialog(
                        categories: [category],
                        imageService: imageService,
                        product: product,
                      ),
                    );
                  },
                  child: const Text('Buka Form'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Buka Form'));
    await tester.pumpAndSettle();
  }

  group('ProductFormDialog', () {
    testWidgets('creates a product with valid input', (tester) async {
      await openForm(tester);

      await tester.enterText(find.byType(TextFormField).at(0), 'Kopi Susu');
      await tester.enterText(find.byType(TextFormField).at(1), '15000');
      await tester.enterText(find.byType(TextFormField).at(2), '20');

      await tester.tap(find.widgetWithText(FilledButton, 'Tambah'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.categoryId, 1);
      expect(result!.name, 'Kopi Susu');
      expect(result!.sellingPrice, 15000);
      expect(result!.stock, 20);
      expect(result!.imagePath, isNull);
      expect(result!.imageChanged, isFalse);
      expect(result!.isNewImage, isFalse);
    });

    testWidgets('prefills fields when editing a product', (tester) async {
      final product = Product(
        id: 1,
        categoryId: 1,
        name: 'Kopi Susu',
        sellingPrice: 15000,
        stock: 20,
        isActive: true,
        createdAt: 1000,
        updatedAt: 1000,
      );

      await openForm(tester, product: product);

      expect(find.text('Edit Produk'), findsOneWidget);

      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(0))
            .controller!
            .text,
        'Kopi Susu',
      );

      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        '15000',
      );

      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(2))
            .controller!
            .text,
        '20',
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.imageChanged, isFalse);
      expect(result!.imagePath, isNull);
    });

    testWidgets('validates required product fields', (tester) async {
      await openForm(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Tambah'));
      await tester.pumpAndSettle();

      expect(find.text('Nama produk wajib diisi.'), findsOneWidget);
      expect(find.text('Harga jual wajib diisi.'), findsOneWidget);
      expect(find.text('Stok produk wajib diisi.'), findsOneWidget);

      expect(result, isNull);
    });

    testWidgets('supports zero price and zero stock', (tester) async {
      await openForm(tester);

      await tester.enterText(find.byType(TextFormField).at(0), 'Produk Gratis');
      await tester.enterText(find.byType(TextFormField).at(1), '0');
      await tester.enterText(find.byType(TextFormField).at(2), '0');

      await tester.tap(find.widgetWithText(FilledButton, 'Tambah'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.sellingPrice, 0);
      expect(result!.stock, 0);
    });
  });
}
