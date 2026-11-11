import 'package:flutter/material.dart';

import '../models/addon.dart';
import '../models/product.dart';

class ProductAddonAssignmentDialog extends StatefulWidget {
  const ProductAddonAssignmentDialog({
    super.key,
    required this.product,
    required this.addons,
    required this.initialAddonIds,
  });

  final Product product;
  final List<Addon> addons;
  final Set<int> initialAddonIds;

  @override
  State<ProductAddonAssignmentDialog> createState() =>
      _ProductAddonAssignmentDialogState();
}

class _ProductAddonAssignmentDialogState
    extends State<ProductAddonAssignmentDialog> {
  late final Set<int> _selectedAddonIds;

  @override
  void initState() {
    super.initState();

    _selectedAddonIds = {...widget.initialAddonIds};
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: const Text('Atur Add-on Produk'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.product.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Pilih add-on yang tersedia untuk produk ini.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (widget.addons.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Belum ada add-on aktif.')),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.addons.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final addon = widget.addons[index];
                    final addonId = addon.id!;

                    final isSelected = _selectedAddonIds.contains(addonId);

                    return CheckboxListTile(
                      key: ValueKey('addon-option-$addonId'),
                      value: isSelected,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(addon.name),
                      subtitle: Text(
                        '${_formatRupiah(addon.additionalPrice)}'
                        ' • Stok: ${addon.stock}',
                      ),
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedAddonIds.add(addonId);
                          } else {
                            _selectedAddonIds.remove(addonId);
                          }
                        });
                      },
                    );
                  },
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
          onPressed: () {
            Navigator.of(context).pop(Set<int>.of(_selectedAddonIds));
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
