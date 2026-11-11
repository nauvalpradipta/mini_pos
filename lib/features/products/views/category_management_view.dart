import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../viewmodels/product_management_view_model.dart';
import 'category_form_dialog.dart';

class CategoryManagementView extends StatefulWidget {
  const CategoryManagementView({super.key, this.loadOnInit = true});

  final bool loadOnInit;

  @override
  State<CategoryManagementView> createState() => _CategoryManagementViewState();
}

class _CategoryManagementViewState extends State<CategoryManagementView> {
  @override
  void initState() {
    super.initState();

    if (!widget.loadOnInit) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      context.read<ProductManagementViewModel>().load();
    });
  }

  Future<void> _showCategoryForm({Category? category}) async {
    final result = await showDialog<CategoryFormResult>(
      context: context,
      builder: (_) => CategoryFormDialog(category: category),
    );

    if (result == null || !mounted) return;

    final viewModel = context.read<ProductManagementViewModel>();

    viewModel.clearMessages();

    final success = category == null
        ? await viewModel.createCategory(
            name: result.name,
            description: result.description,
          )
        : await viewModel.updateCategory(
            id: category.id!,
            name: result.name,
            description: result.description,
          );

    if (!mounted) return;

    _showFeedback(success);
  }

  Future<void> _confirmDeactivate(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Nonaktifkan kategori?'),
          content: Text(
            'Kategori "${category.name}" akan dinonaktifkan. '
            'Kategori tidak akan muncul lagi pada pilihan aktif.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            TextButton(
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

    final success = await viewModel.deactivateCategory(category.id!);

    if (!mounted) return;

    _showFeedback(success);
  }

  void _showFeedback(bool success) {
    final viewModel = context.read<ProductManagementViewModel>();

    final message = success ? viewModel.successMessage : viewModel.errorMessage;

    if (message == null) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ProductManagementViewModel>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Kategori'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: viewModel.isLoading ? null : viewModel.refresh,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: viewModel.isSaving ? null : () => _showCategoryForm(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Kategori'),
      ),
      body: Column(
        children: [
          if (viewModel.isLoading) const LinearProgressIndicator(minHeight: 2),

          Expanded(child: _buildBody(viewModel, theme, colorScheme)),
        ],
      ),
    );
  }

  Widget _buildBody(
    ProductManagementViewModel viewModel,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    if (viewModel.isLoading && viewModel.categories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.errorMessage != null && viewModel.categories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
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

    if (viewModel.categories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.category_outlined,
                size: 56,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text('Belum ada kategori', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Tambahkan kategori untuk mengelompokkan produk tokomu.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: viewModel.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: viewModel.categories.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final category = viewModel.categories[index];

          return Card(
            elevation: 0,
            color: colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  Icons.category_outlined,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              title: Text(category.name, style: theme.textTheme.titleMedium),
              subtitle: Text(
                category.description?.isNotEmpty == true
                    ? category.description!
                    : 'Tidak ada deskripsi',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Edit kategori',
                    onPressed: viewModel.isSaving
                        ? null
                        : () => _showCategoryForm(category: category),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Nonaktifkan kategori',
                    onPressed: viewModel.isSaving
                        ? null
                        : () => _confirmDeactivate(category),
                    color: colorScheme.error,
                    icon: const Icon(Icons.archive_outlined),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
