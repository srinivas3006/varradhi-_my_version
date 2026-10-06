import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/core/network/dio_client.dart';
import 'package:vaaradhi/repositories/feed_repository.dart';
import 'package:vaaradhi/repositories/home_feed_repository.dart';
import 'package:vaaradhi/services/api_service.dart';
import 'package:vaaradhi/state/app_state.dart';

/// Records every request and answers with an empty feed.
class _Recorder implements HttpClientAdapter {
  final List<Uri> seen = [];

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<Uint8List>? _, Future<void>? __) async {
    seen.add(o.uri);
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
  late _Recorder api;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    api = _Recorder();
    ApiClient.instance.dio.httpClientAdapter = api;
    await AppState.instance.setContentLanguage(null); // "All languages"
  });

  // With no `lang` the backend picks its own default — `en` for a guest,
  // the account's language once logged in — so the same reader saw
  // different stories before and after login.
  group('every feed sends lang explicitly, the same for guest and account',
      () {
    for (final ui in ['Telugu', 'English']) {
      test('Spotlight /articles/feed/ (interface $ui)', () async {
        AppState.instance.language = ui;
        await FeedRepository(dio: ApiClient.instance.dio)
            .getInitialFeed(scope: 'main', forceRefresh: true);
        final q = api.seen.last.queryParameters;
        expect(api.seen.last.path, '/api/v1/articles/feed/');
        expect(q['lang'], 'all',
            reason: 'never derived from the interface language');
      });
    }

    test('Home Latest /feed/', () async {
      try {
        await HomeFeedRepository.instance.fetchLatest(
            lang: AppState.instance.contentLanguage,
            state: '',
            district: '',
            subdistrict: '',
            village: '');
      } catch (_) {}
      final latest = api.seen.lastWhere((u) => u.path == '/api/v1/feed/');
      expect(latest.queryParameters['lang'], 'all');
    });

    test('UGC feed and live news send lang too', () async {
      await ApiService.instance.getUgcFeed();
      await ApiService.instance.getLiveNews();
      final ugc = api.seen.lastWhere((u) => u.path == '/api/v1/ugc/feed/');
      final live = api.seen.lastWhere((u) => u.path == '/api/v1/articles/live/');
      expect(ugc.queryParameters['lang'], 'all');
      expect(live.queryParameters['lang'], 'all');
    });

    test('a chosen news language is sent as is', () async {
      await AppState.instance.setContentLanguage('te');
      await FeedRepository(dio: ApiClient.instance.dio)
          .getInitialFeed(scope: 'main', forceRefresh: true);
      expect(api.seen.last.queryParameters['lang'], 'te');
      await AppState.instance.setContentLanguage(null);
    });
  });
}
