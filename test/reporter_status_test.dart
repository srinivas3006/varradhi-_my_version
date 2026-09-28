import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/core/network/dio_client.dart';
import 'package:vaaradhi/state/app_state.dart';

/// Fake backend: /auth/me/ answers with [meId]; the reporter dashboard
/// answers with [submissions]. Every requested path is recorded.
class _Backend implements HttpClientAdapter {
  String meId = 'u1';
  int submissions = 0;
  final List<String> paths = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    paths.add(options.path);
    Object data = const {};
    if (options.path.endsWith('/auth/me/')) {
      data = {'id': meId, 'name': 'Reader'};
    } else if (options.path.endsWith('/ugc/reporter/dashboard/')) {
      data = {'total_submissions': submissions};
    }
    return ResponseBody.fromString(
      jsonEncode({'data': data, 'meta': {}, 'errors': null}),
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
  late _Backend backend;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (_) async => null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    backend = _Backend();
    ApiClient.instance.dio.httpClientAdapter = backend;
    state
      ..isLoggedIn = true
      ..authToken = 'token'
      ..refreshToken = null
      ..isReporter = false
      ..ugcMobileVerified = false
      ..ugcVerifiedMobile = '';
  });

  bool dashboardCalled() =>
      backend.paths.any((p) => p.endsWith('/ugc/reporter/dashboard/'));

  test('a reporter who logs out and back in is not asked to join again',
      () async {
    backend.meId = 'u1';
    await state.refreshRolesFromServer();
    state.registerAsReporter();
    expect(state.hasJoinedAsReporter, isTrue);

    await state.logout();
    expect(state.isReporter, isFalse,
        reason: 'the role belongs to the account, not the device');

    state
      ..isLoggedIn = true
      ..authToken = 'token';
    backend.paths.clear();
    await state.refreshRolesFromServer();
    expect(state.hasJoinedAsReporter, isTrue);
    expect(dashboardCalled(), isFalse,
        reason: 'the device record is enough; no extra request');
  });

  test('another account on the same device does not inherit the role',
      () async {
    backend.meId = 'someone-else';
    backend.submissions = 0;
    await state.refreshRolesFromServer();
    expect(state.hasJoinedAsReporter, isFalse);
  });

  test('an account with past submissions (new device / reinstall) skips join',
      () async {
    backend.meId = 'fresh-install';
    backend.submissions = 3;
    await state.refreshRolesFromServer();
    expect(dashboardCalled(), isTrue);
    expect(state.hasJoinedAsReporter, isTrue);
  });

  test('a verified UGC mobile means the account already joined', () {
    state
      ..ugcMobileVerified = true
      ..ugcVerifiedMobile = '6281732036';
    expect(state.isReporter, isFalse);
    expect(state.hasJoinedAsReporter, isTrue);
  });
}
