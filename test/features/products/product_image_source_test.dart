import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mini_pos/features/products/models/category.dart';
import 'package:mini_pos/features/products/services/product_image_service.dart';
import 'package:mini_pos/features/products/views/product_form_dialog.dart';

class FakeProductImageService extends ProductImageService {
  final List<ImageSource> selectedSources = [];

  @override
  Future<String?> pickAndSaveImage({
    ImageSource source = ImageSource.gallery,
  }) async {
    selectedSources.add(source);
    return null;
  }
}

void main() {
  late FakeProductImageService imageService;

  final category = Category(
    id: 1,
    name: 'Minuman',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUp(() {
    imageService = FakeProductImageService();
  });

  Future<void> openProductForm(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => ProductFormDialog(
                      categories: [category],
                      imageService: imageService,
                    ),
                  );
                },
                child: const Text('Buka Form Produk'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka Form Produk'));
    await tester.pumpAndSettle();
  }

  group('Product image source selection', () {
    testWidgets('opens camera when camera is selected', (tester) async {
      await openProductForm(tester);

      await tester.tap(find.text('Pilih foto'));
      await tester.pumpAndSettle();

      expect(find.text('Pilih sumber foto'), findsOneWidget);

      await tester.tap(find.text('Ambil foto dengan kamera'));
      await tester.pumpAndSettle();

      expect(imageService.selectedSources, [ImageSource.camera]);
    });

    testWidgets('opens gallery when gallery is selected', (tester) async {
      await openProductForm(tester);

      await tester.tap(find.text('Pilih foto'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pilih dari galeri'));
      await tester.pumpAndSettle();

      expect(imageService.selectedSources, [ImageSource.gallery]);
    });

    testWidgets('does nothing when source selection is canceled', (
      tester,
    ) async {
      await openProductForm(tester);

      await tester.tap(find.text('Pilih foto'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(imageService.selectedSources, isEmpty);
    });
  });
}
