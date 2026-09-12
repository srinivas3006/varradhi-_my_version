import 'dart:io';

/// Upload states for UGC submission & media transmission.
enum UgcUploadStatus {
  idle,
  preparing,
  submitting,
  uploading,
  completed,
  failed,
  cancelled,
}

/// Persistent model representing an in-progress or recoverable UGC draft.
class UgcDraft {
  final String title;
  final String description;
  final String category;
  final String type; // 'IMAGE' or 'VIDEO'
  final List<String> filePaths;
  final String? submissionId;
  final UgcUploadStatus uploadStatus;
  final String? locationLat;
  final String? locationLon;
  final String? district;
  final String? stateName;
  final String? mobile;
  final DateTime updatedAt;

  UgcDraft({
    required this.title,
    required this.description,
    required this.category,
    required this.type,
    required this.filePaths,
    this.submissionId,
    this.uploadStatus = UgcUploadStatus.idle,
    this.locationLat,
    this.locationLon,
    this.district,
    this.stateName,
    this.mobile,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  bool get hasContent =>
      title.trim().isNotEmpty ||
      description.trim().isNotEmpty ||
      filePaths.isNotEmpty;

  UgcDraft copyWith({
    String? title,
    String? description,
    String? category,
    String? type,
    List<String>? filePaths,
    String? submissionId,
    UgcUploadStatus? uploadStatus,
    String? locationLat,
    String? locationLon,
    String? district,
    String? stateName,
    String? mobile,
    DateTime? updatedAt,
  }) {
    return UgcDraft(
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      type: type ?? this.type,
      filePaths: filePaths ?? this.filePaths,
      submissionId: submissionId ?? this.submissionId,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      locationLat: locationLat ?? this.locationLat,
      locationLon: locationLon ?? this.locationLon,
      district: district ?? this.district,
      stateName: stateName ?? this.stateName,
      mobile: mobile ?? this.mobile,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'type': type,
      'filePaths': filePaths,
      'submissionId': submissionId,
      'uploadStatus': uploadStatus.name,
      'locationLat': locationLat,
      'locationLon': locationLon,
      'district': district,
      'stateName': stateName,
      'mobile': mobile,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory UgcDraft.fromJson(Map<String, dynamic> json) {
    UgcUploadStatus status = UgcUploadStatus.idle;
    final statusName = json['uploadStatus']?.toString();
    if (statusName != null) {
      for (final s in UgcUploadStatus.values) {
        if (s.name == statusName) {
          status = s;
          break;
        }
      }
    }

    final rawPaths = json['filePaths'];
    final List<String> paths = rawPaths is List
        ? rawPaths.map((p) => p.toString()).toList()
        : <String>[];

    return UgcDraft(
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Local',
      type: json['type']?.toString() ?? 'IMAGE',
      filePaths: paths,
      submissionId: json['submissionId']?.toString(),
      uploadStatus: status,
      locationLat: json['locationLat']?.toString(),
      locationLon: json['locationLon']?.toString(),
      district: json['district']?.toString(),
      stateName: json['stateName']?.toString(),
      mobile: json['mobile']?.toString(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  /// Verifies which media files referenced in the draft still exist on disk.
  /// Returns a list of paths that are missing/deleted.
  Future<List<String>> findMissingFiles() async {
    final List<String> missing = [];
    for (final path in filePaths) {
      final exists = await File(path).exists();
      if (!exists) {
        missing.add(path);
      }
    }
    return missing;
  }
}
