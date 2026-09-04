class AdminOtpDeliveryModel {
  final String id;
  final String mobile;
  final String provider;
  final String status;
  final String failureReason;
  final DateTime createdAt;

  const AdminOtpDeliveryModel({
    required this.id,
    required this.mobile,
    required this.provider,
    required this.status,
    required this.failureReason,
    required this.createdAt,
  });

  factory AdminOtpDeliveryModel.fromJson(Map<String, dynamic> json) {
    return AdminOtpDeliveryModel(
      id: json['id']?.toString() ?? '',
      mobile: (json['mobile'] ?? json['phone'])?.toString() ?? '',
      provider: json['provider']?.toString() ?? '',
      status: json['status']?.toString().toUpperCase() ?? 'PENDING',
      failureReason: (json['failure_reason'] ?? json['error'])?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
