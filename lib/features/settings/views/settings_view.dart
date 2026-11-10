import 'package:flutter/material.dart';

import '../../../core/widgets/feature_placeholder.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.settings_outlined,
      title: 'Settings',
      description: 'Manage store information and cashier account settings.',
    );
  }
}
