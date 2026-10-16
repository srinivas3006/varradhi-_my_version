import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/core/ads/ad_pacer.dart';
import 'package:vaaradhi/core/ads/home_ads.dart';
import 'package:vaaradhi/models/ad_banner.dart';
import 'package:vaaradhi/widgets/ads/corner_three_d_ad_overlay.dart';
import 'package:vaaradhi/widgets/ads/floating_three_d_ad.dart';

AdBanner _ad(String id, String type,
        {String image = '', String video = '', String style = ''}) =>
    AdBanner(
      id: id,
      title: 'Ad $id',
      imageUrl: image.isEmpty ? 'https://cdn.test/$id.jpg' : image,
      videoUrl: video,
      destinationUrl: '',
      adType: type,
      placementZone: 'feed',
      targetScope: 'global',
      displayFrequency: 5,
      ctr: 0,
      displayStyle: style,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final pacer = AdPacer.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    pacer.resetForTest();
  });

  void use(int seconds) {
    var now = DateTime(2026, 10, 10, 9);
    for (var i = 0; i < seconds; i++) {
      now = now.add(const Duration(seconds: 1));
      pacer.reportActivity(now);
      pacer.tick(now: now);
    }
  }

  group('pool and formats', () {
    test('3D ads and video ads play in the corner; video keeps its feed slot',
        () {
      final ads = [
        _ad('b', 'banner'),
        _ad('d', 'three_d'),
        _ad('v', 'video', video: 'https://cdn.test/v.mp4'),
      ];
      expect(HomeAds.corner3d(ads).map((a) => a.id), ['d', 'v']);
      expect(HomeAds.inline(ads).map((a) => a.id), ['b', 'v']);
    });

    test('each appearance plays the next 3D format', () {
      final ad = _ad('d', 'three_d');
      final seen = [for (var i = 0; i < 5; i++) ThreeDAdStyle.forAd(ad, i)];
      expect(seen.toSet(), ThreeDAdStyle.values.toSet());
      expect(ThreeDAdStyle.forAd(ad, 5), ThreeDAdStyle.forAd(ad, 0));
    });

    test('the backend can name the format', () {
      expect(ThreeDAdStyle.parse('3D Cube'), ThreeDAdStyle.cube);
      expect(ThreeDAdStyle.parse('rotating_prism'), ThreeDAdStyle.prism);
      expect(ThreeDAdStyle.parse('multi-panel pillar'), ThreeDAdStyle.pillar);
      expect(
          ThreeDAdStyle.parse('rotating digital column'), ThreeDAdStyle.pillar);
      expect(ThreeDAdStyle.parse('corner_billboard'),
          ThreeDAdStyle.cornerBillboard);
      expect(ThreeDAdStyle.parse('anamorphic'), ThreeDAdStyle.cornerBillboard);
      expect(ThreeDAdStyle.parse('product_showcase'), ThreeDAdStyle.showcase);
      expect(ThreeDAdStyle.parse(''), isNull);
      final named = _ad('p', 'three_d', style: 'prism');
      expect(ThreeDAdStyle.forAd(named, 0), ThreeDAdStyle.prism);
      expect(ThreeDAdStyle.forAd(named, 3), ThreeDAdStyle.prism);
      expect(
          AdBanner.fromJson({'id': 'x', 'three_d_style': 'cube'}).displayStyle,
          'cube');
    });

    test('corners rotate around the screen', () {
      expect({for (var i = 0; i < 4; i++) CornerThreeDAdOverlay.cornerFor(i)},
          AdCorner.values.toSet());
    });
  });

  group('overlay above every screen', () {
    Future<void> pump(WidgetTester tester, List<AdBanner> ads) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      // Mounted like main.dart does: in MaterialApp.builder, above the
      // Navigator (no Overlay there).
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => Stack(children: [
          Positioned.fill(child: child!),
          Positioned.fill(
            child: CornerThreeDAdOverlay(pool: ValueNotifier(ads)),
          ),
        ]),
        home: const Scaffold(body: Placeholder()),
      ));
      await tester.pump();
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump();
    }

    Future<void> done(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 1));
    }

    for (final style in ThreeDAdStyle.values) {
      testWidgets('${style.name} renders and can be closed', (tester) async {
        await pump(tester, [_ad('d', 'three_d', style: style.name)]);
        use(120);
        await settle(tester);
        expect(find.byKey(Key('floating_3d_${style.name}')), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const Key('floating_3d_close')));
        await settle(tester);
        expect(pacer.floatingVisible, isFalse);
        expect(find.byType(FloatingThreeDAd), findsNothing);
        await done(tester);
      });
    }

    testWidgets('next appearance: next corner', (tester) async {
      await pump(tester, [_ad('d', 'three_d')]);
      use(120);
      await settle(tester);
      final first = tester.getCenter(find.byType(FloatingThreeDAd));
      use(20 + 100);
      await settle(tester);
      final second = tester.getCenter(find.byType(FloatingThreeDAd));
      expect(second, isNot(first));
      await done(tester);
    });

    testWidgets('nothing until the pacer says so; touches pass through',
        (tester) async {
      var tapped = false;
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => Stack(children: [
          Positioned.fill(child: child!),
          Positioned.fill(
            child: CornerThreeDAdOverlay(
                pool: ValueNotifier([_ad('d', 'three_d')])),
          ),
        ]),
        home: Scaffold(
          body: SizedBox.expand(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => tapped = true,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(FloatingThreeDAd), findsNothing);
      await tester.tapAt(const Offset(180, 300));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });
  });
}

