import 'package:flutter/material.dart';

import '../../products/models/addon.dart';
import '../../products/models/product.dart';

class ProductAddonSelectionResult {
  ProductAddonSelectionResult({
    required List<Addon> selectedAddons,
    required Map<int, int> addonQuantities,
  }) : selectedAddons = List.unmodifiable(selectedAddons),
       addonQuantities = Map.unmodifiable(addonQuantities);

  final List<Addon> selectedAddons;
  final Map<int, int> addonQuantities;
}

class ProductAddonSelectionDialog extends StatefulWidget {
  const ProductAddonSelectionDialog({
    super.key,
    required this.product,
    required this.addons,
  });

  final Product product;
  final List<Addon> addons;

  @override
  State<ProductAddonSelectionDialog> createState() =>
      _ProductAddonSelectionDialogState();
}

class _ProductAddonSelectionDialogState
    extends State<ProductAddonSelectionDialog> {
  final Map<int, int> _selectedQuantities = {};

  void _toggleAddon(int addonId, bool selected) {
    setState(() {
      if (selected) {
        _selectedQuantities[addonId] = 1;
      } else {
        _selectedQuantities.remove(addonId);
      }
    });
  }

  void _increaseQuantity(int addonId) {
    setState(() {
      _selectedQuantities.update(addonId, (quantity) => quantity + 1);
    });
  }

  void _decreaseQuantity(int addonId) {
    final currentQuantity = _selectedQuantities[addonId];

    if (currentQuantity == null || currentQuantity <= 1) {
      return;
    }

    setState(() {
      _selectedQuantities[addonId] = currentQuantity - 1;
    });
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

  void _submit() {
    final selectedAddons = widget.addons
        .where((addon) => _selectedQuantities.containsKey(addon.id))
        .toList();

    Navigator.of(context).pop(
      ProductAddonSelectionResult(
        selectedAddons: selectedAddons,
        addonQuantities: _selectedQuantities,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: const Text('Pilih Add-on'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.product.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Pilih tambahan untuk satu produk ini. '
              'Kamu juga bisa mengubah jumlah setiap add-on.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (widget.addons.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('Tidak ada add-on tersedia untuk produk ini.'),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.addons.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final addon = widget.addons[index];
                    final addonId = addon.id!;
                    final isOutOfStock = addon.stock <= 0;

                    final quantity = _selectedQuantities[addonId];
                    final isSelected = quantity != null;

                    return Column(
                      children: [
                        CheckboxListTile(
                          key: ValueKey('selection-addon-$addonId'),
                          value: isSelected,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(addon.name),
                          subtitle: Text(
                            isOutOfStock
                                ? '${_formatRupiah(addon.additionalPrice)}'
                                      ' • Stok habis'
                                : '${_formatRupiah(addon.additionalPrice)}'
                                      ' • Stok: ${addon.stock}',
                          ),
                          onChanged: isOutOfStock
                              ? null
                              : (selected) {
                                  _toggleAddon(addonId, selected ?? false);
                                },
                        ),
                        if (isSelected)
                          Padding(
                            padding: const EdgeInsets.only(left: 48, bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'Jumlah per produk',
                                  style: theme.textTheme.bodySmall,
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  key: ValueKey('decrease-addon-$addonId'),
                                  tooltip: 'Kurangi jumlah ${addon.name}',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: quantity > 1
                                      ? () => _decreaseQuantity(addonId)
                                      : null,
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Text(
                                  '$quantity',
                                  key: ValueKey('quantity-addon-$addonId'),
                                  style: theme.textTheme.titleSmall,
                                ),
                                IconButton(
                                  key: ValueKey('increase-addon-$addonId'),
                                  tooltip: 'Tambah jumlah ${addon.name}',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () {
                                    _increaseQuantity(addonId);
                                  },
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            Text(
              '${_selectedQuantities.length} add-on dipilih',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Tambahkan ke Keranjang'),
        ),
      ],
    );
  }
}
