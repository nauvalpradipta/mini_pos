import 'package:flutter/material.dart';

import 'category_management_view.dart';

class ProductsView extends StatelessWidget {
  const ProductsView({super.key});

  void _openCategoryManagement(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CategoryManagementView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Product Management', style: theme.textTheme.titleLarge),

          const SizedBox(height: 8),

          Text(
            'Manage products, categories, and add-ons here.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 24),

          Card(
            elevation: 0,
            color: colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(
                      Icons.category_outlined,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text('Kategori Produk', style: theme.textTheme.titleMedium),

                  const SizedBox(height: 8),

                  Text(
                    'Kelompokkan produk berdasarkan jenis, '
                    'seperti makanan, minuman, atau camilan.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        _openCategoryManagement(context);
                      },
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Kelola Kategori'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
