import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/addon.dart';

class AddonFormResult {
  const AddonFormResult({
    required this.name,
    required this.additionalPrice,
    required this.stock,
  });

  final String name;
  final int additionalPrice;
  final int stock;
}

class AddonFormDialog extends StatefulWidget {
  const AddonFormDialog({super.key, this.addon});

  final Addon? addon;

  @override
  State<AddonFormDialog> createState() => _AddonFormDialogState();
}

class _AddonFormDialogState extends State<AddonFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;

  bool get _isEditing => widget.addon != null;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.addon?.name ?? '');

    _priceController = TextEditingController(
      text: widget.addon?.additionalPrice.toString() ?? '',
    );

    _stockController = TextEditingController(
      text: widget.addon?.stock.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      AddonFormResult(
        name: _nameController.text.trim(),
        additionalPrice: int.parse(_priceController.text.trim()),
        stock: int.parse(_stockController.text.trim()),
      ),
    );
  }

  String? _validateNumber(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label wajib diisi.';
    }

    if (int.tryParse(value.trim()) == null) {
      return '$label harus berupa angka bulat.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Add-on' : 'Tambah Add-on'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const ValueKey('addon-name-field'),
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nama add-on',
                    hintText: 'Contoh: Extra Cheese',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama add-on wajib diisi.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  key: const ValueKey('addon-price-field'),
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Harga tambahan',
                    hintText: 'Contoh: 5000',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      _validateNumber(value, 'Harga tambahan'),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  key: const ValueKey('addon-stock-field'),
                  controller: _stockController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Stok',
                    hintText: 'Contoh: 30',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => _validateNumber(value, 'Stok'),
                  onFieldSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isEditing ? 'Simpan' : 'Tambah'),
        ),
      ],
    );
  }
}
