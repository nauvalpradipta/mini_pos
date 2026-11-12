import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/cart_item.dart';
import '../models/checkout.dart';
import '../viewmodels/checkout_view_model.dart';
import 'cart_currency_formatter.dart';

class CheckoutDialog extends StatefulWidget {
  const CheckoutDialog({
    super.key,
    required this.cashierId,
    required this.cartItems,
  });

  final int cashierId;
  final List<CartItem> cartItems;

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  late final TextEditingController _discountController;
  late final TextEditingController _cashController;

  @override
  void initState() {
    super.initState();

    _discountController = TextEditingController(text: '0');
    _cashController = TextEditingController();
  }

  @override
  void dispose() {
    _discountController.dispose();
    _cashController.dispose();
    super.dispose();
  }

  int get _subtotal {
    return widget.cartItems.fold(0, (total, item) => total + item.lineTotal);
  }

  void _setCashAmount(int amount) {
    _cashController.text = amount.toString();
    context.read<CheckoutViewModel>().setCashReceived(amount);
  }

  Future<void> _submit() async {
    final checkoutViewModel = context.read<CheckoutViewModel>();

    final result = await checkoutViewModel.submit(
      cashierId: widget.cashierId,
      cartItems: widget.cartItems,
    );

    if (!mounted || result == null) return;

    Navigator.of(context).pop(result);
  }

  String _discountTypeLabel(DiscountType type) {
    switch (type) {
      case DiscountType.none:
        return 'Tanpa diskon';
      case DiscountType.percentage:
        return 'Persentase (%)';
      case DiscountType.fixed:
        return 'Nominal (Rp)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final checkout = context.watch<CheckoutViewModel>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final discountError = checkout.discountValidationMessage(_subtotal);
    final discountAmount = checkout.discountAmountFor(_subtotal);
    final total = checkout.totalFor(_subtotal);
    final shortfall = checkout.shortfallFor(_subtotal);
    final change = checkout.changeFor(_subtotal);

    final canSubmit = checkout.canSubmit(
      subtotal: _subtotal,
      hasItems: widget.cartItems.isNotEmpty,
      hasCashier: widget.cashierId > 0,
    );

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pembayaran',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: checkout.isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              Text(
                '${widget.cartItems.length} jenis produk dalam transaksi',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 20),

              // ---------------------------------------------------
              // RINGKASAN
              // ---------------------------------------------------
              _buildSummaryRow(
                'Subtotal produk dan add-on',
                formatCartCurrency(_subtotal),
                theme,
              ),

              const SizedBox(height: 16),

              Text('Diskon', style: theme.textTheme.titleSmall),

              const SizedBox(height: 8),

              InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<DiscountType>(
                    key: const ValueKey('checkout-discount-type'),
                    value: checkout.discountType,
                    isExpanded: true,
                    items: DiscountType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(_discountTypeLabel(type)),
                      );
                    }).toList(),
                    onChanged: checkout.isSubmitting
                        ? null
                        : (type) {
                            if (type == null) return;

                            checkout.setDiscountType(type);
                            _discountController.text = checkout.discountValue
                                .toString();
                          },
                  ),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                key: const ValueKey('checkout-discount-field'),
                controller: _discountController,
                enabled:
                    !checkout.isSubmitting &&
                    checkout.discountType != DiscountType.none,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) {
                  checkout.setDiscountValue(int.tryParse(value) ?? 0);
                },
                decoration: InputDecoration(
                  labelText: checkout.discountType == DiscountType.percentage
                      ? 'Persentase diskon'
                      : 'Nominal diskon',
                  hintText: 'Masukkan nilai diskon',
                  prefixText: checkout.discountType == DiscountType.fixed
                      ? 'Rp '
                      : null,
                  suffixText: checkout.discountType == DiscountType.percentage
                      ? '%'
                      : null,
                  border: const OutlineInputBorder(),
                ),
              ),

              if (discountError != null) ...[
                const SizedBox(height: 8),
                _buildMessage(
                  discountError,
                  colorScheme.error,
                  Icons.error_outline,
                ),
              ],

              const SizedBox(height: 12),

              _buildSummaryRow(
                'Potongan diskon',
                '-${formatCartCurrency(discountAmount)}',
                theme,
                valueColor: colorScheme.error,
              ),

              const SizedBox(height: 12),

              Divider(color: colorScheme.outlineVariant),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total pembayaran',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    formatCartCurrency(total),
                    key: const ValueKey('checkout-total'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ---------------------------------------------------
              // UANG DITERIMA
              // ---------------------------------------------------
              Text('Uang diterima', style: theme.textTheme.titleSmall),

              const SizedBox(height: 8),

              TextField(
                key: const ValueKey('checkout-cash-field'),
                controller: _cashController,
                enabled: !checkout.isSubmitting,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) {
                  checkout.setCashReceived(int.tryParse(value) ?? 0);
                },
                decoration: const InputDecoration(
                  prefixText: 'Rp ',
                  hintText: 'Masukkan nominal pembayaran',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 10),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Uang pas'),
                    onPressed: checkout.isSubmitting
                        ? null
                        : () => _setCashAmount(total),
                  ),
                  ActionChip(
                    label: const Text('+ Rp10.000'),
                    onPressed: checkout.isSubmitting
                        ? null
                        : () => _setCashAmount(checkout.cashReceived + 10000),
                  ),
                  ActionChip(
                    label: const Text('+ Rp20.000'),
                    onPressed: checkout.isSubmitting
                        ? null
                        : () => _setCashAmount(checkout.cashReceived + 20000),
                  ),
                  ActionChip(
                    label: const Text('+ Rp50.000'),
                    onPressed: checkout.isSubmitting
                        ? null
                        : () => _setCashAmount(checkout.cashReceived + 50000),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ---------------------------------------------------
              // KEMBALIAN / KEKURANGAN
              // ---------------------------------------------------
              if (discountError == null && shortfall > 0)
                _buildMessage(
                  checkout.cashReceived == 0
                      ? 'Masukkan uang pembayaran.'
                      : 'Uang pembayaran kurang ${formatCartCurrency(shortfall)}.',
                  colorScheme.error,
                  Icons.warning_amber_outlined,
                )
              else if (discountError == null && checkout.cashReceived >= total)
                _buildMessage(
                  'Kembalian: ${formatCartCurrency(change)}',
                  colorScheme.primary,
                  Icons.check_circle_outline,
                ),

              if (checkout.errorMessage != null) ...[
                const SizedBox(height: 12),
                _buildMessage(
                  checkout.errorMessage!,
                  colorScheme.error,
                  Icons.error_outline,
                ),
              ],

              const SizedBox(height: 24),

              // ---------------------------------------------------
              // ACTIONS
              // ---------------------------------------------------
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('checkout-cancel-button'),
                      onPressed: checkout.isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Batal'),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      key: const ValueKey('checkout-submit-button'),
                      onPressed: canSubmit ? _submit : null,
                      icon: checkout.isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.payments_outlined),
                      label: Text(
                        checkout.isSubmitting
                            ? 'Memproses...'
                            : 'Proses Pembayaran',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String amount,
    ThemeData theme, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Text(
          amount,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildMessage(String message, Color color, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message, style: TextStyle(color: color)),
        ),
      ],
    );
  }
}
