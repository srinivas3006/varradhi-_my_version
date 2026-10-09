import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/models/news_article.dart';
import 'package:vaaradhi/screens/account_login_screen.dart';
import 'package:vaaradhi/services/content_engagement_service.dart';
import 'package:vaaradhi/state/app_state.dart';
import 'package:vaaradhi/widgets/spotlight/report_story_sheet.dart';
import 'package:vaaradhi/widgets/spotlight/story_options_sheet.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status);
  int status;
  final List<RequestOptions> calls = [];

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<Uint8List>? _, Future<void>? __) async {
    calls.add(o);
    final body = status < 300
        ? {
            'data': {'id': 'r1', 'status': 'pending'}
          }
        : {
            'data': null,
            'errors': {
              'code': status,
              'message': status == 401
                  ? 'Authentication credentials were not provided.'
                  : 'x'
            }
          };
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

NewsArticle _desk() => NewsArticle.fromJson({
      'id': 'art-1',
      'slug': 'desk-story',
      'title': 'Story',
      'feed_item_type': 'article',
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Adapter adapter;
  late ContentEngagementService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppState.instance.isLoggedIn = false; // a guest
    AppState.instance.language = 'English';
    adapter = _Adapter(201);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    service = ContentEngagementService.forTesting(dio);
  });

  tearDown(() => AppState.instance.language = 'Telugu');

  Future<void> openReport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2392);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              key: const Key('open'),
              onPressed: () =>
                  StoryActions.report(context, _desk(), service: service),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
  }

  Future<void> pick(WidgetTester tester, ReportKind kind) async {
    await tester.tap(find.byKey(Key('report_kind_${kind.key}')));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('report_submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report_submit')));
    await tester.pumpAndSettle();
  }

  group('the five kinds from the design', () {
    test('labels and backend reason codes', () {
      expect(ReportKind.values.map((k) => k.label), [
        'Mistakes observed',
        'Wrong content',
        'Hateful statements',
        'Biased story',
        'Copyright violation',
      ]);
      const allowed = {
        'misinformation',
        'inappropriate',
        'spam',
        'copyright',
        'other'
      };
      for (final k in ReportKind.values) {
        expect(allowed, contains(k.code), reason: k.label);
      }
    });

    test('notes start with the kind so the queue can tell them apart', () {
      expect(ReportKind.biased.notesWith(''), 'Biased story');
      expect(ReportKind.mistakes.notesWith('  wrong date '),
          'Mistakes observed — wrong date');
      expect(ReportKind.mistakes.notesWith('x' * 2000).length, 1000);
    });
  });

  testWidgets('a guest opens the sheet straight away — no login screen',
      (tester) async {
    await openReport(tester);
    expect(find.byKey(const Key('report_sheet')), findsOneWidget);
    expect(find.byType(AccountLoginScreen), findsNothing);
    for (final k in ReportKind.values) {
      expect(find.text(k.label), findsOneWidget);
    }
    expect(find.byKey(const Key('report_details')), findsOneWidget);
  });

  testWidgets('Report stays off until a kind is chosen', (tester) async {
    await openReport(tester);
    final button = find.descendant(
        of: find.byKey(const Key('report_submit')),
        matching: find.byType(ElevatedButton));
    expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
    await pick(tester, ReportKind.wrongContent);
    expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
  });

  testWidgets('guest report is sent to the article endpoint with notes',
      (tester) async {
    await openReport(tester);
    await pick(tester, ReportKind.wrongContent);
    await tester.enterText(
        find.byKey(const Key('report_details')), 'Wrong village name');
    await submit(tester);

    final call = adapter.calls.single;
    expect(call.method, 'POST');
    expect(call.path, '/api/v1/articles/art-1/report/');
    expect((call.data as Map)['reason'], 'misinformation');
    expect((call.data as Map)['notes'], 'Wrong content — Wrong village name');
    expect(find.byKey(const Key('report_sheet')), findsNothing);
    expect(
        find.text('Thanks — your report was sent for review.'), findsOneWidget);
  });

  testWidgets('reporting the same story again does not send twice',
      (tester) async {
    await openReport(tester);
    await pick(tester, ReportKind.copyright);
    await submit(tester);
    expect(adapter.calls, hasLength(1));

    await tester.pump(const Duration(seconds: 5)); // let the snackbar go
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report_sheet')), findsNothing);
    expect(find.text('You have already reported this story.'), findsOneWidget);
    expect(adapter.calls, hasLength(1));
  });

  testWidgets('a failure keeps the sheet open with the choice, to retry',
      (tester) async {
    adapter.status = 500;
    await openReport(tester);
    await pick(tester, ReportKind.hateful);
    await submit(tester);
    expect(find.byKey(const Key('report_sheet')), findsOneWidget);
    expect(find.byKey(const Key('report_error')), findsOneWidget);

    adapter.status = 201;
    await submit(tester);
    expect(find.byKey(const Key('report_sheet')), findsNothing);
    expect(adapter.calls, hasLength(2));
    expect((adapter.calls.last.data as Map)['reason'], 'inappropriate');
  });

  testWidgets('if the server still requires login, the guest is asked once',
      (tester) async {
    adapter.status = 401;
    await openReport(tester);
    await pick(tester, ReportKind.biased);
    await submit(tester);
    expect(find.byKey(const Key('report_sheet')), findsNothing);
    expect(find.byType(AccountLoginScreen), findsOneWidget);
  });

  testWidgets('no overflow on a small phone', (tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReportStorySheet(onSubmit: (_, __) async => ReportOutcome.sent),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
