import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mini_pos/features/products/models/category.dart';
import 'package:mini_pos/core/database/database_schema.dart';
import 'package:mini_pos/features/products/repositories/category_repository.dart';
import 'package:mini_pos/features/products/repositories/product_repository.dart';
import 'package:mini_pos/features/products/viewmodels/product_management_view_model.dart';
import 'package:mini_pos/features/products/views/category_management_view.dart';

void main() {
  late Database database;
  late CategoryRepository categoryRepository;
  late ProductRepository productRepository;
  late ProductManagementViewModel viewModel;

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

    viewModel = ProductManagementViewModel(
      categoryRepository,
      productRepository,
    );
  });

  tearDown(() async {
    viewModel.dispose();
    await database.close();
  });

  Widget buildTestApp() {
    return ChangeNotifierProvider<ProductManagementViewModel>.value(
      value: viewModel,
      child: const MaterialApp(home: CategoryManagementView(loadOnInit: false)),
    );
  }

  /// Semua akses database di dalam testWidgets lewat sini,
  /// karena sqflite_ffi butuh async "asli", bukan FakeAsync.
  Future<T> runDb<T>(WidgetTester tester, Future<T> Function() action) async {
    final result = await tester.runAsync<T>(action);
    return result as T;
  }

  Future<void> pumpCategoryView(WidgetTester tester) async {
    await runDb(tester, () => viewModel.load());

    expect(
      viewModel.isLoading,
      isFalse,
      reason: 'Category loading did not finish.',
    );

    await tester.pumpWidget(buildTestApp());

    await tester.pump();
  }

  Future<void> waitForSaving(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 500 && viewModel.isSaving; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      viewModel.isSaving,
      isFalse,
      reason: 'Category mutation did not finish within 5 seconds.',
    );
  }

  group('CategoryManagementView', () {
    testWidgets('shows empty state when no categories exist', (tester) async {
      await pumpCategoryView(tester);

      expect(find.text('Kelola Kategori'), findsOneWidget);
      expect(find.text('Belum ada kategori'), findsOneWidget);
      expect(find.text('Tambah Kategori'), findsOneWidget);
    });

    testWidgets('creates a new category', (tester) async {
      await pumpCategoryView(tester);

      await tester.tap(find.text('Tambah Kategori'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Tambah Kategori'), findsNWidgets(2));
      expect(find.text('Nama kategori'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'Makanan');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Kategori makanan',
      );
      await tester.pump();

      // Sesuaikan tipe tombol dengan category_form_dialog.dart
      await tester.tap(find.text('Tambah').last);
      await tester.pump();

      await waitForSaving(tester);

      expect(find.text('Makanan'), findsOneWidget);
      expect(find.text('Kategori makanan'), findsOneWidget);
      expect(viewModel.categories.length, 1);
    });

    testWidgets('edits an existing category', (tester) async {
      final categoryId = await runDb(
        tester,
        () => categoryRepository.create(
          name: 'Minuman',
          description: 'Kategori minuman',
        ),
      );

      await pumpCategoryView(tester);

      expect(find.text('Minuman'), findsOneWidget);

      await tester.tap(find.byTooltip('Edit kategori'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Edit Kategori'), findsOneWidget);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Minuman Dingin',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Minuman siap saji',
      );
      await tester.pump();

      final saveButton = find.widgetWithText(FilledButton, 'Simpan');
      expect(saveButton, findsOneWidget);

      await tester.tap(saveButton);
      await tester.pump();

      await waitForSaving(tester);

      final Category? updatedCategory = await runDb(
        tester,
        () => categoryRepository.getById(categoryId),
      );

      expect(updatedCategory, isNotNull);
      expect(updatedCategory!.name, 'Minuman Dingin');
      expect(find.text('Minuman Dingin'), findsOneWidget);
      expect(find.text('Minuman'), findsNothing);
      expect(find.text('Minuman siap saji'), findsOneWidget);
    }, timeout: const Timeout(Duration(seconds: 30)));

    testWidgets('deactivates a category without active products', (
      tester,
    ) async {
      final categoryId = await runDb(
        tester,
        () => categoryRepository.create(name: 'Makanan'),
      );

      await pumpCategoryView(tester);

      expect(find.text('Makanan'), findsOneWidget);

      await tester.tap(find.byTooltip('Nonaktifkan kategori'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Nonaktifkan kategori?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Nonaktifkan'));
      await tester.pump();

      await waitForSaving(tester);

      expect(find.text('Makanan'), findsNothing);
      expect(viewModel.categories, isEmpty);

      final Category? category = await runDb(
        tester,
        () => categoryRepository.getById(categoryId),
      );

      expect(category, isNotNull);
      expect(category!.isActive, isFalse);
    });

    testWidgets('prevents deactivation when category has active products', (
      tester,
    ) async {
      await runDb(tester, () async {
        final categoryId = await categoryRepository.create(name: 'Minuman');

        await productRepository.create(
          categoryId: categoryId,
          name: 'Kopi Susu',
          sellingPrice: 15000,
          stock: 20,
        );
      });

      await pumpCategoryView(tester);

      await tester.tap(find.byTooltip('Nonaktifkan kategori'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.widgetWithText(FilledButton, 'Nonaktifkan'));
      await tester.pump();

      await waitForSaving(tester);

      expect(find.text('Minuman'), findsOneWidget);
      expect(viewModel.categories.length, 1);
      expect(viewModel.errorMessage, isNotNull);
    });

    testWidgets('reactivates an inactive category from the inactive tab', (
      tester,
    ) async {
      final categoryId = await runDb(
        tester,
        () => categoryRepository.create(
          name: 'Minuman',
          description: 'Kategori minuman',
        ),
      );

      await runDb(tester, () => categoryRepository.deactivate(categoryId));

      await pumpCategoryView(tester);

      // Category should not appear in the active tab.
      expect(viewModel.categories, isEmpty);
      expect(viewModel.inactiveCategories.length, 1);

      expect(find.text('Minuman'), findsNothing);

      // Open the inactive category tab.
      await tester.tap(find.text('Nonaktif'));
      await tester.pumpAndSettle();

      expect(find.text('Minuman'), findsOneWidget);
      expect(find.text('Kategori minuman'), findsOneWidget);
      expect(find.text('Aktifkan'), findsOneWidget);

      // Reactivate the category.
      await tester.tap(find.text('Aktifkan'));
      await tester.pump();

      await waitForSaving(tester);
      await tester.pumpAndSettle();

      // The UI should automatically return to the active tab.
      expect(find.text('Minuman'), findsOneWidget);
      expect(find.text('Kategori minuman'), findsOneWidget);

      expect(viewModel.categories.length, 1);
      expect(viewModel.categories.first.id, categoryId);
      expect(viewModel.categories.first.isActive, isTrue);

      expect(viewModel.inactiveCategories, isEmpty);

      // Verify the original database record is still used.
      final category = await runDb<Category?>(
        tester,
        () => categoryRepository.getById(categoryId),
      );

      expect(category, isNotNull);
      expect(category!.id, categoryId);
      expect(category.name, 'Minuman');
      expect(category.isActive, isTrue);
    });
  });
}
