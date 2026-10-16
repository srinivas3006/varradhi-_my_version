/// Ad booking coverage, as the backend names it.
class AdScope {
  AdScope._();
  static const global = 'global';
  static const state = 'state';
  static const local = 'local';
  static const all = [global, state, local];

  /// Older replies used `main` for the state-wide/global package.
  static String normalize(String raw) {
    final s = raw.trim().toLowerCase();
    if (s == 'main') return global;
    return s;
  }
}

/// An advertisement format offered for booking — value sent to the API,
/// label shown to the advertiser. Both come from the backend.
class AdFormat {
  final String value;
  final String label;
  const AdFormat(this.value, this.label);
}

/// One bookable ad package as the backend prices it: a coverage scope
/// (global / state / local), the area for state and local, a duration and
/// its price. The app never invents durations — only what
/// GET /api/v1/ads/pricing/options/ returns is offered.
class AdPackage {
  final String scope; // AdScope.global | state | local
  final String? areaId;
  final String? areaName;
  final int durationDays;
  final String price;
  final String currency;

  const AdPackage({
    required this.scope,
    required this.durationDays,
    required this.price,
    required this.currency,
    this.areaId,
    this.areaName,
  });

  bool get needsArea => scope != AdScope.global;

  /// "₹1500" for INR, "USD 20" otherwise; trailing ".00" dropped.
  String get priceLabel => formatPrice(price, currency);

  static String formatPrice(String price, String currency) {
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
      o.scope == scope &&
      o.areaId == areaId &&
      o.durationDays == durationDays;
}

/// Everything the booking form offers, from
/// GET /api/v1/ads/pricing/options/ — coverage scopes with their areas,
/// durations and prices, and the ad formats.
class AdPricingCatalog {
  final List<AdPackage> global;

  /// State-level packages per area id, in the backend's order.
  final Map<String, List<AdPackage>> stateByArea;

  /// Local (district / city / subdistrict / village) packages per area id.
  final Map<String, List<AdPackage>> localByArea;

  /// Area id → display name.
  final Map<String, String> areaNames;

  final List<AdFormat> formats;

  const AdPricingCatalog({
    required this.global,
    required this.stateByArea,
    required this.localByArea,
    required this.areaNames,
    this.formats = const [],
  });

  bool get isEmpty =>
      global.isEmpty && stateByArea.isEmpty && localByArea.isEmpty;

  /// Areas (with their packages) for a state or local scope.
  Map<String, List<AdPackage>> areasFor(String scope) => switch (scope) {
        AdScope.state => stateByArea,
        AdScope.local => localByArea,
        _ => const {},
      };

  /// Whether [scope] has anything to book.
  bool offers(String scope) =>
      scope == AdScope.global ? global.isNotEmpty : areasFor(scope).isNotEmpty;

  /// Reads the options reply. Current shape:
  /// ```json
  /// {"coverage_options": {
  ///    "global": [{"duration_days": 7, "price": "5000.00", "currency": "INR"}],
  ///    "state":  [{"area": {"id": "…", "name": "Andhra Pradesh"},
  ///                "options": [{"duration_days": 7, "price": "2500.00"}]}],
  ///    "local":  [{"area": {...}, "options": [...]}]},
  ///  "ad_formats": [{"value": "banner", "label": "Banner"}]}
  /// ```
  /// The older `{"main": [...], "local": [...]}` and flat-row shapes are
  /// still read. Rows without a positive duration or a price are skipped;
  /// duplicates are kept once; durations are sorted.
  static AdPricingCatalog parse(dynamic data,
      {List<dynamic> areas = const []}) {
    final global = <AdPackage>[];
    final byScope = <String, Map<String, List<AdPackage>>>{
      AdScope.state: {},
      AdScope.local: {},
    };
    final names = <String, String>{};
    final formats = <AdFormat>[];

    for (final a in areas) {
      if (a is Map && a['id'] != null) {
        names['${a['id']}'] = (a['name'] ?? '').toString();
      }
    }

    AdPackage? row(Map<dynamic, dynamic> m, String scope,
        {String? areaId, String? areaName}) {
      final days = int.tryParse('${m['duration_days'] ?? ''}');
      final price = m['price'] ?? m['amount'];
      if (days == null || days <= 0 || price == null) return null;
      return AdPackage(
        scope: scope,
        areaId: areaId,
        areaName: areaName,
        durationDays: days,
        price: '$price',
        currency: (m['currency'] ?? 'INR').toString(),
      );
    }

    void add(AdPackage p) {
      if (p.scope == AdScope.global) {
        if (!global.any(p.sameAs)) global.add(p);
        return;
      }
      final map = byScope[p.scope];
      if (map == null || p.areaId == null) return;
      final list = map.putIfAbsent(p.areaId!, () => []);
      if (!list.any(p.sameAs)) list.add(p);
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

    void readGrouped(String scope, dynamic groups) {
      for (final g in (groups is List ? groups : const [])) {
        if (g is! Map) continue;
        final a = areaOf(g);
        if (a.id == null || a.id!.isEmpty) continue;
        if (a.name != null && a.name!.isNotEmpty) names[a.id!] = a.name!;
        final opts = g['options'] ?? g['prices'] ?? g['packages'];
        for (final o in (opts is List ? opts : const [])) {
          if (o is Map) {
            final p = row(o, scope, areaId: a.id, areaName: names[a.id]);
            if (p != null) add(p);
          }
        }
      }
    }

    void readGlobal(dynamic rows) {
      for (final r in (rows is List ? rows : const [])) {
        if (r is Map) {
          final p = row(r, AdScope.global);
          if (p != null) add(p);
        }
      }
    }

    if (data is Map) {
      final coverage = data['coverage_options'] is Map
          ? data['coverage_options'] as Map
          : data;
      readGlobal(coverage['global'] ?? coverage['main']);
      readGrouped(AdScope.state, coverage['state']);
      readGrouped(AdScope.local, coverage['local']);

      final fmts = data['ad_formats'];
      for (final f in (fmts is List ? fmts : const [])) {
        if (f is Map && f['value'] != null) {
          final v = f['value'].toString();
          if (v.isEmpty || formats.any((x) => x.value == v)) continue;
          formats.add(AdFormat(v, (f['label'] ?? v).toString()));
        }
      }
    } else if (data is List) {
      for (final r in data) {
        if (r is! Map) continue;
        final scope =
            AdScope.normalize((r['scope'] ?? r['ad_type'] ?? '').toString());
        if (scope == AdScope.global) {
          final p = row(r, scope);
          if (p != null) add(p);
        } else if (byScope.containsKey(scope)) {
          final a = areaOf(r);
          if (a.id == null || a.id!.isEmpty) continue;
          if (a.name != null && a.name!.isNotEmpty) names[a.id!] = a.name!;
          final p = row(r, scope, areaId: a.id, areaName: names[a.id]);
          if (p != null) add(p);
        }
      }
    }

    int byDays(AdPackage a, AdPackage b) =>
        a.durationDays.compareTo(b.durationDays);
    global.sort(byDays);
    Map<String, List<AdPackage>> ordered(Map<String, List<AdPackage>> m) {
      for (final l in m.values) {
        l.sort(byDays);
      }
      // Keep the backend's area order (from /ads/areas/) where known.
      final order = names.keys.toList();
      return {
        for (final id in order)
          if (m[id] != null) id: m[id]!,
        for (final e in m.entries)
          if (!order.contains(e.key)) e.key: e.value,
      };
    }

    return AdPricingCatalog(
      global: global,
      stateByArea: ordered(byScope[AdScope.state]!),
      localByArea: ordered(byScope[AdScope.local]!),
      areaNames: names,
      formats: formats,
    );
  }
}

/// A failed booking request, read from the backend's error envelope.
class AdBookingError {
  /// Field → message, shown under that input (`advertiser_name`, `phone`,
  /// `area_id`, `duration_days`, `ad_format`, `scope`, …).
  final Map<String, String> fields;

