import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/addon.dart';
import '../viewmodels/addon_management_view_model.dart';
import 'addon_form_dialog.dart';

class AddonManagementView extends StatefulWidget {
  const AddonManagementView({super.key, this.loadOnInit = true});

  final bool loadOnInit;

  @override
  State<AddonManagementView> createState() => _AddonManagementViewState();
}

class _AddonManagementViewState extends State<AddonManagementView> {
  bool _showInactive = false;

  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController();

    if (!widget.loadOnInit) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      context.read<AddonManagementViewModel>().ensureLoaded();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showAddonForm({Addon? addon}) async {
    final viewModel = context.read<AddonManagementViewModel>();

    viewModel.clearMessages();

    final result = await showDialog<AddonFormResult>(
      context: context,
      builder: (_) => AddonFormDialog(addon: addon),
    );

    if (result == null || !mounted) return;

    final success = addon == null
        ? await viewModel.createAddon(
            name: result.name,
            additionalPrice: result.additionalPrice,
            stock: result.stock,
          )
        : await viewModel.updateAddon(
            id: addon.id!,
            name: result.name,
            additionalPrice: result.additionalPrice,
            stock: result.stock,
          );

    if (!mounted) return;

    _showFeedback(success);
  }

  Future<void> _confirmDeactivate(Addon addon) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Nonaktifkan add-on?'),
          content: Text(
            'Add-on "${addon.name}" akan dinonaktifkan. '
            'Add-on tidak akan muncul lagi pada pilihan aktif.',
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

    final viewModel = context.read<AddonManagementViewModel>();

    viewModel.clearMessages();

    final success = await viewModel.deactivateAddon(addon.id!);

    if (!mounted) return;

    _showFeedback(success);
  }

  Future<void> _activateAddon(Addon addon) async {
    final viewModel = context.read<AddonManagementViewModel>();

    viewModel.clearMessages();

    final success = await viewModel.activateAddon(addon.id!);

    if (!mounted) return;

    if (success) {
      setState(() {
        _showInactive = false;
      });
    }

    _showFeedback(success);
  }

  void _showFeedback(bool success) {
    final viewModel = context.read<AddonManagementViewModel>();

    final message = success ? viewModel.successMessage : viewModel.errorMessage;

    if (message == null) return;

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

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AddonManagementViewModel>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Add-on'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: viewModel.isLoading || viewModel.isSaving
                ? null
                : viewModel.refresh,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: _showInactive
          ? null
          : FloatingActionButton.extended(
              onPressed: viewModel.isSaving ? null : () => _showAddonForm(),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Add-on'),
            ),
      body: Column(
        children: [
          if (viewModel.isLoading) const LinearProgressIndicator(minHeight: 2),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              key: const ValueKey('addon-search-field'),
              controller: _searchController,
              onChanged: viewModel.setSearchQuery,
              decoration: InputDecoration(
                hintText: 'Cari nama add-on...',
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
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: false,
                  label: Text('Aktif'),
                  icon: Icon(Icons.check_circle_outline),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text('Nonaktif'),
                  icon: Icon(Icons.archive_outlined),
                ),
              ],
              selected: {_showInactive},
              onSelectionChanged: viewModel.isSaving
                  ? null
                  : (selection) {
                      setState(() {
                        _showInactive = selection.first;
                      });
                    },
            ),
          ),

          Expanded(child: _buildBody(viewModel, theme, colorScheme)),
        ],
      ),
    );
  }

  Widget _buildBody(
    AddonManagementViewModel viewModel,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final addons = _showInactive ? viewModel.inactiveAddons : viewModel.addons;

    if (viewModel.isLoading &&
        viewModel.addons.isEmpty &&
        viewModel.inactiveAddons.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.errorMessage != null && addons.isEmpty) {
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

    if (addons.isEmpty) {
      final hasSearch = viewModel.searchQuery.isNotEmpty;

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasSearch
                    ? Icons.search_off
                    : _showInactive
                    ? Icons.inventory_2_outlined
                    : Icons.tune_outlined,
                size: 56,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                hasSearch
                    ? 'Add-on tidak ditemukan'
                    : _showInactive
                    ? 'Tidak ada add-on nonaktif'
                    : 'Belum ada add-on',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                hasSearch
                    ? 'Coba kata kunci yang berbeda.'
                    : _showInactive
                    ? 'Add-on yang dinonaktifkan akan muncul di sini.'
                    : 'Tambahkan add-on seperti extra cheese atau extra shot.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (_showInactive && !hasSearch) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _showInactive = false;
                    });
                  },
                  child: const Text('Lihat add-on aktif'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: viewModel.refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: addons.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final addon = addons[index];

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
                child: Icon(Icons.tune, color: colorScheme.onPrimaryContainer),
              ),
              title: Text(addon.name, style: theme.textTheme.titleMedium),
              subtitle: Text(
                '${_formatRupiah(addon.additionalPrice)}'
                ' • Stok: ${addon.stock}',
              ),
              trailing: _showInactive
                  ? FilledButton.tonal(
                      onPressed: viewModel.isSaving
                          ? null
                          : () => _activateAddon(addon),
                      child: const Text('Aktifkan'),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit add-on',
                          onPressed: viewModel.isSaving
                              ? null
                              : () => _showAddonForm(addon: addon),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Nonaktifkan add-on',
                          onPressed: viewModel.isSaving
                              ? null
                              : () => _confirmDeactivate(addon),
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
