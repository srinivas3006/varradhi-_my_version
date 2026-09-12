/// Centralized safe Date/Time parser for backend API payloads.
/// Handles nulls, invalid formats, unix timestamps, ISO strings, and timezones
/// without throwing runtime exceptions.
class DateParser {
  DateParser._();

  /// Attempts to parse a date from any backend format (String, int, DateTime).
  /// Returns null if parsing fails.
  static DateTime? tryParse(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;

    if (value is int) {
      if (value > 100000000000) {
        // Milliseconds epoch
        return DateTime.fromMillisecondsSinceEpoch(value);
      } else if (value > 0) {
        // Seconds epoch
        return DateTime.fromMillisecondsSinceEpoch(value * 1000);
      }
      return null;
    }

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;

      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) return parsed;

      final asInt = int.tryParse(trimmed);
      if (asInt != null) {
        return tryParse(asInt);
      }
    }

    return null;
  }

  /// Parses date or defaults to [DateTime.now()] safely.
  static DateTime parseOrNow(dynamic value) {
    return tryParse(value) ?? DateTime.now();
  }
}
