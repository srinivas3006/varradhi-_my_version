import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/core/network/dio_client.dart';
import 'package:vaaradhi/screens/cms_page_screen.dart';
import 'package:vaaradhi/services/api_service.dart';
import 'package:vaaradhi/services/cms_service.dart';

DioException _status(int code) {
  final ro = RequestOptions(path: '/api/v1/cms/x/');
  return DioException(
    requestOptions: ro,
    response: Response(requestOptions: ro, statusCode: code),
    type: DioExceptionType.badResponse,
  );
}

Map<String, dynamic> _page(String title, String html) =>
    {'title': title, 'slug': 'privacy-policy', 'content': html};

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions o) handler;
  @override
  Future<ResponseBody> fetch(
          RequestOptions o, Stream<Uint8List>? _, Future<void>? __) =>
      handler(o);
  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('slugs match the backend', () {
    test('about, privacy, terms, contact', () {
      expect(CmsSlugs.about, 'about-us');
      expect(CmsSlugs.privacy, 'privacy-policy');
      expect(CmsSlugs.terms, 'terms-and-conditions');
      expect(CmsSlugs.contact, 'contact-us');
    });
  });

  group('API', () {
    test('GET /api/v1/cms/{slug}/ and returns data', () async {
      String? path;
      ApiClient.instance.dio.httpClientAdapter = _Adapter((o) async {
        path = o.path;
        return ResponseBody.fromString(
            jsonEncode({
              'data': _page('Privacy Policy', '<p>x</p>'),
              'meta': {},
              'errors': null
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType]
            });
      });
      final data = await ApiService.instance.fetchCmsPage('privacy-policy');
      expect(path, '/api/v1/cms/privacy-policy/');
      expect(data['title'], 'Privacy Policy');
    });

    test('a 404 reply throws with its status', () async {
      ApiClient.instance.dio.httpClientAdapter =
          _Adapter((o) async => ResponseBody.fromString(
                  jsonEncode({
                    'data': null,
                    'errors': {'code': 'not_found', 'message': 'Not found.'}
                  }),
                  404,
                  headers: {
                    Headers.contentTypeHeader: [Headers.jsonContentType]
                  }));
      await expectLater(
        ApiService.instance.fetchCmsPage('about-us'),
        throwsA(isA<DioException>()
            .having((e) => e.response?.statusCode, 'status', 404)),
      );
    });
  });

  group('CmsService', () {
    test('fresh page is returned and cached by slug', () async {
      final s = CmsService(
          fetcher: (_) async => _page('Privacy Policy', '<p>Hello</p>'));
      final r = await s.load('privacy-policy');
      expect(r.status, CmsStatus.fresh);
      expect(r.page!.title, 'Privacy Policy');
      final saved = await s.cached('privacy-policy');
      expect(saved!.content, '<p>Hello</p>');
    });

    test('offline → the cached copy', () async {
      await CmsService(fetcher: (_) async => _page('T', '<p>Saved</p>'))
          .load('terms-and-conditions');
      final r = await CmsService(fetcher: (_) async {
        throw DioException(
            requestOptions: RequestOptions(path: '/'),
            type: DioExceptionType.connectionError);
      }).load('terms-and-conditions');
      expect(r.status, CmsStatus.cached);
      expect(r.page!.content, '<p>Saved</p>');
    });

    test('500 → cached copy if any, else failed', () async {
      final none = await CmsService(fetcher: (_) async => throw _status(500))
          .load('about-us');
      expect(none.status, CmsStatus.failed);

      await CmsService(fetcher: (_) async => _page('A', '<p>a</p>'))
          .load('about-us');
      final r = await CmsService(fetcher: (_) async => throw _status(500))
          .load('about-us');
      expect(r.status, CmsStatus.cached);
    });

    test('404 → not found, and the old copy is forgotten', () async {
      await CmsService(fetcher: (_) async => _page('C', '<p>old</p>'))
          .load('contact-us');
      final s = CmsService(fetcher: (_) async => throw _status(404));
      final r = await s.load('contact-us');
      expect(r.status, CmsStatus.notFound);
      expect(await s.cached('contact-us'), isNull,
          reason: 'an inactive page must not keep showing');
    });

    test('429 → waits and retries once', () async {
      var calls = 0;
      final s = CmsService(
        throttleWait: Duration.zero,
        fetcher: (_) async {
          calls++;
          if (calls == 1) throw _status(429);
          return _page('P', '<p>ok</p>');
        },
      );
      final r = await s.load('privacy-policy');
      expect(calls, 2);
      expect(r.status, CmsStatus.fresh);
    });

    test('429 twice → falls back like any failure', () async {
      var calls = 0;
      final r = await CmsService(
        throttleWait: Duration.zero,
        fetcher: (_) async {
          calls++;
          throw _status(429);
        },
      ).load('privacy-policy');
      expect(calls, 2, reason: 'one retry, not a loop');
      expect(r.status, CmsStatus.failed);
    });
  });

  group('screen', () {
    Future<void> pump(WidgetTester tester, CmsService service) async {
      tester.view.physicalSize = const Size(1080, 2392);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: CMSPageScreen(
          slug: 'privacy-policy',
          initialTitle: 'Menu label',
          service: service,
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the server title and renders the HTML', (tester) async {
      await pump(
          tester,
          CmsService(
              fetcher: (_) async => _page('Privacy Policy',
                  '<h1>Privacy Policy</h1><p>We <b>respect</b> you.</p>')));
      expect(find.text('Privacy Policy'), findsWidgets);
      expect(find.text('Menu label'), findsNothing);
      expect(find.byType(HtmlWidget), findsOneWidget);
      expect(
          find.textContaining('respect', findRichText: true), findsOneWidget);
    });

    testWidgets('the repeated <h1> title is not printed twice', (tester) async {
      await pump(
          tester,
          CmsService(
              fetcher: (_) async =>
                  _page('Privacy Policy', '<h1>Privacy Policy</h1><p>x</p>')));
      final html = tester.widget<HtmlWidget>(find.byType(HtmlWidget)).html;
      expect(html, isNot(contains('<h1>')));
    });

    testWidgets('404 → "Page not available" with Retry', (tester) async {
      var calls = 0;
      await pump(tester, CmsService(fetcher: (_) async {
        calls++;
        throw _status(404);
      }));
      expect(find.byKey(const Key('cms_not_found')), findsOneWidget);
      expect(find.text('పేజీ అందుబాటులో లేదు'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('cms_retry')));
      await tester.tap(find.byKey(const Key('cms_retry')));
      await tester.pumpAndSettle();
      expect(calls, 2);
    });

    testWidgets('no network and no cache → retry screen', (tester) async {
      await pump(tester, CmsService(fetcher: (_) async => throw _status(500)));
      expect(find.byKey(const Key('cms_failed')), findsOneWidget);
      expect(find.byKey(const Key('cms_retry')), findsOneWidget);
    });

    testWidgets('no network but cached → page plus an offline note',
        (tester) async {
      await CmsService(fetcher: (_) async => _page('P', '<p>Saved text</p>'))
          .load('privacy-policy');
      await pump(tester, CmsService(fetcher: (_) async => throw _status(503)));
      expect(find.byKey(const Key('cms_content')), findsOneWidget);
      expect(find.textContaining('Saved text', findRichText: true),
          findsOneWidget);
      expect(find.byKey(const Key('cms_offline_note')), findsOneWidget);
    });
  });

  group('no page text is written into the app', () {
    test('About, Privacy and Terms only open the CMS page', () {
      for (final f in [
        'lib/screens/about_screen.dart',
        'lib/screens/privacy_policy_screen.dart',
        'lib/screens/terms_screen.dart',
      ]) {
        final src = File(f).readAsStringSync();
        expect(src, contains('CMSPageScreen('), reason: f);
        expect(src.split('\n').length, lessThan(20), reason: f);
      }
    });

    test('the CMS screen has no built-in page copy', () {
      final src = File('lib/screens/cms_page_screen.dart').readAsStringSync();
      expect(src, isNot(contains('_getDefaultContent')));
      expect(src, isNot(contains('contact@vaaradhinews.com')));
    });

    test('settings opens the backend slugs', () {
      final src = File('lib/screens/settings_screen.dart').readAsStringSync();
      for (final old in ["slug: 'about'", "slug: 'terms'", "slug: 'contact'"]) {
        expect(src, isNot(contains(old)));
      }
      expect(src, contains('CmsSlugs.contact'));
    });
  });
}
