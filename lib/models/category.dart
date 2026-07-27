class Category {
  final String id;
  final String name;
  final String slug;
  final String icon;
  final int order;
  final bool isActive;

  Category({
    required this.id,
    required this.name,
    required this.slug,
    required this.icon,
    required this.order,
    required this.isActive,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      icon: json['icon'] ?? '',
      order: json['order'] ?? 0,
      isActive: json['is_active'] ?? true,
    );
  }
}
