import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/core/network/dio_client.dart';
import 'package:vaaradhi/models/location_model.dart';
import 'package:vaaradhi/models/poll.dart';
import 'package:vaaradhi/providers/location_provider.dart';
import 'package:vaaradhi/repositories/location_repository.dart';
import 'package:vaaradhi/screens/poll_detail_screen.dart';
import 'package:vaaradhi/services/api_service.dart';
import 'package:vaaradhi/services/poll_context.dart';
import 'package:vaaradhi/services/poll_exposure.dart';
import 'package:vaaradhi/state/app_state.dart';

const _first = '11111111-2222-4333-8444-555555555551';
const _second = '11111111-2222-4333-8444-555555555552';

Map<String, dynamic> _poll(String id,
        {Object? voted, String level = 'global'}) =>
    {
      'id': id,
      'question': 'Which option?',
      'coverage_level': level,
      if (level != 'global') 'state_id': 'state-with-polls',
      if (level == 'district') 'district_id': 'district-with-polls',
      'total_votes': 42,
      'user_vote': voted,
      'options': [
        {
          'id': _second,
          'label': 'Second',
          'sort_order': 2,
          'vote_count': 9,
          'percentage': 0
        },
        {
          'id': _first,
          'label': 'First',
          'sort_order': 1,
          'vote_count': 21,
          'percentage': 50
        },
      ],
    };

