import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/controllers/ugc_controller.dart';
import 'package:vaaradhi/controllers/ugc_phone_verification_controller.dart';
import 'package:vaaradhi/core/errors/app_exception.dart';
import 'package:vaaradhi/core/errors/ugc_error.dart';
import 'package:vaaradhi/core/utils/indian_mobile.dart';
import 'package:vaaradhi/models/ugc_draft.dart';
import 'package:vaaradhi/repositories/ugc_draft_repository.dart';
import 'package:vaaradhi/repositories/ugc_repository.dart';
import 'package:vaaradhi/screens/ugc_phone_verify_screen.dart';
import 'package:vaaradhi/services/firebase_phone_auth_gateway.dart';
import 'package:vaaradhi/state/app_state.dart';

// ---------------------------------------------------------------- fakes ---

class FakeGateway implements PhoneAuthGateway {
  bool available = true;
  FirebaseAuthException? sendError;
  FirebaseAuthException? signInError;
  bool autoVerify = false;
  String? lastPhone;
  int signOuts = 0;
  int refreshes = 0;
  final List<String> tokens = ['token-1', 'token-2', 'token-3'];

  @override
  Future<bool> ensureAvailable() async => available;

  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    int? forceResendingToken,
    required void Function(PhoneAuthCredential credential) onAutoVerified,
    required void Function(FirebaseAuthException error) onFailed,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String verificationId) onAutoRetrievalTimeout,
  }) async {
    lastPhone = phoneNumber;
    if (sendError != null) {
      onFailed(sendError!);
      return;
    }
    onCodeSent('vid-1', 7);
    if (autoVerify) onAutoVerified(credential('vid-1', '123456'));
  }

  @override
  PhoneAuthCredential credential(String verificationId, String smsCode) =>
      PhoneAuthProvider.credential(
          verificationId: verificationId, smsCode: smsCode);

  @override
  Future<String> signInAndGetIdToken(PhoneAuthCredential credential) async {
    if (signInError != null) throw signInError!;
    return tokens.first;
  }

  @override
  Future<String?> refreshIdToken() async {
    refreshes++;
    return tokens[refreshes.clamp(0, tokens.length - 1)];
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    existingSessionToken = null;
  }

  /// Token of a Firebase phone session still signed in on the phone.
  String? existingSessionToken;

  @override
  Future<String?> existingPhoneIdToken() async => existingSessionToken;

  @override
  void setLanguageCode(String code) {}
}

DioException backendError(int status, String message) {
  final options = RequestOptions(path: '/api/v1/ugc/');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: options,
      statusCode: status,
      data: {
        'data': null,
        'meta': {},
        'errors': {
          'code': status,
          'message': message,
          'details': {'detail': message},
        },
      },
    ),
  );
}

class FakeApi implements UgcVerificationApi {
  /// Responses for successive verifyFirebasePhone calls: a Map to succeed or
  /// an Object to throw.
  final List<Object> firebaseResponses = [];
  final List<String> idTokensSeen = [];
  final List<String> otpMobiles = [];
  bool otpOk = true;

  @override
  Future<Map<String, dynamic>> verifyFirebasePhone(String idToken) async {
    idTokensSeen.add(idToken);
    final next = firebaseResponses.isNotEmpty
        ? firebaseResponses.removeAt(0)
        : {'verified': true, 'mobile': '9876543210'};
    if (next is Map<String, dynamic>) return next;
    throw next;
  }

  @override
  Future<bool> sendOtp(String mobile) async {
    otpMobiles.add(mobile);
    return true;
  }

  @override
  Future<bool> verifyOtp(String mobile, String otp) async => otpOk;
}

class RecordingUgcRepository extends UgcRepository {
  Object? submitError;
  Map<String, dynamic>? lastPayload;
  String? lastUploadMobile;
  String? lastUploadType;
  int submitCalls = 0;

  @override
  Future<Map<String, dynamic>> submitPost(Map<String, dynamic> data) async {
    submitCalls++;
    lastPayload = data;
    if (submitError != null) throw submitError!;
    return {'id': 'sub-1'};
  }

