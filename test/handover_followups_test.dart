import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/core/network/dio_client.dart';
import 'package:vaaradhi/features/admin/data/models/admin_report_model.dart';
import 'package:vaaradhi/features/admin/data/models/admin_ugc_submission_model.dart';
import 'package:vaaradhi/features/admin/data/services/admin_ugc_api_service.dart';
import 'package:vaaradhi/features/admin/presentation/widgets/dialogs/admin_approval_dialog.dart';
import 'package:vaaradhi/models/news_article.dart';
import 'package:vaaradhi/models/submission_status.dart';
import 'package:vaaradhi/screens/comments_screen.dart';
import 'package:vaaradhi/screens/submission_status_screen.dart';
import 'package:vaaradhi/state/app_state.dart';

SubmissionStatus _status(Map<String, dynamic> data) =>
    SubmissionStatus.parse({'data': data, 'meta': {}, 'errors': null});

Future<void> _pumpStatus(WidgetTester tester,
    Future<SubmissionStatus> Function(String) loader) async {
  await tester.pumpWidget(MaterialApp(
    home: SubmissionStatusScreen(
        key: UniqueKey(),
        submissionId: 'sub-1', initialTitle: 'Road', statusLoader: loader),
  ));
  await tester.pump();
  await tester.pump();
}

