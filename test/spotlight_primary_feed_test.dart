import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:way2news_clone/core/navigation/notification_navigation_gate.dart';
import 'package:way2news_clone/core/network/dio_client.dart';
import 'package:way2news_clone/models/news_article.dart';
import 'package:way2news_clone/models/notification_target.dart';
import 'package:way2news_clone/screens/home_screen.dart';
import 'package:way2news_clone/screens/spotlight_screen.dart';
import 'package:way2news_clone/spotlight/spotlight_controller.dart';
import 'package:way2news_clone/spotlight/spotlight_screen.dart';
import 'package:way2news_clone/state/app_state.dart';
import 'package:way2news_clone/widgets/spotlight/spotlight_news_card.dart';

class SpotlightMockAdapter implements HttpClientAdapter {
  final List<Map<String, dynamic>> articles;

  SpotlightMockAdapter({this.articles = const []});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({
        'data': articles,
        'next_cursor': null,
        'has_more': false,
        'meta': {'total': articles.length},
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

NewsArticle _createTestArticle({
  required String id,
  required String title,
  String summary = 'Test summary of news article',
  String body = 'Full content body of news article for spotlight test.',
  String imageUrl = 'https://example.com/test.jpg',
  String source = 'Varadhi News',
  String category = 'General',
  String? district,
  String? state,
  String authorName = 'Staff Reporter',
  DateTime? publishedAt,
}) {
  return NewsArticle(
    id: id,
    title: title,
    summary: summary,
    body: body,
    imageUrl: imageUrl,
    source: source,
    category: category,
    publishedAt: publishedAt ?? DateTime.now(),
    likes: 12,
    comments: 4,
    shares: 2,
    readTimeMinutes: 2,
    viewCount: 150,
    district: district,
    state: state,
    authorName: authorName,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final Map<String, String> mockSecureStorage = {};

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel,
            (MethodCall methodCall) async {
      if (methodCall.method == 'read') {
        return mockSecureStorage[methodCall.arguments?['key']];
      } else if (methodCall.method == 'write') {
        final key = methodCall.arguments?['key'] as String?;
        final value = methodCall.arguments?['value'] as String?;
        if (key != null && value != null) {
          mockSecureStorage[key] = value;
        }
        return null;
      } else if (methodCall.method == 'delete') {
        mockSecureStorage.remove(methodCall.arguments?['key']);
        return null;
      } else if (methodCall.method == 'deleteAll') {
        mockSecureStorage.clear();
        return null;
      }
      return null;
    });
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    NotificationNavigationGate.instance.reset();
  });

  tearDown(() {
    NotificationNavigationGate.instance.reset();
  });

  group('Spotlight Controller & FeedRepository Integration', () {
    test('SpotlightController loads articles from FeedRepository into feed', () async {
      final sampleArticles = [
        {
          'id': 'art-1',
          'title': 'Hyderabad Tech Innovation Center Opens',
          'summary': 'Summary of article',
          'body': 'A state-of-the-art tech innovation center was inaugurated today.',
          'image_url': 'https://example.com/art1.jpg',
          'source': 'Varadhi',
          'category': 'Tech',
          'district': 'Hyderabad',
          'state': 'Telangana',
          'published_at': DateTime.now().toIso8601String(),
          'likes_count': 10,
          'comments_count': 1,
          'shares_count': 0,
        },
      ];

      ApiClient.instance.dio.httpClientAdapter =
          SpotlightMockAdapter(articles: sampleArticles);

      final controller = SpotlightController();
      expect(controller.state.isLoading, isTrue);

      await controller.loadFeed(refresh: true);

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.feed.length, equals(1));
      expect(controller.state.feed.first.article?.id, equals('art-1'));
      expect(controller.state.locationName, isNotEmpty);

      controller.dispose();
    });

    test('Category switching triggers clean state reset and re-query', () async {
      final articlesPol = [
        {
          'id': 'pol-1',
          'title': 'New Policy Announced',
          'summary': 'Summary of pol article',
          'body': 'Government announces new education policy.',
          'image_url': 'https://example.com/pol1.jpg',
          'source': 'Varadhi',
          'category': 'Politics',
          'published_at': DateTime.now().toIso8601String(),
          'likes_count': 5,
          'comments_count': 2,
          'shares_count': 1,
        }
      ];

      ApiClient.instance.dio.httpClientAdapter =
          SpotlightMockAdapter(articles: articlesPol);

      final controller = SpotlightController();
      await controller.loadFeed(refresh: true);

      await controller.selectCategory('Politics');
      expect(controller.state.selectedCategory, equals('Politics'));
      expect(controller.state.feed.isNotEmpty, isTrue);
      expect(controller.state.feed.first.article?.id, equals('pol-1'));

      controller.dispose();
    });

    test('Location update updates state location and triggers refresh', () async {
      final controller = SpotlightController();
      await controller.loadFeed(refresh: true);

      AppState.instance.district = 'Warangal';
      AppState.instance.stateName = 'Telangana';
      await controller.updateLocation();
      expect(controller.state.locationName, contains('Warangal'));

      controller.dispose();
    });
  });

