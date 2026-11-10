import 'package:flutter/material.dart';

import '../../../core/widgets/feature_placeholder.dart';

class CashierView extends StatelessWidget {
  const CashierView({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.point_of_sale_outlined,
      title: 'Cashier',
      description: 'Product catalog, cart, and checkout will be built here.',
    );
  }
}
