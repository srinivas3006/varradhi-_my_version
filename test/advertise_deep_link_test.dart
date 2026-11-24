import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Use url_launcher's platform test doubles without adding a runtime dependency.
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/link.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:vaaradhi/core/navigation/notification_deep_link_resolver.dart';
import 'package:vaaradhi/core/navigation/notification_navigation_gate.dart';
import 'package:vaaradhi/core/network/dio_client.dart';
import 'package:vaaradhi/core/widgets/flip_page_view.dart';
import 'package:vaaradhi/models/notification_target.dart';
import 'package:vaaradhi/models/spotlight_item.dart';
import 'package:vaaradhi/repositories/feed_repository.dart';
import 'package:vaaradhi/screens/account_login_screen.dart';
import 'package:vaaradhi/screens/ad_booking_screen.dart';
import 'package:vaaradhi/services/notification_service.dart';
import 'package:vaaradhi/services/poll_exposure.dart';
import 'package:vaaradhi/spotlight/spotlight_screen.dart';
import 'package:vaaradhi/state/app_state.dart';
import 'package:vaaradhi/widgets/poster_card.dart';

const _link = 'vaaradhi://advertise-with-us';

Map<String, dynamic> _poster(String id, {Object? destination = _link}) => {
      'id': id,
      'title': 'Poster $id',
      'image_url': 'https://cdn.example.com/$id.jpg',
      'destination_url': destination,
    };

class _Api implements HttpClientAdapter {
  final requests = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancelFuture) async {
    requests.add(options.path);
    return ResponseBody.fromString(
      jsonEncode({
        'data': options.path == '/api/v1/posters/'
            ? [_poster('before'), _poster('advertising'), _poster('after')]
            : [],
        'meta': {'next': null, 'has_more': false},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Launcher extends UrlLauncherPlatform {
  final urls = <String>[];
  bool fail = false;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    urls.add(url);
    if (fail) throw PlatformException(code: 'unavailable');
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Api api;
  late _Launcher launcher;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NotificationNavigationGate.instance.reset();
    PollExposure.instance.resetForTest();
    AppState.instance.contentLanguagePrompted = true;
    AppState.instance.language = 'English';
    AppState.instance.isLoggedIn = false;
    FeedRepository.instance.clearCache();
    api = _Api();
    ApiClient.instance.dio.httpClientAdapter = api;
    launcher = _Launcher();
    UrlLauncherPlatform.instance = launcher;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('flutter_tts'), (_) async => 1);
  });

  for (final url in [
    _link,
    '  $_link  ',
    '$_link/',
    '$_link?campaign=poster',
    'VAARADHI://ADVERTISE-WITH-US',
    'varadhi://advertise-with-us',
    'screen://advertise-with-us',
  ]) {
    test('parses $url as a public screen', () {
      final target = NotificationDeepLinkResolver.resolveFromUri(url);
      expect(target.type, NotificationTargetType.screen);
      expect(target.screenName, 'advertise-with-us');
      expect(target.requiresAuth, isFalse);
    });
  }

  for (final url in <String?>[
    null,
    '',
    ' ',
    '://broken',
    'vaaradhi://',
    'vaaradhi://unknown',
    'vaaradhi:///advertise-with-us',
    'vaaradhi://advertise-with-us/other',
    'vaaradhi://user@advertise-with-us',
    'vaaradhi://advertise-with-us:1234',
    'https://advertise-with-us',
    'https://example.com/advertise-with-us',
  ]) {
    test('does not treat $url as the advertising route', () {
      expect(NotificationDeepLinkResolver.resolveFromUri(url).type,
          NotificationTargetType.unknown);
    });
  }

  test('poster API destination survives feed page conversion unchanged', () {
    final item = SpotlightItem.posterPages(_poster('advertising')).single;
    expect(item.destinationUrl, _link);
    for (final value in [null, 42, <String, dynamic>{}]) {
      expect(
          SpotlightItem.posterRecord(_poster('invalid', destination: value))
              .destinationUrl,
          isNull);
    }
  });

  for (final loggedIn in [false, true]) {
    testWidgets(
        'Spotlight poster opens booking and Back preserves feed '
        '(loggedIn=$loggedIn)', (tester) async {
      AppState.instance.isLoggedIn = loggedIn;
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
      await tester.pumpWidget(const MaterialApp(
        home: SpotlightScreenView(initialStoryIndex: 1),
      ));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final feedState = tester.state(find.byType(SpotlightScreenView));
      final pager = tester.widget<FlipPageView>(find.byType(FlipPageView));
      expect(pager.controller.page, 1);
      expect(pager.itemCount, greaterThanOrEqualTo(3));
      final card = find.byKey(const ValueKey('poster_advertising'));
      expect(card, findsOneWidget);
      final posterState = tester.state(card);
      expect(tester.widget<PosterCard>(card).destinationUrl, _link);
      final loads = api.requests.where((p) => p == '/api/v1/posters/').length;
      final feedLoads =
          api.requests.where((p) => p.contains('/articles/feed/')).length;

      await tester.tapAt(tester.getCenter(card));
      await tester.tapAt(tester.getCenter(card));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(AdBookingScreen), findsOneWidget);
      expect(find.byType(AccountLoginScreen), findsNothing);
      expect(launcher.urls, isEmpty);

      // Even after the navigation gate's short debounce expires/reset,
      // another dispatch cannot stack a second booking screen.
      NotificationNavigationGate.instance.reset();
      await NotificationService.instance.navigateToTarget(
        NotificationDeepLinkResolver.resolveFromUri(_link),
        context: tester
            .element(find.byType(SpotlightScreenView, skipOffstage: false)),
      );
      await tester.pump();
      expect(find.byType(AdBookingScreen, skipOffstage: false), findsOneWidget);

      await tester.pageBack();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(AdBookingScreen), findsNothing);
      expect(tester.state(find.byType(SpotlightScreenView)), same(feedState));
      expect(tester.state(card), same(posterState));
      final restored = tester.widget<FlipPageView>(find.byType(FlipPageView));
      expect(restored.controller, same(pager.controller));
      expect(restored.controller.page, 1);
      expect(restored.itemCount, pager.itemCount);
      expect(api.requests.where((p) => p == '/api/v1/posters/').length, loads);
      expect(api.requests.where((p) => p.contains('/articles/feed/')).length,
          feedLoads);

      // The active-route guard clears on Back, allowing a later visit.
      NotificationNavigationGate.instance.reset();
      await tester.tapAt(tester.getCenter(card));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AdBookingScreen), findsOneWidget);
      await tester.pageBack();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  for (final destination in <String?>[
    'https://example.com/offer',
    'tel:+919876543210',
    null,
    '',
    '://broken',
    'https://',
    'vaaradhi://unknown',
  ]) {
    testWidgets('poster safely handles destination $destination',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: PosterCard(
          mediaUrl: '',
          destinationUrl: destination,
        )),
      ));
      await tester.tapAt(tester.getCenter(find.byType(PosterCard)));
      await tester.pump();
      expect(
          launcher.urls,
          destination?.startsWith('https://example.com') == true ||
                  destination?.startsWith('tel:') == true
              ? [destination]
              : isEmpty);
      expect(find.byType(AdBookingScreen), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('external launch failure is contained', (tester) async {
    launcher.fail = true;
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
      body: PosterCard(mediaUrl: '', destinationUrl: 'https://example.com'),
    )));
    await tester.tapAt(tester.getCenter(find.byType(PosterCard)));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
