import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../products/models/product.dart';
import '../viewmodels/cashier_catalog_view_model.dart';
import '../../products/viewmodels/addon_management_view_model.dart';
import '../viewmodels/cart_view_model.dart';
import 'product_addon_selection_dialog.dart';
import 'cart_panel.dart';
import 'cart_summary_bar.dart';

class CashierView extends StatefulWidget {
  const CashierView({super.key, this.loadOnInit = true});

  final bool loadOnInit;

  @override
  State<CashierView> createState() => _CashierViewState();
}

class _CashierViewState extends State<CashierView> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController();

    if (!widget.loadOnInit) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      context.read<CashierCatalogViewModel>().ensureLoaded();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectProduct(Product product) async {
    if (product.stock <= 0) return;

    if (product.id == null) {
      _showFeedbackMessage('ID produk tidak valid.');
      return;
    }

    final addonViewModel = context.read<AddonManagementViewModel>();
    final cartViewModel = context.read<CartViewModel>();

    if (addonViewModel.isLoading ||
        addonViewModel.isSaving ||
        addonViewModel.isLoadingAssignments) {
      return;
    }

    try {
      addonViewModel.clearMessages();

      await addonViewModel.ensureLoaded();

      if (!mounted) return;

      if (addonViewModel.errorMessage != null) {
        _showFeedbackMessage(addonViewModel.errorMessage!);
        return;
      }

      final assignedAddons = await addonViewModel.getAssignedAddons(
        product.id!,
      );

      if (!mounted) return;

      final result = await showDialog<ProductAddonSelectionResult>(
        context: context,
        builder: (_) => ProductAddonSelectionDialog(
          product: product,
          addons: assignedAddons,
        ),
      );

      if (result == null || !mounted) return;

      cartViewModel.addProduct(
        product,
        selectedAddons: result.selectedAddons,
        addonQuantities: result.addonQuantities,
      );

      _showFeedbackMessage(
        '${product.name} berhasil ditambahkan ke keranjang.',
      );
    } catch (_) {
      if (!mounted) return;

      _showFeedbackMessage(
        'Tidak dapat menambahkan produk. Silakan coba lagi.',
      );
    }
  }

  void _showFeedbackMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  void _clearFilters() {
    _searchController.clear();
    context.read<CashierCatalogViewModel>().clearFilters();
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

  String _getCategoryName(CashierCatalogViewModel viewModel, int categoryId) {
    for (final category in viewModel.categories) {
      if (category.id == categoryId) {
        return category.name;
      }
    }

    return 'Kategori tidak tersedia';
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CashierCatalogViewModel>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth >= 1100;

        final catalog = Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pilih Produk',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${viewModel.products.length} produk tersedia',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Muat ulang katalog',
                        onPressed: viewModel.isLoading
                            ? null
                            : viewModel.refresh,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    key: const ValueKey('cashier-search-field'),
                    controller: _searchController,
                    onChanged: viewModel.setSearchQuery,
                    decoration: InputDecoration(
                      hintText: 'Cari nama produk...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: viewModel.searchQuery.isNotEmpty
                          ? IconButton(
                              tooltip: 'Hapus pencarian',
                              onPressed: _clearFilters,
                              icon: const Icon(Icons.close),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  _buildCategoryFilters(viewModel),
                ],
              ),
            ),

            if (viewModel.isLoading)
              const LinearProgressIndicator(minHeight: 2),

            Expanded(
              child: _buildProductCatalog(viewModel, theme, colorScheme),
            ),
          ],
        );

        if (isWideScreen) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: catalog),
              SizedBox(
                width: 380,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                  child: CartPanel(key: const ValueKey('desktop-cart-panel')),
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            Expanded(child: catalog),
            const CartSummaryBar(),
          ],
        );
      },
    );
  }

  Widget _buildCategoryFilters(CashierCatalogViewModel viewModel) {
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
          ...viewModel.categories.map((category) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(category.name),
                selected: viewModel.selectedCategoryId == category.id,
                onSelected: (selected) {
                  if (selected) {
                    viewModel.setCategoryFilter(category.id);
                  }
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProductCatalog(
    CashierCatalogViewModel viewModel,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    if (viewModel.isLoading && viewModel.products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.errorMessage != null && viewModel.products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(viewModel.errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: viewModel.refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (viewModel.products.isEmpty) {
      final hasFilter =
          viewModel.searchQuery.isNotEmpty ||
          viewModel.selectedCategoryId != null;

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasFilter ? Icons.search_off : Icons.inventory_2_outlined,
                size: 56,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                hasFilter ? 'Produk tidak ditemukan' : 'Belum ada produk',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                hasFilter
                    ? 'Coba kata kunci atau kategori yang berbeda.'
                    : 'Produk aktif akan muncul di sini setelah ditambahkan.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (hasFilter) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _clearFilters,
                  child: const Text('Reset filter'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = switch (constraints.maxWidth) {
          >= 900 => 4,
          >= 600 => 3,
          _ => 2,
        };

        return RefreshIndicator(
          onRefresh: viewModel.refresh,
          child: GridView.builder(
            key: const ValueKey('cashier-product-grid'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 248,
            ),
            itemCount: viewModel.products.length,
            itemBuilder: (context, index) {
              final product = viewModel.products[index];

              return _buildProductCard(product, viewModel, theme, colorScheme);
            },
          ),
        );
      },
    );
  }

  Widget _buildProductCard(
    Product product,
    CashierCatalogViewModel viewModel,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final isOutOfStock = product.stock <= 0;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        key: ValueKey('cashier-product-${product.id}'),
        borderRadius: BorderRadius.circular(14),
        onTap: isOutOfStock ? null : () => _selectProduct(product),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 112,
              width: double.infinity,
              child: product.imagePath == null || product.imagePath!.isEmpty
                  ? Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.image_outlined,
                        size: 40,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    )
                  : Image.file(
                      File(product.imagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _getCategoryName(viewModel, product.categoryId),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatRupiah(product.sellingPrice),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          isOutOfStock
                              ? Icons.error_outline
                              : Icons.inventory_2_outlined,
                          size: 14,
                          color: isOutOfStock
                              ? colorScheme.error
                              : colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isOutOfStock
                              ? 'Stok habis'
                              : 'Stok: ${product.stock}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isOutOfStock
                                ? colorScheme.error
                                : colorScheme.onSurfaceVariant,
                            fontWeight: isOutOfStock
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
