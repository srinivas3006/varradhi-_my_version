import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/core/ads/ad_pacer.dart';
import 'package:vaaradhi/core/ads/home_ads.dart';
import 'package:vaaradhi/models/ad_banner.dart';
import 'package:vaaradhi/widgets/ads/floating_three_d_ad.dart';
import 'package:vaaradhi/widgets/ads/paced_ads_overlay.dart';

AdBanner _ad(String id, String type) => AdBanner(
      id: id,
      imageUrl: 'https://cdn.test/$id.jpg',
      destinationUrl: '',
      adType: type,
      placementZone: 'feed',
      targetScope: 'global',
      displayFrequency: 5,
      ctr: 0,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final pacer = AdPacer.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    pacer.resetForTest();
  });

  /// [seconds] of continuous use: active every second.
  void use(int seconds) {
    var now = DateTime(2026, 10, 10, 9);
    for (var i = 0; i < seconds; i++) {
      now = now.add(const Duration(seconds: 1));
      pacer.reportActivity(now);
      pacer.tick(now: now);
    }
  }

  /// [seconds] with the app open but nobody touching it.
  void idle(int seconds) {
    final start = DateTime(2026, 10, 10, 9);
    pacer.reportActivity(start);
    for (var i = 1; i <= seconds; i++) {
      pacer.tick(now: start.add(Duration(seconds: 60 + i)));
    }
  }

  group('ads come with continued use, then go', () {
    test('nothing in the first minutes', () {
      use(170);
      expect(pacer.stickyVisible, isFalse);
      expect(pacer.floatingVisible, isFalse);
    });

    test('banner after 3 min of use, gone 30 s later', () {
      use(180);
      expect(pacer.stickyVisible, isTrue);
      use(30);
      expect(pacer.stickyVisible, isFalse);
    });

    test('banner returns every 2 min of use, not before', () {
      use(180 + 30); // first appearance over
      use(60);
      expect(pacer.stickyVisible, isFalse);
      use(30); // 2 min after the first appearance began
      expect(pacer.stickyVisible, isTrue);
    });

    test('3D corner ad every 2 min of use, 20 s each time', () {
      use(119);
      expect(pacer.floatingVisible, isFalse);
      use(1);
      expect(pacer.floatingVisible, isTrue);
      use(20);
      expect(pacer.floatingVisible, isFalse);
      expect(pacer.floatingRotation, 1);
      use(95);
      expect(pacer.floatingVisible, isFalse);
      use(5); // 2 min after the first appearance began
      expect(pacer.floatingVisible, isTrue);
    });

    test('an idle phone does not collect ads', () {
      idle(1200);
      expect(pacer.activeTime, Duration.zero);
      expect(pacer.stickyVisible, isFalse);
      expect(pacer.floatingVisible, isFalse);
    });

    test('closing it hides it now and waits a full period', () {
      use(180);
      expect(pacer.stickyVisible, isTrue);
      pacer.dismiss(AdPacer.sticky);
      expect(pacer.stickyVisible, isFalse);
      use(100);
      expect(pacer.stickyVisible, isFalse);
      use(20); // a full 2-min period after it began
      expect(pacer.stickyVisible, isTrue);
    });

    test('each appearance rotates to the next ad', () {
      expect(pacer.stickyRotation, 0);
      use(180 + 30);
      expect(pacer.stickyRotation, 1);
    });

    test('leaving the app ends an appearance', () {
      use(180);
      expect(pacer.stickyVisible, isTrue);
      pacer.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(pacer.stickyVisible, isFalse);
    });
  });

  group('which ads are paced', () {
    test('3D ads leave the feed and float instead', () {
      final ads = [
        _ad('a', 'banner'),
        _ad('b', 'three_d'),
        _ad('c', 'bottom_sticky')
      ];
      expect(HomeAds.inline(ads).map((a) => a.id), ['a']);
      expect(HomeAds.threeD(ads).map((a) => a.id), ['b']);
      expect(HomeAds.bottomSticky(ads).map((a) => a.id), ['c']);
    });
  });

  /// Lets an enter/exit animation start and finish.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();
  }

  group('overlay', () {
    Future<void> pump(WidgetTester tester, List<AdBanner> ads,
        {bool sticky = true}) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(children: [
            const Positioned.fill(child: Placeholder()),
            Positioned.fill(
              child: PacedAdsOverlay(
                bottomInset: 80,
                showSticky: sticky,
                pool: ValueNotifier(ads),
              ),
            ),
          ]),
        ),
      ));
      await tester.pump();
    }

    testWidgets('nothing on screen until the pacer says so', (tester) async {
      await pump(tester, [_ad('s', 'bottom_sticky'), _ad('d', 'three_d')]);
      expect(find.byType(FloatingThreeDAd), findsNothing);
      expect(find.text('SPONSORED'), findsNothing);
    });

    testWidgets('floating 3D ad appears, and closing it removes it',
        (tester) async {
      await pump(tester, [_ad('d', 'three_d')]);
      use(120);
      await settle(tester);
      expect(find.byType(FloatingThreeDAd), findsOneWidget);

      await tester.tap(find.byKey(const Key('floating_3d_close')));
      await settle(tester);
      expect(pacer.floatingVisible, isFalse);
      expect(find.byType(FloatingThreeDAd), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 1));
    });

    testWidgets('banner slides in and out with the pacer', (tester) async {
      await pump(tester, [_ad('s', 'bottom_sticky')]);
      use(180);
      await settle(tester);
      expect(find.text('SPONSORED'), findsOneWidget);
      use(30);
      await settle(tester);
      expect(find.text('SPONSORED'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 1));
    });

    testWidgets('Spotlight shows no banner', (tester) async {
      await pump(tester, [_ad('s', 'bottom_sticky')], sticky: false);
      use(180);
      await settle(tester);
      expect(find.text('SPONSORED'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 1));
    });

    testWidgets('empty space still lets touches through', (tester) async {
      var tapped = false;
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => tapped = true,
                child: const ColoredBox(color: Colors.white),
              ),
            ),
            Positioned.fill(
              child: PacedAdsOverlay(
                  bottomInset: 80, pool: ValueNotifier(const [])),
            ),
          ]),
        ),
      ));
      await tester.tapAt(const Offset(180, 300));
      expect(tapped, isTrue);
    });
  });
}
