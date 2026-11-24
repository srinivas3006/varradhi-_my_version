import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/screens/feedback_screen.dart';
import 'package:vaaradhi/services/feedback_service.dart';
import 'package:vaaradhi/state/app_state.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    calls++;
    return handler(options);
  }

  @override
  void close({bool force = false}) {}

  static ResponseBody json(Object data, int status) => ResponseBody.fromString(
        jsonEncode(data),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
}

FeedbackService _service(_Adapter adapter) => FeedbackService(
      dio: Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter,
      appVersionProvider: () async => '1.8.6+25',
    );

class _PendingService extends FeedbackService {
  _PendingService(this.response)
      : super(
          dio: Dio(BaseOptions(baseUrl: 'https://api.test')),
          appVersionProvider: () async => '1.8.6+25',
        );

  final Completer<FeedbackSubmission> response;

  @override
  Future<FeedbackSubmission> submit(FeedbackDraft draft) => response.future;
}

Future<void> _pump(WidgetTester tester, FeedbackService service) async {
  await tester.pumpWidget(MaterialApp(
    home: FeedbackScreen(service: service),
  ));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppState.instance.language = 'English';
  });

  testWidgets('validates required input without submitting', (tester) async {
    final adapter = _Adapter((_) async => _Adapter.json({'data': {}}, 201));
    await _pump(tester, _service(adapter));

    await tester.tap(find.byKey(const Key('feedback_submit')));
    await tester.pump();

    expect(find.text('This field may not be blank.'), findsNWidgets(2));
    expect(adapter.calls, 0);
  });

  testWidgets('preserves form values and displays server field errors',
      (tester) async {
    final adapter = _Adapter((_) async => _Adapter.json({
          'data': null,
          'errors': {
            'code': 400,
            'message': 'An error occurred.',
            'details': {
              'subject': ['Subject already exists.'],
              'message': 'Message is invalid.',
            },
          },
        }, 400));
    await _pump(tester, _service(adapter));

    await tester.enterText(
        find.byKey(const Key('feedback_subject')), 'Original subject');
    await tester.enterText(
        find.byKey(const Key('feedback_message')), 'Original message');
    await tester.tap(find.byKey(const Key('feedback_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Subject already exists.'), findsOneWidget);
    expect(find.text('Message is invalid.'), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('feedback_subject')))
            .controller!
            .text,
        'Original subject');
    expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('feedback_message')))
            .controller!
            .text,
        'Original message');
  });

  testWidgets('only 201 shows success and clears submitted values',
      (tester) async {
    final adapter = _Adapter((_) async => _Adapter.json({
          'data': {'id': '9f7f1a5f-a21d-45e1-876b-3053d1647356'},
          'meta': {},
          'errors': null,
        }, 201));
    await _pump(tester, _service(adapter));

    await tester.enterText(
        find.byKey(const Key('feedback_subject')), 'A subject');
    await tester.enterText(
        find.byKey(const Key('feedback_message')), 'A message');
    await tester.tap(find.byKey(const Key('feedback_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Thank you. Your feedback has been submitted.'),
        findsOneWidget);
    expect(find.textContaining('9f7f1a5f-a21d-45e1-876b-3053d1647356'),
        findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('feedback_subject')))
            .controller!
            .text,
        isEmpty);
    expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('feedback_message')))
            .controller!
            .text,
        isEmpty);
  });

  testWidgets('blocks duplicate submits while request is in flight',
      (tester) async {
    final response = Completer<FeedbackSubmission>();
    await _pump(tester, _PendingService(response));
    await tester.enterText(
        find.byKey(const Key('feedback_subject')), 'A subject');
    await tester.enterText(
        find.byKey(const Key('feedback_message')), 'A message');

    await tester.tap(find.byKey(const Key('feedback_submit')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('feedback_submit')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('feedback_submit')));
    await tester.pump();

    response.complete(const FeedbackSubmission(id: 'test-reference'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('feedback_success')), findsOneWidget);
  });
}
