/// Represents a product category.
class Category {
  final int? id;
  final String name;
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Category({
    this.id,
    required this.name,
    this.description,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Converts a Category object into a SQLite-compatible map.
  Map<String, Object?> toMap() {
    return {
      'name': name,
      'description': description,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// Creates a Category object from a SQLite record.
  factory Category.fromMap(Map<String, Object?> map) {
    return Category(
      id: map['id'] as int,
      name: map['name'] as String,
      description: map['description'] as String?,
      isActive: map['is_active'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
}
