import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/errors/ugc_error.dart';
import '../core/utils/indian_mobile.dart';
import '../services/api_service.dart';
import '../services/firebase_phone_auth_gateway.dart';
import '../state/app_state.dart';

/// Backend calls used by the verification flow (seam for tests).
abstract class UgcVerificationApi {
  Future<Map<String, dynamic>> verifyFirebasePhone(String idToken);
  Future<bool> sendOtp(String mobile);
  Future<bool> verifyOtp(String mobile, String otp);
}

class _ApiServiceVerificationApi implements UgcVerificationApi {
  const _ApiServiceVerificationApi();
  @override
  Future<Map<String, dynamic>> verifyFirebasePhone(String idToken) =>
      ApiService.instance.verifyFirebasePhone(idToken);
  @override
  Future<bool> sendOtp(String mobile) => ApiService.instance.sendOtp(mobile);
  @override
  Future<bool> verifyOtp(String mobile, String otp) =>
      ApiService.instance.verifyOtp(mobile, otp);
}

enum UgcVerifyStep { enterPhone, enterCode, verified }

enum UgcVerifyMode {
  /// Recommended: Firebase sends and checks the OTP, backend verifies the
  /// resulting ID token.
  firebase,

  /// Fallback: backend `/ugc/send-otp/` + `/ugc/verify-otp/`.
  backendSms,
}

enum UgcVerifyBusy { none, sendingCode, verifyingCode, linkingAccount }

/// Drives UGC phone verification:
///
/// enterPhone → (Firebase sends OTP) → enterCode → (Firebase verifies) →
/// ID token → POST /ugc/verify-firebase-phone/ → verified
///
/// The backend-returned 10-digit mobile is stored in [AppState] and is the
/// only value later UGC calls send. Login is never touched here.
class UgcPhoneVerificationController extends ChangeNotifier {
  UgcPhoneVerificationController({
    PhoneAuthGateway? gateway,
    UgcVerificationApi? api,
    String? initialMobile,
    this.resendCooldown = const Duration(seconds: 30),
  })  : _gateway = gateway ?? FirebasePhoneAuthGateway.instance,
        _api = api ?? const _ApiServiceVerificationApi() {
    mobile = IndianMobile.normalize(initialMobile) ?? '';
  }

  final PhoneAuthGateway _gateway;
  final UgcVerificationApi _api;
  final Duration resendCooldown;

  static const int codeLength = 6;

  UgcVerifyStep step = UgcVerifyStep.enterPhone;
  UgcVerifyMode mode = UgcVerifyMode.firebase;
  UgcVerifyBusy busy = UgcVerifyBusy.none;

  /// 10-digit number being verified.
  String mobile = '';

  /// 10-digit number confirmed by the backend, once [step] is verified.
  String? verifiedMobile;

  String? errorMessage;
  UgcErrorKind? errorKind;

  /// True when Firebase failed in a way the backend SMS flow can route
  /// around (config problems, quota, Play Integrity, provider disabled).
  bool canUseFallback = false;

  /// True when a Firebase sign-in succeeded but handing the token to the
  /// backend failed transiently — [retryLink] can finish without a new OTP.
  bool canRetryLink = false;

  int resendSecondsLeft = 0;

  String? _verificationId;
  int? _resendToken;
  Timer? _resendTimer;
  bool _signingIn = false;
  bool _disposed = false;

  bool get isBusy => busy != UgcVerifyBusy.none;
  bool get canResend => !isBusy && resendSecondsLeft == 0;

  static String _t(String te, String en) =>
      AppState.instance.language == 'Telugu' ? te : en;

  // --- Phone step ---------------------------------------------------------

  void setMobile(String value) {
    mobile = value.replaceAll(RegExp(r'\D'), '');
    if (errorKind == UgcErrorKind.nonIndianPhone || errorMessage != null) {
      _clearError();
    }
    _notify();
  }

