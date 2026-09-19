import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:way2news_clone/core/errors/app_exception.dart';
import 'package:way2news_clone/core/network/dio_client.dart';
import 'package:way2news_clone/services/api_service.dart';
import 'package:way2news_clone/state/app_state.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions o) handler;
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _,
          Future<void>? __) =>
      handler(o);
  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Map<String, dynamic> body, int status) =>
    ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });

Map<String, dynamic> _envelope(String status) => {
      'data': {
        'id': 7,
        'status': status,
        'reason': 'privacy',
        'notes': 'Remove my data',
        'created_at': '2026-09-19T10:00:00Z',
      },
      'meta': {},
      'errors': null,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final state = AppState.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    state.isLoggedIn = true;
    state.authToken = 'token-abc';
  });

  void serve(Future<ResponseBody> Function(RequestOptions) h) {
    ApiClient.instance.dio.httpClientAdapter = _Adapter(h);
  }

  group('raise a request', () {
    test('POSTs to the deletion-request endpoint with confirm true', () async {
      String? method, path;
      Object? body;
      serve((o) async {
        method = o.method;
        path = o.path;
        body = o.data;
        return _json(_envelope('pending'), 201);
      });

      final req = await ApiService.instance.requestAccountDeletion(
        reason: 'privacy',
        notes: 'Remove my data',
        confirm: true,
      );

      expect(method, 'POST');
      expect(path, '/api/v1/auth/account/deletion-request/');
      expect((body as Map)['confirm'], isTrue);
      expect((body as Map)['reason'], 'privacy');
      expect((body as Map)['notes'], 'Remove my data');
      expect(req.status, 'pending');
      expect(req.isPending, isTrue);
    });

    test('201 pending does NOT clear the session', () async {
      serve((o) async => _json(_envelope('pending'), 201));
      await ApiService.instance.requestAccountDeletion(confirm: true);

      // The invariant: a pending request is not a deletion.
      expect(state.isLoggedIn, isTrue);
      expect(state.authToken, 'token-abc');
    });

    test('blank notes are omitted rather than sent empty', () async {
      Object? body;
      serve((o) async {
        body = o.data;
        return _json(_envelope('pending'), 201);
      });
      await ApiService.instance
          .requestAccountDeletion(reason: 'other', notes: '   ');
      expect((body as Map).containsKey('notes'), isFalse);
    });
  });

  group('check status', () {
    test('404 means no request exists, not an error', () async {
      serve((o) async => _json({'errors': {'message': 'not found'}}, 404));
      expect(await ApiService.instance.getAccountDeletionRequest(), isNull);
      expect(state.isLoggedIn, isTrue);
    });

    for (final s in ['pending', 'approved', 'rejected', 'cancelled']) {
      test('$s is parsed into explicit state', () async {
        serve((o) async => _json(_envelope(s), 200));
        final req = await ApiService.instance.getAccountDeletionRequest();
        expect(req, isNotNull);
        expect(req!.status, s);
        expect(req.isPending, s == 'pending');
        expect(req.isApproved, s == 'approved');
        expect(req.isRejected, s == 'rejected');
        expect(req.isCancelled, s == 'cancelled');
      });
    }

    test('rejected keeps the reader logged in', () async {
      serve((o) async => _json(_envelope('rejected'), 200));
      final req = await ApiService.instance.getAccountDeletionRequest();
      expect(req!.isRejected, isTrue);
      expect(state.isLoggedIn, isTrue,
          reason: 'rejection is not deletion');
    });
  });

  group('cancel', () {
    test('DELETEs the endpoint with no body and keeps the session', () async {
      String? method, path;
      Object? body;
      serve((o) async {
        method = o.method;
        path = o.path;
        body = o.data;
        return _json({'data': {'status': 'cancelled'}}, 200);
      });

      expect(await ApiService.instance.cancelAccountDeletionRequest(), isTrue);
      expect(method, 'DELETE');
      expect(path, '/api/v1/auth/account/deletion-request/');
      expect(body, isNull);
      expect(state.isLoggedIn, isTrue);
    });
  });

  group('errors carry their status so the UI can act', () {
    Future<ApiException> raise(int code, String message) async {
      serve((o) async => _json({
            'errors': {'message': message}
          }, code));
      try {
        await ApiService.instance.requestAccountDeletion(confirm: true);
      } on ApiException catch (e) {
        return e;
      }
      fail('expected ApiException for $code');
    }

    test('400 duplicate pending is distinguishable', () async {
      final e = await raise(400, 'A deletion request is already pending review.');
      expect(e.statusCode, 400);
      expect(e.message.toLowerCase(), contains('already pending'));
    });

    test('429 rate limit is distinguishable', () async {
      expect((await raise(429, 'Too many requests')).statusCode, 429);
    });

    test('401 is routed to the existing session handling, not to success',
        () async {
      // The Dio interceptor claims a 401 first and runs the app's normal
      // token-refresh/session-expiry path, so it never arrives here carrying
      // a 401 status. What matters is that it fails loudly rather than
      // reading as a completed deletion.
      serve((o) async => _json({
            'errors': {'message': 'Unauthorized'}
          }, 401));
      await expectLater(
        ApiService.instance.requestAccountDeletion(confirm: true),
        throwsA(anything),
      );
    });

    test('403 is not reported as deletion', () async {
      final e = await raise(403, 'Forbidden');
      expect(e.statusCode, 403);
      expect(state.isLoggedIn, isTrue);
    });

    test('5xx leaves the session untouched', () async {
      expect((await raise(500, 'Server error')).statusCode, 500);
      expect(state.isLoggedIn, isTrue);
      expect(state.authToken, 'token-abc');
    });

    test('a network failure does not alter the session', () async {
      serve((o) async => throw DioException(
          requestOptions: o, type: DioExceptionType.connectionError));
      await expectLater(
        ApiService.instance.requestAccountDeletion(confirm: true),
        throwsA(anything),
      );
      expect(state.isLoggedIn, isTrue);
      expect(state.authToken, 'token-abc');
    });
  });

  group('the old immediate-delete path is gone', () {
    test('no deleteAccount method remains on ApiService', () {
      // Guards the contract change: the only deletion route is the
      // admin-reviewed request flow above.
      final src = File('lib/services/api_service.dart').readAsStringSync();
      expect(src, isNot(contains('Future<bool> deleteAccount(')));
      expect(src, isNot(contains('/api/v1/auth/delete-account/')));
      expect(src, isNot(contains('/api/v1/auth/account/delete/')));
    });
  });
}
