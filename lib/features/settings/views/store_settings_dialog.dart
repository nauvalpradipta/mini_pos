import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mini_pos/features/settings/models/store_settings.dart';
import 'package:mini_pos/features/settings/viewmodels/settings_view_model.dart';

class StoreSettingsDialog extends StatefulWidget {
  const StoreSettingsDialog({super.key, required this.settings});

  final StoreSettings settings;

  @override
  State<StoreSettingsDialog> createState() => _StoreSettingsDialogState();
}

class _StoreSettingsDialogState extends State<StoreSettingsDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _storeNameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _receiptFooterController;

  @override
  void initState() {
    super.initState();

    _storeNameController = TextEditingController(
      text: widget.settings.storeName,
    );
    _addressController = TextEditingController(text: widget.settings.address);
    _phoneController = TextEditingController(text: widget.settings.phone);
    _receiptFooterController = TextEditingController(
      text: widget.settings.receiptFooter,
    );
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _receiptFooterController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final success = await context.read<SettingsViewModel>().updateSettings(
      storeName: _storeNameController.text,
      address: _addressController.text,
      phone: _phoneController.text,
      receiptFooter: _receiptFooterController.text,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Informasi Toko'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _storeNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nama Toko',
                    hintText: 'Masukkan nama toko',
                    prefixIcon: Icon(Icons.store_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama toko wajib diisi.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Alamat Toko',
                    hintText: 'Masukkan alamat toko',
                    prefixIcon: Icon(Icons.location_on_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Nomor Telepon',
                    hintText: 'Masukkan nomor telepon toko',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _receiptFooterController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Footer Struk',
                    hintText: 'Pesan yang ditampilkan di bagian bawah struk',
                    prefixIcon: Icon(Icons.receipt_long_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
                Consumer<SettingsViewModel>(
                  builder: (context, viewModel, _) {
                    final errorMessage = viewModel.errorMessage;

                    if (errorMessage == null) {
                      return const SizedBox.shrink();
                    }

                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          errorMessage,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              context.select<SettingsViewModel, bool>(
                (viewModel) => viewModel.isSaving,
              )
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        Consumer<SettingsViewModel>(
          builder: (context, viewModel, _) {
            return FilledButton(
              onPressed: viewModel.isSaving ? null : _save,
              child: viewModel.isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan'),
            );
          },
        ),
      ],
    );
  }
}