  /// Sends the OTP to [mobile] via the active mode.
  Future<void> sendCode() async {
    if (isBusy) return;
    final normalized = IndianMobile.normalize(mobile);
    if (normalized == null) {
      _setError(
          UgcErrorKind.nonIndianPhone,
          _t('దయచేసి సరైన 10 అంకెల భారతీయ మొబైల్ నంబర్ నమోదు చేయండి.',
              'Please use a valid Indian mobile number.'));
      return;
    }
    mobile = normalized;
    _clearError();
    canUseFallback = false;
    busy = UgcVerifyBusy.sendingCode;
    _notify();

    if (mode == UgcVerifyMode.firebase && !await _gateway.ensureAvailable()) {
      // No Firebase on this install. Do not call /ugc/send-otp/ on our own:
      // it is the old SMS fallback, only used when the reader picks it.
      busy = UgcVerifyBusy.none;
      canUseFallback = true;
      _setError(
          UgcErrorKind.unknown,
          _t('ప్రస్తుతం OTP పంపడం సాధ్యం కాలేదు. మళ్లీ ప్రయత్నించండి లేదా SMS ద్వారా OTP పొందండి.',
              'Could not send the OTP right now. Try again, or get it by SMS instead.'));
      return;
    }

    if (mode == UgcVerifyMode.backendSms) {
      await _sendBackendOtp();
    } else {
      await _sendFirebaseOtp();
    }
  }

  Future<void> resendCode() async {
    if (!canResend) return;
    await sendCode();
  }

  /// Back to the number field (e.g. "Change number").
  void editNumber() {
    if (isBusy) return;
    _resendTimer?.cancel();
    resendSecondsLeft = 0;
    _verificationId = null;
    _resendToken = null;
    canRetryLink = false;
    step = UgcVerifyStep.enterPhone;
    _clearError();
    _notify();
  }

  /// Switches to the backend SMS OTP flow after a Firebase failure.
  Future<void> useFallback() async {
    if (isBusy) return;
    mode = UgcVerifyMode.backendSms;
    canUseFallback = false;
    _verificationId = null;
    _resendToken = null;
    _resendTimer?.cancel();
    resendSecondsLeft = 0;
    await _gateway.signOut();
    await sendCode();
  }

  Future<void> _sendFirebaseOtp() async {
    _gateway.setLanguageCode(
        AppState.instance.language == 'Telugu' ? 'te' : 'en');
    try {
      await _gateway.verifyPhoneNumber(
        phoneNumber: IndianMobile.toE164(mobile),
        forceResendingToken: _resendToken,
        onAutoVerified: (credential) {
          // Android read the SMS itself. Finish without the user typing.
          unawaited(_signInAndLink(credential));
        },
        onFailed: (error) {
          if (_disposed) return;
          busy = UgcVerifyBusy.none;
          _handleFirebaseError(error);
        },
        onCodeSent: (verificationId, resendToken) {
          if (_disposed) return;
          _verificationId = verificationId;
          _resendToken = resendToken;
          busy = UgcVerifyBusy.none;
          step = UgcVerifyStep.enterCode;
          _startResendTimer();
          _notify();
        },
        onAutoRetrievalTimeout: (verificationId) {
          _verificationId ??= verificationId;
        },
      );
    } on FirebaseAuthException catch (e) {
      busy = UgcVerifyBusy.none;
      _handleFirebaseError(e);
    } catch (e) {
      debugPrint('[UgcVerify] verifyPhoneNumber threw: $e');
      busy = UgcVerifyBusy.none;
      canUseFallback = true;
      _setError(
          UgcErrorKind.unknown,
          _t('OTP పంపడం సాధ్యం కాలేదు. మళ్లీ ప్రయత్నించండి.',
              'Could not send the OTP. Please try again.'));
    }
  }

  Future<void> _sendBackendOtp() async {
    try {
      await _api.sendOtp(mobile);
      busy = UgcVerifyBusy.none;
      step = UgcVerifyStep.enterCode;
      _startResendTimer();
      _notify();
    } catch (e) {
      busy = UgcVerifyBusy.none;
      _handleBackendError(UgcApiError.from(e));
    }
  }

  // --- Code step ----------------------------------------------------------

  Future<void> submitCode(String code) async {
    if (isBusy) return;
    final otp = code.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      _setError(
          UgcErrorKind.invalidOtp,
          _t('దయచేసి 6 అంకెల OTP నమోదు చేయండి.',
              'Please enter the 6-digit OTP.'));
      return;
    }
    _clearError();

    if (mode == UgcVerifyMode.backendSms) {
      await _verifyBackendOtp(otp);
      return;
    }

