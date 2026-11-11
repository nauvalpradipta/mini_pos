import 'package:flutter/material.dart';

import '../../../core/widgets/app_text_field.dart';
import '../models/category.dart';

class CategoryFormResult {
  const CategoryFormResult({required this.name, this.description});

  final String name;
  final String? description;
}

class CategoryFormDialog extends StatefulWidget {
  const CategoryFormDialog({super.key, this.category});

  final Category? category;

  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.category?.name ?? '');

    _descriptionController = TextEditingController(
      text: widget.category?.description ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final description = _descriptionController.text.trim();

    Navigator.of(context).pop(
      CategoryFormResult(
        name: _nameController.text.trim(),
        description: description.isEmpty ? null : description,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Kategori' : 'Tambah Kategori'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  label: 'Nama kategori',
                  hintText: 'Contoh: Minuman',
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama kategori wajib diisi.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                AppTextField(
                  label: 'Deskripsi',
                  hintText: 'Deskripsi kategori (opsional)',
                  controller: _descriptionController,
                  maxLines: 3,
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