ResponseBody _response(
  Object? data, {
  int status = 200,
  Map<String, dynamic> meta = const {},
  Map<String, dynamic>? errors,
  String? retryAfter,
}) =>
    ResponseBody.fromString(
      jsonEncode({'data': data, 'meta': meta, 'errors': errors}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        if (retryAfter != null) 'retry-after': [retryAfter],
      },
    );

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final FutureOr<ResponseBody> Function(RequestOptions) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body,
      Future<void>? cancel) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final client = ApiClient.instance.dio;
  final app = AppState.instance;
  final api = ApiService.instance;
  late HttpClientAdapter previous;
  _Adapter install(FutureOr<ResponseBody> Function(RequestOptions) respond) {
    final adapter = _Adapter(respond);
    client.httpClientAdapter = adapter;
    return adapter;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    previous = client.httpClientAdapter;
    app
      ..deviceId = 'fixture-device'
      ..installationSecret = 'fixture-secret'
      ..isLoggedIn = false
      ..authToken = null
      ..refreshToken = null
      ..userId = null
      ..sessionId = null
      ..stateId = null
      ..districtId = null
      ..subdistrictId = null
      ..villageId = null
      ..hasValidLocation = false;
  });
  tearDown(() {
    client.httpClientAdapter = previous;
    app
      ..isLoggedIn = false
      ..authToken = null
      ..userId = null
      ..hasValidLocation = false;
  });

  test('paged poll list trusts eligibility and follows next beyond twenty',
      () async {
    final adapter = install((request) {
      if (request.uri.queryParameters['page'] == '2') {
        return _response([
          _poll('p20', level: 'state'),
          _poll('p21', level: 'district')
        ], meta: {
          'count': 20,
          'next': 'https://wrong.example/api/v1/polls/?page=3'
        });
      }
      return _response([
        for (var i = 1; i <= 20; i++)
          _poll('p$i', level: i == 20 ? 'state' : 'global')
      ], meta: {
        'count': 20,
        'next': '${client.options.baseUrl}/api/v1/polls/?page=2'
      });
    });
    final polls = await api.getPolls();
    expect(polls, hasLength(21));
    expect(adapter.requests, hasLength(2));
    expect(adapter.requests.first.uri.queryParameters, {'page_size': '20'});
    expect(adapter.requests.first.headers['X-Device-ID'], 'fixture-device');
    expect(adapter.requests.last.headers['X-Installation-Secret'],
        'fixture-secret');
    expect(polls.last.districtId, 'district-with-polls');
    expect(polls[19].stateId, 'state-with-polls');
    expect(polls.first.coverageLevel, 'global');
  });

  test('sorted options use server zero percent and recognize legacy votes', () {
    final poll = Poll.fromJson(_poll('p', voted: 'b'));
    expect(poll.options, ['First', 'Second']);
    expect(poll.totalVotes, 42);
    expect(poll.percentFor(1), 0);
    expect(poll.hasVoted, isTrue);
    expect(poll.selectedOptionId, _second);
  });

  test('all seven coverage levels and nullable IDs parse', () {
    for (final value in PollCoverage.values) {
      final local =
          value == PollCoverage.mandal || value == PollCoverage.village;
      final regional =
          value == PollCoverage.municipality || value == PollCoverage.assembly;
      final poll = Poll.fromJson({
        ..._poll('coverage', level: value.name),
        'subdistrict_id': local ? 'mandal-id' : null,
        'village_id': value == PollCoverage.village ? 'village-id' : null,
        'region_id': regional ? 'region-id' : null,
      });
      expect(poll.coverage, value);
      expect(poll.subdistrictId, local ? 'mandal-id' : null);
      expect(
          poll.villageId, value == PollCoverage.village ? 'village-id' : null);
      expect(poll.regionId, regional ? 'region-id' : null);
      if (regional) expect(poll.districtId, isNull);
    }
    final future = Poll.fromJson(_poll('future', level: 'future'));
    expect(future.coverage, isNull);
    expect(future.coverageLevel, 'future');
  });

  test('legacy vote uses only choice and keeps guest identity with push off',
      () async {
    final previousPush = app.pushNotificationsEnabled;
    app
      ..pushNotificationsEnabled = false
      ..authToken = 'stale-access';
    addTearDown(() => app.pushNotificationsEnabled = previousPush);
    final adapter = install((_) => _response({
          'id': 'legacy',
          'option_a': 'First',
          'option_b': 'Second',
          'user_vote': 'b',
          'total_votes': 5,
        }));
    final poll = await api.submitPollVote('legacy', optionId: 'b');
    expect(poll.selectedOptionId, 'b');
    expect(poll.optionItems.every((option) => option.canVote), isTrue);
    final request = adapter.requests.single;
    expect(request.data, {'choice': 'b'});
    expect(request.headers['Authorization'], isNull);
    expect(request.headers['X-Device-ID'], 'fixture-device');
    expect(request.headers['X-Installation-Secret'], 'fixture-secret');
  });

  test('signed-in vote sends Bearer and exact option payload', () async {
    app
      ..isLoggedIn = true
      ..authToken = 'fixture-access'
      ..userId = 'alice';
    final adapter = install((_) => _response({
          ..._poll('authenticated-poll'),
          'user_vote_option_id': _first,
        }));
    final poll =
        await api.submitPollVote('authenticated-poll', optionId: _first);
    expect(poll.selectedOptionId, _first);
    final request = adapter.requests.single;
    expect(request.headers['Authorization'], 'Bearer fixture-access');
    expect(request.headers['X-Installation-Secret'], isNull);
    expect(request.data, {'option_id': _first});
  });

  test('uncertain vote requires detail before the same reader can resubmit',
      () async {
    final adapter = install((request) => request.method == 'GET'
        ? _response(_poll('uncertain-poll'))
        : _response(null, status: 503));
    final first = api.submitPollVote('uncertain-poll', optionId: _first);
    await expectLater(first, throwsA(isA<PollFailure>()));
    await expectLater(api.submitPollVote('uncertain-poll', optionId: _first),
        throwsA(isA<PollFailure>()));
    expect(adapter.requests, hasLength(1));
    await api.fetchPollDetail('uncertain-poll');
    await expectLater(api.submitPollVote('uncertain-poll', optionId: _first),
        throwsA(isA<PollFailure>()));
    expect(adapter.requests.map((r) => r.method), ['POST', 'GET', 'POST']);
  });

  test(
      'a village change in the same mandal discards a personalized list response',
      () async {
    final arrived = Completer<void>();
    final answer = Completer<ResponseBody>();
    install((_) {
      arrived.complete();
      return answer.future;
    });
    app
      ..hasValidLocation = true
      ..stateId = 'same-state'
      ..districtId = 'same-district'
      ..subdistrictId = 'same-mandal'
      ..villageId = 'old-village';
    final pending = api.getPolls();
    await arrived.future;
    app.villageId = 'new-village';
    answer.complete(_response([_poll('old-reader', voted: 'a')]));
    expect(await pending, isEmpty);
  });

  test('a location change cannot bypass reconciliation of an in-flight vote',
      () async {
    final arrived = Completer<void>();
    final answer = Completer<ResponseBody>();
    final adapter = install((request) {
      if (request.method == 'GET') return _response(_poll('moving-voter'));
      arrived.complete();
      return answer.future;
    });
    app
      ..hasValidLocation = true
      ..villageId = 'village-before';
    final pending = api.submitPollVote('moving-voter', optionId: _first);
    await arrived.future;
    app.villageId = 'village-after';
    answer.complete(_response(_poll('moving-voter', voted: _first)));
    await expectLater(pending, throwsA(isA<PollFailure>()));
    await expectLater(
      api.submitPollVote('moving-voter', optionId: _first),
      throwsA(isA<PollFailure>().having(
          (failure) => failure.problem, 'problem', PollProblem.uncertain)),
    );
    expect(adapter.requests, hasLength(1));
    await api.fetchPollDetail('moving-voter');
    expect(adapter.requests.map((request) => request.method), ['POST', 'GET']);
  });

  test('exposure pacing does not cross accounts', () async {
    final exposure = PollExposure.instance;
    exposure.resetForTest();
    app
      ..isLoggedIn = true
      ..userId = 'alice';
    await exposure.markShown('shared-poll');
    exposure.newSessionForTest();
    await exposure.markShown('shared-poll');
    exposure.newSessionForTest();
    await exposure.ready();
    expect(exposure.shouldShow(Poll.fromJson(_poll('shared-poll'))), isFalse);
    app.userId = 'bob';
    await exposure.ready();
    expect(exposure.shouldShow(Poll.fromJson(_poll('shared-poll'))), isTrue);
  });

  test('the inactive-poll 400 response removes a stale card', () async {
    install((_) => _response(null, status: 400, errors: {
          'message': 'Invalid input.',
          'details': {
            'detail': ['Poll not found or is no longer active.']
          },
        }));
    await expectLater(
      api.submitPollVote('inactive', optionId: _first),
      throwsA(isA<PollFailure>().having(
          (failure) => failure.problem, 'problem', PollProblem.unavailable)),
    );
  });

  testWidgets('a shared poll can refresh after an admin resets votes',
      (tester) async {
    app.language = 'English';
    var reset = false;
    final adapter = install((_) => _response({
          ..._poll('reset-poll', level: 'assembly', voted: reset ? null : 'a'),
          'region_id': 'private-region-id',
        }));
    await tester.pumpWidget(
        const MaterialApp(home: PollDetailScreen(pollId: 'reset-poll')));
    await tester.pumpAndSettle();
    expect(find.text('Assembly Constituency'), findsOneWidget);
    expect(find.textContaining('private-region-id'), findsNothing);
    expect(find.byKey(const Key('poll_voted_note')), findsOneWidget);
    reset = true;
    await tester.ensureVisible(find.byKey(const Key('poll_refresh')));
    await tester.tap(find.byKey(const Key('poll_refresh')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('poll_voted_note')), findsNothing);
    expect(find.byKey(const Key('poll_vote')), findsOneWidget);
    expect(adapter.requests.map((r) => r.method), ['GET', 'GET']);
  });

  test('nested duplicate errors reconcile and 429 prevents another request',
      () async {
    final adapter = install((request) {
      if (request.path.contains('duplicate')) {
        return request.method == 'GET'
            ? _response(_poll('duplicate', voted: 'a'))
            : _response(null, status: 400, errors: {
                'message': 'Invalid request',
                'details': {
                  'vote': ['You already voted.']
                },
              });
      }
      return _response(null, status: 429, retryAfter: '20');
    });
    await expectLater(
        api.submitPollVote('duplicate', optionId: _first),
        throwsA(isA<PollFailure>()
            .having((f) => f.problem, 'problem', PollProblem.duplicate)
            .having((f) => f.message, 'message', 'You already voted.')));
    expect((await api.fetchPollDetail('duplicate')).hasVoted, isTrue);

    app.deviceId = 'throttled-fixture-device';
    for (var i = 0; i < 2; i++) {
      await expectLater(
          api.submitPollVote('throttled', optionId: _first),
          throwsA(isA<PollFailure>()
              .having((f) => f.problem, 'problem', PollProblem.throttled)
              .having((f) => f.retryAfter, 'remaining',
                  greaterThan(Duration.zero))));
    }
    expect(adapter.requests, hasLength(3));
  });

  test('manual location commits only after the server confirms the save',
      () async {
    final arrived = Completer<void>();
    final answer = Completer<ResponseBody>();
    final adapter = install((_) {
      arrived.complete();
      return answer.future;
    });
    final provider = LocationProvider(repository: LocationRepository());
    addTearDown(provider.dispose);
    final pending = provider.apply(const LocationSearchResult(
      type: LocationLevel.district,
      id: 'confirmed-district',
      nameEn: 'District',
      state: 'State',
      district: 'District',
    ));
    await arrived.future;
    expect(app.hasValidLocation, isFalse);
    expect(adapter.requests.single.headers['X-Installation-Secret'],
        'fixture-secret');
    answer.complete(_response({}));
    expect(await pending, isTrue);
    expect(app.districtId, 'confirmed-district');
  });

  testWidgets('shared poll shows an unavailable screen for a missing poll',
      (tester) async {
    install((_) => _response(null, status: 404));
    app.language = 'English';
    await tester.pumpWidget(
        const MaterialApp(home: PollDetailScreen(pollId: 'missing')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('poll_unavailable')), findsOneWidget);
    expect(find.byKey(const Key('poll_vote')), findsNothing);
  });

  testWidgets('expired polls show results without a vote control',
      (tester) async {
    install((_) => _response({..._poll('expired'), 'is_expired': true}));
    app.language = 'English';
    await tester.pumpWidget(
      const MaterialApp(home: PollDetailScreen(pollId: 'expired')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Final results'), findsOneWidget);
    expect(find.byKey(const Key('poll_vote')), findsNothing);
  });
}
