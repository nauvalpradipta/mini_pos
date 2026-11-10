import 'package:flutter/material.dart';

import '../../../core/widgets/feature_placeholder.dart';

class ProductsView extends StatelessWidget {
  const ProductsView({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.inventory_2_outlined,
      title: 'Product Management',
      description: 'Manage products, categories, and add-ons here.',
    );
  }
}
