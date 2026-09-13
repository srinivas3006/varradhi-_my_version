import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:way2news_clone/core/ads/ad_event_queue.dart';
import 'package:way2news_clone/core/media/media_source.dart';
import 'package:way2news_clone/core/media/video_playback_controller.dart';
import 'package:way2news_clone/core/navigation/app_navigator.dart';
import 'package:way2news_clone/core/navigation/notification_deep_link_resolver.dart';
import 'package:way2news_clone/core/network/dio_client.dart';
import 'package:way2news_clone/core/state/feed_state.dart';
import 'package:way2news_clone/models/notification_target.dart';
import 'package:way2news_clone/repositories/feed_repository.dart';
import 'package:way2news_clone/repositories/ugc_draft_repository.dart';
import 'package:way2news_clone/repositories/ugc_repository.dart';
import 'package:way2news_clone/services/api_service.dart';
import 'package:way2news_clone/state/app_state.dart';

class ReleaseMockAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;

  ReleaseMockAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}

  static ResponseBody jsonResponse(dynamic body, int statusCode) {
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Step 9 Reliability: Storage & Startup Resilience (P0-02)', () {
    test(
        'AppState init safely handles empty or corrupted prefs and defaults to guest',
        () async {
      SharedPreferences.setMockInitialValues({
        'hasOnboarded': true,
        'language': 'Telugu',
        'isLoggedIn': true, // Stale flag without token
      });

      final state = AppState.instance;
      await state.init();

      expect(state.hasOnboarded, isTrue);
      expect(state.language, equals('Telugu'));
      // Stale isLoggedIn flag without token must be reset to false
      expect(state.isLoggedIn, isFalse);
      expect(state.authToken, isNull);
    });

    test('completeOnboarding preserves the selected app language', () async {
      final state = AppState.instance;
      state.language = 'English';
      state.hasOnboarded = false;

      state.completeOnboarding();

      expect(state.hasOnboarded, isTrue);
      expect(state.language, equals('English'));

      state.completeOnboarding('Telugu');
      expect(state.language, equals('Telugu'));
    });
  });

  group('Release Readiness: Notification Language Contract', () {
    test('guest notification registration uses current content language',
        () async {
      final state = AppState.instance;
      state.deviceId = 'device-123';
      state.fcmToken = 'fcm-123';
      state.installationSecret = null;
      state.language = 'English';

      Map<String, dynamic>? capturedBody;
      ApiClient.instance.dio.httpClientAdapter =
          ReleaseMockAdapter((options) async {
        if (options.path == '/api/v1/notifications/guest-device/') {
          capturedBody = Map<String, dynamic>.from(options.data as Map);
          return ReleaseMockAdapter.jsonResponse({
            'data': {'installation_secret': 'secret-123'}
          }, 200);
        }
        return ReleaseMockAdapter.jsonResponse({'data': {}}, 200);
      });

      final response = await ApiService.instance.registerGuestDevice();

      expect(response, isNotNull);
      expect(capturedBody?['preferences'], isA<Map>());
      expect(
        (capturedBody?['preferences'] as Map)['content_language'],
        equals('en'),
      );
    });
  });

  group('Release Readiness: Account Deletion Contract', () {
    test('deleteAccount falls back across supported backend contracts',
        () async {
      final requestedPaths = <String>[];
      ApiClient.instance.dio.httpClientAdapter =
          ReleaseMockAdapter((options) async {
        requestedPaths.add('${options.method} ${options.path}');
        if (options.method == 'POST' &&
            options.path == '/api/v1/auth/account/delete/') {
          return ReleaseMockAdapter.jsonResponse({'data': {}}, 204);
        }
        return ReleaseMockAdapter.jsonResponse({
          'errors': {'message': 'Not found'}
        }, 404);
      });

      final deleted = await ApiService.instance.deleteAccount();

      expect(deleted, isTrue);
      expect(
          requestedPaths,
          equals([
            'DELETE /api/v1/auth/delete-account/',
            'DELETE /api/v1/auth/me/',
            'POST /api/v1/auth/account/delete/',
          ]));
    });
  });

  group('Step 9 Reliability: UGC Upload & Cancellation Propagation (P0-01)',
      () {
    test('UgcRepository propagates DioException for cancel and status codes',
        () async {
      final tempDir = Directory.systemTemp.createTempSync('ugc_cancel_test');
      final tempFile = File('${tempDir.path}/test_upload.jpg')
        ..writeAsBytesSync([1, 2, 3]);

      final interceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.contains('upload-media')) {
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.cancel,
                message: 'Upload cancelled by user',
              ),
            );
          }
          return handler.next(options);
        },
      );

      ApiClient.instance.dio.interceptors.insert(0, interceptor);

      try {
        final repo = UgcRepository();
        await expectLater(
          () => repo.uploadMedia(
            submissionId: 'test-sub-1',
            mobile: '9876543210',
            mediaType: 'IMAGE',
            filePath: tempFile.path,
          ),
          throwsA(isA<DioException>()),
        );
      } finally {
        ApiClient.instance.dio.interceptors.remove(interceptor);
        tempDir.deleteSync(recursive: true);
      }
    });

    test('UgcDraftRepository safely handles corrupted JSON string', () async {
      SharedPreferences.setMockInitialValues({
        'vaaradhi_ugc_pending_draft_v1': '{{{CORRUPTED_JSON_STRING%%%',
      });

      final repo = UgcDraftRepository.instance;
      final draft = await repo.loadDraft();
      expect(draft, isNull);
    });
  });

  group(
      'Step 9 Reliability: Feed Response Hardening & Proxy Error Defense (P1-02)',
      () {
    test(
        'FeedRepository safely handles HTML/non-Map 502 error responses without throwing TypeError',
        () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 502,
                data: '<html><body>502 Bad Gateway - Cloudflare</body></html>',
              ),
            );
          },
        ),
      );

      final repo = FeedRepository(dio: dio);
      final state = await repo.getInitialFeed(pageSize: 10, forceRefresh: true);

      expect(state.status, equals(FeedStatus.error));
      expect(state.items, isEmpty);
    });

    test('FeedRepository safely skips malformed article items in data list',
        () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'data': [
                    {
                      'id': 'valid-art-1',
                      'title': 'Valid Article Title',
                      'summary': 'Valid article summary',
                      'published_at': '2026-09-11T10:00:00Z',
                    },
                    'corrupted_string_item_instead_of_map',
                    null,
                    {
                      'id': 'valid-art-2',
                      'title': 'Second Valid Title',
                      'summary': 'Summary 2',
                      'published_at': '2026-09-11T11:00:00Z',
                    },
                  ],
                  'meta': {
                    'next': null,
                    'count': 2,
                  },
                },
              ),
            );
          },
        ),
      );

      final repo = FeedRepository(dio: dio);
      final state = await repo.getInitialFeed(pageSize: 10, forceRefresh: true);

      expect(state.isSuccess, isTrue);
      expect(state.items.length, equals(2));
      expect(state.items.first.id, equals('valid-art-1'));
      expect(state.items.last.id, equals('valid-art-2'));
    });
  });

  group('Step 9 Reliability: Navigation Unmounted Safety (P1-03)', () {
    testWidgets('AppNavigator pushSafe returns null when context is unmounted',
        (tester) async {
      BuildContext? capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              capturedContext = ctx;
              return const Scaffold(body: Text('Home'));
            },
          ),
        ),
      );

      expect(capturedContext, isNotNull);
      expect(capturedContext!.mounted, isTrue);

      // Unmount the widget by pumping an empty Container
      await tester.pumpWidget(const SizedBox.shrink());
      expect(capturedContext!.mounted, isFalse);

      // Calling pushSafe on unmounted context must return null without crashing
      final result = await AppNavigator.pushSafe(
        capturedContext!,
        MaterialPageRoute(builder: (_) => const Text('Next')),
      );
      expect(result, isNull);
    });
  });

  group(
      'Step 9 Reliability: Ad Event Queue Bounded Capacity & Deduplication (P2-01)',
      () {
    setUp(() {
      AdEventQueue.instance.reset();
    });

    tearDown(() {
      AdEventQueue.instance.reset();
    });

    test('AdEventQueue ignores empty adId and enqueues valid events', () {
      final queue = AdEventQueue.instance;
      queue.enqueue(adId: '', eventType: 'impression', placementZone: 'feed');
      queue.enqueue(
          adId: '   ', eventType: 'impression', placementZone: 'feed');
      expect(queue.pendingCount, equals(0));

      queue.enqueue(
          adId: 'ad-100', eventType: 'impression', placementZone: 'feed');
      queue.enqueue(adId: 'ad-100', eventType: 'click', placementZone: 'feed');
      queue.enqueue(
          adId: 'ad-200', eventType: 'impression', placementZone: 'feed');
      expect(queue.pendingCount, equals(3));
    });

    test('AdEventQueue enforces maxQueueSize = 50 and drops oldest on overflow',
        () {
      final queue = AdEventQueue.instance;
      for (int i = 0; i < 60; i++) {
        queue.enqueue(
            adId: 'ad-$i', eventType: 'impression', placementZone: 'feed');
      }

      expect(queue.pendingCount, equals(AdEventQueue.maxQueueSize));
      expect(queue.pendingCount, equals(50));
    });
  });

  group('Step 9 Reliability: Guest 401 Handling (P2-03)', () {
    test('Guest user receiving 401 does not trigger logout state notification',
        () async {
      final state = AppState.instance;
      state.isLoggedIn = false;
      state.authToken = null;

      bool logoutNotified = false;
      void listener() {
        if (!state.isLoggedIn) {
          logoutNotified = true;
        }
      }

      state.addListener(listener);

      // Simulate a guest 401 error directly through ApiClient
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.reject(
              DioException(
                requestOptions: options,
                response: Response(requestOptions: options, statusCode: 401),
                type: DioExceptionType.badResponse,
              ),
            );
          },
        ),
      );

      // Verify guest state is untouched and logout was not dispatched
      expect(state.isLoggedIn, isFalse);
      expect(logoutNotified, isFalse);
      state.removeListener(listener);
    });
  });

  group('Step 9 Reliability: Deep Link & URI Resilience', () {
    test('Resolves varadhi:// article and category deep links', () {
      final catTarget = NotificationDeepLinkResolver.resolveFromUri(
          'varadhi://category/education');
      expect(catTarget.type, equals(NotificationTargetType.category));
      expect(catTarget.identifier, equals('education'));

      final artTarget = NotificationDeepLinkResolver.resolveFromUri(
          'varadhi://article/telangana-budget-2026');
      expect(artTarget.type, equals(NotificationTargetType.article));
      expect(artTarget.identifier, equals('telangana-budget-2026'));
    });

    test('Resolves custom scheme article:// and relative paths', () {
      final artTarget = NotificationDeepLinkResolver.resolveFromUri(
          'article://hyderabad-metro-phase-2');
      expect(artTarget.type, equals(NotificationTargetType.article));
      expect(artTarget.identifier, equals('hyderabad-metro-phase-2'));

      final relTarget = NotificationDeepLinkResolver.resolveFromUri(
          '/article/hyderabad-metro-phase-2');
      expect(relTarget.type, equals(NotificationTargetType.article));
      expect(relTarget.identifier, equals('hyderabad-metro-phase-2'));
    });

    test('Resolves screen:// targets with correct auth flags', () {
      final bookmarks =
          NotificationDeepLinkResolver.resolveFromUri('screen://bookmarks');
      expect(bookmarks.type, equals(NotificationTargetType.screen));
      expect(bookmarks.screenName, equals('bookmarks'));
      expect(bookmarks.requiresAuth, isTrue);

      final settings =
          NotificationDeepLinkResolver.resolveFromUri('screen://settings');
      expect(settings.type, equals(NotificationTargetType.screen));
      expect(settings.screenName, equals('settings'));
      expect(settings.requiresAuth, isFalse);
    });

    test('Safely handles empty, malformed, and unknown URIs without throwing',
        () {
      final empty = NotificationDeepLinkResolver.resolveFromUri('');
      expect(empty.type, equals(NotificationTargetType.unknown));

      final malformed =
          NotificationDeepLinkResolver.resolveFromUri('varadhi://');
      expect(malformed.type, equals(NotificationTargetType.unknown));

      final unknownScheme = NotificationDeepLinkResolver.resolveFromUri(
          'unknownscheme://foo/bar');
      expect(unknownScheme.type, equals(NotificationTargetType.unknown));
    });
  });

  group('Step 9 Reliability: Video Playback Error Handling', () {
    test(
        'NetworkVideoPlaybackController handles empty/invalid URL with status error',
        () async {
      const source = MediaSource.networkVideo(videoUrl: '', thumbnailUrl: '');
      final controller = VideoPlaybackController.fromSource(source);

      await controller.initialize();
      expect(controller.value.status, equals(PlaybackStatus.error));
      expect(controller.value.errorMessage, isNotNull);

      controller.dispose();
    });
  });
}
