import '../core/utils/date_parser.dart';
import '../core/utils/url_normalizer.dart';

int _toInt(dynamic val, [int fallback = 0]) {
  if (val == null) return fallback;
  if (val is int) return val;
  if (val is num) return val.toInt();
  return int.tryParse(val.toString().trim()) ?? fallback;
}

class UnifiedFeedItem {
  final String id;
  final String type;
  final String title;
  final String summary;
  final String thumbnailUrl;
  final String mediaUrl;
  final DateTime createdAt;
  final String district;
  final String subdistrict;
  final String village;
  final String state;
  final int priorityScore;
  final String source;
  final int trustScore;
  final Map<String, dynamic> metadata;

  UnifiedFeedItem({
    required this.id,
    required this.type,
    required this.title,
    required this.summary,
    required this.thumbnailUrl,
    required this.mediaUrl,
    required this.createdAt,
    required this.district,
    required this.subdistrict,
    required this.village,
    required this.state,
    required this.priorityScore,
    required this.source,
    required this.trustScore,
    required this.metadata,
  });

  factory UnifiedFeedItem.fromJson(Map<String, dynamic> json) {
    final rawThumb = (json['thumbnail_url'] ?? json['image_url'])?.toString();
    final rawMedia = (json['media_url'] ?? json['video_url'])?.toString();

    Map<String, dynamic> parsedMeta = {};
    if (json['metadata'] is Map) {
      parsedMeta = Map<String, dynamic>.from(json['metadata'] as Map);
    }

    return UnifiedFeedItem(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString().trim().toLowerCase() ?? 'article',
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? json['description']?.toString() ?? '',
      thumbnailUrl: UrlNormalizer.normalize(rawThumb),
      mediaUrl: UrlNormalizer.normalize(rawMedia),
      createdAt: DateParser.tryParse(json['created_at'] ?? json['published_at']) ?? DateTime.now(),
      district: json['district']?.toString() ?? '',
      subdistrict: json['subdistrict']?.toString() ?? '',
      village: json['village']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      priorityScore: _toInt(json['priority_score']),
      source: json['source']?.toString() ?? json['source_name']?.toString() ?? 'VARADHI',
      trustScore: _toInt(json['trust_score']),
      metadata: parsedMeta,
    );
  }
}
