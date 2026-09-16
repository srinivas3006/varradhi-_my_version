import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:way2news_clone/core/ads/ad_event_queue.dart';
import 'package:way2news_clone/core/network/dio_client.dart';
import 'package:way2news_clone/services/ad_manager.dart';
import 'package:way2news_clone/state/app_state.dart';
import 'package:way2news_clone/widgets/ads/ad_viewability_detector.dart';
import 'package:way2news_clone/widgets/ads/sponsored_spotlight_ad_card.dart';
import 'package:way2news_clone/widgets/article_media_carousel.dart';
import 'package:way2news_clone/core/widgets/flip_page_view.dart';
import 'support/integration_contract_cases.dart';

class _AdAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(
        jsonEncode({
          'data': {'recorded': true},
          'meta': {},
          'errors': null
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _AdAdapter adapter;
  late HttpClientAdapter previousAdapter;
  setUp(() {
    previousAdapter = ApiClient.instance.dio.httpClientAdapter;
    adapter = _AdAdapter();
    ApiClient.instance.dio.httpClientAdapter = adapter;
    AppState.instance.deviceId = 'stable-installation';
    AppState.instance.sessionId = 'existing-session';
    AdEventQueue.instance.reset();
    AdManager.instance.resetSession();
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });
  tearDown(() {
    AdEventQueue.instance.reset();
    ApiClient.instance.dio.httpClientAdapter = previousAdapter;
    VisibilityDetectorController.instance.updateInterval =
        const Duration(milliseconds: 500);
  });

  Widget exposure({bool active = true, String id = 'a'}) => MaterialApp(
          home: Scaffold(
        body: AdViewabilityDetector(
            ad: ad(id),
            active: active,
            exposureKey: 'slot-$id',
            child: SizedBox(
                width: 200,
                height: 200,
                child: GestureDetector(
                  onTap: () => AdManager.instance
                      .recordClick(ad(id), placementZone: 'feed'),
                  child: const ColoredBox(
                      color: Colors.red, child: Center(child: Text('Ad'))),
                ))),
      ));

  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 25));
    }
  }

  testWidgets(
      'visibility waits one continuous second; rebuild cannot duplicate events',
      (tester) async {
    await tester.pumpWidget(exposure());
    await tester.pump(const Duration(milliseconds: 900));
    expect(adapter.requests, isEmpty);
    await tester.pump(const Duration(milliseconds: 150));
    await flush(tester);
    expect(
        adapter.requests
            .where((r) => r.data['event_type'] == 'impression')
            .length,
        1);
    expect(
        adapter.requests
            .where((r) => r.data['event_type'] == 'viewability')
            .length,
        1);
    await tester.pumpWidget(exposure());
    await tester.pump(const Duration(seconds: 2));
    await flush(tester);
    expect(adapter.requests.length, 2);
    for (final request in adapter.requests) {
      expect(request.headers['X-Device-ID'], 'stable-installation');
      expect(request.headers['X-Session-ID'], 'existing-session');
      expect(request.data['placement_zone'], 'feed');
    }
    await tester.tap(find.text('Ad'));
    await flush(tester);
    expect(adapter.requests.last.data['event_type'], 'click');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'inactive cards never count impressions and reset interrupted dwell',
      (tester) async {
    await tester.pumpWidget(exposure(active: false));
    await tester.pump(const Duration(seconds: 2));
    expect(adapter.requests, isEmpty);
    await tester.pumpWidget(exposure());
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpWidget(exposure(active: false));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpWidget(exposure());
    await tester.pump(const Duration(milliseconds: 600));
    expect(adapter.requests, isEmpty);
    await tester.pump(const Duration(milliseconds: 450));
    await flush(tester);
    expect(
        adapter.requests
            .where((r) => r.data['event_type'] == 'impression')
            .length,
        1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('background time is not viewable dwell', (tester) async {
    await tester.pumpWidget(exposure());
    await tester.pump(const Duration(milliseconds: 600));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 3));
    expect(adapter.requests, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 600));
    expect(adapter.requests, isEmpty);
    await tester.pump(const Duration(milliseconds: 500));
    await flush(tester);
    expect(
        adapter.requests
            .where((r) => r.data['event_type'] == 'impression')
            .length,
        1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('horizontal media swipe does not turn parent Spotlight page',
      (tester) async {
    final parent = PageController();
    addTearDown(parent.dispose);
    var mediaIndex = 0;
    final article = story('a', ['image', 'image', 'image']);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: FlipPageView(
      controller: parent,
      itemCount: 2,
      itemBuilder: (_, index) => index == 0
          ? ArticleMediaCarousel(
              article: article,
              active: true,
              onPageChanged: (index) => mediaIndex = index)
          : const Text('Next parent'),
    ))));

    // The inner carousel is horizontal, the feed vertical: the drag must go
    // to the media and leave the parent page where it is.
    await tester.drag(find.byType(ArticleMediaCarousel), const Offset(-600, 0));
    await tester.pump(const Duration(seconds: 1));
    expect(mediaIndex, 1);
    expect(parent.page?.round() ?? 0, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('fullscreen zero duration has no artificial expiry',
      (tester) async {
    var closed = 0;
    await tester.pumpWidget(MaterialApp(
        home: Material(
            child: SponsoredSpotlightAdCard(
      ad: ad('zero', type: 'full_screen'),
      durationSeconds: 0,
      onClose: () => closed++,
      exposureKey: 'zero',
    ))));
    await tester.pump(const Duration(seconds: 20));
    expect(closed, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('timed fullscreen only counts active foreground seconds',
      (tester) async {
    var closed = 0;
    Widget timed(bool active) => MaterialApp(
            home: Material(
                child: SponsoredSpotlightAdCard(
          ad: ad('timed', type: 'full_screen', duration: 2),
          durationSeconds: 2,
          active: active,
          onClose: () => closed++,
          exposureKey: 'timed',
        )));
    await tester.pumpWidget(timed(false));
    await tester.pump(const Duration(seconds: 4));
    expect(closed, 0);
    await tester.pumpWidget(timed(true));
    await tester.pump(const Duration(seconds: 1));
    expect(closed, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(closed, 1);
    await flush(tester);
    expect(adapter.requests.any((r) => r.data['event_type'] == 'hide'), isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}
