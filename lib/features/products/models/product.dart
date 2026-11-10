class Product {
  const Product({
    this.id,
    required this.categoryId,
    required this.name,
    required this.sellingPrice,
    required this.stock,
    this.imagePath,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final int categoryId;
  final String name;
  final int sellingPrice;
  final int stock;
  final String? imagePath;
  final bool isActive;
  final int createdAt;
  final int updatedAt;

  Map<String, Object?> toMap() {
    final map = <String, Object?>{
      'category_id': categoryId,
      'name': name,
      'selling_price': sellingPrice,
      'stock_quantity': stock,
      'image_path': imagePath,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };

    if (id != null) {
      map['id'] = id;
    }

    return map;
  }

  factory Product.fromMap(Map<String, Object?> map) {
    return Product(
      id: map['id'] as int,
      categoryId: map['category_id'] as int,
      name: map['name'] as String,
      sellingPrice: map['selling_price'] as int,
      stock: map['stock_quantity'] as int,
      imagePath: map['image_path'] as String?,
      isActive: map['is_active'] == 1,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
    );
  }
}
