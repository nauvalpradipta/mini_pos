import '../../cashier/models/checkout.dart';

class SalesSummary {
  const SalesSummary({
    required this.transactionCount,
    required this.revenue,
    required this.totalDiscount,
    required this.averageTransaction,
  });

  final int transactionCount;

  // Total penjualan setelah diskon.
  final int revenue;

  final int totalDiscount;

  final int averageTransaction;

  bool get isEmpty => transactionCount == 0;
}

class SaleTransaction {
  const SaleTransaction({
    required this.id,
    required this.receiptNumber,
    required this.cashierId,
    required this.cashierName,
    required this.storeName,
    required this.storeAddress,
    required this.storePhone,
    required this.transactionAt,
    required this.subtotal,
    required this.discountType,
    required this.discountValue,
    required this.discountAmount,
    required this.total,
    required this.cashReceived,
    required this.changeAmount,
  });

  final int id;
  final String receiptNumber;

  final int cashierId;
  final String cashierName;

  final String storeName;
  final String storeAddress;
  final String storePhone;

  final int transactionAt;

  final int subtotal;
  final DiscountType discountType;
  final int discountValue;
  final int discountAmount;

  final int total;
  final int cashReceived;
  final int changeAmount;

  factory SaleTransaction.fromMap(Map<String, Object?> map) {
    return SaleTransaction(
      id: map['id'] as int,
      receiptNumber: map['receipt_number'] as String,
      cashierId: map['cashier_id'] as int,
      cashierName: map['cashier_name_snapshot'] as String,
      storeName: map['store_name_snapshot'] as String,
      storeAddress: map['store_address_snapshot'] as String,
      storePhone: map['store_phone_snapshot'] as String,
      transactionAt: map['transaction_at'] as int,
      subtotal: map['subtotal'] as int,
      discountType: DiscountType.values.firstWhere(
        (type) => type.name == map['discount_type'],
      ),
      discountValue: map['discount_value'] as int,
      discountAmount: map['discount_amount'] as int,
      total: map['total'] as int,
      cashReceived: map['cash_received'] as int,
      changeAmount: map['change_amount'] as int,
    );
  }
}

class SaleItemAddon {
  const SaleItemAddon({
    required this.id,
    required this.addonId,
    required this.addonName,
    required this.unitPrice,
    required this.quantityPerProduct,
    required this.totalQuantity,
    required this.subtotal,
  });

  final int id;
  final int? addonId;

  final String addonName;
  final int unitPrice;

  final int quantityPerProduct;
  final int totalQuantity;
  final int subtotal;

  factory SaleItemAddon.fromMap(Map<String, Object?> map) {
    return SaleItemAddon(
      id: map['id'] as int,
      addonId: map['addon_id'] as int?,
      addonName: map['addon_name_snapshot'] as String,
      unitPrice: map['unit_price_snapshot'] as int,
      quantityPerProduct: map['quantity_per_product'] as int,
      totalQuantity: map['total_quantity'] as int,
      subtotal: map['subtotal'] as int,
    );
  }
}

class SaleItem {
  const SaleItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    required this.baseSubtotal,
    required this.addonsSubtotal,
    required this.lineTotal,
    required this.addons,
  });

  final int id;
  final int? productId;

  final String productName;
  final int unitPrice;
  final int quantity;

  final int baseSubtotal;
  final int addonsSubtotal;
  final int lineTotal;

  final List<SaleItemAddon> addons;
}

class SaleDetail {
  SaleDetail({required this.transaction, required List<SaleItem> items})
    : items = List.unmodifiable(items);

  final SaleTransaction transaction;
  final List<SaleItem> items;
}
