import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/models/unified_feed_item.dart';
import 'package:vaaradhi/screens/profile_tab.dart';
import 'package:vaaradhi/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final app = AppState.instance;

  group('comment count: one comment shows as 1', () {
    setUp(() => app.userAddedComments.clear());

    test('server count already includes my comment → not added twice', () {
      expect(app.getDisplayCommentCount('a1', 0), 0); // story opened
      app.recordUserComment('a1'); // I comment
      expect(app.getDisplayCommentCount('a1', 0), 1,
          reason: 'shown at once, before the server count updates');
      expect(app.getDisplayCommentCount('a1', 1), 1,
          reason: 'server now says 1 — it was 2 before the fix');
    });

    test('others commenting too is still counted', () {
      expect(app.getDisplayCommentCount('a2', 3), 3);
      app.recordUserComment('a2');
      expect(app.getDisplayCommentCount('a2', 3), 4);
      expect(app.getDisplayCommentCount('a2', 5), 5);
    });
  });

  test('live /ugc/feed/ item shows the uploader name', () {
    final a = UnifiedFeedItem.fromJson({
      'id': '7cb8',
      'type': 'ugc',
      'title': 'రూ.300 శ్రీవారి దర్శన టికెట్లు విడుదల',
      'description': 'తిరుమల',
      'source': 'USER_UPLOAD',
      'created_at': '2026-10-06T10:00:00+05:30',
      'uploader': {
        'id': '2f4beca2',
        'display_name': 'Ramakrishna Sagar',
        'trust_level': 'VERIFIED_USER'
      },
    }).toArticle();
    expect(a.byline, 'Ramakrishna Sagar');
  });

  group('profile mobile', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      app
        ..isLoggedIn = true
        ..userName = 'srinivasnaskanti@yopmail.com'
        ..userPhone = '';
    });
    tearDown(() => app
      ..profileVerifiedMobile = ''
      ..isLoggedIn = false);

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4800);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ProfileTab())));
      await tester.pump();
    }

    testWidgets('verified → "+91 90140 66807"', (tester) async {
      app.profileVerifiedMobile = '9014066807';
      await pump(tester);
      expect(find.byKey(const Key('profile_verified_mobile')), findsOneWidget);
      expect(find.text('+91 90140 66807'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 1));
    });

    testWidgets('not verified → no lone "+91"', (tester) async {
      app.profileVerifiedMobile = '';
      await pump(tester);
      expect(find.byKey(const Key('profile_verified_mobile')), findsNothing);
      expect(find.text('+91 '), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 1));
    });
  });
}
