import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../services/product_image_service.dart';
import '../viewmodels/product_management_view_model.dart';
import 'category_management_view.dart';
import 'product_form_dialog.dart';

class ProductsView extends StatefulWidget {
  const ProductsView({super.key, this.loadOnInit = true, this.imageService});

  final bool loadOnInit;
  final ProductImageService? imageService;

  @override
  State<ProductsView> createState() => _ProductsViewState();
}

class _ProductsViewState extends State<ProductsView> {
  late final ProductImageService _imageService;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();

    _imageService = widget.imageService ?? ProductImageService();
    _searchController = TextEditingController();

    if (!widget.loadOnInit) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      context.read<ProductManagementViewModel>().ensureLoaded();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openCategoryManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CategoryManagementView()),
    );

    if (!mounted) return;

    await context.read<ProductManagementViewModel>().refresh();
  }

  Future<void> _showProductForm({Product? product}) async {
    final viewModel = context.read<ProductManagementViewModel>();

    if (viewModel.categories.isEmpty) {
      _showFeedbackMessage('Tambahkan kategori terlebih dahulu.');
      return;
    }

    viewModel.clearMessages();

    final result = await showDialog<ProductFormResult>(
      context: context,
      builder: (_) => ProductFormDialog(
        categories: viewModel.categories,
        imageService: _imageService,
        product: product,
      ),
    );

    if (result == null) return;

    // Check whether another active product has the same name and category.
    Product? duplicate;

    try {
      duplicate = await viewModel.findActiveDuplicateProduct(
        categoryId: result.categoryId,
        name: result.name,
        excludeId: product?.id,
      );
    } catch (_) {
      // Clean up a newly selected image if duplicate checking fails.
      if (result.isNewImage && result.imagePath != null) {
        await _deleteImageSafely(result.imagePath);
      }

      if (!mounted) return;

      _showFeedbackMessage(
        'Tidak dapat memeriksa duplikasi produk. Silakan coba lagi.',
      );
      return;
    }

    if (!mounted) {
      if (result.isNewImage && result.imagePath != null) {
        await _deleteImageSafely(result.imagePath);
      }
      return;
    }

    // Ask for confirmation when a duplicate is found.
    if (duplicate != null) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Produk dengan nama sama sudah ada'),
          content: Text(
            'Produk "${duplicate!.name}" sudah ada dalam kategori ini.\n\n'
            'Apakah kamu tetap ingin '
            '${product == null ? 'menambahkan' : 'menyimpan'} '
            'produk ini sebagai data terpisah?\n\n'
            'Stok produk yang sudah ada tidak akan digabung otomatis.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(product == null ? 'Tetap Tambahkan' : 'Tetap Simpan'),
            ),
          ],
        ),
      );

      // Cancel or dismiss the confirmation dialog.
      if (shouldContinue != true) {
        if (result.isNewImage && result.imagePath != null) {
          await _deleteImageSafely(result.imagePath);
        }
        return;
      }
    }

    if (!mounted) {
      if (result.isNewImage && result.imagePath != null) {
        await _deleteImageSafely(result.imagePath);
      }
      return;
    }

    // Continue with the normal create or update operation.
    final success = product == null
        ? await viewModel.createProduct(
            categoryId: result.categoryId,
            name: result.name,
            sellingPrice: result.sellingPrice,
            stock: result.stock,
            imagePath: result.imagePath,
          )
        : await viewModel.updateProduct(
            id: product.id!,
            categoryId: result.categoryId,
            name: result.name,
            sellingPrice: result.sellingPrice,
            stock: result.stock,
            imagePath: result.imagePath,
          );

    if (success) {
      // Delete the previous image only after the database update succeeds.
      if (product != null &&
          result.imageChanged &&
          product.imagePath != result.imagePath) {
        await _deleteImageSafely(product.imagePath);
      }
    } else if (result.isNewImage && result.imagePath != null) {
      // A new image must not be left behind when saving fails.
      await _deleteImageSafely(result.imagePath);
    }

    if (!mounted) return;

    _showFeedback(success);
  }

  Future<void> _confirmDeactivate(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Nonaktifkan produk?'),
          content: Text(
            'Produk "${product.name}" akan dinonaktifkan '
            'dan tidak muncul lagi pada daftar produk aktif.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Nonaktifkan'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final viewModel = context.read<ProductManagementViewModel>();

    viewModel.clearMessages();

    final success = await viewModel.deactivateProduct(product.id!);

    if (!mounted) return;

    _showFeedback(success);
  }

  Future<void> _deleteImageSafely(String? imagePath) async {
    try {
      await _imageService.deleteImage(imagePath);
    } catch (_) {
      // A file cleanup failure must not undo a successful product save.
    }
  }

  void _showFeedback(bool success) {
    final viewModel = context.read<ProductManagementViewModel>();

    final message = success ? viewModel.successMessage : viewModel.errorMessage;

    if (message != null) {
      _showFeedbackMessage(message);
    }
  }

  void _showFeedbackMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  String _formatRupiah(int amount) {
    final digits = amount.toString();
    final buffer = StringBuffer();

    for (var index = 0; index < digits.length; index++) {
      buffer.write(digits[index]);

      final remaining = digits.length - index - 1;

      if (remaining > 0 && remaining % 3 == 0) {
        buffer.write('.');
      }
    }

    return 'Rp$buffer';
  }

  String _getCategoryName(
    ProductManagementViewModel viewModel,
    int categoryId,
  ) {
    for (final category in viewModel.categories) {
      if (category.id == categoryId) {
        return category.name;
      }
    }

    return 'Kategori tidak tersedia';
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ProductManagementViewModel>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Product Management',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Muat ulang',
                onPressed: viewModel.isLoading || viewModel.isSaving
                    ? null
                    : viewModel.refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            'Kelola produk dan kategori tokomu.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 20),

          _buildCategoryCard(theme, colorScheme),

          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Daftar Produk', style: theme.textTheme.titleMedium),
              FilledButton.icon(
                onPressed: viewModel.isSaving || viewModel.categories.isEmpty
                    ? null
                    : () => _showProductForm(),
                icon: const Icon(Icons.add),
                label: const Text('Tambah'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          TextField(
            key: const ValueKey('product-search-field'),
            controller: _searchController,
            onChanged: viewModel.setSearchQuery,
            decoration: InputDecoration(
              hintText: 'Cari nama produk...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: viewModel.searchQuery.isNotEmpty
                  ? IconButton(
                      tooltip: 'Hapus pencarian',
                      onPressed: () {
                        _searchController.clear();
                        viewModel.setSearchQuery('');
                      },
                      icon: const Icon(Icons.close),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Text('Filter kategori', style: theme.textTheme.titleSmall),

          const SizedBox(height: 10),

          _buildCategoryFilters(viewModel),

          const SizedBox(height: 16),

          if (viewModel.isLoading) const LinearProgressIndicator(minHeight: 2),

          _buildProductList(viewModel, theme, colorScheme),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.category_outlined,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kategori Produk', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    'Kelompokkan produk berdasarkan jenisnya.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Kelola Kategori',
              onPressed: _openCategoryManagement,
              icon: const Icon(Icons.arrow_forward_ios, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilters(ProductManagementViewModel viewModel) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Semua'),
            selected: viewModel.selectedCategoryId == null,
            onSelected: (selected) {
              if (selected) {
                viewModel.setCategoryFilter(null);
              }
            },
          ),
          const SizedBox(width: 8),
          ...viewModel.categories.where((category) => category.id != null).map((
            category,
          ) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(category.name),
                selected: viewModel.selectedCategoryId == category.id,
                onSelected: (selected) {
                  if (selected) {
                    viewModel.setCategoryFilter(category.id!);
                  }
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProductList(
    ProductManagementViewModel viewModel,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    if (viewModel.isLoading && viewModel.products.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (viewModel.errorMessage != null &&
        viewModel.products.isEmpty &&
        viewModel.categories.isNotEmpty) {
      return _buildMessageState(
        icon: Icons.error_outline,
        title: viewModel.errorMessage!,
        subtitle: 'Silakan coba muat ulang data produk.',
        action: OutlinedButton.icon(
          onPressed: viewModel.refresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Coba lagi'),
        ),
        colorScheme: colorScheme,
        theme: theme,
      );
    }

    if (viewModel.categories.isEmpty) {
      return _buildMessageState(
        icon: Icons.category_outlined,
        title: 'Belum ada kategori',
        subtitle: 'Tambahkan kategori terlebih dahulu sebelum membuat produk.',
        action: OutlinedButton.icon(
          onPressed: _openCategoryManagement,
          icon: const Icon(Icons.add),
          label: const Text('Tambah Kategori'),
        ),
        colorScheme: colorScheme,
        theme: theme,
      );
    }

    if (viewModel.products.isEmpty) {
      final hasFilter =
          viewModel.searchQuery.isNotEmpty ||
          viewModel.selectedCategoryId != null;

      return _buildMessageState(
        icon: Icons.inventory_2_outlined,
        title: hasFilter ? 'Produk tidak ditemukan' : 'Belum ada produk',
        subtitle: hasFilter
            ? 'Coba kata kunci atau kategori yang berbeda.'
            : 'Tambahkan produk pertama untuk mulai mengelola inventori.',
        action: hasFilter
            ? OutlinedButton(
                onPressed: () {
                  _searchController.clear();
                  viewModel.setSearchQuery('');
                  viewModel.setCategoryFilter(null);
                },
                child: const Text('Reset filter'),
              )
            : FilledButton.icon(
                onPressed: viewModel.isSaving ? null : () => _showProductForm(),
                icon: const Icon(Icons.add),
                label: const Text('Tambah Produk'),
              ),
        colorScheme: colorScheme,
        theme: theme,
      );
    }

    return Column(
      children: viewModel.products.map((product) {
        return _buildProductCard(product, viewModel, theme, colorScheme);
      }).toList(),
    );
  }

  Widget _buildMessageState({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget action,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 48, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            action,
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(
    Product product,
    ProductManagementViewModel viewModel,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 76,
                height: 76,
                color: colorScheme.surfaceContainerHighest,
                child: product.imagePath == null
                    ? Icon(
                        Icons.image_outlined,
                        color: colorScheme.onSurfaceVariant,
                      )
                    : Image.file(
                        File(product.imagePath!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.broken_image_outlined,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getCategoryName(viewModel, product.categoryId),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatRupiah(product.sellingPrice),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                  Text(
                    'Stok: ${product.stock}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            Column(
              children: [
                IconButton(
                  tooltip: 'Edit produk',
                  onPressed: viewModel.isSaving
                      ? null
                      : () => _showProductForm(product: product),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Nonaktifkan produk',
                  onPressed: viewModel.isSaving
                      ? null
                      : () => _confirmDeactivate(product),
                  color: colorScheme.error,
                  icon: const Icon(Icons.archive_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
