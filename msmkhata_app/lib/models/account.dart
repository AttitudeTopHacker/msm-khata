/// Model representing an isolated Book / Account in MsmKhata
class AccountBook {
  final String id;
  final String name;
  final bool isDefault;
  final String color;
  final String createdAt;

  AccountBook({
    required this.id,
    required this.name,
    this.isDefault = false,
    this.color = '#4F46E5',
    required this.createdAt,
  });

  factory AccountBook.fromJson(Map<String, dynamic> json) {
    return AccountBook(
      id: json['id'] ?? 'main',
      name: json['name'] ?? 'Main Account (Book 1)',
      isDefault: json['is_default'] ?? false,
      color: json['color'] ?? '#4F46E5',
      createdAt: json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'is_default': isDefault,
      'color': color,
      'created_at': createdAt,
    };
  }
}
