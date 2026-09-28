/// Indian mobile number handling for UGC phone verification.
///
/// The backend stores and expects exactly 10 digits (`9876543210`) on every
/// UGC endpoint. Firebase needs E.164 (`+919876543210`). This is the single
/// place that converts between the two, so a `+91` can never leak into a UGC
/// submit payload.
class IndianMobile {
  IndianMobile._();

  static final RegExp _tenDigit = RegExp(r'^[6-9]\d{9}$');

  /// Returns the 10-digit form of [input], or null if it is not a valid
  /// Indian mobile number.
  ///
  /// Accepts `9876543210`, `+91 98765 43210`, `919876543210`, `09876543210`
  /// and similar spellings users type or backends return.
  static String? normalize(String? input) {
    if (input == null) return null;
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return _tenDigit.hasMatch(digits) ? digits : null;
  }

  static bool isValid(String? input) => normalize(input) != null;

  /// E.164 form for Firebase. [tenDigit] must already be normalized.
  static String toE164(String tenDigit) => '+91$tenDigit';

  /// `98765 43210` — for display only.
  static String format(String tenDigit) => tenDigit.length == 10
      ? '${tenDigit.substring(0, 5)} ${tenDigit.substring(5)}'
      : tenDigit;

  /// `98xxxxxx10` — for places where the number should not be shown whole.
  static String mask(String tenDigit) => tenDigit.length == 10
      ? '${tenDigit.substring(0, 2)}xxxxxx${tenDigit.substring(8)}'
      : tenDigit;
}
