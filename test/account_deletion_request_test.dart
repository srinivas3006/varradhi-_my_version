import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/core/network/dio_client.dart';
import 'package:vaaradhi/screens/profile_tab.dart';
import 'package:vaaradhi/services/api_service.dart';
import 'package:vaaradhi/state/app_state.dart';

/// [newPathLive]: whether POST /api/v1/accounts/delete-request/ is deployed.
class _Backend implements HttpClientAdapter {
  _Backend({required this.newPathLive});
  final bool newPathLive;
  final List<(String, Map<String, dynamic>)> posts = [];

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<Uint8List>? body, Future<void>? _) async {
    final sent = o.data is Map ? Map<String, dynamic>.from(o.data) : {};
    posts.add((o.path, Map<String, dynamic>.from(sent)));
    if (o.path == '/api/v1/accounts/delete-request/' && !newPathLive) {
      return ResponseBody.fromString('<h1>Not Found</h1>', 404,
          headers: {Headers.contentTypeHeader: ['text/html']});
    }
    return ResponseBody.fromString(
      jsonEncode({
        'data': {
          'id': 'del-1',
          'status': 'pending',
          'reason': sent['reason'],
          'feedback': sent['feedback'],
        },
        'meta': {},
        'errors': null,
      }),
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('new endpoint: readable reason + feedback', () async {
    final api = _Backend(newPathLive: true);
    ApiClient.instance.dio.httpClientAdapter = api;
    final r = await ApiService.instance.requestAccountDeletion(
        reason: 'no_longer_used', notes: 'Too busy');
    expect(r.status, 'pending');
    expect(api.posts.single.$1, '/api/v1/accounts/delete-request/');
    expect(api.posts.single.$2,
        {'reason': 'I no longer use or need the app', 'feedback': 'Too busy'});
  });

  test('new endpoint not deployed (404) → existing endpoint', () async {
    final api = _Backend(newPathLive: false);
    ApiClient.instance.dio.httpClientAdapter = api;
    final r = await ApiService.instance
        .requestAccountDeletion(reason: 'privacy', notes: '');
    expect(r.status, 'pending');
    expect(api.posts.map((p) => p.$1), [
      '/api/v1/accounts/delete-request/',
      '/api/v1/auth/account/deletion-request/',
    ]);
    expect(api.posts.last.$2, {'reason': 'privacy', 'confirm': true});
  });

  group('Profile entry', () {
    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ProfileTab())));
      await tester.pump();
    }

    Future<void> done(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 1));
    }

    testWidgets('logged in: "Request account deletion" is in Profile',
        (tester) async {
      AppState.instance
        ..isLoggedIn = true
        ..language = 'Telugu';
      await pump(tester);
      expect(find.byKey(const Key('profile_delete_account')), findsOneWidget);
      expect(find.text('ఖాతా తొలగింపు అభ్యర్థన'), findsOneWidget);
      await done(tester);
      AppState.instance.isLoggedIn = false;
    });

    testWidgets('guest: not shown', (tester) async {
      AppState.instance.isLoggedIn = false;
      await pump(tester);
      expect(find.byKey(const Key('profile_delete_account')), findsNothing);
      await done(tester);
    });
  });
}
