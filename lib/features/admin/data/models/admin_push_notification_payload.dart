/// Optional push-notification payload attached to an approve request.
/// Only constructed when the Approve dialog's "Send Push Notification"
/// toggle is on — omitted from the request body entirely otherwise.
class AdminPushNotificationPayload {
  final String title;
  final String body;
  final String type;
  final String target;
  final String? stateName;
  final String? district;
  final String? city;
  final String? village;
  final String? subdistrict;

  const AdminPushNotificationPayload({
    required this.title,
    required this.body,
    required this.type,
    required this.target,
    this.stateName,
    this.district,
    this.city,
    this.village,
    this.subdistrict,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'body': body,
        'type': type,
        'target': target,
        if (stateName != null) 'state': stateName,
        if (district != null) 'district': district,
        if (city != null) 'city': city,
        if (village != null) 'village': village,
        if (subdistrict != null) 'subdistrict': subdistrict,
      };
}
