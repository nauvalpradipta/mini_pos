import 'package:flutter/material.dart';

import '../models/cart_item.dart';
import '../models/checkout.dart';
import 'cart_currency_formatter.dart';

class CheckoutReceiptDialog extends StatelessWidget {
  const CheckoutReceiptDialog({
    super.key,
    required this.result,
    required this.cashierName,
    required this.cartItems,
  });

  final CheckoutResult result;
  final String cashierName;
  final List<CartItem> cartItems;

  String _formatDateTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day-$month-$year $hour:$minute';
  }

  String _discountLabel() {
    switch (result.discountType) {
      case DiscountType.none:
        return 'Diskon';
      case DiscountType.percentage:
        return 'Diskon (${result.discountValue}%)';
      case DiscountType.fixed:
        return 'Diskon nominal';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 56,
                color: colorScheme.primary,
              ),

              const SizedBox(height: 12),

              Text(
                'Transaksi berhasil',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                'Pembayaran telah disimpan.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 20),

              Divider(color: colorScheme.outlineVariant),

              _buildInfoRow('Nomor struk', result.receiptNumber),
              _buildInfoRow('Tanggal', _formatDateTime(result.transactionAt)),
              _buildInfoRow('Kasir', cashierName),

              Divider(color: colorScheme.outlineVariant),

              Text('Rincian produk', style: theme.textTheme.titleSmall),

              const SizedBox(height: 12),

              ...cartItems.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(
                        '${item.productName} × ${item.quantity}',
                        formatCartCurrency(item.productSubtotal),
                      ),

                      ...item.addons.map((addon) {
                        final totalQuantity =
                            addon.quantityPerProduct * item.quantity;

                        final addonSubtotal =
                            addon.additionalPrice * totalQuantity;

                        return Padding(
                          padding: const EdgeInsets.only(left: 12, top: 5),
                          child: _buildInfoRow(
                            '+ ${addon.addonName} × $totalQuantity',
                            formatCartCurrency(addonSubtotal),
                            isSecondary: true,
                          ),
                        );
                      }),

                      const SizedBox(height: 4),

                      _buildInfoRow(
                        'Total item',
                        formatCartCurrency(item.lineTotal),
                        isEmphasized: true,
                      ),
                    ],
                  ),
                );
              }),

              Divider(color: colorScheme.outlineVariant),

              _buildInfoRow('Subtotal', formatCartCurrency(result.subtotal)),

              if (result.discountAmount > 0)
                _buildInfoRow(
                  _discountLabel(),
                  '-${formatCartCurrency(result.discountAmount)}',
                  valueColor: colorScheme.error,
                ),

              const SizedBox(height: 8),

              _buildInfoRow(
                'Total pembayaran',
                formatCartCurrency(result.total),
                isEmphasized: true,
              ),

              _buildInfoRow(
                'Uang diterima',
                formatCartCurrency(result.cashReceived),
              ),

              _buildInfoRow(
                'Kembalian',
                formatCartCurrency(result.changeAmount),
                valueColor: colorScheme.primary,
                isEmphasized: true,
              ),

              const SizedBox(height: 20),

              SelectableText(
                result.receiptNumber,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 16),

              FilledButton(
                key: const ValueKey('receipt-done-button'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Selesai'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    Color? valueColor,
    bool isSecondary = false,
    bool isEmphasized = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isSecondary ? 12 : 14,
                color: isSecondary ? Colors.grey : null,
                fontWeight: isEmphasized ? FontWeight.w600 : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: isSecondary ? 12 : 14,
                color: valueColor,
                fontWeight: isEmphasized ? FontWeight.bold : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
