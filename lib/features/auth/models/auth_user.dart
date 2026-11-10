class AuthUser {
  const AuthUser({
    required this.id,
    required this.fullName,
    required this.username,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String fullName;
  final String username;
  final bool isActive;
  final int createdAt;
  final int updatedAt;

  factory AuthUser.fromMap(Map<String, Object?> map) {
    return AuthUser(
      id: map['id'] as int,
      fullName: map['full_name'] as String,
      username: map['username'] as String,
      isActive: map['is_active'] == 1,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
    );
  }
}