  /// The message for the error box.
  final String message;

  /// 404: the area / pricing went away — reload the options.
  final bool refreshOptions;

  /// Offline / timeout: offer Retry.
  final bool retryable;

  const AdBookingError({
    required this.message,
    this.fields = const {},
    this.refreshOptions = false,
    this.retryable = false,
  });

  /// [status] null means no response (offline / timeout).
  static AdBookingError from(int? status, dynamic body) {
    final fields = <String, String>{};
    String? backendMessage;
    if (body is Map) {
      final errors = body['errors'];
      final details = errors is Map ? errors['details'] : null;
      // Field errors: inside the envelope, or the body itself
      // ({"area_id": ["…"]}).
      final source = details is Map ? details : (errors is Map ? null : body);
      if (source is Map) {
        source.forEach((k, v) {
          if (k == 'data' || k == 'meta' || k == 'errors') return;
          final msgs = v is List ? v.map((e) => '$e') : [if (v != null) '$v'];
          final text = msgs.where((m) => m.trim().isNotEmpty).join(' ');
          if (text.isNotEmpty) fields['$k'] = text;
        });
      }
      if (details is String && details.trim().isNotEmpty) {
        backendMessage = details;
      }
      final m = errors is Map ? errors['message']?.toString() : null;
      if (backendMessage == null &&
          m != null &&
          m.isNotEmpty &&
          m != 'An error occurred.') {
        backendMessage = m;
      }
    }

    if (status == null) {
      return const AdBookingError(
        message:
            'ఇంటర్నెట్ కనెక్షన్ లేదు. మీ వివరాలు అలాగే ఉన్నాయి — మళ్లీ ప్రయత్నించండి.',
        retryable: true,
      );
    }
    switch (status) {
      case 400:
        return AdBookingError(
          fields: fields,
          message: fields.isNotEmpty
              ? fields.values.join('\n')
              : (backendMessage ?? 'వివరాలు సరిచూసి మళ్లీ ప్రయత్నించండి.'),
        );
      case 401:
        return AdBookingError(
          message: backendMessage ?? 'బుకింగ్ కోసం దయచేసి లాగిన్ అవ్వండి.',
        );
      case 404:
        return AdBookingError(
          message: backendMessage ??
              'ఎంచుకున్న ప్రాంతం లేదా ధర ఇప్పుడు అందుబాటులో లేదు. ఎంపికలు మళ్లీ లోడ్ చేశాం — దయచేసి మళ్లీ ఎంచుకోండి.',
          refreshOptions: true,
        );
      case 429:
        return const AdBookingError(
          message:
              'చాలా ఎక్కువ అభ్యర్థనలు. కొద్దిసేపు ఆగి మళ్లీ ప్రయత్నించండి.',
        );
    }
    if (status >= 500) {
      return const AdBookingError(
        message:
            'బుకింగ్ సమర్పించలేకపోయాం. మీ వివరాలు అలాగే ఉన్నాయి — మళ్లీ ప్రయత్నించండి.',
        retryable: true,
      );
    }
    return AdBookingError(
      fields: fields,
      message:
          backendMessage ?? 'బుకింగ్ సమర్పించలేకపోయాం. మళ్లీ ప్రయత్నించండి.',
    );
  }
}
