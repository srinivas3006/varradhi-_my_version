class LiveNews {
  final String id;
  final String title;
  final String youtubeUrl;
  final String youtubeVideoId;
  final String thumbnailUrl;
  final String description;
  final String channelName;
  final bool isActive;
  final bool autoplay;
  final int sortOrder;
  final String status; // 'live', 'upcoming', 'ended'
  final DateTime? scheduledAt;

  LiveNews({
    required this.id,
    required this.title,
    required this.youtubeUrl,
    required this.youtubeVideoId,
    required this.thumbnailUrl,
    required this.description,
    required this.channelName,
    required this.isActive,
    required this.autoplay,
    required this.sortOrder,
    this.status = 'live',
    this.scheduledAt,
  });

  bool get isLiveActive => (isActive || status.toLowerCase() == 'live') && status.toLowerCase() != 'ended';
  bool get isUpcoming => status.toLowerCase() == 'upcoming' || (scheduledAt != null && scheduledAt!.isAfter(DateTime.now()));

  factory LiveNews.fromJson(Map<String, dynamic> json) {
    DateTime? parsedScheduled;
    if (json['scheduled_at'] != null) {
      parsedScheduled = DateTime.tryParse(json['scheduled_at'].toString());
    } else if (json['scheduled_time'] != null) {
      parsedScheduled = DateTime.tryParse(json['scheduled_time'].toString());
    }

    final rawStatus = (json['status']?.toString() ?? '').toLowerCase().trim();
    final bool rawActive = json['is_active'] == true;
    final String resolvedStatus = rawStatus.isNotEmpty
        ? rawStatus
        : (rawActive ? 'live' : (parsedScheduled != null && parsedScheduled.isAfter(DateTime.now()) ? 'upcoming' : 'ended'));

    return LiveNews(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      youtubeUrl: json['youtube_url'] ?? '',
      youtubeVideoId: json['youtube_video_id'] ?? '',
      thumbnailUrl: json['thumbnail_url'] ?? '',
      description: json['description'] ?? '',
      channelName: json['channel_name'] ?? 'VARADHI TV',
      isActive: rawActive || resolvedStatus == 'live',
      autoplay: json['autoplay'] ?? false,
      sortOrder: json['sort_order'] ?? 0,
      status: resolvedStatus,
      scheduledAt: parsedScheduled,
    );
  }
}
