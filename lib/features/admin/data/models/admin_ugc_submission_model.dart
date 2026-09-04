import 'admin_ugc_status.dart';

int _asInt(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? fallback;
}

double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

Map<String, dynamic>? _asMap(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;

/// One flat model backing both the queue card and the detail screen —
/// detail-only fields are simply empty/zero when only list data is
/// available, and get filled in once the detail endpoint responds.
class AdminUgcSubmissionModel {
  final String id;
  final String title;
  final String description;
  final String editorNotes;
  final String category;
  final String publicationLevel;
  final String moderationLevel;
  final AdminUgcStatus status;

  final String village;
  final String mandal;
  final String district;
  final String stateName;
  final double? latitude;
  final double? longitude;

  final String originalMediaUrl;
  final String originalMediaType;
  final String videoThumbnailUrl;
  final String brandedMediaUrl;
  final String brandedMediaType;

  final String uploadStatus;
  final String validationStatus;

  final String? reporterUserId;
  final String reporterName;
  final String reporterEmail;
  final String reporterMobile;
  final AdminTrustLevel trustLevel;
  final int trustScore;
  final bool uploaderBlocked;
  final String uploaderStatus;

  final bool duplicateFlagged;
  final double? duplicateScore;
  final int reportCount;

  final String adminNotes;
  final DateTime submittedAt;
  final DateTime updatedAt;

  const AdminUgcSubmissionModel({
    required this.id,
    required this.title,
    required this.description,
    required this.editorNotes,
    required this.category,
    required this.publicationLevel,
    required this.moderationLevel,
    required this.status,
    required this.village,
    required this.mandal,
    required this.district,
    required this.stateName,
    required this.latitude,
    required this.longitude,
    required this.originalMediaUrl,
    required this.originalMediaType,
    required this.videoThumbnailUrl,
    required this.brandedMediaUrl,
    required this.brandedMediaType,
    required this.uploadStatus,
    required this.validationStatus,
    required this.reporterUserId,
    required this.reporterName,
    required this.reporterEmail,
    required this.reporterMobile,
    required this.trustLevel,
    required this.trustScore,
    required this.uploaderBlocked,
    required this.uploaderStatus,
    required this.duplicateFlagged,
    required this.duplicateScore,
    required this.reportCount,
    required this.adminNotes,
    required this.submittedAt,
    required this.updatedAt,
  });

  bool get isVideo => originalMediaType.toLowerCase() == 'video';
  bool get hasMedia => originalMediaUrl.isNotEmpty;
  bool get hasBrandedMedia => brandedMediaUrl.isNotEmpty;

  factory AdminUgcSubmissionModel.fromJson(Map<String, dynamic> raw) {
    final json = raw['data'] is Map ? Map<String, dynamic>.from(raw['data'] as Map) : raw;

    final location = _asMap(json['location']) ?? _asMap(json['address']);

    final reporterMap = _asMap(json['reporter']) ?? _asMap(json['uploader']) ?? _asMap(json['user']);

    final uploaderBlocked = (reporterMap?['is_blocked'] ??
            reporterMap?['blocked'] ??
            json['is_blocked'] ??
            json['blocked'] ??
            json['uploader_blocked']) ==
        true;

    return AdminUgcSubmissionModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled Submission',
      description: json['description']?.toString() ?? '',
      editorNotes: json['editor_notes']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      publicationLevel: json['publication_level']?.toString() ?? '',
      moderationLevel: (json['level'] ?? json['moderation_level'] ?? json['publication_level'])?.toString() ?? '',
      status: AdminUgcStatusX.fromWire(json['status']?.toString()),
      village: (json['village'] ?? location?['village'])?.toString() ?? '',
      mandal: (json['mandal'] ?? json['subdistrict'] ?? location?['mandal'] ?? location?['subdistrict'])?.toString() ?? '',
      district: (json['district'] ?? location?['district'])?.toString() ?? '',
      stateName: (json['state'] ?? location?['state'])?.toString() ?? '',
      latitude: _asDouble(json['latitude'] ?? json['lat'] ?? location?['latitude'] ?? location?['lat']),
      longitude: _asDouble(json['longitude'] ?? json['lng'] ?? json['lon'] ?? location?['longitude'] ?? location?['lon']),
      originalMediaUrl: (json['media_url'] ?? json['original_media_url'] ?? json['file_url'])?.toString() ?? '',
      originalMediaType: (json['media_type'] ?? json['content_type'])?.toString() ?? 'image',
      videoThumbnailUrl: (json['thumbnail_url'] ?? json['video_thumbnail_url'])?.toString() ?? '',
      brandedMediaUrl: json['branded_media_url']?.toString() ?? '',
      brandedMediaType: (json['branded_media_type'] ?? json['media_type'])?.toString() ?? 'image',
      uploadStatus: json['upload_status']?.toString() ?? '',
      validationStatus: json['validation_status']?.toString() ?? '',
      reporterUserId: (reporterMap?['id'] ?? reporterMap?['user_id'] ?? json['reporter_id'] ?? json['user_id'])?.toString(),
      reporterName: (reporterMap?['name'] ?? reporterMap?['full_name'] ?? reporterMap?['username'] ?? json['reporter_name'] ?? json['uploader'])
              ?.toString() ??
          '',
      reporterEmail: (reporterMap?['email'] ?? json['reporter_email'])?.toString() ?? '',
      reporterMobile: (reporterMap?['mobile'] ?? reporterMap?['phone'] ?? reporterMap?['mobile_number'] ?? json['mobile'] ?? json['reporter_mobile'])
              ?.toString() ??
          '',
      trustLevel: AdminTrustLevelX.fromWire((reporterMap?['trust_level'] ?? json['trust_level'])?.toString()),
      trustScore: _asInt(reporterMap?['trust_score'] ?? reporterMap?['score'] ?? json['trust_score'] ?? json['score'], 0),
      uploaderBlocked: uploaderBlocked,
      uploaderStatus: json['uploader_status']?.toString() ?? (uploaderBlocked ? 'BLOCKED' : 'ACTIVE'),
      duplicateFlagged: (json['duplicate_flagged'] ?? json['is_duplicate']) == true,
      duplicateScore: _asDouble(json['duplicate_score'] ?? json['duplicate_percentage']),
      reportCount: _asInt(json['report_count'] ?? json['reports_count'], 0),
      adminNotes: (json['admin_notes'] ?? json['notes'])?.toString() ?? '',
      submittedAt: DateTime.tryParse((json['created_at'] ?? json['submitted_at'])?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.tryParse((json['created_at'] ?? json['submitted_at'])?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  AdminUgcSubmissionModel copyWith({
    String? title,
    String? description,
    String? editorNotes,
    String? category,
    String? publicationLevel,
    String? moderationLevel,
    AdminUgcStatus? status,
    String? village,
    String? mandal,
    String? district,
    String? stateName,
    double? latitude,
    double? longitude,
    String? brandedMediaUrl,
    String? brandedMediaType,
    String? uploadStatus,
    String? validationStatus,
    int? trustScore,
    AdminTrustLevel? trustLevel,
    bool? uploaderBlocked,
    String? uploaderStatus,
    String? adminNotes,
    DateTime? updatedAt,
  }) {
    return AdminUgcSubmissionModel(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      editorNotes: editorNotes ?? this.editorNotes,
      category: category ?? this.category,
      publicationLevel: publicationLevel ?? this.publicationLevel,
      moderationLevel: moderationLevel ?? this.moderationLevel,
      status: status ?? this.status,
      village: village ?? this.village,
      mandal: mandal ?? this.mandal,
      district: district ?? this.district,
      stateName: stateName ?? this.stateName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      originalMediaUrl: originalMediaUrl,
      originalMediaType: originalMediaType,
      videoThumbnailUrl: videoThumbnailUrl,
      brandedMediaUrl: brandedMediaUrl ?? this.brandedMediaUrl,
      brandedMediaType: brandedMediaType ?? this.brandedMediaType,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      validationStatus: validationStatus ?? this.validationStatus,
      reporterUserId: reporterUserId,
      reporterName: reporterName,
      reporterEmail: reporterEmail,
      reporterMobile: reporterMobile,
      trustLevel: trustLevel ?? this.trustLevel,
      trustScore: trustScore ?? this.trustScore,
      uploaderBlocked: uploaderBlocked ?? this.uploaderBlocked,
      uploaderStatus: uploaderStatus ?? (uploaderBlocked ?? this.uploaderBlocked ? 'BLOCKED' : 'ACTIVE'),
      duplicateFlagged: duplicateFlagged,
      duplicateScore: duplicateScore,
      reportCount: reportCount,
      adminNotes: adminNotes ?? this.adminNotes,
      submittedAt: submittedAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Builds the snake_case PATCH body for the Edit-Metadata sheet — only
  /// editable fields, omitting anything left unchanged (null).
  Map<String, dynamic> toPatchJson({
    String? title,
    String? description,
    String? category,
    String? publicationLevel,
    String? stateName,
    String? district,
    String? subdistrict,
    String? village,
    double? latitude,
    double? longitude,
    String? adminNotes,
  }) {
    return {
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (category != null) 'category': category,
      if (publicationLevel != null) 'publication_level': publicationLevel,
      if (stateName != null) 'state': stateName,
      if (district != null) 'district': district,
      if (subdistrict != null) 'subdistrict': subdistrict,
      if (village != null) 'village': village,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (adminNotes != null) 'admin_notes': adminNotes,
    };
  }
}
