class Category {
  final int id;
  final String name;
  final DateTime createdAt;

  const Category({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      createdAt: json['created_at'] != null 
        ? DateTime.parse(json['created_at']) 
        : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Create an "All" category for filtering
  factory Category.all() {
    return Category(
      id: 0,
      name: 'All',
      createdAt: DateTime.now(),
    );
  }
} 