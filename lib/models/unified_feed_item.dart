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
    return UnifiedFeedItem(
      id: json['id']?.toString() ?? '',
      type: json['type'] ?? 'article',
      title: json['title'] ?? '',
      summary: json['summary'] ?? '',
      thumbnailUrl: json['thumbnail_url'] ?? '',
      mediaUrl: json['media_url'] ?? '',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      district: json['district'] ?? '',
      subdistrict: json['subdistrict'] ?? '',
      village: json['village'] ?? '',
      state: json['state'] ?? '',
      priorityScore: json['priority_score'] ?? 0,
      source: json['source'] ?? '',
      trustScore: json['trust_score'] ?? 0,
      metadata: json['metadata'] ?? {},
    );
  }
}
