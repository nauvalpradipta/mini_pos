import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mini_pos/features/auth/viewmodels/auth_view_model.dart';
import 'package:mini_pos/features/settings/models/store_settings.dart';
import 'package:mini_pos/features/settings/viewmodels/settings_view_model.dart';
import 'package:mini_pos/features/settings/views/store_settings_dialog.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      unawaited(context.read<SettingsViewModel>().ensureLoaded());
    });
  }

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthViewModel>().logout();
  }

  Future<void> _openStoreSettings(StoreSettings settings) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => StoreSettingsDialog(settings: settings),
    );

    if (!mounted) return;

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informasi toko berhasil diperbarui.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildStoreSection(BuildContext context, SettingsViewModel viewModel) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settings = viewModel.settings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Informasi Toko', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Informasi toko yang digunakan dalam transaksi.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Card(
          elevation: 0,
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: settings == null
                ? _buildStoreLoadingState(context, viewModel)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: colorScheme.primaryContainer,
                            child: Icon(
                              Icons.store_outlined,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              settings.storeName,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Ubah informasi toko',
                            onPressed: viewModel.isSaving
                                ? null
                                : () => _openStoreSettings(settings),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                      ),
                      const Divider(height: 28),
                      _SettingsInfoTile(
                        icon: Icons.store_outlined,
                        label: 'Nama toko',
                        value: settings.storeName,
                      ),
                      _SettingsInfoTile(
                        icon: Icons.location_on_outlined,
                        label: 'Alamat',
                        value: _displayValue(settings.address),
                      ),
                      _SettingsInfoTile(
                        icon: Icons.phone_outlined,
                        label: 'Nomor telepon',
                        value: _displayValue(settings.phone),
                      ),
                      _SettingsInfoTile(
                        icon: Icons.receipt_long_outlined,
                        label: 'Footer struk',
                        value: _displayValue(settings.receiptFooter),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildStoreLoadingState(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (viewModel.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          viewModel.errorMessage ?? 'Pengaturan toko belum tersedia.',
          style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.error),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: viewModel.isLoading ? null : () => viewModel.load(),
          icon: const Icon(Icons.refresh),
          label: const Text('Coba lagi'),
        ),
      ],
    );
  }

  String _displayValue(String value) {
    return value.trim().isEmpty ? 'Belum diatur' : value;
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final settingsViewModel = context.watch<SettingsViewModel>();
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
          _buildStoreSection(context, settingsViewModel),

          const SizedBox(height: 32),

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
