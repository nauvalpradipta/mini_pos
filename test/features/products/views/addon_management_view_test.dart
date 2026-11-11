import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mini_pos/core/database/database_schema.dart';
import 'package:mini_pos/features/products/models/addon.dart';
import 'package:mini_pos/features/products/repositories/addon_repository.dart';
import 'package:mini_pos/features/products/viewmodels/addon_management_view_model.dart';
import 'package:mini_pos/features/products/views/addon_management_view.dart';

void main() {
  late Database database;
  late AddonRepository addonRepository;
  late AddonManagementViewModel viewModel;

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

    addonRepository = AddonRepository(database);
    viewModel = AddonManagementViewModel(addonRepository);
  });

  tearDown(() async {
    viewModel.dispose();
    await database.close();
  });

  Future<T> runDb<T>(WidgetTester tester, Future<T> Function() action) async {
    final result = await tester.runAsync<T>(action);
    return result as T;
  }

  Future<void> pumpAddonView(WidgetTester tester) async {
    await tester.runAsync(() async {
      await viewModel.load();
    });

    expect(viewModel.isLoading, isFalse);

    await tester.pumpWidget(
      ChangeNotifierProvider<AddonManagementViewModel>.value(
        value: viewModel,
        child: const MaterialApp(home: AddonManagementView(loadOnInit: false)),
      ),
    );

    await tester.pump();
  }

  Future<void> waitForSaving(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 500 && viewModel.isSaving; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });

    await tester.pump();

    expect(
      viewModel.isSaving,
      isFalse,
      reason: 'Add-on mutation did not finish within 5 seconds.',
    );
  }

  group('AddonManagementView', () {
    testWidgets('shows active and inactive add-ons separately', (tester) async {
      final activeAddon = await runDb<Addon>(
        tester,
        () => addonRepository.create(
          name: 'Extra Shot',
          additionalPrice: 5000,
          stock: 20,
        ),
      );

      final inactiveAddon = await runDb<Addon>(
        tester,
        () => addonRepository.create(
          name: 'Extra Cheese',
          additionalPrice: 3000,
          stock: 10,
        ),
      );

      await runDb(tester, () => addonRepository.deactivate(inactiveAddon.id!));

      await pumpAddonView(tester);

      expect(find.text(activeAddon.name), findsOneWidget);
      expect(find.text(inactiveAddon.name), findsNothing);

      await tester.tap(find.text('Nonaktif'));
      await tester.pumpAndSettle();

      expect(find.text(activeAddon.name), findsNothing);
      expect(find.text(inactiveAddon.name), findsOneWidget);
      expect(find.text('Aktifkan'), findsOneWidget);
    });

    testWidgets('creates a new add-on', (tester) async {
      await pumpAddonView(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Tambah Add-on'), findsNWidgets(2));

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
      await tester.pump();

      await waitForSaving(tester);
      await tester.pumpAndSettle();

      expect(find.text('Extra Cheese'), findsOneWidget);
      expect(find.textContaining('Rp3.000'), findsOneWidget);
      expect(find.textContaining('Stok: 20'), findsOneWidget);
    });

    testWidgets('edits an existing add-on', (tester) async {
      final addon = await runDb<Addon>(
        tester,
        () => addonRepository.create(
          name: 'Extra Shot',
          additionalPrice: 5000,
          stock: 15,
        ),
      );

      await pumpAddonView(tester);

      await tester.tap(find.byTooltip('Edit add-on'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Add-on'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('addon-name-field')),
        'Double Shot',
      );

      await tester.enterText(
        find.byKey(const ValueKey('addon-price-field')),
        '8000',
      );

      await tester.enterText(
        find.byKey(const ValueKey('addon-stock-field')),
        '25',
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await tester.pump();

      await waitForSaving(tester);
      await tester.pumpAndSettle();

      final updatedAddon = await runDb<Addon?>(
        tester,
        () => addonRepository.getById(addon.id!),
      );

      expect(updatedAddon, isNotNull);
      expect(updatedAddon!.name, 'Double Shot');
      expect(updatedAddon.additionalPrice, 8000);
      expect(updatedAddon.stock, 25);

      expect(find.text('Double Shot'), findsOneWidget);
      expect(find.text('Extra Shot'), findsNothing);
    });

    testWidgets('searches add-ons by name', (tester) async {
      await runDb(
        tester,
        () => addonRepository.create(
          name: 'Extra Cheese',
          additionalPrice: 3000,
          stock: 10,
        ),
      );

      await runDb(
        tester,
        () => addonRepository.create(
          name: 'Extra Shot',
          additionalPrice: 5000,
          stock: 20,
        ),
      );

      await runDb(
        tester,
        () => addonRepository.create(
          name: 'Caramel',
          additionalPrice: 2000,
          stock: 15,
        ),
      );

      await pumpAddonView(tester);

      await tester.enterText(
        find.byKey(const ValueKey('addon-search-field')),
        'cheese',
      );

      await tester.pump();

      expect(find.text('Extra Cheese'), findsOneWidget);
      expect(find.text('Extra Shot'), findsNothing);
      expect(find.text('Caramel'), findsNothing);
    });

    testWidgets('deactivates an add-on', (tester) async {
      final addon = await runDb<Addon>(
        tester,
        () => addonRepository.create(
          name: 'Extra Cheese',
          additionalPrice: 3000,
          stock: 10,
        ),
      );

      await pumpAddonView(tester);

      await tester.tap(find.byTooltip('Nonaktifkan add-on'));
      await tester.pumpAndSettle();

      expect(find.text('Nonaktifkan add-on?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Nonaktifkan'));
      await tester.pump();

      await waitForSaving(tester);
      await tester.pumpAndSettle();

      expect(viewModel.addons, isEmpty);
      expect(viewModel.inactiveAddons.length, 1);
      expect(viewModel.inactiveAddons.first.id, addon.id);

      await tester.tap(find.text('Nonaktif'));
      await tester.pumpAndSettle();

      expect(find.text('Extra Cheese'), findsOneWidget);
    });

    testWidgets('reactivates an inactive add-on', (tester) async {
      final addon = await runDb<Addon>(
        tester,
        () => addonRepository.create(
          name: 'Extra Shot',
          additionalPrice: 5000,
          stock: 20,
        ),
      );

      await runDb(tester, () => addonRepository.deactivate(addon.id!));

      await pumpAddonView(tester);

      await tester.tap(find.text('Nonaktif'));
      await tester.pumpAndSettle();

      expect(find.text('Extra Shot'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Aktifkan'));
      await tester.pump();

      await waitForSaving(tester);
      await tester.pumpAndSettle();

      expect(viewModel.inactiveAddons, isEmpty);
      expect(viewModel.addons.length, 1);
      expect(viewModel.addons.first.id, addon.id);
      expect(viewModel.addons.first.isActive, isTrue);

      expect(find.text('Extra Shot'), findsOneWidget);
      expect(find.text('Nonaktif'), findsOneWidget);
    });
  });
}
