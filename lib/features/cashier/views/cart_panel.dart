import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cart_item.dart';
import '../viewmodels/cart_view_model.dart';
import 'cart_currency_formatter.dart';
import '../../auth/viewmodels/auth_view_model.dart';
import '../models/checkout.dart';
import '../viewmodels/checkout_view_model.dart';
import 'checkout_dialog.dart';
import 'checkout_receipt_dialog.dart';

class CartPanel extends StatelessWidget {
  const CartPanel({super.key, this.onClose});

  final VoidCallback? onClose;

  void _increaseQuantity(
    BuildContext context,
    CartViewModel viewModel,
    CartItem item,
  ) {
    try {
      viewModel.increaseQuantity(item);
    } on CartStockException catch (error) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(error.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _openCheckout(BuildContext context) async {
    final authViewModel = context.read<AuthViewModel>();
    final cashier = authViewModel.currentUser;
    final cartViewModel = context.read<CartViewModel>();

    if (cashier == null || !authViewModel.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesi kasir tidak valid. Silakan login kembali.'),
        ),
      );
      return;
    }

    if (cartViewModel.isEmpty) return;

    // Simpan snapshot keranjang sebelum proses pembayaran.
    final cartItems = List<CartItem>.unmodifiable(cartViewModel.items);

    final checkoutViewModel = context.read<CheckoutViewModel>();
    checkoutViewModel.reset();

    final result = await showDialog<CheckoutResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          CheckoutDialog(cashierId: cashier.id, cartItems: cartItems),
    );

    if (!context.mounted || result == null) return;

    // Keranjang hanya dikosongkan setelah transaksi berhasil.
    cartViewModel.clear();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CheckoutReceiptDialog(
        result: result,
        cashierName: cashier.fullName,
        cartItems: cartItems,
      ),
    );

    if (!context.mounted) return;

    checkoutViewModel.reset();
  }

  Future<void> _confirmClear(
    BuildContext context,
    CartViewModel viewModel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Kosongkan keranjang?'),
          content: const Text(
            'Semua produk yang ada di keranjang akan dihapus.',
          ),
          actions: [
            TextButton(
              key: const ValueKey('cart-clear-cancel'),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              key: const ValueKey('cart-clear-confirm'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Kosongkan'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      viewModel.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CartViewModel>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      key: const ValueKey('cart-panel'),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Keranjang', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 3),
                      Text(
                        '${viewModel.itemCount} item',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                if (viewModel.isNotEmpty)
                  IconButton(
                    key: const ValueKey('cart-clear-button'),
                    tooltip: 'Kosongkan keranjang',
                    onPressed: () => _confirmClear(context, viewModel),
                    icon: const Icon(Icons.delete_sweep_outlined),
                  ),

                if (onClose != null)
                  IconButton(
                    tooltip: 'Tutup keranjang',
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
          ),

          Divider(height: 1, color: colorScheme.outlineVariant),

          Expanded(
            child: viewModel.isEmpty
                ? _buildEmptyState(theme, colorScheme)
                : ListView.separated(
                    key: const ValueKey('cart-item-list'),
                    padding: const EdgeInsets.all(12),
                    itemCount: viewModel.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = viewModel.items[index];

                      return _buildCartItem(
                        context,
                        item,
                        index,
                        viewModel,
                        theme,
                        colorScheme,
                      );
                    },
                  ),
          ),

          Divider(height: 1, color: colorScheme.outlineVariant),

          _buildTotals(context, viewModel, theme, colorScheme),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 52,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Keranjang masih kosong',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Pilih produk dari katalog untuk mulai bertransaksi.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItem(
    BuildContext context,
    CartItem item,
    int index,
    CartViewModel viewModel,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Container(
      key: ValueKey('cart-item-$index'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.productName, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 3),
                    Text(
                      '${formatCartCurrency(item.unitPrice)} / produk',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: ValueKey('cart-remove-$index'),
                tooltip: 'Hapus item',
                visualDensity: VisualDensity.compact,
                onPressed: () => viewModel.removeItem(item),
                icon: Icon(Icons.delete_outline, color: colorScheme.error),
              ),
            ],
          ),

          if (item.addons.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...item.addons.map((addon) {
              final addonTotal =
                  addon.additionalPrice *
                  addon.quantityPerProduct *
                  item.quantity;

              return Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '+ ${addon.addonName} × ${addon.quantityPerProduct}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      formatCartCurrency(addonTotal),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 10),

          Row(
            children: [
              IconButton(
                key: ValueKey('cart-decrease-$index'),
                tooltip: 'Kurangi jumlah',
                visualDensity: VisualDensity.compact,
                onPressed: () => viewModel.decreaseQuantity(item),
                icon: const Icon(Icons.remove_circle_outline),
              ),

              SizedBox(
                width: 28,
                child: Text(
                  '${item.quantity}',
                  key: ValueKey('cart-quantity-$index'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall,
                ),
              ),

              IconButton(
                key: ValueKey('cart-increase-$index'),
                tooltip: 'Tambah jumlah',
                visualDensity: VisualDensity.compact,
                onPressed: () => _increaseQuantity(context, viewModel, item),
                icon: const Icon(Icons.add_circle_outline),
              ),

              const Spacer(),

              Text(
                formatCartCurrency(item.lineTotal),
                key: ValueKey('cart-line-total-$index'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotals(
    BuildContext context,
    CartViewModel viewModel,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTotalRow(
            'Subtotal produk',
            formatCartCurrency(viewModel.productSubtotal),
            theme,
            valueKey: const ValueKey('cart-product-subtotal'),
          ),

          const SizedBox(height: 6),

          _buildTotalRow(
            'Subtotal add-on',
            formatCartCurrency(viewModel.addonsSubtotal),
            theme,
            valueKey: const ValueKey('cart-addons-subtotal'),
          ),

          const SizedBox(height: 12),

          Divider(height: 1, color: colorScheme.outlineVariant),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Text(
                  'Total',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                formatCartCurrency(viewModel.subtotal),
                key: const ValueKey('cart-total'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),

          if (viewModel.isNotEmpty) ...[
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('cart-checkout-button'),
                onPressed: () => _openCheckout(context),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Lanjut Pembayaran'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    String amount,
    ThemeData theme, {
    Key? valueKey,
  }) {
    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Text(amount, key: valueKey, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