  @override
  Future<Map<String, dynamic>> uploadMedia({
    required String submissionId,
    required String mobile,
    required String mediaType,
    required String filePath,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    lastUploadMobile = mobile;
    lastUploadType = mediaType;
    return {'status': 'ok'};
  }
}

// ---------------------------------------------------------------- tests ---

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UgcPhoneVerificationController.resetSessionState();
    AppState.instance.language = 'English';
    AppState.instance.ugcMobileVerified = false;
    AppState.instance.ugcVerifiedMobile = '';
    AppState.instance.ugcUploadLockedUntil = null;
    AppState.instance.ugcBlockedAt = null;
  });

  group('IndianMobile', () {
    test('normalizes the spellings users type', () {
      for (final input in [
        '9876543210',
        '+91 98765 43210',
        '919876543210',
        '09876543210',
        '+91-98765-43210',
      ]) {
        expect(IndianMobile.normalize(input), '9876543210', reason: input);
      }
    });

    test('rejects non-Indian or malformed numbers', () {
      for (final input in ['12345', '5876543210', '+1 415 555 0100', '', null]) {
        expect(IndianMobile.normalize(input), isNull, reason: '$input');
      }
    });

    test('E.164 is only for Firebase', () {
      expect(IndianMobile.toE164('9876543210'), '+919876543210');
    });
  });

  group('UgcApiError.classify maps every documented backend message', () {
    const cases = {
      'Invalid Firebase token.': UgcErrorKind.invalidFirebaseToken,
      'Firebase authentication is not configured.':
          UgcErrorKind.firebaseProjectNotAllowed,
      'Firebase token project is not allowed.':
          UgcErrorKind.firebaseProjectNotAllowed,
      'Firebase token does not contain a verified phone number.':
          UgcErrorKind.tokenMissingPhone,
      'Firebase token does not contain a verified Indian phone number.':
          UgcErrorKind.nonIndianPhone,
      // Current backend wording (2026-09-27 contract). These two used to
      // fall through to unknown and skip their handling.
      'Firebase token has no verified phone number.':
          UgcErrorKind.tokenMissingPhone,
      'Only Indian mobile numbers are supported.':
          UgcErrorKind.nonIndianPhone,
      'Submitted mobile does not match verified mobile.':
          UgcErrorKind.mobileMismatch,
      'Mobile number is not verified.': UgcErrorKind.mobileNotVerified,
      'Daily upload limit reached.': UgcErrorKind.dailyLimitReached,
      'Uploader is blocked.': UgcErrorKind.uploaderBlocked,
    };
    cases.forEach((message, kind) {
      test(message, () {
        expect(UgcApiError.classify(message, 400), kind);
        expect(UgcApiError.from(backendError(400, message)).kind, kind);
      });
    });

    test('reads the message the Dio interceptor already mapped', () {
      final options = RequestOptions(path: '/x');
      final e = DioException(
        requestOptions: options,
        error: ValidationException('Daily upload limit reached.', 400),
      );
      expect(UgcApiError.from(e).kind, UgcErrorKind.dailyLimitReached);
    });

    test('connection failures are retryable network errors', () {
      final e = DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError);
      final err = UgcApiError.from(e);
      expect(err.kind, UgcErrorKind.network);
      expect(err.isRetryable, isTrue);
    });
  });

  group('Firebase phone verification flow', () {
    late FakeGateway gateway;
    late FakeApi api;
    late UgcPhoneVerificationController c;

    setUp(() {
      gateway = FakeGateway();
      api = FakeApi();
      c = UgcPhoneVerificationController(
        gateway: gateway,
        api: api,
        resendCooldown: Duration.zero,
        initialMode: UgcVerifyMode.firebase,
      );
    });

    tearDown(() => c.dispose());

    test('happy path: OTP → ID token → backend → verified mobile stored',
        () async {
      c.setMobile('98765 43210');
      await c.sendCode();
      expect(gateway.lastPhone, '+919876543210');
      expect(c.step, UgcVerifyStep.enterCode);

      api.firebaseResponses.add({
        'message': 'Mobile verified.',
        'verified': true,
        'mobile': '9876543210',
        'reporter_level': 'VERIFIED_USER',
      });
      await c.submitCode('123456');

      expect(api.idTokensSeen, ['token-1']);
      expect(c.step, UgcVerifyStep.verified);
      expect(c.verifiedMobile, '9876543210');
      expect(AppState.instance.uploadVerified, isTrue);
      expect(AppState.instance.ugcVerifiedMobile, '9876543210');
      // The Firebase phone session is kept for the next pre-OTP check.
      expect(gateway.signOuts, 0);
    });

    group('before any OTP: is this account already verified?', () {
      setUp(() async {
        FlutterSecureStorage.setMockInitialValues({});
        await AppState.instance.clearUgcVerification();
        AppState.instance
          ..userId = 'acct-1'
          ..isLoggedIn = true;
      });

      test('kept session of this account → "Mobile verified." → no OTP',
          () async {
        await AppState.instance.writeUgcFirebaseOwner('acct-1');
        gateway.existingSessionToken = 'kept-token';
        api.firebaseResponses.add({
          'message': 'Mobile verified.',
          'verified': true,
          'mobile': '9014066807',
        });

        expect(await c.checkExistingVerification(), isTrue);
        expect(c.step, UgcVerifyStep.verified);
        expect(api.idTokensSeen, ['kept-token']);
        expect(gateway.lastPhone, isNull, reason: 'no OTP was sent');
        expect(AppState.instance.ugcVerifiedMobile, '9014066807');
      });

      test('sendCode asks the backend first, then skips the OTP', () async {
        await AppState.instance.writeUgcFirebaseOwner('acct-1');
        gateway.existingSessionToken = 'kept-token';
        api.firebaseResponses.add({'verified': true, 'mobile': '9014066807'});
        c.setMobile('9014066807');
        await c.sendCode();
        expect(c.step, UgcVerifyStep.verified);
        expect(gateway.lastPhone, isNull);
      });

      test('no kept session → normal OTP, nothing sent to the backend',
          () async {
        expect(await c.checkExistingVerification(), isFalse);
        expect(api.idTokensSeen, isEmpty);
        c.setMobile('9876543210');
        await c.sendCode();
        expect(gateway.lastPhone, '+919876543210');
      });

      test("another account's session is signed out, never reused",
          () async {
        await AppState.instance.writeUgcFirebaseOwner('someone-else');
        gateway.existingSessionToken = 'their-token';
        expect(await c.checkExistingVerification(), isFalse);
        expect(api.idTokensSeen, isEmpty);
        expect(gateway.signOuts, 1);
      });

      test('backend does not confirm → session dropped, OTP next', () async {
        await AppState.instance.writeUgcFirebaseOwner('acct-1');
        gateway.existingSessionToken = 'kept-token';
        api.firebaseResponses.add(backendError(401, 'Invalid Firebase token.'));
        expect(await c.checkExistingVerification(), isFalse);
        expect(c.errorMessage, isNull, reason: 'the check is silent');
        expect(gateway.signOuts, 1);
        expect(AppState.instance.uploadVerified, isFalse);
      });

      test('a reply without verified:true is not a verification', () async {
        await AppState.instance.writeUgcFirebaseOwner('acct-1');
        gateway.existingSessionToken = 'kept-token';
        api.firebaseResponses.add({'message': 'ok'});
        expect(await c.checkExistingVerification(), isFalse);
        expect(AppState.instance.uploadVerified, isFalse);
      });

      test('a successful OTP tags the kept session with the account',
          () async {
        c.setMobile('9876543210');
        await c.sendCode();
        await c.submitCode('123456');
        expect(c.step, UgcVerifyStep.verified);
        expect(await AppState.instance.readUgcFirebaseOwner(), 'acct-1');
      });
    });

    test('backend-returned mobile wins over what was typed', () async {
      c.setMobile('9876543210');
      await c.sendCode();
      api.firebaseResponses.add({'verified': true, 'mobile': '+919123456789'});
      await c.submitCode('123456');
      expect(AppState.instance.ugcVerifiedMobile, '9123456789');
    });

    for (final body in <Map<String, dynamic>>[
      {},
      {'message': 'ok'},
      {'verified': true},
      {'verified': 'yes', 'mobile': '9876543210'},
    ]) {
      test('bridge reply $body is NOT a verification', () async {
        await AppState.instance.clearUgcVerification();
        c.setMobile('9876543210');
        await c.sendCode();
        api.firebaseResponses.add(body);
        await c.submitCode('123456');

        expect(c.step, isNot(UgcVerifyStep.verified));
        expect(AppState.instance.uploadVerified, isFalse);
        // Firebase user kept: the reporter can retry the bridge call
        // from the OTP screen without a new SMS.
        expect(c.canRetryLink, isTrue);
        expect(c.errorMessage, isNotNull);

        api.firebaseResponses.add({'verified': true, 'mobile': '9876543210'});
        await c.retryLink();
        expect(c.step, UgcVerifyStep.verified);
        expect(AppState.instance.ugcVerifiedMobile, '9876543210');
      });
    }

    test('Android auto-retrieval finishes without typing the code', () async {
      gateway.autoVerify = true;
      c.setMobile('9876543210');
      await c.sendCode();
      // Sign-in, backend link and the encrypted-storage write run async.
      for (var i = 0; i < 50 && c.step != UgcVerifyStep.verified; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(c.step, UgcVerifyStep.verified);
    });

    test('rejects a non-Indian number before calling Firebase', () async {
      c.setMobile('12345');
      await c.sendCode();
      expect(gateway.lastPhone, isNull);
      expect(c.errorKind, UgcErrorKind.nonIndianPhone);
    });

    test('invalid Firebase token: refreshes once and retries', () async {
      c.setMobile('9876543210');
      await c.sendCode();
      api.firebaseResponses.add(backendError(401, 'Invalid Firebase token.'));
      await c.submitCode('123456');
      expect(gateway.refreshes, 1);
      expect(api.idTokensSeen, ['token-1', 'token-2']);
      expect(c.step, UgcVerifyStep.verified);
    });

    test('invalid Firebase token twice: back to phone step', () async {
      c.setMobile('9876543210');
      await c.sendCode();
      api.firebaseResponses
        ..add(backendError(401, 'Invalid Firebase token.'))
        ..add(backendError(401, 'Invalid Firebase token.'));
      await c.submitCode('123456');
      expect(api.idTokensSeen.length, 2);
      expect(c.step, UgcVerifyStep.enterPhone);
      expect(c.errorKind, UgcErrorKind.invalidFirebaseToken);
      expect(AppState.instance.uploadVerified, isFalse);
    });

    test('project not allowed: never retried, offers SMS fallback', () async {
      c.setMobile('9876543210');
      await c.sendCode();
      api.firebaseResponses
          .add(backendError(401, 'Firebase token project is not allowed.'));
      await c.submitCode('123456');
      expect(api.idTokensSeen.length, 1);
      expect(gateway.refreshes, 0);
      expect(c.errorKind, UgcErrorKind.firebaseProjectNotAllowed);
      expect(c.canUseFallback, isTrue);
    });

    test('token without phone restarts the OTP flow', () async {
      c.setMobile('9876543210');
      await c.sendCode();
      api.firebaseResponses.add(backendError(
          400, 'Firebase token does not contain a verified phone number.'));
      await c.submitCode('123456');
      expect(c.step, UgcVerifyStep.enterPhone);
      expect(c.errorKind, UgcErrorKind.tokenMissingPhone);
    });

    test('non-Indian number in token shows the Indian-number message',
        () async {
      c.setMobile('9876543210');
      await c.sendCode();
      api.firebaseResponses.add(backendError(400,
          'Firebase token does not contain a verified Indian phone number.'));
      await c.submitCode('123456');
      expect(c.errorMessage, 'Please use a valid Indian mobile number.');
    });

    test('network failure while linking can retry without a new OTP',
        () async {
      c.setMobile('9876543210');
      await c.sendCode();
      api.firebaseResponses.add(DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError));
      await c.submitCode('123456');
      expect(c.canRetryLink, isTrue);
      expect(c.step, UgcVerifyStep.enterCode);

      await c.retryLink();
      expect(c.step, UgcVerifyStep.verified);
    });

    test('wrong code keeps the user on the code step', () async {
      c.setMobile('9876543210');
      await c.sendCode();
      gateway.signInError =
          FirebaseAuthException(code: 'invalid-verification-code');
      await c.submitCode('000000');
      expect(c.step, UgcVerifyStep.enterCode);
      expect(c.errorKind, UgcErrorKind.invalidOtp);
      expect(api.idTokensSeen, isEmpty);
    });

    Future<void> settle() async {
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    // Client APK on 2026-10-06: the Firebase project has no Blaze plan, so
    // every OTP failed with BILLING_NOT_ENABLED and the screen showed the
    // raw code. A setup error now goes straight to the backend SMS OTP.
    test('BILLING_NOT_ENABLED → backend SMS OTP sent automatically',
        () async {
      gateway.sendError = FirebaseAuthException(
          code: 'unknown',
          message: 'An internal error has occurred. [ BILLING_NOT_ENABLED ]');
      c.setMobile('9876543210');
      await c.sendCode();
      await settle();
      expect(c.mode, UgcVerifyMode.backendSms);
      expect(api.otpMobiles, ['9876543210']);
      expect(c.step, UgcVerifyStep.enterCode);
      expect(c.errorMessage, isNull, reason: 'no error, no code on screen');
    });

    test('CONFIGURATION_NOT_FOUND is a setup error too', () async {
      gateway.sendError = FirebaseAuthException(
          code: 'internal-error',
          message: 'An internal error has occurred. [ CONFIGURATION_NOT_FOUND ]');
      c.setMobile('9876543210');
      await c.sendCode();
      await settle();
      expect(api.otpMobiles, ['9876543210']);
    });

    test('after a setup error the next screen starts on SMS', () async {
      gateway.sendError = FirebaseAuthException(
          code: 'unknown', message: '[ BILLING_NOT_ENABLED ]');
      c.setMobile('9876543210');
      await c.sendCode();
      await settle();
      final next = UgcPhoneVerificationController(
          gateway: FakeGateway(), api: FakeApi());
      expect(next.mode, UgcVerifyMode.backendSms);
      next.dispose();
    });

    test('a reader-side failure is not treated as a setup error', () async {
      gateway.sendError =
          FirebaseAuthException(code: 'internal-error', message: 'timeout');
      c.setMobile('9876543210');
      await c.sendCode();
      await settle();
      expect(c.mode, UgcVerifyMode.firebase);
      expect(api.otpMobiles, isEmpty);
      expect(c.canUseFallback, isTrue);
      expect(c.errorMessage, isNot(contains('internal-error')));
    });

    test('Firebase misconfigured → backend SMS with 10 digits, verified',
        () async {
      gateway.sendError = FirebaseAuthException(code: 'app-not-authorized');
      c.setMobile('+91 98765 43210');
      await c.sendCode();
      await settle();
      expect(c.mode, UgcVerifyMode.backendSms);
      expect(api.otpMobiles, ['9876543210']);
      expect(c.step, UgcVerifyStep.enterCode);

      await c.submitCode('123456');
      expect(c.step, UgcVerifyStep.verified);
      expect(AppState.instance.ugcVerifiedMobile, '9876543210');
    });

    test('no Firebase on the install never calls send-otp by itself',
        () async {
      gateway.available = false;
      c.setMobile('9876543210');
      await c.sendCode();
      expect(c.mode, UgcVerifyMode.firebase);
      expect(gateway.lastPhone, isNull);
      expect(api.otpMobiles, isEmpty,
          reason: 'send-otp is the old SMS fallback, not the normal flow');
      expect(c.canUseFallback, isTrue);
      expect(c.errorMessage, isNotNull);
      expect(c.isBusy, isFalse);

      // Only an explicit choice reaches the backend SMS flow.
      await c.useFallback();
      expect(c.mode, UgcVerifyMode.backendSms);
    });
  });

  test('defaults to Firebase mode', () {
    final c = UgcPhoneVerificationController(
        gateway: FakeGateway(), api: FakeApi());
    expect(c.mode, UgcVerifyMode.firebase);
    c.dispose();
  });

  group('Backend SMS phone verification flow (fallback)', () {
    late FakeApi api;
    late UgcPhoneVerificationController c;

    setUp(() {
      api = FakeApi();
      c = UgcPhoneVerificationController(
        api: api,
        resendCooldown: Duration.zero,
        initialMode: UgcVerifyMode.backendSms,
      );
    });

    tearDown(() => c.dispose());

    test('happy path: mobile → backend send-otp → enter code → verify-otp → verified',
        () async {
      c.setMobile('9876543210');
      await c.sendCode();
      expect(api.otpMobiles, ['9876543210']);
      expect(c.step, UgcVerifyStep.enterCode);

      await c.submitCode('123456');
      expect(c.step, UgcVerifyStep.verified);
      expect(c.verifiedMobile, '9876543210');
      expect(AppState.instance.uploadVerified, isTrue);
      expect(AppState.instance.ugcVerifiedMobile, '9876543210');
    });

    test('invalid OTP shows error and stays on enterCode step', () async {
      api.otpOk = false;
      c.setMobile('9876543210');
      await c.sendCode();
      expect(c.step, UgcVerifyStep.enterCode);

      await c.submitCode('654321');
      expect(c.step, UgcVerifyStep.enterCode);
      expect(c.errorMessage, isNotNull);
      expect(AppState.instance.uploadVerified, isFalse);
    });
  });

  group('UGC submit uses the verified mobile and honours backend rules', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('ugc_verify_');
      AppState.instance.latitude = 17.1415;
      AppState.instance.longitude = 79.6236;
      AppState.instance.hasValidLocation = true;
      AppState.instance.userPhone = '9000000000';
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    Future<BuildContext> pumpContext(WidgetTester tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      })));
      return ctx;
    }

    Future<UgcController> readyController(
        WidgetTester tester, RecordingUgcRepository repo) async {
      final img = File('${tempDir.path}/pic.jpg')..writeAsBytesSync([1, 2, 3]);
      await UgcDraftRepository.instance.saveDraft(UgcDraft(
        title: 'Road issue near market',
        description: 'Road damaged near local market area.',
        category: 'Local',
        type: 'IMAGE',
        filePaths: [img.path],
      ));
      final controller = UgcController(ugcRepository: repo);
      await tester.runAsync(() async {
        await controller.checkForPendingDraft();
        await controller.restorePendingDraft();
      });
      return controller;
    }

    testWidgets('unverified: asks for verification, sends nothing',
        (tester) async {
      final context = await pumpContext(tester);
      final repo = RecordingUgcRepository();
      final controller = await readyController(tester, repo);
      late bool ok;
      await tester.runAsync(() async {
        ok = await controller.submitNews(context);
      });
      expect(ok, isFalse);
      expect(controller.status, UgcUploadStatus.verificationRequired);
      expect(repo.submitCalls, 0);
    });

    testWidgets('verified: sends the backend mobile, no +91, uppercase type',
        (tester) async {
      AppState.instance.ugcMobileVerified = true;
      AppState.instance.ugcVerifiedMobile = '9876543210';
      final context = await pumpContext(tester);
      final repo = RecordingUgcRepository();
      final controller = await readyController(tester, repo);
      late bool ok;
      await tester.runAsync(() async {
        ok = await controller.submitNews(context);
      });
      expect(ok, isTrue);
      expect(repo.lastPayload!['mobile'], '9876543210');
      expect(repo.lastPayload!['content_type'], 'IMAGE');
      expect(repo.lastUploadMobile, '9876543210');
      expect(repo.lastUploadType, 'IMAGE');
    });

    testWidgets('"Mobile number is not verified." clears cache and re-verifies',
        (tester) async {
      AppState.instance.ugcMobileVerified = true;
      AppState.instance.ugcVerifiedMobile = '9876543210';
      final context = await pumpContext(tester);
      final repo = RecordingUgcRepository()
        ..submitError = backendError(400, 'Mobile number is not verified.');
      final controller = await readyController(tester, repo);
      await tester.runAsync(() async {
        await controller.submitNews(context);
      });
      expect(controller.status, UgcUploadStatus.verificationRequired);
      expect(AppState.instance.uploadVerified, isFalse);
    });

    testWidgets('daily limit locks uploads until tomorrow', (tester) async {
      AppState.instance.ugcMobileVerified = true;
      AppState.instance.ugcVerifiedMobile = '9876543210';
      final context = await pumpContext(tester);
      final repo = RecordingUgcRepository()
        ..submitError = backendError(400, 'Daily upload limit reached.');
      final controller = await readyController(tester, repo);
      await tester.runAsync(() async {
        await controller.submitNews(context);
      });
      expect(controller.errorKind, UgcErrorKind.dailyLimitReached);
      expect(AppState.instance.isUgcDailyLimitActive, isTrue);
      expect(controller.isUploadRestricted, isTrue);

      // A second attempt does not reach the server.
      await tester.runAsync(() async {
        await controller.submitNews(context);
      });
      expect(repo.submitCalls, 1);
    });

    testWidgets('blocked uploader is not retried', (tester) async {
      AppState.instance.ugcMobileVerified = true;
      AppState.instance.ugcVerifiedMobile = '9876543210';
      final context = await pumpContext(tester);
      final repo = RecordingUgcRepository()
        ..submitError = backendError(400, 'Uploader is blocked.');
      final controller = await readyController(tester, repo);
      await tester.runAsync(() async {
        await controller.submitNews(context);
        await controller.submitNews(context);
      });
      expect(controller.errorKind, UgcErrorKind.uploaderBlocked);
      expect(repo.submitCalls, 1);
    });
  });

  group('verify screen', () {
    testWidgets('enter number → OTP → pops with verified mobile',
        (tester) async {
      final gateway = FakeGateway();
      final controller = UgcPhoneVerificationController(
          gateway: gateway, api: FakeApi(), resendCooldown: Duration.zero);
      String? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                        builder: (_) =>
                            UgcPhoneVerifyScreen(controller: controller)));
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('ugc-verify-phone')), '9876543210');
      await tester.pump();
      await tester.tap(find.byKey(const Key('ugc-verify-send')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ugc-verify-code')), findsOneWidget);

      await tester.runAsync(() async {
        await tester.enterText(
            find.byKey(const Key('ugc-verify-code')), '123456');
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      expect(result, '9876543210');
      controller.dispose();
    });

    testWidgets('billing off → OTP code step appears, no error shown',
        (tester) async {
      final gateway = FakeGateway()
        ..sendError = FirebaseAuthException(
            code: 'unknown',
            message: 'An internal error has occurred. [ BILLING_NOT_ENABLED ]');
      final api = FakeApi();
      final controller = UgcPhoneVerificationController(
          gateway: gateway, api: api, resendCooldown: Duration.zero);
      await tester.pumpWidget(MaterialApp(
          home: UgcPhoneVerifyScreen(controller: controller)));
      await tester.enterText(
          find.byKey(const Key('ugc-verify-phone')), '9876543210');
      await tester.pump();
      await tester.tap(find.byKey(const Key('ugc-verify-send')));
      await tester.pumpAndSettle();

      // Switched to the backend SMS by itself: straight to the code step.
      expect(api.otpMobiles, ['9876543210']);
      expect(find.byKey(const Key('ugc-verify-code')), findsOneWidget);
      expect(find.textContaining('BILLING_NOT_ENABLED'), findsNothing);
      controller.dispose();
    });
  });

  group('the login phone is never the verified UGC mobile', () {
    test('uploadVerified needs the bridge flag, not just a number', () async {
      await AppState.instance.clearUgcVerification();
      AppState.instance.ugcVerifiedMobile = '9876543210';
      expect(AppState.instance.uploadVerified, isFalse);
      expect(AppState.instance.ugcMobileVerified, isFalse);
      await AppState.instance.clearUgcVerification();
    });
  });
}
