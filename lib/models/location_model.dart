// location_model.dart

class LocationNode {
  final String id;
  final String nameEn;
  final String nameTe;
  final String slug;
  final String code;
  final String pincode;
  final String parentId;
  final int sortOrder;

  const LocationNode({
    required this.id,
    required this.nameEn,
    this.nameTe = '',
    this.slug = '',
    this.code = '',
    this.pincode = '',
    this.parentId = '',
    this.sortOrder = 0,
  });

  factory LocationNode.fromJson(Map<String, dynamic> json) {
    return LocationNode(
      id: (json['id'] ?? '').toString(),
      nameEn: (json['name_en'] ?? json['name'] ?? '').toString(),
      nameTe: (json['name_te'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      pincode: (json['pincode'] ?? '').toString(),
      parentId: (json['state'] ?? json['district'] ?? json['subdistrict'] ?? '').toString(),
      sortOrder: int.tryParse(json['sort_order']?.toString() ?? '0') ?? 0,
    );
  }

  String label(String contentLanguage) =>
      contentLanguage == 'te' && nameTe.isNotEmpty ? nameTe : nameEn;
}

/// Level of a location search hit.
enum LocationLevel {
  state,
  district,
  subdistrict,
  village,
  unknown;

  static LocationLevel parse(String raw) {
    switch (raw.toLowerCase()) {
      case 'state':
        return LocationLevel.state;
      case 'district':
        return LocationLevel.district;
      case 'subdistrict':
      case 'mandal':
        return LocationLevel.subdistrict;
      case 'village':
        return LocationLevel.village;
      default:
        return LocationLevel.unknown;
    }
  }

  String get label {
    switch (this) {
      case LocationLevel.state:
        return 'State';
      case LocationLevel.district:
        return 'District';
      case LocationLevel.subdistrict:
        return 'Mandal';
      case LocationLevel.village:
        return 'Village';
      case LocationLevel.unknown:
        return 'Location';
    }
  }
}

/// `GET /api/v1/locations/search/` result item (section 8).
class LocationSearchResult {
  final LocationLevel type;
  final String id;
  final String nameEn;
  final String nameTe;
  final String slug;
  final String state;
  final String district;
  final String subdistrict;
  final String pincode;

  const LocationSearchResult({
    required this.type,
    required this.id,
    required this.nameEn,
    this.nameTe = '',
    this.slug = '',
    this.state = '',
    this.district = '',
    this.subdistrict = '',
    this.pincode = '',
  });

  factory LocationSearchResult.fromJson(Map<String, dynamic> json) {
    return LocationSearchResult(
      type: LocationLevel.parse((json['type'] ?? '').toString()),
      id: (json['id'] ?? '').toString(),
      nameEn: (json['name_en'] ?? json['name'] ?? '').toString(),
      nameTe: (json['name_te'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      state: (json['state'] ?? '').toString(),
      district: (json['district'] ?? '').toString(),
      subdistrict: (json['subdistrict'] ?? '').toString(),
      pincode: (json['pincode'] ?? '').toString(),
    );
  }

  /// "Khairatabad, Hyderabad, Telangana"
  String get breadcrumb {
    final parts = <String>[];
    if (subdistrict.isNotEmpty && subdistrict != nameEn) parts.add(subdistrict);
    if (district.isNotEmpty && district != nameEn) parts.add(district);
    if (state.isNotEmpty && state != nameEn) parts.add(state);
    return parts.join(', ');
  }

  /// Body for PATCH `/auth/locations/{profile|guest}/`.
  /// Round-trips a saved place through local storage.
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'id': id,
        'name_en': nameEn,
        'name_te': nameTe,
        'slug': slug,
        'state': state,
        'district': district,
        'subdistrict': subdistrict,
        'pincode': pincode,
      };

  Map<String, dynamic> toPatchBody() {
    switch (type) {
      case LocationLevel.state:
        return {'state_id': id};
      case LocationLevel.district:
        return {'district_id': id};
      case LocationLevel.subdistrict:
        return {'subdistrict_id': id};
      case LocationLevel.village:
        return {'village_id': id};
      case LocationLevel.unknown:
        return {'district_id': id};
    }
  }
}

/// Canonical location profile (`/auth/locations/profile/` or `/guest/`).
class LocationProfile {
  final String locationType;
  final String locationId;
  final LocationNode? state;
  final LocationNode? district;
  final LocationNode? subdistrict;
  final LocationNode? village;
  final String legacyState;
  final String legacyDistrict;
  final String legacySubdistrict;
  final String legacyVillage;
  final DateTime? updatedAt;

  const LocationProfile({
    this.locationType = '',
    this.locationId = '',
    this.state,
    this.district,
    this.subdistrict,
    this.village,
    this.legacyState = '',
    this.legacyDistrict = '',
    this.legacySubdistrict = '',
    this.legacyVillage = '',
    this.updatedAt,
  });

  factory LocationProfile.fromJson(Map<String, dynamic> json) {
    LocationNode? node(String key) {
      if (json[key] is! Map) return null;
      final map = Map<String, dynamic>.from(json[key]);
      return map.isEmpty ? null : LocationNode.fromJson(map);
    }

    final legacy = json['legacy'] is Map ? Map<String, dynamic>.from(json['legacy']) : <String, dynamic>{};
    return LocationProfile(
      locationType: (json['location_type'] ?? '').toString(),
      locationId: (json['location_id'] ?? '').toString(),
      state: node('state'),
      district: node('district'),
      subdistrict: node('subdistrict'),
      village: node('village'),
      legacyState: (legacy['state'] ?? '').toString(),
      legacyDistrict: (legacy['district'] ?? '').toString(),
      legacySubdistrict: (legacy['subdistrict'] ?? '').toString(),
      legacyVillage: (legacy['village'] ?? '').toString(),
      updatedAt: json['location_updated_at'] != null ? DateTime.tryParse(json['location_updated_at'].toString()) : null,
    );
  }

  bool get isEmpty =>
      locationId.isEmpty &&
      legacyDistrict.isEmpty &&
      legacyState.isEmpty &&
      district == null &&
      state == null;

  String get stateName =>
      state?.nameEn.isNotEmpty == true ? state!.nameEn : legacyState;
  String get districtName =>
      district?.nameEn.isNotEmpty == true ? district!.nameEn : legacyDistrict;
  String get subdistrictName => subdistrict?.nameEn.isNotEmpty == true
      ? subdistrict!.nameEn
      : legacySubdistrict;
  String get villageName =>
      village?.nameEn.isNotEmpty == true ? village!.nameEn : legacyVillage;

  /// Chip label in the home header — most specific name available.
  /// This profile as a saved place, so the reader can pin wherever they are
  /// without another lookup.
  LocationSearchResult asSearchResult() => LocationSearchResult(
        type: LocationLevel.parse(locationType),
        id: locationId,
        nameEn: displayName,
        state: stateName,
        district: districtName,
        subdistrict: subdistrictName,
      );

  String get displayName {
    for (final value in [
      villageName,
      subdistrictName,
      districtName,
      stateName
    ]) {
      if (value.isNotEmpty) return value;
    }
    return 'All India';
  }

  /// The town the reader reads for: the finest urban unit they picked.
  ///
  /// The feed's `city` filter is not a synonym for `district` — it matches
  /// articles tagged at village/town level, which a district filter alone
  /// never returns. Omitting it silently hid local stories.
  String get cityName {
    for (final value in [villageName, subdistrictName, districtName]) {
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  /// Location filters sent to feed / video / UGC / ads endpoints.
  Map<String, dynamic> get feedQuery => {
        if (stateName.isNotEmpty) 'state': stateName,
        if (districtName.isNotEmpty) 'district': districtName,
        if (cityName.isNotEmpty) 'city': cityName,
        if (subdistrictName.isNotEmpty) 'subdistrict': subdistrictName,
        if (villageName.isNotEmpty) 'village': villageName,
      };

  Map<String, dynamic> toJson() => {
        'location_type': locationType,
        'location_id': locationId,
        'legacy': {
          'state': stateName,
          'district': districtName,
          'subdistrict': subdistrictName,
          'village': villageName,
        },
        'location_updated_at': updatedAt?.toIso8601String(),
      };
}
