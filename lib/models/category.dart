import '../localization/app_translations.dart';

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
  final String? displayName;
  final String? nameTe;
  final String slug;
  final String icon;
  final int order;
  final bool isActive;

  Category({
    required this.id,
    required this.name,
    this.displayName,
    this.nameTe,
    required this.slug,
    required this.icon,
    required this.order,
    required this.isActive,
  });

  /// The localized display label, preferring backend Telugu fields.
  String get localizedName {
    final te = nameTe?.trim();
    if (te != null && te.isNotEmpty) return te;

    final disp = displayName?.trim();
    if (disp != null && disp.isNotEmpty && _hasTelugu(disp)) {
      return disp;
    }

    if (_hasTelugu(name)) return name;

    return categoryLabel(name.isNotEmpty ? name : slug);
  }

  static bool _hasTelugu(String text) {
    for (final rune in text.runes) {
      if (rune >= 0x0C00 && rune <= 0x0C7F) return true;
    }
    return false;
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    String? nameTe = json['name_te']?.toString().trim();
    if (nameTe == null || nameTe.isEmpty) {
      nameTe = json['name_telugu']?.toString().trim();
    }
    if (nameTe == null || nameTe.isEmpty) {
      nameTe = json['telugu_name']?.toString().trim();
    }

    if (nameTe == null || nameTe.isEmpty) {
      if (json['translations'] is Map) {
        final trans = json['translations'] as Map;
        final te = trans['te'] ?? trans['telugu'];
        if (te is Map) {
          nameTe = (te['name'] ?? te['title'] ?? te['display_name'])?.toString().trim();
        } else if (te is String && te.trim().isNotEmpty) {
          nameTe = te.trim();
        }
      }
    }

    final rawName = (json['name'] ?? json['display_name'] ?? json['title'])?.toString() ?? '';
    final displayName = json['display_name']?.toString();

    return Category(
      id: json['id']?.toString() ?? '',
      name: rawName,
      displayName: displayName,
      nameTe: nameTe,
      slug: json['slug']?.toString() ?? '',
      icon: (json['icon'] ?? json['icon_url'])?.toString() ?? '',
      order: _toInt(json['order'] ?? json['sort_order'], 0),
      isActive: _toBool(json['is_active'], true),
    );
  }
}
