/// One bookable ad package as the backend prices it: an ad type (`main` /
/// `local`), the area for local ads, a duration and its price. The app never
/// invents durations — only what GET /api/v1/ads/pricing/options/ returns is
/// offered.
class AdPackage {
  final String adType; // 'main' | 'local'
  final String? areaId;
  final String? areaName;
  final int durationDays;
  final String price;
  final String currency;

  const AdPackage({
    required this.adType,
    required this.durationDays,
    required this.price,
    required this.currency,
    this.areaId,
    this.areaName,
  });

  /// "₹1500" for INR, "USD 20" otherwise; trailing ".00" dropped.
  String get priceLabel {
    var p = price.trim();
    if (p.endsWith('.00')) p = p.substring(0, p.length - 3);
    return currency.toUpperCase() == 'INR' ? '₹$p' : '$currency $p';
  }

  /// "7 రోజులు" with a friendly sub-label derived from the number itself
  /// ("1 వారం", "1 నెల") — formatting only, nothing assumed about which
  /// durations exist.
  String get durationLabel => '$durationDays రోజులు';

  String? get durationHint {
    if (durationDays >= 30 && durationDays % 30 == 0) {
      final m = durationDays ~/ 30;
      return m == 1 ? '1 నెల' : '$m నెలలు';
    }
    if (durationDays >= 7 && durationDays % 7 == 0) {
      final w = durationDays ~/ 7;
      return w == 1 ? '1 వారం' : '$w వారాలు';
    }
    return null;
  }

  bool sameAs(AdPackage? o) =>
      o != null &&
      o.adType == adType &&
      o.areaId == areaId &&
      o.durationDays == durationDays;
}

/// Every package the backend offers, grouped for the booking screen.
class AdPricingCatalog {
  final List<AdPackage> main;

  /// Local packages per area id, in the backend's area order.
  final Map<String, List<AdPackage>> localByArea;

  /// Area id → display name (from the options reply or /ads/areas/).
  final Map<String, String> areaNames;

  const AdPricingCatalog({
    required this.main,
    required this.localByArea,
    required this.areaNames,
  });

  bool get isEmpty => main.isEmpty && localByArea.isEmpty;

  /// Reads the options reply. Accepted shapes:
  ///
  /// A) grouped
  /// ```json
  /// {"main": [{"duration_days": 7, "price": "5000.00", "currency": "INR"}],
  ///  "local": [{"area": {"id": "…", "name": "Vikarabad"},
  ///             "options": [{"duration_days": 7, "price": "1500.00",
  ///                          "currency": "INR"}]}]}
  /// ```
  /// B) flat rows
  /// ```json
  /// [{"ad_type": "local", "area": {"id": "…", "name": "…"},
  ///   "duration_days": 7, "price": "1500.00", "currency": "INR"}]
  /// ```
  /// Rows without a positive duration or a price are skipped; duplicates
  /// (same type/area/duration) are kept once; durations are sorted.
  static AdPricingCatalog parse(dynamic data,
      {List<dynamic> areas = const []}) {
    final main = <AdPackage>[];
    final local = <String, List<AdPackage>>{};
    final names = <String, String>{};

    for (final a in areas) {
      if (a is Map && a['id'] != null) {
        names['${a['id']}'] = (a['name'] ?? '').toString();
      }
    }

    AdPackage? row(Map<dynamic, dynamic> m, String type,
        {String? areaId, String? areaName}) {
      final days = int.tryParse('${m['duration_days'] ?? ''}');
      final price = m['price'] ?? m['amount'];
      if (days == null || days <= 0 || price == null) return null;
      return AdPackage(
        adType: type,
        areaId: areaId,
        areaName: areaName,
        durationDays: days,
        price: '$price',
        currency: (m['currency'] ?? 'INR').toString(),
      );
    }

    void addLocal(AdPackage p) {
      final list = local.putIfAbsent(p.areaId!, () => []);
      if (!list.any(p.sameAs)) list.add(p);
    }

    void addMain(AdPackage p) {
      if (!main.any(p.sameAs)) main.add(p);
    }

    ({String? id, String? name}) areaOf(Map<dynamic, dynamic> m) {
      final area = m['area'];
      if (area is Map) {
        return (id: area['id']?.toString(), name: area['name']?.toString());
      }
      return (
        id: (m['area_id'] ?? area)?.toString(),
        name: m['area_name']?.toString()
      );
    }

    if (data is Map) {
      for (final r in (data['main'] is List ? data['main'] as List : const [])) {
        if (r is Map) {
          final p = row(r, 'main');
          if (p != null) addMain(p);
        }
      }
      for (final g
          in (data['local'] is List ? data['local'] as List : const [])) {
        if (g is! Map) continue;
        final a = areaOf(g);
        if (a.id == null || a.id!.isEmpty) continue;
        if (a.name != null && a.name!.isNotEmpty) names[a.id!] = a.name!;
        final opts = g['options'] ?? g['prices'] ?? g['packages'];
        for (final o in (opts is List ? opts : const [])) {
          if (o is Map) {
            final p = row(o, 'local', areaId: a.id, areaName: names[a.id]);
            if (p != null) addLocal(p);
          }
        }
      }
    } else if (data is List) {
      for (final r in data) {
        if (r is! Map) continue;
        final type = (r['ad_type'] ?? '').toString().toLowerCase();
        if (type == 'main') {
          final p = row(r, 'main');
          if (p != null) addMain(p);
        } else if (type == 'local') {
          final a = areaOf(r);
          if (a.id == null || a.id!.isEmpty) continue;
          if (a.name != null && a.name!.isNotEmpty) names[a.id!] = a.name!;
          final p = row(r, 'local', areaId: a.id, areaName: names[a.id]);
          if (p != null) addLocal(p);
        }
      }
    }

    main.sort((a, b) => a.durationDays.compareTo(b.durationDays));
    for (final l in local.values) {
      l.sort((a, b) => a.durationDays.compareTo(b.durationDays));
    }
    // Keep the backend's area order (from /ads/areas/) where known.
    final order = names.keys.toList();
    final ordered = <String, List<AdPackage>>{
      for (final id in order)
        if (local[id] != null) id: local[id]!,
      for (final e in local.entries)
        if (!order.contains(e.key)) e.key: e.value,
    };
    return AdPricingCatalog(
        main: main, localByArea: ordered, areaNames: names);
  }
}
