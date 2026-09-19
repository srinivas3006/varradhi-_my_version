import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:way2news_clone/core/network/dio_client.dart';
import 'package:way2news_clone/services/api_service.dart';
import 'package:way2news_clone/state/app_state.dart';

/// Replays a scripted outcome per request path.
class _DeleteAdapter implements HttpClientAdapter {
  _DeleteAdapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions o) handler;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _,
          Future<void>? __) =>
      handler(o);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status) => ResponseBody.fromString(
      jsonEncode({'detail': 'ok'}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

final Map<String, String> secureStore = {};

void serve(Future<ResponseBody> Function(RequestOptions) h) {
  ApiClient.instance.dio.httpClientAdapter = _DeleteAdapter(h);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Clearing the session writes to secure storage, which has no
  // implementation under flutter test.

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        final key = call.arguments?['key'] as String?;
        switch (call.method) {
          case 'read':
            return secureStore[key];
          case 'write':
            final v = call.arguments?['value'] as String?;
            if (key != null && v != null) secureStore[key] = v;
            return null;
          case 'delete':
            secureStore.remove(key);
            return null;
          case 'deleteAll':
            secureStore.clear();
            return null;
        }
        return null;
      },
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppState.instance.isLoggedIn = true;
    AppState.instance.authToken = 'token-123';
  });



  group('1. successful DELETE', () {
    test('first endpoint succeeds', () async {
      serve((o) async => _json(204));
      expect(await ApiService.instance.deleteAccount(),
          AccountDeletionResult.deleted);
    });
  });

  group('2. DELETE fails, POST fallback succeeds', () {
    test('falls through to the POST contract', () async {
      serve((o) async =>
          o.method == 'POST' ? _json(200) : _json(404));
      expect(await ApiService.instance.deleteAccount(),
          AccountDeletionResult.deleted);
    });
  });

  group('3. DELETE fails and POST fails', () {
    test('reports server error, not success', () async {
      serve((o) async => _json(500));
      expect(await ApiService.instance.deleteAccount(),
          AccountDeletionResult.serverError);
    });
  });

  group('4. network failure', () {
    test('is distinguished from a server rejection', () async {
      serve((o) async => throw DioException(
            requestOptions: o,
            type: DioExceptionType.connectionError,
          ));
      expect(await ApiService.instance.deleteAccount(),
          AccountDeletionResult.networkFailure);
    });
  });

  group('5. unauthorized / expired session', () {
    test('401 surfaces as unauthorized', () async {
      serve((o) async => _json(401));
      expect(await ApiService.instance.deleteAccount(),
          AccountDeletionResult.unauthorized);
    });

    test('an auth rejection outranks a later network error', () async {
      serve((o) async {
        if (o.method == 'DELETE') return _json(403);
        throw DioException(
            requestOptions: o, type: DioExceptionType.connectionError);
      });
      expect(await ApiService.instance.deleteAccount(),
          AccountDeletionResult.unauthorized,
          reason: 'the most informative failure must not be masked');
    });
  });

  group('the session survives a failed deletion so retry is possible', () {
    test('failure keeps the user logged in and keeps the token', () async {
      serve((o) async => _json(500));
      final result = await AppState.instance.deleteAccount();

      expect(result, isNot(AccountDeletionResult.deleted));
      expect(AppState.instance.isLoggedIn, isTrue,
          reason: 'clearing the session would destroy the retry path');
      expect(AppState.instance.authToken, 'token-123');
    });

    test('success clears the session', () async {
      serve((o) async => _json(204));
      final result = await AppState.instance.deleteAccount();

      expect(result, AccountDeletionResult.deleted);
      expect(AppState.instance.isLoggedIn, isFalse);
    });
  });

  group('persisted session matches the deletion outcome across a restart', () {
    test('failure leaves the persisted auth state intact', () async {
      SharedPreferences.setMockInitialValues({'isLoggedIn': true});
      secureStore['authToken'] = 'token-123';
      AppState.instance.isLoggedIn = true;
      AppState.instance.authToken = 'token-123';

      serve((o) async => _json(503));
      final result = await AppState.instance.deleteAccount();
      expect(result, AccountDeletionResult.serverError);

      // _clearLocalSession never ran, so neither store was written.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('isLoggedIn'), isTrue,
          reason: 'a restart must find the user still authenticated');
      expect(secureStore['authToken'], 'token-123',
          reason: 'the token the retry needs must survive');
    });

    test('success removes the persisted auth state', () async {
      SharedPreferences.setMockInitialValues({'isLoggedIn': true});
      secureStore['authToken'] = 'token-123';
      secureStore['refreshToken'] = 'refresh-123';
      AppState.instance.isLoggedIn = true;
      AppState.instance.authToken = 'token-123';

      serve((o) async => _json(204));
      expect(await AppState.instance.deleteAccount(),
          AccountDeletionResult.deleted);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('isLoggedIn'), isFalse);
      expect(secureStore['authToken'], isNull,
          reason: 'a restart must not restore a deleted account');
      expect(secureStore['refreshToken'], isNull);
    });
  });
}
