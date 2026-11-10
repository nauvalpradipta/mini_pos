import 'cart_item.dart';

enum DiscountType { none, percentage, fixed }

class CheckoutRequest {
  CheckoutRequest({
    required this.cashierId,
    required List<CartItem> cartItems,
    this.discountType = DiscountType.none,
    this.discountValue = 0,
    required this.cashReceived,
  }) : cartItems = List.unmodifiable(cartItems);

  final int cashierId;
  final List<CartItem> cartItems;
  final DiscountType discountType;
  final int discountValue;
  final int cashReceived;
}

class CheckoutResult {
  const CheckoutResult({
    required this.saleId,
    required this.receiptNumber,
    required this.transactionAt,
    required this.subtotal,
    required this.discountType,
    required this.discountValue,
    required this.discountAmount,
    required this.total,
    required this.cashReceived,
    required this.changeAmount,
  });

  final int saleId;
  final String receiptNumber;
  final int transactionAt;

  final int subtotal;
  final DiscountType discountType;
  final int discountValue;
  final int discountAmount;

  final int total;
  final int cashReceived;
  final int changeAmount;
}

class CheckoutException implements Exception {
  const CheckoutException(this.message);

  final String message;

  @override
  String toString() => 'CheckoutException: $message';
}
