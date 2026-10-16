import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/core/network/dio_client.dart';
import 'package:vaaradhi/models/poll.dart';
import 'package:vaaradhi/services/poll_exposure.dart';
import 'package:vaaradhi/state/app_state.dart';
import 'package:vaaradhi/widgets/poll_card.dart';

Poll _poll({String id = 'p1', int? voted}) => Poll(
      id: id,
      question: 'Who will win?',
      options: const ['Congress', 'BRS', 'BJP'],
      votes: [0, 2, 0],
      selectedOption: voted,
    );

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status);
  final int status;
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<Uint8List>? _, Future<void>? __) async {
    calls++;
    return ResponseBody.fromString(
        jsonEncode(status < 300
            ? {'data': {}}
            : {
                'errors': {'message': 'x'}
              }),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final exposure = PollExposure.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    exposure.resetForTest();
    AppState.instance.language = 'English';
  });
  tearDown(() => AppState.instance.language = 'Telugu');

  group('a poll is shown at most twice, and not after voting', () {
    test('two sessions, then hidden', () async {
      await exposure.ready();
      final p = _poll();
      expect(exposure.shouldShow(p), isTrue);

      await exposure.markShown(p.id); // session 1
      await exposure.markShown(p.id); // same session: still one view
      expect(exposure.shouldShow(p), isTrue, reason: 'visible this session');

      exposure.newSessionForTest();
      await exposure.ready();
      expect(exposure.shouldShow(p), isTrue, reason: 'one view so far');
      await exposure.markShown(p.id); // session 2

      exposure.newSessionForTest();
      await exposure.ready();
      expect(exposure.shouldShow(p), isFalse, reason: 'seen twice');
    });

    test('voting hides it from the next session on', () async {
      await exposure.ready();
      final p = _poll();
      await exposure.markShown(p.id);
      await exposure.markVoted(p.id);
      expect(exposure.shouldShow(p), isTrue,
          reason: 'the results stay where the reader voted');

      exposure.newSessionForTest();
      await exposure.ready();
      expect(exposure.shouldShow(_poll()), isFalse);
    });

    test('a poll the server says was voted on is not offered', () async {
      await exposure.ready();
      expect(exposure.shouldShow(_poll(voted: 1)), isFalse);
    });

    test('eligible keeps order and drops the rest', () async {
      await exposure.ready();
      await exposure.markVoted('b');
      exposure.newSessionForTest();
      await exposure.ready();
      final list = exposure
          .eligible([_poll(id: 'a'), _poll(id: 'b'), _poll(id: 'c', voted: 0)]);
      expect(list.map((p) => p.id), ['a']);
    });
  });

  group('feeds use the cap', () {
    test('Spotlight inserts each eligible poll once, no cycling', () {
      final src =
          File('lib/spotlight/spotlight_controller.dart').readAsStringSync();
      expect(src, contains('PollExposure.instance.eligible(_pollsPool)'));
      expect(src, contains('pollIndex < polls.length'));
      expect(src, isNot(contains('pollIndex++ % _pollsPool.length')));
    });

    test('Home picks the first eligible poll', () {
      final src = File('lib/screens/news_feed_tab.dart').readAsStringSync();
      expect(src, contains('PollExposure.instance.eligible(polls)'));
    });
  });

  group('card', () {
    Future<void> pump(WidgetTester tester, Poll poll) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: PollCard(poll: poll)))));
      await tester.pumpAndSettle();
    }

    testWidgets('before voting: question, tappable options, no percentages',
        (tester) async {
      await pump(tester, _poll());
      expect(find.text('Who will win?'), findsOneWidget);
      expect(find.text('Tap an option to vote'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        expect(find.byKey(Key('poll_option_$i')), findsOneWidget);
      }
      expect(find.textContaining('%'), findsNothing);
      expect(find.text('2 votes'), findsOneWidget);
    });

    testWidgets('voting shows results, ticks the pick and records it',
        (tester) async {
      final adapter = _Adapter(201);
      ApiClient.instance.dio.httpClientAdapter = adapter;
      final poll = _poll();
      await pump(tester, poll);
      await tester.tap(find.byKey(const Key('poll_option_0')));
      await tester.pumpAndSettle();

      expect(adapter.calls, 1);
      expect(poll.selectedOption, 0);
      expect(find.text('3 votes'), findsOneWidget);
      expect(find.textContaining('%'), findsWidgets);
      expect(find.byKey(const Key('poll_voted_note')), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      exposure.newSessionForTest();
      await exposure.ready();
      expect(exposure.shouldShow(_poll()), isFalse);
    });

    testWidgets('a failed vote is undone so the reader can try again',
        (tester) async {
      ApiClient.instance.dio.httpClientAdapter = _Adapter(500);
      final poll = _poll();
      await pump(tester, poll);
      await tester.tap(find.byKey(const Key('poll_option_1')));
      await tester.pumpAndSettle();
      expect(poll.selectedOption, isNull);
      expect(poll.totalVotes, 2);
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('showing the card counts one view', (tester) async {
      await exposure.ready();
      await pump(tester, _poll(id: 'seen'));
      exposure.newSessionForTest();
      await exposure.ready();
      final prefs = await SharedPreferences.getInstance();
      final views = jsonDecode(prefs.getString(PollExposure.viewsKey)!) as Map;
      expect(views['seen'], 1);
    });

    testWidgets('no overflow on a small phone', (tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: PollCard(poll: _poll(voted: 1))))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