/// Captures admin requests on the shared client and answers them.
class _Capture extends Interceptor {
  final List<RequestOptions> requests = [];
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requests.add(options);
    handler.resolve(Response(
      requestOptions: options,
      statusCode: 200,
      data: {
        'data': options.path.contains('target-preview')
            ? {
                'target_count': 1200,
                'target_scope': 'district',
                'warnings': ['Large audience'],
              }
            : <dynamic>[],
        'meta': {'next': null},
        'errors': null,
      },
    ));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppState.instance.language = 'English';
  });

  group('submission status (handover §10)', () {
    test('parses the backend decision fields', () {
      final s = _status({
        'id': 'sub-1',
        'title': 'Road',
        'reporter_status': 'pending',
        'next_action': 'wait_media_processing',
        'upload_status': 'processing',
        'can_upload_media': false,
        'can_resubmit': false,
        'review_note': '',
        'moderation_timeline': [
          {'status': 'PENDING_REVIEW', 'created_at': '2026-09-25T10:00:00Z'},
        ],
      });
      expect(s.nextAction, SubmissionStatus.waitMedia);
      expect(s.uploadStatus, 'PROCESSING');
      expect(s.isProcessing, isTrue);
      expect(s.timeline.single.status, 'PENDING_REVIEW');
    });

    test('READY / FAILED stop the polling', () {
      expect(
          _status({'next_action': 'wait_editor_review', 'upload_status': 'READY'})
              .isProcessing,
          isFalse);
      expect(
          _status({
            'next_action': 'upload_failed_retry_media',
            'upload_status': 'FAILED'
          }).isProcessing,
          isFalse);
    });

    testWidgets('published → "View story"', (tester) async {
      await _pumpStatus(
          tester,
          (_) async => _status({
                'title': 'Road',
                'reporter_status': 'published',
                'next_action': 'view_in_feed',
                'upload_status': 'READY',
              }));
      expect(find.byKey(const Key('status_view_in_feed')), findsOneWidget);
      expect(find.text('Published'), findsOneWidget);
    });

    testWidgets('failed media → retry only when can_upload_media',
        (tester) async {
      await _pumpStatus(
          tester,
          (_) async => _status({
                'next_action': 'upload_failed_retry_media',
                'upload_status': 'FAILED',
                'can_upload_media': true,
              }));
      expect(find.byKey(const Key('status_retry_media')), findsOneWidget);

      await _pumpStatus(
          tester,
          (_) async => _status({
                'next_action': 'upload_failed_retry_media',
                'upload_status': 'FAILED',
                'can_upload_media': false,
              }));
      expect(find.byKey(const Key('status_retry_media')), findsNothing);
    });

    testWidgets('rejected shows the editor note and "New story"',
        (tester) async {
      await _pumpStatus(
          tester,
          (_) async => _status({
                'reporter_status': 'rejected',
                'next_action': 'create_new_submission',
                'review_note': 'Location could not be verified.',
              }));
      expect(find.text('Location could not be verified.'), findsOneWidget);
      expect(find.byKey(const Key('status_create_new')), findsOneWidget);
    });

    testWidgets('keeps polling while media processes', (tester) async {
      var calls = 0;
      await _pumpStatus(tester, (_) async {
        calls++;
        return _status({
          'next_action': calls < 3 ? 'wait_media_processing' : 'wait_editor_review',
          'upload_status': calls < 3 ? 'PROCESSING' : 'READY',
        });
      });
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(calls, 3);
      await tester.pump(const Duration(seconds: 10));
      expect(calls, 3, reason: 'READY stops polling');
    });
  });

  group('admin report queues (handover §17.5)', () {
    late _Capture capture;
    setUp(() {
      capture = _Capture();
      ApiClient.instance.dio.interceptors.insert(0, capture);
    });
    tearDown(() => ApiClient.instance.dio.interceptors.remove(capture));

    test('desk and citizen queues use their own endpoints', () async {
      final api = AdminUgcApiService();
      await api.getReports(status: 'PENDING', source: AdminReportSource.desk);
      await api.getReports(status: 'PENDING');
      await api.reviewReport('r1', source: AdminReportSource.desk);
      await api.dismissReport('r2');

      final paths = capture.requests.map((r) => r.path).toList();
      expect(paths, [
        '/admin/api/articles/reports/',
        '/admin/api/ugc/reports/',
        '/admin/api/articles/reports/r1/review/',
        '/admin/api/ugc/reports/r2/dismiss/',
      ]);
      expect(capture.requests.first.queryParameters['status'], 'pending',
          reason: 'desk queue statuses are lowercase');
      expect(capture.requests[1].queryParameters['status'], 'PENDING');
    });

    test('an article report row parses its article fields', () {
      final r = AdminReportModel.fromJson({
        'id': 'r1',
        'article_id': 'a1',
        'reason': 'spam',
        'notes': 'Duplicate',
        'status': 'pending',
      });
      expect(r.targetSubmissionId, 'a1');
      expect(r.reporterNote, 'Duplicate');
      expect(r.status, 'PENDING');
    });
  });

  group('push target preview before approve (handover §15)', () {
    AdminUgcSubmissionModel submission() => AdminUgcSubmissionModel.fromJson({
          'id': 's1',
          'title': 'Road repair',
          'state': 'Telangana',
          'district': 'Suryapet',
        });

    testWidgets('warnings require explicit confirmation', (tester) async {
      var approved = false;
      Map<String, dynamic>? sentPreview;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAdminApprovalDialog(
              context,
              submission: submission(),
              onApprove: (_, __, ___) async => approved = true,
              onPreview: (req) async {
                sentPreview = req;
                return {
                  'target_count': 1200,
                  'target_scope': 'district',
                  'warnings': ['Large audience'],
                };
              },
            ),
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(sentPreview?['district'], 'Suryapet');
      expect(find.textContaining('1200'), findsOneWidget);
      expect(find.text('Large audience'), findsOneWidget);

      ElevatedButton approve() => tester
          .widget<ElevatedButton>(find.byKey(const Key('admin_approve_submit')));
      expect(approve().onPressed, isNull, reason: 'blocked until confirmed');

      await tester.ensureVisible(find.byKey(const Key('admin_push_confirm')));
      await tester.tap(find.byKey(const Key('admin_push_confirm')));
      await tester.pumpAndSettle();
      expect(approve().onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('admin_approve_submit')));
      await tester.pumpAndSettle();
      expect(approved, isTrue);
    });

    testWidgets('no push → no preview, approve works directly',
        (tester) async {
      var previews = 0;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAdminApprovalDialog(
              context,
              submission: submission(),
              onApprove: (_, __, ___) async {},
              onPreview: (_) async {
                previews++;
                return {};
              },
            ),
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(previews, 0);
      expect(
          tester
              .widget<ElevatedButton>(
                  find.byKey(const Key('admin_approve_submit')))
              .onPressed,
          isNotNull);
    });
  });

  group('citizen-post comments (handover §17.4)', () {
    late _Capture capture;
    setUp(() {
      capture = _Capture();
      ApiClient.instance.dio.interceptors.insert(0, capture);
    });
    tearDown(() => ApiClient.instance.dio.interceptors.remove(capture));

    testWidgets('never call the article comment API with a UGC id',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: CommentsScreen(
          article: NewsArticle.fromJson(
              {'id': 'sub-1', 'title': 'x', 'feed_item_type': 'ugc'}),
        ),
      ));
      await tester.pump();
      expect(find.byKey(const Key('ugc_comments_unavailable')), findsOneWidget);
      expect(capture.requests.where((r) => r.path.contains('comments')),
          isEmpty);
    });
  });

  group('source checks', () {
    test('a bare citizen-post link opens the post, loaded from the API', () {
      final src =
          File('lib/services/notification_service.dart').readAsStringSync();
      expect(src, contains("NewsArticle.fromJson({'id': id, 'feed_item_type': 'ugc'})"));
      final detail =
          File('lib/screens/news_detail_screen.dart').readAsStringSync();
      expect(detail, contains('ApiService.instance.getUgcDetail(id)'));
    });

    test('reporter submissions are cursor-paginated (no page=)', () {
      final api = File('lib/services/api_service.dart').readAsStringSync();
      final fn = api.substring(
          api.indexOf('Future<List<ReporterPost>> getReporterSubmissions'));
      expect(fn.substring(0, 600), isNot(contains("'page':")));
    });
  });
}
