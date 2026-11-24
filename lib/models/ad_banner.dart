import '../core/utils/url_normalizer.dart';

class AdExposure {
  const AdExposure({
    required this.id,
    required this.expiresAt,
    required this.deviceId,
    this.variantId,
    this.videoDurationMs,
    this.targetingKey,
  });

  final String id;
  final DateTime? expiresAt;
  final String deviceId;
  final String? variantId;
  final int? videoDurationMs;
  final String? targetingKey;

  bool isValidAt(DateTime time) =>
      id.isNotEmpty && expiresAt?.isAfter(time) == true;
}

int _toInt(dynamic val, [int fallback = 0]) {
  if (val == null) return fallback;
  if (val is int) return val;
  if (val is num) return val.toInt();
  return int.tryParse(val.toString().trim()) ?? fallback;
}

double _toDouble(dynamic val, [double fallback = 0.0]) {
  if (val == null) return fallback;
  if (val is double) return val;
  if (val is num) return val.toDouble();
  return double.tryParse(val.toString().trim()) ?? fallback;
}

class AdBanner {
  final String id;
  final String title;
  final String imageUrl;
  final String videoUrl;
  final String destinationUrl;
  final String adType;
  final String placementZone;
  final String targetScope;
  final String? area;
  final String? areaId;
  final int displayFrequency;
  final int durationSeconds;
  final int dailyMaxImpressionsPerUser;
  final double ctr;

  /// 3D ads: which 3D format to play (cube, prism, pillar, corner
  /// billboard, showcase) when the backend names one; empty = take turns.
  final String displayStyle;
  final AdExposure? exposure;
  final DateTime? startsAt;
  final DateTime? endsAt;

  AdBanner({
    required this.id,
    this.title = 'Sponsored Promotion',
    required this.imageUrl,
    this.videoUrl = '',
    required this.destinationUrl,
    required this.adType,
    required this.placementZone,
    required this.targetScope,
    this.area,
    this.areaId,
    required this.displayFrequency,
    this.durationSeconds = 0,
    this.dailyMaxImpressionsPerUser = 0,
    required this.ctr,
    this.displayStyle = '',
    this.exposure,
    this.startsAt,
    this.endsAt,
  });

  bool get canDisplay {
    final now = DateTime.now();
    return (startsAt?.isAfter(now) != true) &&
        (endsAt == null || endsAt!.isAfter(now)) &&
        (exposure?.isValidAt(now) ?? true);
  }

  int get displayDurationSeconds => durationSeconds;

  bool get isVideo =>
      adType.toLowerCase() == 'video' || videoUrl.trim().isNotEmpty;

  bool get isBanner => adType.toLowerCase() == 'banner';
  bool get isBox => adType.toLowerCase() == 'box';
  bool get isThreeD =>
      adType.toLowerCase() == 'three_d' || adType.toLowerCase() == '3d';
  bool get isInterstitial => adType.toLowerCase() == 'interstitial';
  bool get isNative => adType.toLowerCase() == 'native';
  bool get isPoster => adType.toLowerCase() == 'poster';
  bool get isSponsoredCard => adType.toLowerCase() == 'sponsored_card';
  bool get isBreakingStrip => adType.toLowerCase() == 'breaking_strip';
  bool get isLocalListing => adType.toLowerCase() == 'local_listing';
  bool get isFullScreen => adType.toLowerCase() == 'full_screen';
  bool get isBottomSticky => adType.toLowerCase() == 'bottom_sticky';

