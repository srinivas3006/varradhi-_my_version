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
    if (status == 401) return UgcErrorKind.sessionExpired;
    if (status != null && status >= 500) return UgcErrorKind.server;
    return UgcErrorKind.unknown;
  }

  static String? _extractMessage(dynamic data) {
    if (data is! Map) return null;
    final errors = data['errors'];
    if (errors is Map) {
      final msg = errors['message'] ?? errors['detail'];
      if (msg != null) return msg.toString();
      final details = errors['details'];
      if (details is Map && details['detail'] != null) {
        return details['detail'].toString();
      }
    } else if (errors is List && errors.isNotEmpty) {
      return errors.first.toString();
    }
    return (data['message'] ?? data['detail'])?.toString();
  }
}
