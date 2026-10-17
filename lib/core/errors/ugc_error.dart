import 'package:dio/dio.dart';
import 'app_exception.dart';

/// Every UGC verification / submission failure the backend documents, plus
/// the transport failures around them. The UI decides what to do from the
/// kind, never by re-parsing message strings.
enum UgcErrorKind {
  /// 401 "Invalid Firebase token." — refresh the ID token and retry once,
  /// then ask the user to verify again.
  invalidFirebaseToken,

  /// 401 "Firebase token project is not allowed." — configuration issue.
  /// Never retried automatically.
  firebaseProjectNotAllowed,

  /// 400 "Firebase token has no verified phone number." — restart the phone
  /// OTP flow.
  tokenMissingPhone,

  /// 400 "Only Indian mobile numbers are supported." — ask for a valid
  /// Indian number.
  nonIndianPhone,

  /// 400 "Submitted mobile does not match verified mobile." — the account
  /// is already bound to another number.
  mobileMismatch,

  /// 400 "Mobile number is not verified." — send the user to verification.
  mobileNotVerified,

  /// 400 "Daily upload limit reached." — disable upload until tomorrow.
  dailyLimitReached,

  /// 400 "Uploader is blocked." — do not retry.
  uploaderBlocked,

  /// Wrong / expired backend SMS OTP (fallback flow).
  invalidOtp,

  /// Backend session is gone; the user must log in again.
  sessionExpired,

  /// No connectivity or timeout — safe to retry.
  network,

  /// 5xx — safe to retry later.
  server,

  /// The request was cancelled by the user.
  cancelled,

  /// 404 "Submission not found." on upload. The draft is kept and nothing
  /// is recreated silently; the reporter chooses to start a new submission.
  submissionNotFound,

  /// 413 — the media is larger than the server accepts.
  payloadTooLarge,

  /// 429 — too many requests; wait before trying again.
  rateLimited,

  unknown,
}

class UgcApiError extends AppException {
  final UgcErrorKind kind;

  UgcApiError(this.kind, String message, [int? statusCode, dynamic details])
      : super(message, statusCode, details);

  /// Errors that can be fixed by trying the same request again.
  bool get isRetryable =>
      kind == UgcErrorKind.network || kind == UgcErrorKind.server;

  /// Errors that mean the locally cached verified mobile is no longer valid.
  bool get invalidatesLocalVerification =>
      kind == UgcErrorKind.mobileNotVerified ||
      kind == UgcErrorKind.mobileMismatch;

  /// Classifies anything thrown by the network layer into a [UgcApiError].
  ///
  /// Handles raw [DioException]s (ApiService uses Dio directly, with the
  /// mapped [AppException] riding in `error`), bare [AppException]s, and
  /// anything else.
  static UgcApiError from(Object error) {
    if (error is UgcApiError) return error;

    int? status;
    String? backendMessage;
    AppException? appError;

    if (error is DioException) {
      if (error.type == DioExceptionType.cancel) {
        return UgcApiError(UgcErrorKind.cancelled, 'Request cancelled.');
      }
      status = error.response?.statusCode;
      backendMessage = _extractMessage(error.response?.data);
      if (error.error is AppException) appError = error.error as AppException;
      if (appError == null) {
        switch (error.type) {
          case DioExceptionType.connectionTimeout:
          case DioExceptionType.sendTimeout:
          case DioExceptionType.receiveTimeout:
            return UgcApiError(UgcErrorKind.network,
                TimeoutException().message, null, error.message);
          case DioExceptionType.connectionError:
            return UgcApiError(UgcErrorKind.network,
                NetworkException().message, null, error.message);
          default:
            break;
        }
      }
    } else if (error is AppException) {
      appError = error;
    }

    if (appError != null) {
      status ??= appError.statusCode;
      backendMessage ??= appError.message;
      if (appError is NetworkException || appError is TimeoutException) {
        return UgcApiError(
            UgcErrorKind.network, appError.message, status, appError);
      }
    }

    final message = backendMessage ?? error.toString();
    return UgcApiError(classify(message, status), message, status, error);
  }

