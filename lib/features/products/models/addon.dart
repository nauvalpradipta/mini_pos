class Addon {
  const Addon({
    this.id,
    required this.name,
    required this.additionalPrice,
    required this.stock,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String name;
  final int additionalPrice;
  final int stock;
  final bool isActive;
  final int createdAt;
  final int updatedAt;

  Map<String, Object?> toMap() {
    final map = <String, Object?>{
      'name': name,
      'additional_price': additionalPrice,
      'stock_quantity': stock,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };

    if (id != null) {
      map['id'] = id;
    }

    return map;
  }

  factory Addon.fromMap(Map<String, Object?> map) {
    return Addon(
      id: map['id'] as int,
      name: map['name'] as String,
      additionalPrice: map['additional_price'] as int,
      stock: map['stock_quantity'] as int,
      isActive: map['is_active'] == 1,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
    );
  }
}
