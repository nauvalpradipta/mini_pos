import 'package:flutter/material.dart';

import '../../../core/widgets/feature_placeholder.dart';

class SalesView extends StatelessWidget {
  const SalesView({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.bar_chart_outlined,
      title: 'Sales Reports',
      description: 'View revenue, transaction history, and sales performance.',
    );
  }
}