  group('Spotlight News Card Rendering', () {
    testWidgets('Renders story title, content, location badge, and reporter attribution', (tester) async {
      final article = _createTestArticle(
        id: 'spotlight-card-1',
        title: 'Bumper Harvest in Guntur District',
        summary: 'Farmers celebrate high chilli yields this season across several mandals.',
        body: 'Farmers celebrate high chilli yields this season across several mandals.',
        category: 'Agriculture',
        district: 'Guntur',
        state: 'Andhra Pradesh',
        authorName: 'Ravi Kumar (Citizen Reporter)',
        publishedAt: DateTime.now().subtract(const Duration(minutes: 35)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpotlightNewsCard(
              article: article,
              isCurrent: true,
              onTap: () {},
              onShare: () {},
              onClose: () {},
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Bumper Harvest in Guntur District'), findsOneWidget);
      expect(find.textContaining('Farmers celebrate high chilli yields'), findsOneWidget);
      expect(find.text('Guntur'), findsOneWidget);
      expect(find.text('Ravi Kumar (Citizen Reporter)'), findsOneWidget);
    });
  });

  group('Spotlight Startup Navigation & Notification Priority', () {
    testWidgets('HomeScreen with openSpotlightOnStart pushes SpotlightScreen', (tester) async {
      ApiClient.instance.dio.httpClientAdapter =
          SpotlightMockAdapter(articles: []);

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(openSpotlightOnStart: true),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SpotlightScreen), findsOneWidget);
      expect(find.byType(SpotlightScreenView), findsOneWidget);
    });

    testWidgets('HomeScreen suppresses openSpotlightOnStart if pending notification target exists', (tester) async {
      ApiClient.instance.dio.httpClientAdapter =
          SpotlightMockAdapter(articles: []);

      // Register a pending notification target before HomeScreen mounts
      NotificationNavigationGate.instance.setPendingTarget(
        NotificationTarget.article(
          slugOrId: 'notif-article-999',
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(openSpotlightOnStart: true),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // SpotlightScreen should NOT be mounted since notification had priority
      expect(find.byType(SpotlightScreen), findsNothing);
    });

    testWidgets('SpotlightScreen top home button exits to HomeScreen cleanly', (tester) async {
      ApiClient.instance.dio.httpClientAdapter =
          SpotlightMockAdapter(articles: []);

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(openSpotlightOnStart: true),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SpotlightScreen), findsOneWidget);

      // Tap Home button
      final homeBtn = find.byKey(const Key('spotlight_home_btn'));
      expect(homeBtn, findsOneWidget);
      await tester.tap(homeBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Spotlight popped, returned cleanly to HomeScreen root shell
      expect(find.byType(SpotlightScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
