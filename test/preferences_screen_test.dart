import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/core/network/dio_client.dart';
import 'package:vaaradhi/screens/preferences_screen.dart';
import 'package:vaaradhi/state/app_state.dart';

/// The live category list (Oct 2026), as `/api/v1/categories/` sends it.
const _slugs = [
  'general', 'politics', 'national-news', 'state-news', 'local-news',
  'crime', 'education', 'health', 'agriculture', 'sports', 'district-news',
  'business', 'weather', 'jobs-careers', 'devotional', 'cinima',
];

class _Api implements HttpClientAdapter {
  final patches = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<Uint8List>? body, Future<void>? _) async {
    if (o.method == 'PATCH') {
      patches.add(Map<String, dynamic>.from(o.data as Map));
      return _json({'data': o.data});
    }
    if (o.path.contains('/categories/')) {
      return _json({
        'data': [
          for (var i = 0; i < _slugs.length; i++)
            {'id': '$i', 'name': _slugs[i], 'slug': _slugs[i], 'sort_order': i},
        ],
      });
    }
    return _json({'data': []});
  }

  ResponseBody _json(Object body) => ResponseBody.fromString(
        jsonEncode(body),
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
  late _Api api;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (_) async => null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = _Api();
    ApiClient.instance.dio.httpClientAdapter = api;
    AppState.instance.isLoggedIn = false;
    AppState.instance.preferredCategories = [];
  });

  group('saved choices map onto backend slugs', () {
    final active = _slugs.toSet();

    test('slugs are kept as they are', () {
      expect(AppState.resolvePreferenceSlugs(['sports', 'cinima'], active),
          {'sports', 'cinima'});
    });

    test('old English chip names are translated, unknown ones dropped', () {
      expect(
        AppState.resolvePreferenceSlugs(
            ['Politics', 'Cinema', 'National', 'Spiritual',
              'Education & Jobs', 'Videos', 'Technology'],
            active),
        {'politics', 'cinima', 'national-news', 'devotional', 'education',
          'jobs-careers'},
      );
    });
  });

  test('every category is sent, unticked ones as 0.0', () async {
    AppState.instance.isLoggedIn = true;
    AppState.instance.preferredCategories = ['sports', 'Cinema'];
    await AppState.instance.syncPreferredCategories();

    final weights =
        Map<String, dynamic>.from(api.patches.single['category_weights']);
    expect(weights.keys.toSet(), _slugs.toSet());
    expect(weights['sports'], 1.0);
    expect(weights['cinima'], 1.0);
    expect(weights['politics'], 0.0);
  });

  testWidgets('the screen shows backend categories and saves the choice',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const PreferencesScreen())),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    for (final slug in _slugs) {
      expect(find.byKey(ValueKey('pref_$slug')), findsOneWidget);
    }

    await tester.tap(find.byKey(const ValueKey('pref_sports')));
    await tester.pump();
    await tester.tap(find.text('సేవ్ చేయండి'));
    await tester.pumpAndSettle();

    expect(AppState.instance.preferredCategories, ['sports']);
    expect(find.byType(PreferencesScreen), findsNothing);
    // A guest's choice stays on the device until login.
    expect(api.patches, isEmpty);
  });
}
