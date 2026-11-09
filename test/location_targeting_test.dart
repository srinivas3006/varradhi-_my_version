import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/core/network/dio_client.dart';
import 'package:vaaradhi/features/reels/reels_screen.dart';
import 'package:vaaradhi/repositories/ad_repository.dart';
import 'package:vaaradhi/services/api_service.dart';
import 'package:vaaradhi/services/location_service.dart';
import 'package:vaaradhi/state/app_state.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body,
      Future<void>? cancel) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'data': [], 'meta': {}, 'errors': null}),
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

  const places = ['state', 'district', 'city', 'subdistrict', 'village'];
  final state = AppState.instance;
  late _Adapter adapter;
  late HttpClientAdapter previous;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    previous = ApiClient.instance.dio.httpClientAdapter;
    adapter = _Adapter();
    ApiClient.instance.dio.httpClientAdapter = adapter;
    AdRepository.instance.clearCache();
    state
      ..isLoggedIn = false
      ..hasValidLocation = false
      ..fcmToken = null
      ..deviceId = 'device-1'
      ..stateName = 'Telangana'
      ..district = 'Hyderabad'
      ..city = 'Hyderabad'
      ..subdistrict = ''
      ..village = '';
  });
  tearDown(() {
    ApiClient.instance.dio.httpClientAdapter = previous;
    state
      ..hasValidLocation = false
      ..fcmToken = null;
  });

  group('no saved location: nothing is sent', () {
    void expectNoPlace(Map<String, dynamic> query) {
      for (final key in places) {
        expect(query.containsKey(key), isFalse, reason: key);
      }
    }

    test('article feed, main and local', () async {
      await ApiService.instance.getNewsFeed(scope: 'main', forceRefresh: true);
      expectNoPlace(adapter.requests.last.queryParameters);
      await ApiService.instance.getNewsFeed(scope: 'local', forceRefresh: true);
      expectNoPlace(adapter.requests.last.queryParameters);
    });

    test('ads', () async {
      await AdRepository.instance.getAds(forceRefresh: true);
      expectNoPlace(adapter.requests.single.queryParameters);
    });

    test('guest registration: not the starting Hyderabad', () async {
      await ApiService.instance.registerGuestDevice(fcmToken: 'token');
      expectNoPlace(
          Map<String, dynamic>.from(adapter.requests.single.data as Map));
    });

    test('Reels', () {
      final location = ReelsScreen.readerLocation();
      for (final key in places) {
        expect(location[key], '', reason: key);
      }
    });
  });

  test('no saved location: no Hyderabad on screen either', () {
    expect(state.displayLocation, isNot(contains('Hyderabad')));
    expect(state.displayLocation, isNot(contains('హైదరాబాద్')));
    final nav = File('lib/widgets/bottom_nav_bar.dart').readAsStringSync();
    expect(nav, contains('s.feedPlace'));
    expect(nav, isNot(contains('s.village, s.subdistrict')));
  });

  group('a saved location', () {
    test('every level is sent; a district is not sent as the city', () async {
      state.setLocation('Telangana', 'Vikarabad',
          subdistrict: 'Mominpet', village: 'Velchal');
      expect(state.city, '');
      await ApiService.instance.getNewsFeed(scope: 'main', forceRefresh: true);
      final query = adapter.requests.last.queryParameters;
      expect(query['state'], 'Telangana');
      expect(query['district'], 'Vikarabad');
      expect(query['subdistrict'], 'Mominpet');
      expect(query['village'], 'Velchal');
      expect(query.containsKey('city'), isFalse);
    });

    test('a district-only reader sends no deeper level', () async {
      state.setLocation('Telangana', 'Vikarabad');
      await AdRepository.instance.getAds(forceRefresh: true);
      final query = adapter.requests.single.queryParameters;
      expect(query['district'], 'Vikarabad');
      for (final key in ['city', 'subdistrict', 'village']) {
        expect(query.containsKey(key), isFalse, reason: key);
      }
    });

    test('placeholder values are never kept', () {
      state.setLocation('Telangana', 'all',
          city: 'Unknown', subdistrict: 'undefined', village: '0');
      expect(state.district, '');
      expect(state.city, '');
      expect(state.subdistrict, '');
      expect(state.village, '');
      expect(AppState.cleanPlace(' null '), '');
      expect(AppState.cleanPlace(' Velchal '), 'Velchal');
    });

    test('a guest who changes place is registered again with it', () async {
      state.fcmToken = 'token';
      state.setLocation('Telangana', 'Vikarabad', subdistrict: 'Mominpet');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final body = adapter.requests
          .singleWhere((r) => r.path.contains('/guest-device/'))
          .data as Map;
      expect(body['district'], 'Vikarabad');
      expect(body['subdistrict'], 'Mominpet');
      expect(body.containsKey('city'), isFalse);
    });

    test('a logged-in reader does not use the guest registration', () async {
      state
        ..isLoggedIn = true
        ..fcmToken = 'token';
      state.setLocation('Telangana', 'Vikarabad');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(adapter.requests.where((r) => r.path.contains('/guest-device/')),
          isEmpty);
    });
  });

  test('older builds: a saved district-as-city is cleared once', () async {
    SharedPreferences.setMockInitialValues({
      'hasValidLocation': true,
      'stateName': 'Telangana',
      'district': 'Vikarabad',
      'city': 'Vikarabad',
    });
    await state.init();
    expect(state.city, '');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('city'), '');
  });

  group('nothing turns another level into the city', () {
    test('GPS result matched to the location database', () {
      final src = File('lib/services/location_service.dart')
          .readAsStringSync()
          .replaceAll('\r\n', '\n');
      expect(src, isNot(contains(': district;\n')));
      expect(src, isNot(contains('subdistrict : district)')));
      expect(DeviceLocation, isNotNull);
    });

    test('manual selection and admin approval', () {
      expect(File('lib/providers/location_provider.dart').readAsStringSync(),
          isNot(contains('city: result.nameEn')));
      final admin = File('lib/features/admin/presentation/widgets/dialogs/'
              'admin_approval_dialog.dart')
          .readAsStringSync();
      expect(admin, isNot(contains("'city': s.district")));
      expect(admin, isNot(contains('city: widget.submission.district')));
    });

    test('profile updates do not send the district as the mandal', () {
      expect(File('lib/services/api_service.dart').readAsStringSync(),
          isNot(contains('location.subdistrict ?? location.district')));
    });
  });

  test('logout always registers the device as a guest again', () {
    final src = File('lib/services/notification_service.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');
    final fn = src.substring(src.indexOf('Future<void> registerAsGuest'));
    expect(fn.substring(0, 300), isNot(contains('if (token != null')));
  });
}