  /// Maps the backend's documented `errors.message` texts to a kind.
  /// Matching is case-insensitive and substring-based so trailing
  /// punctuation or wording tweaks on the server do not break it.
  static UgcErrorKind classify(String message, int? status) {
    final m = message.toLowerCase();
    // Both are backend configuration problems: never retried, SMS offered.
    if (m.contains('project is not allowed') ||
        (m.contains('firebase') && m.contains('not configured'))) {
      return UgcErrorKind.firebaseProjectNotAllowed;
    }
    if (m.contains('invalid firebase token') ||
        (m.contains('firebase') && m.contains('expired'))) {
      return UgcErrorKind.invalidFirebaseToken;
    }
    // "Only Indian mobile numbers are supported." (current) and the older
    // "... does not contain a verified Indian phone number.".
    if (m.contains('verified indian phone') ||
        m.contains('indian mobile')) {
      return UgcErrorKind.nonIndianPhone;
    }
    // "Firebase token has no verified phone number." (current) and the
    // older "... does not contain a verified phone number.".
    if (m.contains('does not contain a verified phone') ||
        m.contains('no verified phone')) {
      return UgcErrorKind.tokenMissingPhone;
    }
    if (m.contains('does not match verified mobile')) {
      return UgcErrorKind.mobileMismatch;
    }
    if (m.contains('mobile number is not verified') ||
        m.contains('mobile not verified')) {
      return UgcErrorKind.mobileNotVerified;
    }
    if (m.contains('daily upload limit')) {
      return UgcErrorKind.dailyLimitReached;
    }
    if (m.contains('uploader is blocked') || m.contains('user is blocked')) {
      return UgcErrorKind.uploaderBlocked;
    }
    if (m.contains('otp')) {
      return UgcErrorKind.invalidOtp;
    }
    if (m.contains('submission not found')) {
      return UgcErrorKind.submissionNotFound;
    }
    if (status == 413) return UgcErrorKind.payloadTooLarge;
    if (status == 429) return UgcErrorKind.rateLimited;
    if (status == 401) return UgcErrorKind.sessionExpired;
    if (status != null && status >= 500) return UgcErrorKind.server;
    return UgcErrorKind.unknown;
  }

  static String? _extractMessage(dynamic data) {
    if (data is! Map) return null;
    final errors = data['errors'];
    if (errors is Map) {
      final msg = (errors['message'] ?? errors['detail'])?.toString();
      final details = errors['details'];
      // Serializer field errors ({"content_type": ["…not a valid choice."]})
      // and "Media validation failed." per-file reasons live in
      // errors.details — show them, not just the headline.
      final lines = [...fieldErrors(details), ...fileReasons(details)];
      final generic = msg == null ||
          msg.trim().isEmpty ||
          msg.trim().toLowerCase() == 'an error occurred.';
      if (lines.isNotEmpty) {
        return generic ? lines.join('\n') : '$msg\n${lines.join('\n')}';
      }
      if (details is Map && details['detail'] != null) {
        return details['detail'].toString();
      }
      if (details is List && details.isNotEmpty) {
        return details.first.toString();
      }
      if (msg != null) return msg;
    } else if (errors is List && errors.isNotEmpty) {
      return errors.first.toString();
    }
    return (data['message'] ?? data['detail'])?.toString();
  }

  /// Field errors from `errors.details`, one line each, e.g.
  /// "Content type: "image" is not a valid choice.". Skips the keys that
  /// carry other things (`errors` = per-file, `detail`, `message`, `code`).
  static List<String> fieldErrors(dynamic details) {
    if (details is! Map) return const [];
    const skip = {'errors', 'detail', 'message', 'code'};
    String first(dynamic v) {
      if (v is List) return v.isEmpty ? '' : first(v.first);
      if (v is Map) return v.isEmpty ? '' : first(v.values.first);
      return v?.toString() ?? '';
    }

    final out = <String>[];
    details.forEach((key, value) {
      final k = '$key';
      if (skip.contains(k)) return;
      final why = first(value).trim();
      if (why.isEmpty) return;
      out.add(k == 'non_field_errors' ? why : '${_fieldLabel(k)}: $why');
    });
    return out;
  }

  /// `location_lat` → "Location lat".
  static String _fieldLabel(String key) {
    final words = key.replaceAll('_', ' ').trim();
    return words.isEmpty
        ? key
        : words[0].toUpperCase() + words.substring(1);
  }

  /// Per-file reasons from `errors.details.errors`, one line each, e.g.
  /// "photo2.jpg: File too large." Accepts a list of strings, a list of
  /// maps (file/filename/name/index + error/message/reason), or a map of
  /// file → reason(s). Empty when there are none.
  static List<String> fileReasons(dynamic details) {
    final raw = details is Map ? details['errors'] : null;
    String reasonOf(dynamic v) =>
        v is List ? v.map((e) => '$e').join(', ') : '$v';
    final out = <String>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final who = item['file'] ??
              item['filename'] ??
              item['name'] ??
              (int.tryParse('${item['index']}') != null
                  ? '#${int.parse('${item['index']}') + 1}'
                  : null);
          final why = item['error'] ?? item['message'] ?? item['reason'];
          if (why == null) continue;
          out.add(who == null ? reasonOf(why) : '$who: ${reasonOf(why)}');
        } else if (item != null) {
          out.add('$item');
        }
      }
    } else if (raw is Map) {
      raw.forEach((k, v) => out.add('$k: ${reasonOf(v)}'));
    }
    return out;
  }
}
