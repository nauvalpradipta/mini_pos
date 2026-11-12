class StoreSettings {
  const StoreSettings({
    required this.id,
    required this.storeName,
    required this.address,
    required this.phone,
    required this.receiptFooter,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String storeName;
  final String address;
  final String phone;
  final String receiptFooter;

  final int createdAt;
  final int updatedAt;

  factory StoreSettings.fromMap(Map<String, Object?> map) {
    return StoreSettings(
      id: map['id'] as int,
      storeName: map['store_name'] as String,
      address: map['address'] as String,
      phone: map['phone'] as String,
      receiptFooter: map['receipt_footer'] as String,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
    );
  }
}
