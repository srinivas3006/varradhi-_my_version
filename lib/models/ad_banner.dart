class AdBanner {
  final String id;
  final String imageUrl;
  final String destinationUrl;
  final String adType;
  final String placementZone;
  final String targetScope;
  final int displayFrequency;
  final double ctr;

  AdBanner({
    required this.id,
    required this.imageUrl,
    required this.destinationUrl,
    required this.adType,
    required this.placementZone,
    required this.targetScope,
    required this.displayFrequency,
    required this.ctr,
  });

  factory AdBanner.fromJson(Map<String, dynamic> json) {
    return AdBanner(
      id: json['id'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      destinationUrl: json['destination_url'] as String? ?? '',
      adType: json['ad_type'] as String? ?? 'banner',
      placementZone: json['placement_zone'] as String? ?? 'feed',
      targetScope: json['target_scope'] as String? ?? 'global',
      displayFrequency: json['display_frequency'] as int? ?? 5,
      ctr: (json['ctr'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
