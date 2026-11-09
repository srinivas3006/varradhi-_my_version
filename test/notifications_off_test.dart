import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/core/network/dio_client.dart';
import 'package:vaaradhi/services/api_service.dart';
import 'package:vaaradhi/services/notification_service.dart';
import 'package:vaaradhi/state/app_state.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body,
      Future<void>? cancel) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({
        'data': {'installation_secret': 'secret'},
        'errors': null,
      }),
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

  late _Adapter adapter;
  late HttpClientAdapter previous;
  late int drops;
  final state = AppState.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    previous = ApiClient.instance.dio.httpClientAdapter;
    adapter = _Adapter();
    ApiClient.instance.dio.httpClientAdapter = adapter;
    drops = 0;
    ApiService.fcmTokenDropper = () async => drops++;
    state.isLoggedIn = false;
    state.fcmToken = 'old-token';
    state.deviceId = 'device-1';
    state.pushNotificationsEnabled = false;
  });
  tearDown(() {
    ApiClient.instance.dio.httpClientAdapter = previous;
    ApiService.fcmTokenDropper = null;
    state.pushNotificationsEnabled = true;
    state.fcmToken = null;
    state.installationSecret = null;
  });

  Iterable<RequestOptions> tokenCalls() => adapter.requests.where((r) =>
      r.path.contains('/guest-device/') || r.path.contains('/device-token/'));

  group('notifications off', () {
    test('no token is registered', () async {
      state.installationSecret = 'secret';
      await ApiService.instance.updateFcmToken('new-token');
      await ApiService.instance.registerGuestDevice(fcmToken: 'new-token');
      await ApiService.instance.handoffDeviceToken(fcmToken: 'new-token');
      expect(tokenCalls(), isEmpty);
    });

    test('a phone with no credential still gets one, then loses the token',
        () async {
      state.installationSecret = null;
      await ApiService.instance.registerGuestDevice(fcmToken: 'tmp-token');
      final call = tokenCalls().single;
      expect((call.data as Map)['preferences']['enabled'], isFalse);
      expect(state.installationSecret, 'secret');
      expect(drops, 1, reason: 'the token used to register must not stay');
    });

    test('login recovery can register, and the token does not stay', () async {
      state.installationSecret = 'lost';
      await ApiService.instance.recoverInstallation('tmp-token');
      expect(tokenCalls(), isNotEmpty);
      expect(drops, greaterThan(0));
    });

    test('a guest turning off tells the backend, then loses the token',
        () async {
      state
        ..pushNotificationsEnabled = true
        ..installationSecret = 'secret'
        ..fcmToken = 'old-token';
      await NotificationService.instance.setPushEnabled(false);
      final call = tokenCalls().single;
      expect((call.data as Map)['fcm_token'], 'old-token');
      expect((call.data as Map)['preferences']['enabled'], isFalse);
      expect(drops, greaterThan(0));
      expect(state.fcmToken, isNull);
    });

    test('dropping forgets the token on this phone', () async {
      await ApiService.instance.dropFcmToken();
      expect(state.fcmToken, isNull);
      expect(drops, 1);
    });

    test('the switch stays off after a restart', () async {
      await NotificationService.instance.setPushEnabled(false);
      await Future<void>.delayed(Duration.zero);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('pushNotificationsEnabled'), isFalse);
      expect(state.pushNotificationsEnabled, isFalse);
    });
  });

  test('notifications on: the token is registered as before', () async {
    state.pushNotificationsEnabled = true;
    state.installationSecret = 'secret';
    await ApiService.instance.registerGuestDevice(fcmToken: 'token');
    final call = tokenCalls().single;
    final preferences = (call.data as Map)['preferences'] as Map;
    expect(preferences['enabled'], isTrue);
    expect(drops, 0);
    // The backend's defaults decide the limits.
    expect(preferences.containsKey('max_per_hour'), isFalse);
    expect(preferences.containsKey('max_per_day'), isFalse);
  });

  test('saving settings does not send delivery limits', () {
    final src = File('lib/screens/notification_settings_screen.dart')
        .readAsStringSync();
    expect(src, isNot(contains("'max_per_hour':")));
    expect(src, isNot(contains("'max_per_day':")));
  });

  group('every way in respects the switch', () {
    final src = File('lib/services/notification_service.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');

    test('Profile bell and the settings switch act on the token', () {
      final profile = File('lib/screens/profile_tab.dart').readAsStringSync();
      expect(profile, contains('.setPushEnabled('));
      expect(profile, isNot(contains('state.togglePushNotifications(')));
      final settings = File('lib/screens/notification_settings_screen.dart')
          .readAsStringSync();
      expect(settings, contains('.setPushEnabled(val, syncAccount: false)'));
    });

    test('off removes the token; a push on its way is dropped', () {
      final apply = src.substring(src.indexOf('Future<void> _applyPushSetting'),
          src.indexOf('/// Creates the channel'));
      expect(apply, contains('setAutoInitEnabled(enabled)'));
      expect(apply, contains('dropFcmToken()'));
      final onMessage = src.substring(
          src.indexOf('FirebaseMessaging.onMessage.listen'),
          src.indexOf('final data = message.data;',
              src.indexOf('FirebaseMessaging.onMessage.listen')));
      expect(onMessage, contains('pushNotificationsEnabled) return'));
    });

    test('startup, token refresh and the permission step get no new token', () {
      expect(
          src,
          contains('if (!AppState.instance.pushNotificationsEnabled) {\n'
              '        unawaited(_applyPushSetting());'));
      final refresh = src.substring(src.indexOf('onTokenRefresh.listen'));
      expect(refresh.substring(0, 120), contains('pushNotificationsEnabled'));
      final permission = src.substring(
          src.indexOf('requestPermissionAfterArticlesLoaded() async'));
      expect(
          permission.substring(0, 120), contains('pushNotificationsEnabled'));
    });
  });
}
