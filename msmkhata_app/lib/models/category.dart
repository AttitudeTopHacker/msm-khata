class Category {
  final String id;
  final String name;
  final String type; // EXPENSE, INCOME, BOTH
  final String color;

  Category({
    required this.id,
    required this.name,
    this.type = 'BOTH',
    this.color = '#4F46E5',
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 'BOTH',
      color: json['color'] ?? '#4F46E5',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'color': color,
  };
}
