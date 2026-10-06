import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/core/network/dio_client.dart';
import 'package:vaaradhi/state/app_state.dart';

/// Answers GET /ugc/reporter/dashboard/ with [dashboard].
class _Dashboard implements HttpClientAdapter {
  Map<String, dynamic> dashboard = {'total_submissions': 0};
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<Uint8List>? _, Future<void>? __) async {
    calls++;
    return ResponseBody.fromString(
      jsonEncode({'data': dashboard, 'meta': {}, 'errors': null}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final state = AppState.instance;
  late _Dashboard api;

  /// What logout does to the verification: the active copy goes, the
  /// per-account memory stays.
  void simulateLogout() {
    state
      ..ugcMobileVerified = false
      ..ugcVerifiedMobile = ''
      ..userId = null
      ..isLoggedIn = false;
  }

  void login(String id) => state
    ..userId = id
    ..isLoggedIn = true;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    api = _Dashboard();
    ApiClient.instance.dio.httpClientAdapter = api;
    simulateLogout();
  });

  test('logout clears the local copy (handover §6); re-login re-checks',
      () async {
    login('u1');
    await state.markUgcMobileVerified('9876543210');
    simulateLogout();
    login('u1');
    // Nothing local: the backend is asked (dashboard here, then the kept
    // Firebase session on the verify screen) before any OTP.
    expect(await state.syncUgcVerificationFromServer(), isFalse);
    expect(api.calls, 1);
  });

  test('another account on the phone does not inherit it', () async {
    login('u1');
    await state.markUgcMobileVerified('9876543210');
    simulateLogout();

    login('u2');
    expect(await state.syncUgcVerificationFromServer(), isFalse);
    expect(state.uploadVerified, isFalse);
  });

  test('new phone: the server-reported verified mobile is used', () async {
    login('u3');
    api.dashboard = {
      'total_submissions': 1,
      'verified_mobile': '9014066807',
      'mobile_verified': true,
    };
    expect(await state.syncUgcVerificationFromServer(), isTrue);
    expect(state.ugcVerifiedMobile, '9014066807');
  });

  test('server without a mobile → OTP is still asked', () async {
    login('u4');
    api.dashboard = {'total_submissions': 1, 'reporter_level': 'verified_user'};
    expect(await state.syncUgcVerificationFromServer(), isFalse);
  });

  test('backend rejection forgets it for that account too', () async {
    login('u5');
    await state.markUgcMobileVerified('9876543210');
    await state.clearUgcVerification();
    simulateLogout();
    login('u5');
    expect(await state.syncUgcVerificationFromServer(), isFalse);
  });

  group('reading the server reply', () {
    String? read(Map<String, dynamic> m) => AppState.serverVerifiedMobile(m);

    test('verified_mobile, with or without +91', () {
      expect(read({'verified_mobile': '9876543210'}), '9876543210');
      expect(read({'verified_mobile': '+919876543210'}), '9876543210');
    });

    test('mobile counts only when flagged verified', () {
      expect(read({'mobile': '9876543210'}), isNull);
      expect(read({'mobile': '9876543210', 'mobile_verified': true}),
          '9876543210');
      expect(
          read({'verified_mobile': '9876543210', 'mobile_verified': false}),
          isNull);
    });

    test('nested ugc_profile', () {
      expect(read({'ugc_profile': {'verified_mobile': '9876543210'}}),
          '9876543210');
    });
  });
}
