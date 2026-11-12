import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/category.dart';
import '../models/product.dart';
import '../services/product_image_service.dart';

import 'package:image_picker/image_picker.dart';

class ProductFormResult {
  const ProductFormResult({
    required this.categoryId,
    required this.name,
    required this.sellingPrice,
    required this.stock,
    required this.imagePath,
    required this.imageChanged,
    required this.isNewImage,
  });

  final int categoryId;
  final String name;
  final int sellingPrice;
  final int stock;
  final String? imagePath;
  final bool imageChanged;
  final bool isNewImage;
}

class ProductFormDialog extends StatefulWidget {
  const ProductFormDialog({
    super.key,
    required this.categories,
    required this.imageService,
    this.product,
  });

  final List<Category> categories;
  final ProductImageService imageService;
  final Product? product;

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;

  int? _selectedCategoryId;
  String? _selectedImagePath;

  bool _imageChanged = false;
  bool _isNewImage = false;
  bool _isPickingImage = false;
  bool _didSubmit = false;

  String? _imageError;

  bool get _isEditing => widget.product != null;

  List<Category> get _availableCategories =>
      widget.categories.where((category) => category.id != null).toList();

  @override
  void initState() {
    super.initState();

    final product = widget.product;

    _nameController = TextEditingController(text: product?.name ?? '');
    _priceController = TextEditingController(
      text: product?.sellingPrice.toString() ?? '',
    );
    _stockController = TextEditingController(
      text: product?.stock.toString() ?? '',
    );

    _selectedImagePath = product?.imagePath;

    final availableCategories = _availableCategories;

    if (availableCategories.any(
      (category) => category.id == product?.categoryId,
    )) {
      _selectedCategoryId = product!.categoryId;
    } else if (availableCategories.isNotEmpty) {
      _selectedCategoryId = availableCategories.first.id;
    }
  }

  Future<void> _pickImage() async {
    if (_isPickingImage) return;

    setState(() {
      _imageError = null;
    });

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Pilih sumber foto',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ListTile(
                key: const ValueKey('product-image-source-camera'),
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Ambil foto dengan kamera'),
                onTap: () {
                  Navigator.of(sheetContext).pop(ImageSource.camera);
                },
              ),
              ListTile(
                key: const ValueKey('product-image-source-gallery'),
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Pilih dari galeri'),
                onTap: () {
                  Navigator.of(sheetContext).pop(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || source == null) return;

    setState(() {
      _isPickingImage = true;
    });

    try {
      final newImagePath = await widget.imageService.pickAndSaveImage(
        source: source,
      );

      if (newImagePath == null) return;

      if (!mounted) {
        await _deleteSafely(newImagePath);
        return;
      }

      final previousNewImage = _isNewImage ? _selectedImagePath : null;

      setState(() {
        _selectedImagePath = newImagePath;
        _imageChanged = true;
        _isNewImage = true;
      });

      if (previousNewImage != null) {
        await _deleteSafely(previousNewImage);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _imageError = 'Foto gagal dipilih. Silakan coba lagi.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  Future<void> _removeImage() async {
    final previousImage = _isNewImage ? _selectedImagePath : null;

    setState(() {
      _selectedImagePath = null;
      _imageChanged = true;
      _isNewImage = false;
      _imageError = null;
    });

    if (previousImage != null) {
      await _deleteSafely(previousImage);
    }
  }

  Future<void> _deleteSafely(String path) async {
    try {
      await widget.imageService.deleteImage(path);
    } catch (_) {
      // A failed cleanup should not interrupt the product form.
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final categoryId = _selectedCategoryId;
    final sellingPrice = int.tryParse(_priceController.text);
    final stock = int.tryParse(_stockController.text);

    if (categoryId == null || sellingPrice == null || stock == null) {
      return;
    }

    _didSubmit = true;

    Navigator.of(context).pop(
      ProductFormResult(
        categoryId: categoryId,
        name: _nameController.text.trim(),
        sellingPrice: sellingPrice,
        stock: stock,
        imagePath: _selectedImagePath,
        imageChanged: _imageChanged,
        isNewImage: _isNewImage,
      ),
    );
  }

  @override
  void dispose() {
    if (!_didSubmit && _isNewImage && _selectedImagePath != null) {
      unawaited(_deleteSafely(_selectedImagePath!));
    }

    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Text(_isEditing ? 'Edit Produk' : 'Tambah Produk'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildImagePicker(theme, colorScheme),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nama produk',
                    hintText: 'Contoh: Kopi Susu',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama produk wajib diisi.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<int>(
                  initialValue: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: _availableCategories.map((category) {
                    return DropdownMenuItem<int>(
                      value: category.id,
                      child: Text(category.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategoryId = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Pilih kategori produk.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Harga jual (Rp)',
                    hintText: 'Contoh: 15000',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Harga jual wajib diisi.';
                    }

                    if (int.tryParse(value) == null) {
                      return 'Harga jual tidak valid.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _stockController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Stok produk',
                    hintText: 'Contoh: 20',
                    prefixIcon: Icon(Icons.warehouse_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Stok produk wajib diisi.';
                    }

                    if (int.tryParse(value) == null) {
                      return 'Stok produk tidak valid.';
                    }

                    return null;
                  },
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

  Widget _buildImagePicker(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Foto produk', style: theme.textTheme.titleSmall),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: _selectedImagePath == null
                  ? Icon(
                      Icons.image_outlined,
                      size: 36,
                      color: colorScheme.onSurfaceVariant,
                    )
                  : Image.file(
                      File(_selectedImagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.broken_image_outlined,
                        size: 36,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isPickingImage ? null : _pickImage,
                    icon: _isPickingImage
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_library_outlined),
                    label: Text(
                      _isPickingImage ? 'Memilih foto...' : 'Pilih foto',
                    ),
                  ),
                  if (_selectedImagePath != null)
                    TextButton(
                      onPressed: _isPickingImage ? null : _removeImage,
                      child: const Text('Hapus foto'),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (_imageError != null) ...[
          const SizedBox(height: 6),
          Text(
            _imageError!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}
