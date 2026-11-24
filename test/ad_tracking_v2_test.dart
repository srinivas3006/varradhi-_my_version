import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:vaaradhi/core/ads/ad_event_queue.dart';
import 'package:vaaradhi/core/ads/ad_video_measurement.dart';
import 'package:vaaradhi/core/media/video_playback_controller.dart';
import 'package:vaaradhi/core/network/dio_client.dart';
import 'package:vaaradhi/models/ad_banner.dart';
import 'package:vaaradhi/repositories/ad_repository.dart';
import 'package:vaaradhi/state/app_state.dart';
import 'package:vaaradhi/widgets/ads/ad_viewability_detector.dart';

const _device = 'stable-reader';
Map<String, dynamic> _offer(
        {String zone = 'article_end', bool expired = false}) =>
    {
      'id': 'creative-id',
      'image_url': 'https://example.com/selected.png',
      'destination_url': 'https://example.com/selected',
      'ad_type': 'banner',
      'placement_zone': zone,
      'tracking': {
        'tracking_version': 2,
        'exposure_id': 'opaque-exposure',
        'exposure_expires_at': DateTime.now()
            .add(Duration(minutes: expired ? -2 : 2))
            .toIso8601String(),
        'variant_id': 'chosen-variant',
      },
    };

Dio _dio(FutureOr<Object?> Function(RequestOptions) respond) => Dio()
  ..interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
    final payload = await respond(options);
    if (payload is DioException) {
      handler.reject(payload);
    } else {
      handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {'data': payload, 'errors': null}));
    }
  }));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final app = AppState.instance;
  setUp(() {
    app.deviceId = _device;
    app.hasValidLocation = false;
  });

  test('decision binds the real creative to its device, variant and placement',
      () async {
    final request = <RequestOptions>[];
    final repo = AdRepository.test(dio: _dio((options) {
      request.add(options);
      return {
        'should_show': true,
        'ads': [_offer()]
      };
    }));
    final ad = await repo.decide(
        placementZone: 'article_end',
        language: 'te',
        category: 'sports',
        areaId: 'unknown');
    expect(ad?.id, 'creative-id');
    expect(ad?.exposure?.id, 'opaque-exposure');
    expect(ad?.exposure?.variantId, 'chosen-variant');
    expect(ad?.imageUrl, 'https://example.com/selected.png');
    final wire = request.single;
    expect(wire.path, '/api/v1/ads/decision/');
    expect(wire.headers['X-Device-ID'], _device);
    expect(wire.data, {
      'tracking_version': 2,
      'placement_zone': 'article_end',
      'limit': 1,
      'language': 'te',
      'category': 'sports',
    });
  });

  test('declined, wrong-zone, expired and stale decisions leave the slot empty',
      () async {
    final responses = <Object>[
      {
        'should_show': false,
        'ads': [_offer()]
      },
      {
        'should_show': true,
        'ads': [_offer(zone: 'feed')]
      },
      {
        'should_show': true,
        'ads': [_offer(expired: true)]
      },
    ];
    final repo = AdRepository.test(dio: _dio((_) => responses.removeAt(0)));
    for (var i = 0; i < 3; i++) {
      expect(await repo.decide(placementZone: 'article_end'), isNull);
    }
    final started = Completer<void>();
    final response = Completer<Object>();
    final pendingRepo = AdRepository.test(dio: _dio((_) {
      started.complete();
      return response.future;
    }));
    final pending = pendingRepo.decide(placementZone: 'article_end');
    await started.future;
    app.deviceId = 'different-reader';
    response.complete({
      'should_show': true,
      'ads': [_offer()]
    });
    expect(await pending, isNull);
  });

  test('tracked list is never reused as cached inventory', () async {
    final requests = <RequestOptions>[];
    final repo = AdRepository.test(dio: _dio((request) {
      requests.add(request);
      return [_offer()];
    }));
    for (var i = 0; i < 2; i++) {
      final response =
          await repo.getAds(placementZone: 'article_end', trackingV2: true);
      expect(response.data, hasLength(1));
    }
    expect(requests, hasLength(2));
    expect(requests.first.queryParameters['tracking_version'], 2);
  });

  test(
      'accepted duplicate impression precedes click-through and preserves identity',
      () async {
    final requests = <RequestOptions>[];
    final queue = AdEventQueue(dio: _dio((options) {
      requests.add(options);
      return {
        'recorded': false,
        if (options.path.endsWith('click-through/'))
          'destination_url': 'https://example.com/signed',
      };
    }));
    final ad = AdBanner.fromJson(_offer(), deviceId: _device);
    Future<Map?> track(String event) => queue.enqueue(
        adId: ad.id,
        eventType: event,
        exposure: ad.exposure,
        placementZone: ad.placementZone);
    expect(await track('click'), isNull);
    final impressions = [track('impression'), track('impression')];
    app.deviceId = 'changed';
    final click = track('click');
    await Future.wait(impressions);
    expect((await click)?['destination_url'], 'https://example.com/signed');
    expect(requests.map((item) => item.path), [
      '/api/v1/ads/event/',
      '/api/v1/ads/click-through/',
    ]);
    expect(requests.every((r) => r.headers['X-Device-ID'] == _device), isTrue);
    expect(requests.first.data, {
      'ad_id': ad.id,
      'event_type': 'impression',
      'placement_zone': 'article_end',
      'tracking_version': 2,
      'exposure_id': ad.exposure!.id,
    });
    expect(requests.last.data, {'exposure_id': ad.exposure!.id});
  });

  test('permanent exposure rejection invalidates without retry or downgrade',
      () async {
    var attempts = 0;
    final queue = AdEventQueue(dio: _dio((options) {
      attempts++;
      return DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: options, statusCode: 400, data: {
            'errors': {
              'details': {
                'exposure_id': ['Expired']
              }
            }
          }));
    }));
    final ad = AdBanner.fromJson(_offer(), deviceId: _device);
    expect(
        await queue.enqueue(
            adId: ad.id,
            eventType: 'impression',
            placementZone: ad.placementZone,
            exposure: ad.exposure),
        isNull);
    expect(queue.isInvalid(ad.exposure), isTrue);
    expect(
        await queue.enqueue(
            adId: ad.id,
            eventType: 'impression',
            placementZone: ad.placementZone,
            exposure: ad.exposure),
        isNull);
    expect(attempts, 1);
  });

  test('video requires real position and watch progress for quartiles', () {
    final measurement = AdVideoMeasurement(selectedDurationMs: 10000);
    List<String> sample(int wall, int position,
            [PlaybackStatus status = PlaybackStatus.playing]) =>
        measurement.sample(
            VideoPlaybackState(
                status: status,
                position: Duration(milliseconds: position),
                duration: const Duration(seconds: 12)),
            wall,
            eligible: true);
    expect(sample(0, 0), isEmpty);
    expect(sample(1000, 1000), ['video_start']);
    expect(sample(1100, 9500), isEmpty);
    expect(measurement.telemetry['watch_time_ms'], 1000);
    expect(sample(2500, 9600, PlaybackStatus.buffering), isEmpty);
    expect(measurement.continuousMs, 0);
    measurement.interrupt();
    expect(sample(3000, 1000), isEmpty);
    expect(sample(4000, 2000), isEmpty);
    expect(sample(4500, 2500), ['video_25']);
    expect(measurement.telemetry['video_duration_ms'], 10000);
    expect(measurement.telemetry['watch_time_ms'], 2500);
  });

  test('Retry-After retries the same request', () async {
    final requests = <RequestOptions>[];
    final queue = AdEventQueue(dio: _dio((options) {
      requests.add(options);
      if (requests.length == 1) {
        return DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response(
                requestOptions: options,
                statusCode: 429,
                headers: Headers.fromMap({
                  'retry-after': ['0']
                })));
      }
      return {'recorded': true};
    }));
    final ad = AdBanner.fromJson(_offer(), deviceId: _device);
    expect(
        await queue.enqueue(
            adId: ad.id,
            eventType: 'impression',
            placementZone: ad.placementZone,
            exposure: ad.exposure),
        {'recorded': true});
    expect(requests, hasLength(2));
    expect(requests.last.data, requests.first.data);
    expect(requests.last.headers['X-Device-ID'], _device);
  });

  testWidgets(
      'v2 starts with a painted frame and requires continuous 50% visibility',
      (tester) async {
    final events = <Map>[];
    final dio = ApiClient.instance.dio;
    final interceptor = InterceptorsWrapper(onRequest: (options, handler) {
      if (options.path != '/api/v1/ads/event/') {
        handler.next(options);
        return;
      }
      events.add(options.data as Map);
      handler.resolve(Response(requestOptions: options, statusCode: 200, data: {
        'data': {'recorded': true},
        'errors': null
      }));
    });
    dio.interceptors.insert(0, interceptor);
    addTearDown(() => dio.interceptors.remove(interceptor));
    addTearDown(AdEventQueue.instance.reset);
    final detector = VisibilityDetectorController.instance;
    final originalInterval = detector.updateInterval;
    detector.updateInterval = Duration.zero;
    addTearDown(() => detector.updateInterval = originalInterval);
    final ad = AdBanner.fromJson(_offer(), deviceId: _device);
    final image = MemoryImage(base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4r5T2HwAGMgKHJ+9AYgAAAABJRU5ErkJggg=='));
    await tester.runAsync(() async {
      final stream = image.resolve(ImageConfiguration.empty);
      final loaded = Completer<void>();
      final listener = ImageStreamListener((_, __) => loaded.complete(),
          onError: (error, stack) => loaded.completeError(error, stack));
      stream.addListener(listener);
      try {
        await loaded.future;
      } finally {
        stream.removeListener(listener);
      }
    });

    Future<void> show(double top, {required bool loaded}) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
            width: 100,
            height: 100,
            child: Stack(children: [
              Positioned(
                top: top,
                width: 100,
                height: 100,
                child: AdViewabilityDetector(
                    ad: ad,
                    placementZone: ad.placementZone,
                    child: loaded
                        ? Builder(
                            builder: (context) =>
                                AdViewabilityDetector.imageBuilder(ad)!(
                                    context, image))
                        : const ColoredBox(color: Colors.grey)),
              ),
            ])),
      ))));
      await tester.pump();
    }

    await show(0, loaded: false);
    await tester.pump(const Duration(seconds: 2));
    expect(events, isEmpty);
    await show(-51, loaded: true);
    await tester.pump(const Duration(seconds: 2));
    expect(events.map((e) => e['event_type']), ['impression']);
    await show(-50, loaded: true);
    await tester.pump(const Duration(milliseconds: 900));
    expect(events, hasLength(1));
    await show(-51, loaded: true);
    await show(-50, loaded: true);
    await tester.pump(const Duration(seconds: 1));
    expect(events.map((e) => e['event_type']), ['impression', 'viewability']);
    expect(events.last['visible_fraction'], closeTo(0.5, 0.001));
    await tester.pumpWidget(const SizedBox());
  });
}
