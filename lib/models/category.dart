int _toInt(dynamic val, [int fallback = 0]) {
  if (val == null) return fallback;
  if (val is int) return val;
  if (val is num) return val.toInt();
  return int.tryParse(val.toString().trim()) ?? fallback;
}

bool _toBool(dynamic val, [bool fallback = true]) {
  if (val == null) return fallback;
  if (val is bool) return val;
  final str = val.toString().trim().toLowerCase();
  if (str == 'true' || str == '1') return true;
  if (str == 'false' || str == '0') return false;
  return fallback;
}

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
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '',
      order: _toInt(json['order'], 0),
      isActive: _toBool(json['is_active'], true),
    );
  }
}
