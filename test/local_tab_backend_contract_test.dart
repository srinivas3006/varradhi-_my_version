import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:way2news_clone/core/network/dio_client.dart';
import 'package:way2news_clone/screens/local_news_tab.dart';
import 'package:way2news_clone/state/app_state.dart';

class RecordedRequest {
  final String path;
  final String method;
  final Map<String, dynamic> queryParameters;

  RecordedRequest({
    required this.path,
    required this.method,
    required this.queryParameters,
  });

  @override
  String toString() => '$method $path ? $queryParameters';
}

class ContractMockHttpClientAdapter implements HttpClientAdapter {
  final List<RecordedRequest> recordedRequests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<dynamic>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    recordedRequests.add(
      RecordedRequest(
        path: options.path,
        method: options.method,
        queryParameters: Map<String, dynamic>.from(options.queryParameters),
      ),
    );

    if (options.path.contains('/api/v1/articles/feed/')) {
      final scope = options.queryParameters['scope']?.toString();
      final village = options.queryParameters['village']?.toString();
      final subdistrict = options.queryParameters['subdistrict']?.toString();
      final district = options.queryParameters['district']?.toString();

      final id = 'art_${scope}_${village ?? subdistrict ?? district ?? "state"}';
      return ResponseBody.fromString(
        jsonEncode({
          'data': [
            {
              'id': id,
              'title': 'Test Article for $scope ($village / $subdistrict / $district)',
              'slug': '$id-slug',
              'summary': 'Summary of article',
              'content': 'Body of article',
              'category': 'LOCAL',
              'source': 'Varadhi News',
              'published_at': DateTime.now().toIso8601String(),
              'likes_count': 12,
              'comments_count': 3,
              'shares_count': 2,
              'view_count': 50,
              'read_time_minutes': 2,
              'state': 'Telangana',
              'district': district ?? 'Suryapet',
              'subdistrict': subdistrict,
              'village': village,
              'coverage_level': scope ?? 'local',
            }
          ],
          'meta': {
            'count': 25,
            'next': 'cur_next_$id',
            'previous': null,
          },
          'errors': null,
        }),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }

    if (options.path.contains('/api/v1/ugc/feed/')) {
      final scope = options.queryParameters['scope']?.toString();
      final village = options.queryParameters['village']?.toString();
      final subdistrict = options.queryParameters['subdistrict']?.toString();
      final district = options.queryParameters['district']?.toString();

      final id = 'ugc_${scope}_${village ?? subdistrict ?? district ?? "main"}';
      return ResponseBody.fromString(
        jsonEncode({
          'data': [
            {
              'id': id,
              'type': 'ugc',
              'title': 'Citizen Report $scope ($village / $subdistrict)',
              'description': 'Description of citizen report',
              'thumbnail_url': 'https://example.com/ugc.jpg',
              'media_url': 'https://example.com/ugc.jpg',
              'created_at': DateTime.now().toIso8601String(),
              'district': district ?? 'Suryapet',
              'subdistrict': subdistrict ?? '',
              'village': village ?? '',
              'state': 'Telangana',
              'priority_score': 10,
              'source': 'Citizen Reporter',
              'trust_score': 85,
            }
          ],
          'meta': {'count': 10, 'next': 'cur_ugc_next', 'previous': null},
          'errors': null,
        }),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }

    if (options.path.contains('/api/v1/ads/')) {
      return ResponseBody.fromString(
        jsonEncode({
          'data': [
            {
              'id': 'ad_1',
              'title': 'Local Business Ad',
              'image_url': 'https://example.com/ad.jpg',
              'target_url': 'https://example.com',
              'placement_zone': 'feed',
              'zone': 'feed',
            }
          ],
          'meta': {},
          'errors': null,
        }),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }

    return ResponseBody.fromString(
      jsonEncode({'data': [], 'meta': {}, 'errors': null}),
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ContractMockHttpClientAdapter mockAdapter;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    mockAdapter = ContractMockHttpClientAdapter();
    ApiClient.instance.dio.httpClientAdapter = mockAdapter;

    // Configure exact target test location:
    // Telangana -> Suryapet -> Jajireddygudem -> Kesaram
    AppState.instance.setLocation(
      'Telangana',
      'Suryapet',
      subdistrict: 'Jajireddygudem',
      village: 'Kesaram',
    );
  });

  testWidgets(
    'LocalNewsTab Backend Contract: Verifies scope=local for village/mandal, scope=main for district/state, and matching UGC context',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(
            body: LocalNewsTab(),
          ),
        ),
      );

      // Settle network futures by advancing frames without infinite loop on spinners
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      final requests = mockAdapter.recordedRequests;
      expect(requests.isNotEmpty, isTrue, reason: 'Requests should have been made to backend');

      // 1. Village News Request: scope=local, village=Kesaram, subdistrict=Jajireddygudem, district=Suryapet, state=Telangana
      final villageNewsReq = requests.firstWhere(
        (r) =>
            r.path.contains('/api/v1/articles/feed/') &&
            r.queryParameters['scope'] == 'local' &&
            r.queryParameters['village'] == 'Kesaram',
        orElse: () => throw TestFailure('Village news request not found in $requests'),
      );
      expect(villageNewsReq.queryParameters['subdistrict'], 'Jajireddygudem');
      expect(villageNewsReq.queryParameters['district'], 'Suryapet');
      expect(villageNewsReq.queryParameters['state'], 'Telangana');

      // 2. Village UGC Request: scope=local with same location context
      final villageUgcReq = requests.firstWhere(
        (r) =>
            r.path.contains('/api/v1/ugc/feed/') &&
            r.queryParameters['scope'] == 'local' &&
            r.queryParameters['village'] == 'Kesaram',
        orElse: () => throw TestFailure('Village UGC request not found in $requests'),
      );
      expect(villageUgcReq.queryParameters['subdistrict'], 'Jajireddygudem');
      expect(villageUgcReq.queryParameters['district'], 'Suryapet');
      expect(villageUgcReq.queryParameters['state'], 'Telangana');

      // 3. Mandal News Request: scope=local, subdistrict=Jajireddygudem, district=Suryapet, state=Telangana, village=null or empty
      final mandalNewsReq = requests.firstWhere(
        (r) =>
            r.path.contains('/api/v1/articles/feed/') &&
            r.queryParameters['scope'] == 'local' &&
            r.queryParameters['subdistrict'] == 'Jajireddygudem' &&
            (r.queryParameters['village'] == null || r.queryParameters['village'] == ''),
        orElse: () => throw TestFailure('Mandal news request not found in $requests'),
      );
      expect(mandalNewsReq.queryParameters['district'], 'Suryapet');
      expect(mandalNewsReq.queryParameters['state'], 'Telangana');

      // 4. Mandal UGC Request: scope=local with mandal context
      final mandalUgcReq = requests.firstWhere(
        (r) =>
            r.path.contains('/api/v1/ugc/feed/') &&
            r.queryParameters['scope'] == 'local' &&
            r.queryParameters['subdistrict'] == 'Jajireddygudem' &&
            (r.queryParameters['village'] == null || r.queryParameters['village'] == ''),
        orElse: () => throw TestFailure('Mandal UGC request not found in $requests'),
      );
      expect(mandalUgcReq.queryParameters['district'], 'Suryapet');
      expect(mandalUgcReq.queryParameters['state'], 'Telangana');

      // 5. District News Request: scope=main, district=Suryapet, state=Telangana, no subdistrict/village
      final districtNewsReq = requests.firstWhere(
        (r) =>
            r.path.contains('/api/v1/articles/feed/') &&
            r.queryParameters['scope'] == 'main' &&
            r.queryParameters['district'] == 'Suryapet',
        orElse: () => throw TestFailure('District news request not found in $requests'),
      );
      expect(districtNewsReq.queryParameters['subdistrict'], anyOf(isNull, ''));
      expect(districtNewsReq.queryParameters['village'], anyOf(isNull, ''));
      expect(districtNewsReq.queryParameters['state'], 'Telangana');

      // 6. District UGC Request: scope=main, district=Suryapet, state=Telangana
      final districtUgcReq = requests.firstWhere(
        (r) =>
            r.path.contains('/api/v1/ugc/feed/') &&
            r.queryParameters['scope'] == 'main' &&
            r.queryParameters['district'] == 'Suryapet',
        orElse: () => throw TestFailure('District UGC request not found in $requests'),
      );
      expect(districtUgcReq.queryParameters['state'], 'Telangana');

      // 7. State / Global Fallback Request: scope=main, state=Telangana
      final stateNewsReq = requests.firstWhere(
        (r) =>
            r.path.contains('/api/v1/articles/feed/') &&
            r.queryParameters['scope'] == 'main' &&
            (r.queryParameters['district'] == null || r.queryParameters['district'] == ''),
        orElse: () => throw TestFailure('State fallback request not found in $requests'),
      );
      expect(stateNewsReq.queryParameters['state'], 'Telangana');

      // 8. Verify UI Elements: Section headers and localized Telugu location tags
      expect(find.text('గ్రామ వార్తలు'), findsOneWidget);
      expect(find.text('కేసారం'), findsWidgets);
      expect(find.text('మండల వార్తలు'), findsOneWidget);
      expect(find.text('జాజిరెడ్డిగూడెం'), findsWidgets);
      expect(find.text('జిల్లా వార్తలు'), findsOneWidget);
      expect(find.text('సూర్యాపేట'), findsWidgets);

      // 9. Verify Per-Section Pagination:
      // Find the Village Load More button and tap it
      final villageLoadMore = find.text('ఇంకా చూడండి (కేసారం)');
      expect(villageLoadMore, findsOneWidget);

      final preCount = requests.length;
      await tester.ensureVisible(villageLoadMore);
      await tester.tap(villageLoadMore);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      final postRequests = requests.sublist(preCount);
      expect(
        postRequests.any(
          (r) =>
              r.path.contains('/api/v1/articles/feed/') &&
              r.queryParameters['scope'] == 'local' &&
              r.queryParameters['village'] == 'Kesaram' &&
              r.queryParameters['cursor'] != null,
        ),
        isTrue,
        reason: 'Village section should paginate using its cursor with scope=local',
      );

      await tester.pump(const Duration(seconds: 1));
    },
  );
}
