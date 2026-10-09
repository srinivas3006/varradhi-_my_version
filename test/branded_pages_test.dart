import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/core/network/dio_client.dart';
import 'package:vaaradhi/screens/reporter_intro_screen.dart';
import 'package:vaaradhi/widgets/branded_page.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.body, this.status);
  final Map<String, dynamic> body;
  final int status;
  @override
  Future<ResponseBody> fetch(
          RequestOptions o, Stream<Uint8List>? _, Future<void>? __) async =>
      ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });
  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // No CMS page → each screen shows its built-in copy.
    ApiClient.instance.dio.httpClientAdapter = _Adapter({
      'errors': {'message': 'not found'}
    }, 404);
  });

  Future<void> pump(WidgetTester tester, Widget screen,
      {Size size = const Size(1080, 2392)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  testWidgets('reporter intro: branded header, stats, steps, pinned button',
      (tester) async {
    await pump(tester, const ReporterIntroScreen());
    expect(find.byType(BrandedPage), findsOneWidget);
    expect(find.byKey(const Key('reporter_stat_per_story')), findsOneWidget);
    expect(find.byKey(const Key('reporter_stat_withdraw')), findsOneWidget);
    expect(find.text('వార్తను సమర్పించండి'), findsOneWidget);
    expect(find.text('100 టోకెన్లు చేరినప్పుడు విత్‌డ్రా'), findsOneWidget);
    expect(find.byKey(const Key('reporter_register_button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the header collapses into a titled red app bar', (tester) async {
    await pump(tester, const ReporterIntroScreen());
    double barTitleOpacity() => tester
        .widget<AnimatedOpacity>(find.ancestor(
            of: find.descendant(
                of: find.byType(AppBar),
                matching: find.text('రిపోర్టర్‌గా చేరండి')),
            matching: find.byType(AnimatedOpacity)))
        .opacity;
    expect(barTitleOpacity(), 0);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(barTitleOpacity(), 1);
  });

  testWidgets('DocClause.parse splits "N. heading: body"', (tester) async {
    final w = DocClause.parse('2. Heading: the body') as DocClause;
    expect(w.number, '2');
    expect(w.heading, 'Heading');
    expect(w.body, 'the body');
    expect(DocClause.parse('plain text'), isA<DocText>());
  });
}
