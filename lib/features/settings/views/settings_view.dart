import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../features/auth/viewmodels/auth_view_model.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthViewModel>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final user = authViewModel.currentUser;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (user == null) {
      return const Center(child: Text('Informasi akun tidak tersedia.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Akun Kasir', style: theme.textTheme.titleLarge),

          const SizedBox(height: 8),

          Text(
            'Informasi akun yang sedang digunakan.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 20),

          // Profile card.
          Card(
            elevation: 0,
            color: colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(
                      user.fullName.isNotEmpty
                          ? user.fullName[0].toUpperCase()
                          : '?',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.fullName, style: theme.textTheme.titleMedium),

                        const SizedBox(height: 4),

                        Text(
                          '@${user.username}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Aktif',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          Text('Informasi Akun', style: theme.textTheme.titleMedium),

          const SizedBox(height: 12),

          _SettingsInfoTile(
            icon: Icons.badge_outlined,
            label: 'Nama lengkap',
            value: user.fullName,
          ),

          const Divider(height: 1),

          _SettingsInfoTile(
            icon: Icons.person_outline,
            label: 'Username',
            value: user.username,
          ),

          const Divider(height: 1),

          _SettingsInfoTile(
            icon: Icons.verified_user_outlined,
            label: 'Status akun',
            value: user.isActive ? 'Aktif' : 'Nonaktif',
          ),

          const SizedBox(height: 32),

          Text('Sesi', style: theme.textTheme.titleMedium),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: authViewModel.isLoading
                  ? null
                  : () => _logout(context),
              icon: authViewModel.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout),
              label: const Text('Keluar dari akun'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.error,
                minimumSize: const Size(double.infinity, 48),
                side: BorderSide(color: colorScheme.error),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsInfoTile extends StatelessWidget {
  const _SettingsInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label, style: theme.textTheme.bodySmall),
      subtitle: Text(value, style: theme.textTheme.bodyLarge),
    );
  }
}
