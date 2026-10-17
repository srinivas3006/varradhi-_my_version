/// Makes text safe for logs: no tokens, OTPs or full mobile numbers.
///
/// Logs can end up in logcat or crash reports, so anything printed from the
/// verification / UGC flow goes through [scrub] first.
class LogSafe {
  LogSafe._();

  // JWT-like (Firebase ID token, backend access/refresh): three base64url
  // parts separated by dots.
  static final _jwt =
      RegExp(r'[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}');
  // "Bearer <anything>".
  static final _bearer = RegExp(r'Bearer\s+\S+', caseSensitive: false);
  // Phone numbers: optional +91 / 91 / 0 prefix, then 10 digits (spaces or
  // dashes allowed between groups).
  static final _phone = RegExp(r'(\+?\d[\d\s-]{8,}\d)');
  // Standalone 4–8 digit codes (OTPs).
  static final _otp = RegExp(r'\b\d{4,8}\b');

  /// `98******10` — enough to tell numbers apart, not enough to reuse.
  static String maskMobile(String? mobile) {
    final digits = (mobile ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return '***';
    return '${digits.substring(0, 2)}******'
        '${digits.substring(digits.length - 2)}';
  }

  static String scrub(Object? value) {
    var s = value?.toString() ?? '';
    s = s.replaceAll(_bearer, 'Bearer ***');
    s = s.replaceAll(_jwt, '***TOKEN***');
    s = s.replaceAllMapped(_phone, (m) {
      final digits = m.group(0)!.replaceAll(RegExp(r'\D'), '');
      return digits.length >= 10 ? maskMobile(digits) : m.group(0)!;
    });
    s = s.replaceAll(_otp, '****');
    return s;
  }
}
