import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/cart_view_model.dart';
import 'cart_currency_formatter.dart';
import 'cart_panel.dart';

class CartSummaryBar extends StatelessWidget {
  const CartSummaryBar({super.key});

  Future<void> _openCart(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final height = MediaQuery.sizeOf(sheetContext).height * 0.78;

        return SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: CartPanel(onClose: () => Navigator.of(sheetContext).pop()),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartViewModel>();

    if (cart.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${cart.itemCount} item dalam keranjang',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      formatCartCurrency(cart.subtotal),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                key: const ValueKey('open-cart-button'),
                onPressed: () => _openCart(context),
                icon: const Icon(Icons.shopping_cart_outlined),
                label: const Text('Lihat Keranjang'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
