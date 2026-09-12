import '../core/utils/url_normalizer.dart';

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
  final int dailyMaxImpressionsPerUser;
  final double ctr;

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
    this.dailyMaxImpressionsPerUser = 0,
    required this.ctr,
  });

  bool get isVideo =>
      adType.toLowerCase() == 'video' || videoUrl.trim().isNotEmpty;

  factory AdBanner.fromJson(Map<String, dynamic> json) {
    final rawImg = (json['image_url'] ?? json['thumbnail_url'] ?? json['banner_url'])?.toString();
    final rawVideo = (json['video_url'] ?? json['video'])?.toString();
    final rawDest = (json['destination_url'] ?? json['target_url'] ?? json['click_url'])?.toString();

    return AdBanner(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? json['headline']?.toString() ?? 'Sponsored Promotion',
      imageUrl: UrlNormalizer.normalize(rawImg),
      videoUrl: UrlNormalizer.normalize(rawVideo),
      destinationUrl: rawDest?.trim() ?? '',
      adType: json['ad_type']?.toString() ?? 'banner',
      placementZone: json['placement_zone']?.toString() ?? 'feed',
      targetScope: json['target_scope']?.toString() ?? 'global',
      area: json['area']?.toString(),
      areaId: json['area_id']?.toString(),
      displayFrequency: _toInt(json['display_frequency'], 5),
      dailyMaxImpressionsPerUser: _toInt(json['daily_max_impressions_per_user'], 0),
      ctr: _toDouble(json['ctr'], 0.0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'image_url': imageUrl,
      'video_url': videoUrl,
      'destination_url': destinationUrl,
      'ad_type': adType,
      'placement_zone': placementZone,
      'target_scope': targetScope,
      if (area != null) 'area': area,
      if (areaId != null) 'area_id': areaId,
      'display_frequency': displayFrequency,
      'daily_max_impressions_per_user': dailyMaxImpressionsPerUser,
      'ctr': ctr,
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
    int? dailyMaxImpressionsPerUser,
    double? ctr,
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
      dailyMaxImpressionsPerUser: dailyMaxImpressionsPerUser ?? this.dailyMaxImpressionsPerUser,
      ctr: ctr ?? this.ctr,
    );
  }
}
