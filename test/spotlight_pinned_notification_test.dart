import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/core/network/dio_client.dart';
import 'package:vaaradhi/models/news_article.dart';
import 'package:vaaradhi/spotlight/spotlight_controller.dart';
import 'package:vaaradhi/state/app_state.dart';

class _FeedAdapter implements HttpClientAdapter {
  _FeedAdapter(this.articles);
  final List<Map<String, dynamic>> articles;

  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<Uint8List>? _, Future<void>? __) async {
    return ResponseBody.fromString(
      jsonEncode({
        'data': options.path.contains('/articles/feed/') ? articles : [],
        'next_cursor': null,
        'has_more': false,
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

Map<String, dynamic> _json(String id, DateTime at) => {
      'id': id,
      'title': 'Story $id',
      'summary': 'Summary',
      'body': 'Body',
      'image_url': 'https://example.com/$id.jpg',
      'source': 'Varadhi',
      'category': 'General',
      'published_at': at.toIso8601String(),
    };

/// A tapped notification opens its story in Spotlight, as the first card.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    AppState.instance.contentLanguagePrompted = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (_) async => null);
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final now = DateTime.now();
  // Older than everything in the feed, so it would not be first by date.
  final pinned = NewsArticle.fromJson(
      _json('pinned-1', now.subtract(const Duration(days: 3))));

  test('the notified story is shown at once, before the feed loads', () {
    ApiClient.instance.dio.httpClientAdapter = _FeedAdapter(const []);
    final c = SpotlightController(pinnedArticle: pinned);
    expect(c.state.isLoading, isFalse);
    expect(c.state.feed.single.article?.id, 'pinned-1');
    c.dispose();
  });

  test('it stays first when the feed arrives, without a duplicate', () async {
    ApiClient.instance.dio.httpClientAdapter = _FeedAdapter([
      _json('newer-1', now),
      _json('pinned-1', now.subtract(const Duration(days: 3))),
    ]);
    final c = SpotlightController(pinnedArticle: pinned);
    await c.loadFeed(refresh: true);
    final ids = c.state.feed.map((i) => i.article?.id).whereType<String>();
    expect(ids.first, 'pinned-1');
    expect(ids.where((id) => id == 'pinned-1').length, 1);
    expect(ids, contains('newer-1'));
    c.dispose();
  });

  test('changing category releases the pin', () async {
    ApiClient.instance.dio.httpClientAdapter =
        _FeedAdapter([_json('newer-1', now)]);
    final c = SpotlightController(pinnedArticle: pinned);
    await c.loadFeed(refresh: true);
    await c.selectCategory('Politics');
    final ids = c.state.feed.map((i) => i.article?.id).whereType<String>();
    expect(ids, isNot(contains('pinned-1')));
    c.dispose();
  });

  test('article and UGC notifications open Spotlight', () {
    final src =
        File('lib/services/notification_service.dart').readAsStringSync();
    final router = src.substring(src.indexOf('Future<void> navigateToTarget('));
    expect(
        RegExp(r'_openInSpotlight\(').allMatches(router).length,
        greaterThanOrEqualTo(2));
    expect(router, contains('SpotlightScreen('));
  });
}