  factory AdBanner.fromJson(Map<String, dynamic> json,
      {String deviceId = '', String? targetingKey}) {
    final tracking = json['tracking'];
    final isV2 = tracking is Map && _toInt(tracking['tracking_version']) == 2;
    final creative = tracking is Map ? tracking['creative'] : null;
    final rawImg = (json['image_url'] ??
            (isV2 ? null : json['thumbnail_url'] ?? json['banner_url']))
        ?.toString();
    final rawVideo =
        (json['video_url'] ?? (isV2 ? null : json['video']))?.toString();
    final rawDest = (json['destination_url'] ??
            (isV2 ? null : json['target_url'] ?? json['click_url']))
        ?.toString();

    return AdBanner(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ??
          json['headline']?.toString() ??
          'Sponsored Promotion',
      imageUrl: UrlNormalizer.normalize(rawImg),
      videoUrl: UrlNormalizer.normalize(rawVideo),
      destinationUrl: rawDest?.trim() ?? '',
      adType: json['ad_type']?.toString() ?? 'banner',
      placementZone: json['placement_zone']?.toString() ?? 'feed',
      targetScope: json['target_scope']?.toString() ?? 'global',
      area: json['area']?.toString(),
      areaId: json['area_id']?.toString(),
      displayFrequency: _toInt(json['display_frequency'], 5),
      durationSeconds: _toInt(
        json['display_duration_seconds'] ??
            json['duration_seconds'] ??
            json['display_seconds'] ??
            json['duration'],
        0,
      ).clamp(0, 2147483647),
      dailyMaxImpressionsPerUser:
          _toInt(json['daily_max_impressions_per_user'], 0),
      ctr: _toDouble(json['ctr'], 0.0),
      startsAt: DateTime.tryParse(json['start_date']?.toString() ?? ''),
      endsAt: DateTime.tryParse(json['end_date']?.toString() ?? ''),
      exposure: isV2
          ? AdExposure(
              id: tracking['exposure_id']?.toString().trim() ?? '',
              expiresAt: DateTime.tryParse(
                  tracking['exposure_expires_at']?.toString() ?? ''),
              deviceId: deviceId,
              targetingKey: targetingKey,
              variantId: tracking['variant_id']?.toString(),
              videoDurationMs: creative is Map
                  ? int.tryParse('${creative['video_duration_ms']}')
                  : null,
            )
          : null,
      displayStyle: (json['three_d_style'] ??
              json['animation_style'] ??
              json['display_style'] ??
              '')
          .toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'image_url': imageUrl,
      'video_url': videoUrl,
      'destination_url': destinationUrl,
      'ad_type': isThreeD ? 'three_d' : adType,
      'placement_zone': placementZone,
      'target_scope': targetScope,
      if (area != null) 'area': area,
      if (areaId != null) 'area_id': areaId,
      'display_frequency': displayFrequency,
      'display_duration_seconds': durationSeconds,
      'daily_max_impressions_per_user': dailyMaxImpressionsPerUser,
      'ctr': ctr,
      if (startsAt != null) 'start_date': startsAt!.toIso8601String(),
      if (endsAt != null) 'end_date': endsAt!.toIso8601String(),
      if (displayStyle.isNotEmpty) 'three_d_style': displayStyle,
    };
  }

  AdBanner copyWith({
    String? id,
    String? title,
    String? imageUrl,
    String? videoUrl,
    String? destinationUrl,
    String? adType,
    String? placementZone,
    String? targetScope,
    String? area,
    String? areaId,
    int? displayFrequency,
    int? durationSeconds,
    int? dailyMaxImpressionsPerUser,
    double? ctr,
    String? displayStyle,
  }) {
    return AdBanner(
      id: id ?? this.id,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      destinationUrl: destinationUrl ?? this.destinationUrl,
      adType: adType ?? this.adType,
      placementZone: placementZone ?? this.placementZone,
      targetScope: targetScope ?? this.targetScope,
      area: area ?? this.area,
      areaId: areaId ?? this.areaId,
      displayFrequency: displayFrequency ?? this.displayFrequency,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      dailyMaxImpressionsPerUser:
          dailyMaxImpressionsPerUser ?? this.dailyMaxImpressionsPerUser,
      ctr: ctr ?? this.ctr,
      displayStyle: displayStyle ?? this.displayStyle,
      exposure: exposure,
      startsAt: startsAt,
      endsAt: endsAt,
    );
  }
}
