import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mini_pos/features/settings/models/store_settings.dart';
import 'package:mini_pos/features/settings/repositories/settings_repository.dart';
import 'package:mini_pos/features/settings/viewmodels/settings_view_model.dart';
import 'package:mini_pos/features/settings/views/store_settings_dialog.dart';

class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository(this.settings);

  StoreSettings settings;

  int updateCalls = 0;

  @override
  Future<StoreSettings> getSettings() async => settings;

  @override
  Future<StoreSettings> updateSettings({
    required String storeName,
    required String address,
    required String phone,
    required String receiptFooter,
  }) async {
    updateCalls++;

    settings = StoreSettings(
      id: settings.id,
      storeName: storeName.trim(),
      address: address,
      phone: phone,
      receiptFooter: receiptFooter,
      createdAt: settings.createdAt,
      updatedAt: settings.updatedAt + 1,
    );

    return settings;
  }
}

StoreSettings createSettings() {
  return StoreSettings(
    id: 1,
    storeName: 'KASIRKU POS',
    address: 'Jl. Malioboro No. 10',
    phone: '081234567890',
    receiptFooter: 'Thank you for your purchase!',
    createdAt: 1000,
    updatedAt: 1000,
  );
}

void main() {
  late FakeSettingsRepository repository;
  late SettingsViewModel viewModel;

  setUp(() {
    repository = FakeSettingsRepository(createSettings());
    viewModel = SettingsViewModel(repository);
  });

  tearDown(() {
    viewModel.dispose();
  });

  Future<void> openDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsViewModel>.value(
        value: viewModel,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog<bool>(
                      context: context,
                      builder: (_) => StoreSettingsDialog(
                        settings: viewModel.settings ?? createSettings(),
                      ),
                    );
                  },
                  child: const Text('Buka Pengaturan'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka Pengaturan'));
    await tester.pumpAndSettle();
  }

  group('StoreSettingsDialog', () {
    testWidgets('displays existing store information', (tester) async {
      await viewModel.load();
      await openDialog(tester);

      expect(find.text('Informasi Toko'), findsOneWidget);
      expect(find.text('KASIRKU POS'), findsOneWidget);
      expect(find.text('Jl. Malioboro No. 10'), findsOneWidget);
      expect(find.text('081234567890'), findsOneWidget);
      expect(find.text('Thank you for your purchase!'), findsOneWidget);
    });

    testWidgets('rejects empty store name', (tester) async {
      await viewModel.load();
      await openDialog(tester);

      await tester.enterText(find.byType(TextFormField).at(0), '   ');

      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(find.text('Nama toko wajib diisi.'), findsOneWidget);
      expect(repository.updateCalls, 0);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('saves updated store information', (tester) async {
      await viewModel.load();
      await openDialog(tester);

      await tester.enterText(find.byType(TextFormField).at(0), 'Toko Maju');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Jl. Diponegoro No. 5',
      );
      await tester.enterText(find.byType(TextFormField).at(2), '089876543210');
      await tester.enterText(
        find.byType(TextFormField).at(3),
        'Terima kasih sudah berbelanja!',
      );

      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(repository.updateCalls, 1);
      expect(viewModel.settings?.storeName, 'Toko Maju');
      expect(viewModel.settings?.address, 'Jl. Diponegoro No. 5');
      expect(viewModel.settings?.phone, '089876543210');
      expect(
        viewModel.settings?.receiptFooter,
        'Terima kasih sudah berbelanja!',
      );
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('closes dialog when cancel is tapped', (tester) async {
      await viewModel.load();
      await openDialog(tester);

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(repository.updateCalls, 0);
    });
  });
}
