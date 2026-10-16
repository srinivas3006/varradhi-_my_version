import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/core/network/dio_client.dart';
import 'package:vaaradhi/services/api_service.dart';
import 'package:vaaradhi/state/app_state.dart';

/// Backend contract (Oct 2026): once a place is chosen, every main feed
/// call carries state, district, subdistrict and village; with no place
/// chosen none is sent (broad feed). Local calls send exactly what they ask.
class _Recorder implements HttpClientAdapter {
  final List<RequestOptions> calls = [];
  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<Uint8List>? _, Future<void>? __) async {
    calls.add(o);
    return ResponseBody.fromString(
        jsonEncode({'data': [], 'meta': {}, 'errors': null}), 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final app = AppState.instance;
  late _Recorder rec;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    rec = _Recorder();
    ApiClient.instance.dio.httpClientAdapter = rec;
    app
      ..stateName = 'Andhra Pradesh'
      ..district = 'Guntur'
      ..city = 'Guntur'
      ..subdistrict = 'Tenali'
      ..village = 'Kolakaluru';
  });

  tearDown(() {
    app
      ..hasValidLocation = false
      ..stateName = 'Telangana'
      ..district = 'Hyderabad'
      ..city = 'Hyderabad'
      ..subdistrict = ''
      ..village = '';
  });

  Map<String, dynamic> q() => rec.calls.single.queryParameters;

  group('a place is chosen: every main feed carries it', () {
    setUp(() => app.hasValidLocation = true);

    void expectPlace(Map<String, dynamic> p) {
      expect(p['state'], 'Andhra Pradesh');
      expect(p['district'], 'Guntur');
      expect(p['subdistrict'], 'Tenali');
      expect(p['village'], 'Kolakaluru');
    }

    test('/articles/feed/ scope=main', () async {
      await ApiService.instance.getNewsFeed(scope: 'main', lang: 'te');
      expect(rec.calls.single.path, '/api/v1/articles/feed/');
      expect(q()['scope'], 'main');
      expectPlace(q());
    });

    test('/ugc/feed/ scope=main', () async {
      await ApiService.instance.getUgcFeed(scope: 'main');
      expect(rec.calls.single.path, '/api/v1/ugc/feed/');
      expectPlace(q());
    });

    test('/feed/ sends scope=main and the place', () async {
      await ApiService.instance.getUnifiedFeed(include: 'all', lang: 'te');
      expect(rec.calls.single.path, '/api/v1/feed/');
      expect(q()['scope'], 'main');
      expectPlace(q());
    });

    test('feedPlace is the chosen place', () {
      expect(app.feedPlace.state, 'Andhra Pradesh');
      expect(app.feedPlace.village, 'Kolakaluru');
    });
  });

  group('no place chosen: no location sent (broad feed)', () {
    setUp(() => app.hasValidLocation = false);

    test('the Telangana placeholder never narrows the feed', () async {
      await ApiService.instance.getNewsFeed(scope: 'main', lang: 'te');
      for (final k in ['state', 'district', 'city', 'subdistrict', 'village']) {
        expect(q().containsKey(k), isFalse, reason: k);
      }
    });

    test('/ugc/feed/ and /feed/ too', () async {
      await ApiService.instance.getUgcFeed(scope: 'main');
      await ApiService.instance.getUnifiedFeed(include: 'all');
      for (final call in rec.calls) {
        expect(call.queryParameters.containsKey('state'), isFalse,
            reason: call.path);
        expect(call.queryParameters.containsKey('district'), isFalse,
            reason: call.path);
      }
    });

    test('feedPlace is empty', () {
      expect(app.feedPlace.state, isEmpty);
      expect(app.feedPlace.district, isEmpty);
    });
  });

  group('local sends exactly the level it asks for', () {
    setUp(() => app.hasValidLocation = true);

    test('a mandal request keeps the village out', () async {
      await ApiService.instance.getUgcFeed(
          scope: 'local',
          state: 'Andhra Pradesh',
          district: 'Guntur',
          subdistrict: 'Tenali');
      expect(q()['scope'], 'local');
      expect(q()['subdistrict'], 'Tenali');
      expect(q().containsKey('village'), isFalse);
    });

    test('an explicit empty value is never sent', () async {
      await ApiService.instance.getUgcFeed(
          scope: 'main', state: 'Andhra Pradesh', district: '', village: '');
      expect(q()['state'], 'Andhra Pradesh');
      expect(q().containsKey('district'), isFalse);
      expect(q().containsKey('village'), isFalse);
    });
  });
}
