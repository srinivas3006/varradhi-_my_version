import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/core/navigation/app_navigator.dart';
import 'package:vaaradhi/core/network/dio_client.dart';
import 'package:vaaradhi/localization/location_translations.dart';
import 'package:vaaradhi/screens/news_feed_tab.dart';
import 'package:vaaradhi/screens/profile_tab.dart';
import 'package:vaaradhi/state/app_state.dart';
import 'package:vaaradhi/widgets/bottom_nav_bar.dart';

class _EmptyApi implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _,
          Future<void>? __) async =>
      ResponseBody.fromString(
        jsonEncode({'data': [], 'meta': {}, 'errors': null}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String village, subdistrict, district, city;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final s = AppState.instance;
    village = s.village;
    subdistrict = s.subdistrict;
    district = s.district;
    city = s.city;
    AppNavigator.resetDebounce();
  });
  tearDown(() {
    final s = AppState.instance
      ..village = village
      ..subdistrict = subdistrict
      ..district = district
      ..city = city;
    s.notifyListeners();
  });

  group('bottom bar: Home, Main, Post, Reels, Local', () {
    Future<List<int>> pumpBar(WidgetTester tester) async {
      final taps = <int>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: BottomNavBar(currentIndex: 0, onTap: taps.add),
        ),
      ));
      return taps;
    }

    testWidgets('Profile is gone and Reels is there', (tester) async {
      final taps = await pumpBar(tester);
      expect(find.byIcon(Icons.person_rounded), findsNothing);
      await tester.tap(find.byIcon(Icons.play_circle_outline_rounded));
      await tester.tap(find.byIcon(Icons.location_on_rounded));
      expect(taps, [3, 4]);
    });

    testWidgets('Local is labelled with the reader\'s place', (tester) async {
      AppState.instance
        ..village = 'Kesaram'
        ..subdistrict = 'Jajireddygudem';
      await pumpBar(tester);
      // The app is in Telugu, so the village shows in Telugu.
      expect(find.text('కేసారం'), findsOneWidget);
    });

    testWidgets('it follows a location change', (tester) async {
      // In English, so the names read back exactly as set.
      addTearDown(() => AppState.instance.language = 'Telugu');
      AppState.instance
        ..language = 'English'
        ..village = ''
        ..subdistrict = 'Yousufguda';
      await pumpBar(tester);
      expect(find.text('Yousufguda'), findsOneWidget);

      AppState.instance.subdistrict = 'Khairatabad';
      AppState.instance.notifyListeners();
      await tester.pump();
      expect(find.text('Khairatabad'), findsOneWidget);
    });

    testWidgets('in Telugu, the place shows its Telugu name', (tester) async {
      // A mandal the built-in table does not know: its Telugu name comes
      // from the location API (name_te) when the reader picks it.
      LocationTranslations.learn('Yousufguda', 'యూసుఫ్‌గూడ');
      AppState.instance
        ..language = 'Telugu'
        ..village = ''
        ..subdistrict = 'Yousufguda';
      await pumpBar(tester);
      expect(find.text('యూసుఫ్‌గూడ'), findsOneWidget);
      expect(find.text('Yousufguda'), findsNothing);
    });

    testWidgets('a district uses the built-in Telugu table', (tester) async {
      AppState.instance
        ..language = 'Telugu'
        ..village = ''
        ..subdistrict = ''
        ..district = 'Hyderabad';
      await pumpBar(tester);
      expect(find.text('హైదరాబాద్'), findsOneWidget);
    });

    testWidgets('in English, the place stays in English', (tester) async {
      LocationTranslations.learn('Yousufguda', 'యూసుఫ్‌గూడ');
      AppState.instance
        ..language = 'English'
        ..village = ''
        ..subdistrict = 'Yousufguda';
      addTearDown(() => AppState.instance.language = 'Telugu');
      await pumpBar(tester);
      expect(find.text('Yousufguda'), findsOneWidget);
    });

    testWidgets('with no place set it just says Local', (tester) async {
      AppState.instance
        ..village = ''
        ..subdistrict = ''
        ..district = ''
        ..city = '';
      await pumpBar(tester);
      expect(find.byTooltip('లోకల్'), findsOneWidget);
    });
  });

  group('Home header: profile left, logo centred, search + bell right', () {
    setUp(() => ApiClient.instance.dio.httpClientAdapter = _EmptyApi());

    Future<void> pumpHome(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: NewsFeedTab()));
      await tester.pump();
    }

    testWidgets('the pieces are where the design puts them', (tester) async {
      await pumpHome(tester);
      final width = tester.getSize(find.byType(NewsFeedTab)).width;

      final logo = tester.getCenter(find.byKey(const Key('home_header_logo')));
      expect(logo.dx, closeTo(width / 2, 1), reason: 'logo centred');

      final profile = tester.getRect(find.byKey(const Key('home_header_profile')));
      expect(profile.left, lessThan(width * 0.2), reason: 'profile top-left');
      expect(profile.width, greaterThanOrEqualTo(40));
      expect(profile.height, greaterThanOrEqualTo(40));

      final search = tester.getCenter(find.byKey(const Key('home_header_search')));
      expect(search.dx, greaterThan(width * 0.7), reason: 'search on the right');
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);

      // Profile is a plain outline icon like Search and the bell — no
      // avatar circle.
      expect(
          find.descendant(
              of: find.byKey(const Key('home_header_profile')),
              matching: find.byIcon(Icons.person_outline_rounded)),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const Key('home_header_profile')),
              matching: find.byType(DecoratedBox)),
          findsNothing);

      // No wordmark and no location picker in the header any more.
      expect(find.text('Vaaradhi'), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
      // Let Home's startup timers run out before the test ends.
      await tester.pumpAndSettle(const Duration(seconds: 1));
    });

    testWidgets('logged in, the profile button is the reader\'s avatar',
        (tester) async {
      final s = AppState.instance;
      final oldName = s.userName;
      s
        ..isLoggedIn = true
        ..userName = 'vaaradhi'
        ..profileImagePath = null;
      addTearDown(() => s
        ..isLoggedIn = false
        ..userName = oldName);

      await pumpHome(tester);
      final avatar = find.descendant(
          of: find.byKey(const Key('home_header_profile')),
          matching: find.byKey(const Key('home_header_avatar')));
      expect(avatar, findsOneWidget);
      expect(find.descendant(of: avatar, matching: find.text('V')),
          findsOneWidget);
      // 32dp circle inside the 48dp target, in line with the 36dp logo.
      expect(tester.getSize(avatar), const Size(32, 32));
      await tester.pumpAndSettle(const Duration(seconds: 1));
    });

    testWidgets('the profile button opens Profile with a way back',
        (tester) async {
      await pumpHome(tester);
      await tester.tap(find.byKey(const Key('home_header_profile')));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileTab), findsOneWidget);
      expect(find.byKey(const Key('profile_back_btn')), findsOneWidget);

      await tester.tap(find.byKey(const Key('profile_back_btn')));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileTab), findsNothing);
    });
  });
}