    final verificationId = _verificationId;
    if (verificationId == null) {
      _setError(
          UgcErrorKind.tokenMissingPhone,
          _t('OTP సెషన్ ముగిసింది. దయచేసి కొత్త OTP పొందండి.',
              'The OTP session expired. Please request a new code.'));
      return;
    }
    await _signInAndLink(_gateway.credential(verificationId, otp));
  }

  Future<void> _verifyBackendOtp(String otp) async {
    busy = UgcVerifyBusy.verifyingCode;
    _notify();
    try {
      final ok = await _api.verifyOtp(mobile, otp);
      if (!ok) {
        busy = UgcVerifyBusy.none;
        _setError(UgcErrorKind.invalidOtp,
            _t('OTP తప్పు. మళ్లీ ప్రయత్నించండి.', 'Incorrect OTP. Try again.'));
        return;
      }
      await _complete(mobile);
    } catch (e) {
      busy = UgcVerifyBusy.none;
      _handleBackendError(UgcApiError.from(e));
    }
  }

  Future<void> _signInAndLink(PhoneAuthCredential credential) async {
    if (_signingIn || step == UgcVerifyStep.verified || _disposed) return;
    _signingIn = true;
    busy = UgcVerifyBusy.verifyingCode;
    _clearError();
    _notify();
    try {
      final idToken = await _gateway.signInAndGetIdToken(credential);
      await _linkWithBackend(idToken, allowTokenRefresh: true);
    } on FirebaseAuthException catch (e) {
      busy = UgcVerifyBusy.none;
      _handleFirebaseError(e);
    } catch (e) {
      debugPrint('[UgcVerify] sign-in failed: $e');
      busy = UgcVerifyBusy.none;
      _setError(
          UgcErrorKind.unknown,
          _t('ధృవీకరణ విఫలమైంది. మళ్లీ ప్రయత్నించండి.',
              'Verification failed. Please try again.'));
    } finally {
      _signingIn = false;
    }
  }

  /// Retries handing the (still signed-in) Firebase user's token to the
  /// backend after a network/server failure, without a new OTP.
  Future<void> retryLink() async {
    if (isBusy || !canRetryLink) return;
    busy = UgcVerifyBusy.linkingAccount;
    _clearError();
    _notify();
    try {
      final token = await _gateway.refreshIdToken();
      if (token == null) {
        busy = UgcVerifyBusy.none;
        canRetryLink = false;
        _restart(
            UgcErrorKind.tokenMissingPhone,
            _t('ధృవీకరణ సెషన్ ముగిసింది. దయచేసి మళ్లీ OTP పొందండి.',
                'Verification session ended. Please request a new OTP.'));
        return;
      }
      await _linkWithBackend(token, allowTokenRefresh: true);
    } catch (e) {
      busy = UgcVerifyBusy.none;
      _handleBackendError(UgcApiError.from(e));
    }
  }

  Future<void> _linkWithBackend(String idToken,
      {required bool allowTokenRefresh}) async {
    busy = UgcVerifyBusy.linkingAccount;
    canRetryLink = false;
    _notify();
    try {
      final data = await _api.verifyFirebasePhone(idToken);
      if (data['verified'] == false) {
        throw UgcApiError(UgcErrorKind.tokenMissingPhone,
            data['message']?.toString() ?? 'Mobile not verified.');
      }
      // Backend's mobile wins: it is what UGC submit will be checked against.
      final backendMobile =
          IndianMobile.normalize(data['mobile']?.toString()) ?? mobile;
      await _complete(backendMobile);
    } catch (e) {
      final error = UgcApiError.from(e);
      if (error.kind == UgcErrorKind.invalidFirebaseToken &&
          allowTokenRefresh) {
        // Spec: refresh the Firebase ID token and call the backend again.
        final fresh = await _safeRefreshToken();
        if (fresh != null) {
          await _linkWithBackend(fresh, allowTokenRefresh: false);
          return;
        }
      }
      busy = UgcVerifyBusy.none;
      _handleBackendError(error, afterFirebaseSignIn: true);
    }
  }

  Future<String?> _safeRefreshToken() async {
    try {
      return await _gateway.refreshIdToken();
    } catch (_) {
      return null;
    }
  }

  Future<void> _complete(String verified) async {
    await AppState.instance.markUgcMobileVerified(verified);
    // The Firebase user existed only to mint the ID token.
    await _gateway.signOut();
    _resendTimer?.cancel();
    verifiedMobile = verified;
    busy = UgcVerifyBusy.none;
    step = UgcVerifyStep.verified;
    canRetryLink = false;
    _clearError();
    _notify();
  }

  // --- Error handling ------------------------------------------------------

  void _handleFirebaseError(FirebaseAuthException e) {
    debugPrint('[UgcVerify] Firebase error ${e.code}: ${e.message}');
    switch (e.code) {
      case 'invalid-phone-number':
        _restart(
            UgcErrorKind.nonIndianPhone,
            _t('మొబైల్ నంబర్ చెల్లదు. సరైన భారతీయ నంబర్ నమోదు చేయండి.',
                'Please use a valid Indian mobile number.'));
        return;
      case 'invalid-verification-code':
        _setError(UgcErrorKind.invalidOtp,
            _t('OTP తప్పు. మళ్లీ ప్రయత్నించండి.', 'Incorrect OTP. Try again.'));
        return;
      case 'session-expired':
      case 'code-expired':
      case 'invalid-verification-id':
        _verificationId = null;
        resendSecondsLeft = 0;
        _resendTimer?.cancel();
        _setError(
            UgcErrorKind.invalidOtp,
            _t('OTP గడువు ముగిసింది. దయచేసి కొత్త OTP పొందండి.',
                'This OTP has expired. Please request a new one.'));
        return;
      case 'network-request-failed':
        _setError(
            UgcErrorKind.network,
            _t('ఇంటర్నెట్ కనెక్షన్ లేదు. దయచేసి తనిఖీ చేసి మళ్లీ ప్రయత్నించండి.',
                'No internet connection. Check your network and try again.'));
        return;
      case 'web-context-cancelled':
      case 'web-context-canceled':
        _setError(
            UgcErrorKind.unknown,
            _t('ధృవీకరణ రద్దు చేయబడింది. మళ్లీ ప్రయత్నించండి.',
                'Verification was cancelled. Please try again.'));
        return;
      case 'too-many-requests':
      case 'quota-exceeded':
        canUseFallback = true;
        _setError(
            UgcErrorKind.unknown,
            _t('చాలా ప్రయత్నాలు జరిగాయి. కొద్దిసేపటి తర్వాత ప్రయత్నించండి లేదా SMS ద్వారా OTP పొందండి.',
                'Too many attempts. Try again later, or get the OTP by SMS instead.'));
        return;
      default:
        // app-not-authorized, missing-client-identifier,
        // invalid-app-credential, captcha-check-failed,
        // operation-not-allowed, internal-error, …: Firebase cannot serve
        // this install. The backend SMS flow does not depend on it.
        canUseFallback = true;
        // The code is shown so support can tell a console problem
        // (CONFIGURATION_NOT_FOUND = Authentication never set up,
        // BILLING_NOT_ENABLED, app-not-authorized = missing SHA) from a
        // device one without needing a USB log.
        _setError(
            UgcErrorKind.unknown,
            '${_t('ప్రస్తుతం ఈ విధానంలో OTP పంపడం సాధ్యం కాలేదు. SMS ద్వారా OTP పొందండి.',
                'We could not send the OTP this way right now. Get it by SMS instead.')}'
            ' (${firebaseErrorDetail(e)})');
    }
  }

  /// Short, support-readable form of a Firebase error: its code plus the
  /// server reason when Firebase buries it in the message (e.g.
  /// `internal-error · CONFIGURATION_NOT_FOUND`).
  @visibleForTesting
  static String firebaseErrorDetail(FirebaseAuthException e) {
    final reason = RegExp(r'\b[A-Z][A-Z_]{5,}\b').firstMatch(e.message ?? '');
    return reason == null ? e.code : '${e.code} · ${reason.group(0)}';
  }

  void _handleBackendError(UgcApiError e, {bool afterFirebaseSignIn = false}) {
    debugPrint('[UgcVerify] backend error ${e.kind}: ${e.message}');
    switch (e.kind) {
      case UgcErrorKind.invalidFirebaseToken:
        unawaited(_gateway.signOut());
        _restart(
            e.kind,
            _t('ధృవీకరణ విఫలమైంది. దయచేసి మళ్లీ ఫోన్ ధృవీకరణ చేయండి.',
                'Verification failed. Please verify your phone again.'));
        return;
      case UgcErrorKind.firebaseProjectNotAllowed:
        // Configuration problem on our side — never retry automatically.
        unawaited(_gateway.signOut());
        canUseFallback = true;
        _setError(
            e.kind,
            _t('ధృవీకరణ సేవలో సాంకేతిక సమస్య ఉంది. దయచేసి SMS ద్వారా OTP పొందండి లేదా సపోర్ట్‌ను సంప్రదించండి.',
                'Phone verification is misconfigured. Get the OTP by SMS instead, or contact support.'));
        return;
      case UgcErrorKind.tokenMissingPhone:
        unawaited(_gateway.signOut());
        _restart(
            e.kind,
            _t('ఫోన్ ధృవీకరణ పూర్తి కాలేదు. దయచేసి మళ్లీ ప్రారంభించండి.',
                'Phone verification did not complete. Please start again.'));
        return;
      case UgcErrorKind.nonIndianPhone:
        unawaited(_gateway.signOut());
        _restart(
            e.kind,
            _t('దయచేసి సరైన భారతీయ మొబైల్ నంబర్ ఉపయోగించండి.',
                'Please use a valid Indian mobile number.'));
        return;
      case UgcErrorKind.mobileMismatch:
        unawaited(_gateway.signOut());
        _restart(
            e.kind,
            _t('మీ ఖాతా ఇప్పటికే మరో మొబైల్ నంబర్‌తో ధృవీకరించబడింది. దయచేసి ఆ నంబర్‌నే ఉపయోగించండి.',
                'Your account is already verified with a different mobile number. Please use that number.'));
        return;
      case UgcErrorKind.invalidOtp:
        // SMS fallback: the backend's exact text distinguishes invalid,
        // expired, already used, attempts exceeded, cooldown ("Please wait
        // 60 seconds…"), request limit and service unavailable.
        _setError(
            e.kind,
            e.message.isNotEmpty
                ? e.message
                : _t('OTP తప్పు. మళ్లీ ప్రయత్నించండి.',
                    'Incorrect OTP. Try again.'));
        return;
      case UgcErrorKind.sessionExpired:
        unawaited(_gateway.signOut());
        _setError(
            e.kind,
            _t('సెషన్ గడువు ముగిసింది. దయచేసి మళ్లీ లాగిన్ అవ్వండి.',
                'Your session expired. Please log in again.'));
        return;
      case UgcErrorKind.network:
      case UgcErrorKind.server:
        canRetryLink = afterFirebaseSignIn;
        _setError(
            e.kind,
            e.kind == UgcErrorKind.network
                ? _t('ఇంటర్నెట్ కనెక్షన్ లేదు. మళ్లీ ప్రయత్నించండి.',
                    'No internet connection. Please try again.')
                : _t('సర్వర్ సమస్య. కొద్దిసేపటి తర్వాత మళ్లీ ప్రయత్నించండి.',
                    'Server problem. Please try again shortly.'));
        return;
      default:
        if (afterFirebaseSignIn) unawaited(_gateway.signOut());
        _setError(
            e.kind,
            e.message.isNotEmpty
                ? e.message
                : _t('ధృవీకరణ విఫలమైంది. మళ్లీ ప్రయత్నించండి.',
                    'Verification failed. Please try again.'));
    }
  }

  /// Error that needs a fresh OTP: back to the number step.
  void _restart(UgcErrorKind kind, String message) {
    _resendTimer?.cancel();
    resendSecondsLeft = 0;
    _verificationId = null;
    _resendToken = null;
    canRetryLink = false;
    step = UgcVerifyStep.enterPhone;
    _setError(kind, message);
  }

  // --- Plumbing -----------------------------------------------------------

  void _startResendTimer() {
    _resendTimer?.cancel();
    resendSecondsLeft = resendCooldown.inSeconds;
    if (resendSecondsLeft <= 0) return;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_disposed) {
        t.cancel();
        return;
      }
      resendSecondsLeft = resendSecondsLeft > 0 ? resendSecondsLeft - 1 : 0;
      if (resendSecondsLeft == 0) t.cancel();
      _notify();
    });
  }

  void _setError(UgcErrorKind kind, String message) {
    errorKind = kind;
    errorMessage = message;
    _notify();
  }

  void _clearError() {
    errorKind = null;
    errorMessage = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _resendTimer?.cancel();
    // Abandoned mid-flow: do not leave a stray Firebase phone session.
    if (step != UgcVerifyStep.verified) unawaited(_gateway.signOut());
    super.dispose();
  }
}
