import 'package:flutter/material.dart';

import '../models/sale.dart';
import 'sales_formatters.dart';
import '../../cashier/models/checkout.dart';

class SaleDetailDialog extends StatelessWidget {
  const SaleDetailDialog({super.key, required this.detail});

  final SaleDetail detail;

  String _discountLabel(SaleTransaction sale) {
    switch (sale.discountType) {
      case DiscountType.none:
        return 'Diskon';

      case DiscountType.percentage:
        return 'Diskon (${sale.discountValue}%)';

      case DiscountType.fixed:
        return 'Diskon nominal';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sale = detail.transaction;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Detail Transaksi',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sale.storeName, style: theme.textTheme.titleMedium),
                    if (sale.storeAddress.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(sale.storeAddress),
                    ],
                    if (sale.storePhone.isNotEmpty) Text(sale.storePhone),
                    const SizedBox(height: 12),
                    _buildInfoRow('Nomor struk', sale.receiptNumber),
                    _buildInfoRow(
                      'Tanggal',
                      formatSalesDate(sale.transactionAt),
                    ),
                    _buildInfoRow('Kasir', sale.cashierName),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Text('Rincian Produk', style: theme.textTheme.titleMedium),

              const SizedBox(height: 12),

              ...detail.items.map((item) {
                return Container(
                  key: ValueKey('sale-detail-item-${item.id}'),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(
                        '${item.productName} × ${item.quantity}',
                        formatSalesCurrency(item.baseSubtotal),
                        emphasized: true,
                      ),

                      const SizedBox(height: 4),

                      Text(
                        '${formatSalesCurrency(item.unitPrice)} / produk',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),

                      if (item.addons.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ...item.addons.map((addon) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: _buildInfoRow(
                              '+ ${addon.addonName} × ${addon.totalQuantity}',
                              formatSalesCurrency(addon.subtotal),
                            ),
                          );
                        }),
                      ],

                      const SizedBox(height: 8),

                      Divider(color: colorScheme.outlineVariant),

                      _buildInfoRow(
                        'Total item',
                        formatSalesCurrency(item.lineTotal),
                        emphasized: true,
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 8),

              _buildInfoRow('Subtotal', formatSalesCurrency(sale.subtotal)),

              if (sale.discountAmount > 0)
                _buildInfoRow(
                  _discountLabel(sale),
                  '-${formatSalesCurrency(sale.discountAmount)}',
                  valueColor: colorScheme.error,
                ),

              const SizedBox(height: 8),

              Divider(color: colorScheme.outlineVariant),

              const SizedBox(height: 8),

              _buildInfoRow(
                'Total Pembayaran',
                formatSalesCurrency(sale.total),
                emphasized: true,
                valueColor: colorScheme.primary,
              ),

              _buildInfoRow(
                'Uang Diterima',
                formatSalesCurrency(sale.cashReceived),
              ),

              _buildInfoRow(
                'Kembalian',
                formatSalesCurrency(sale.changeAmount),
                emphasized: true,
              ),

              const SizedBox(height: 20),

              OutlinedButton(
                key: const ValueKey('sale-detail-close'),
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
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
    bool emphasized = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontWeight: emphasized ? FontWeight.w600 : null),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: emphasized ? FontWeight.bold : null,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
