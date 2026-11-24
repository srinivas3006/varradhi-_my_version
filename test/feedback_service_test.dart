import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/core/network/dio_client.dart';
import 'package:vaaradhi/services/feedback_service.dart';
import 'package:vaaradhi/state/app_state.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}

  static ResponseBody json(
    Object body,
    int status, {
    Map<String, List<String>> headers = const {},
  }) =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          ...headers,
        },
      );
}

const _uuid = '22f55b83-c38b-49fd-b034-a26f92abbcf0';
const _ok = {
  'data': {'id': '9f7f1a5f-a21d-45e1-876b-3053d1647356'},
  'meta': {},
  'errors': null,
};

FeedbackDraft _draft({
  FeedbackType type = FeedbackType.general,
  String subject = 'Subject',
  String message = 'Message',
  FeedbackContentReference? content,
}) =>
    FeedbackDraft(
      type: type,
      subject: subject,
      message: message,
      content: content,
    );

FeedbackService _service(
  _Adapter adapter, {
  bool useAppClient = false,
}) {
  final dio = useAppClient
      ? ApiClient.instance.dio
      : Dio(BaseOptions(baseUrl: 'https://api.test'));
  dio.httpClientAdapter = adapter;
  return FeedbackService(
    dio: dio,
    appVersionProvider: () async => '1.8.6+25',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final secureStorage = <String, String>{};

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
      final key = call.arguments?['key']?.toString();
      switch (call.method) {
        case 'read':
          return secureStorage[key];
        case 'write':
          if (key != null) {
            secureStorage[key] = call.arguments?['value'].toString() ?? '';
          }
          return null;
        case 'delete':
          secureStorage.remove(key);
          return null;
        case 'deleteAll':
          secureStorage.clear();
          return null;
        default:
          return null;
      }
    });
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secureStorage.clear();
    AppState.instance.authToken = null;
    AppState.instance.refreshToken = null;
    AppState.instance.deviceId = 'installed-device-id';
    AppState.instance.isLoggedIn = false;
  });

  tearDown(() {
    AppState.instance.authToken = null;
    AppState.instance.refreshToken = null;
    AppState.instance.isLoggedIn = false;
  });

  test('guest submission sends installation header and omits user_id',
      () async {
    final adapter = _Adapter((_) async => _Adapter.json(_ok, 201));
    final service = _service(adapter, useAppClient: true);

    final result = await service.submit(_draft());

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/api/v1/feedback/');
    expect(request.headers['X-Device-ID'], 'installed-device-id');
    expect(request.headers.containsKey('Authorization'), isFalse);
    expect(request.headers['Content-Type'], contains('application/json'));
    expect(request.data, containsPair('app_version', '1.8.6+25'));
    expect(request.data, isNot(contains('user_id')));
    expect(request.data, isNot(contains('content_type')));
    expect(request.data, isNot(contains('content_id')));
    expect(result.id, '9f7f1a5f-a21d-45e1-876b-3053d1647356');
  });

  test('logged-in submission sends bearer token', () async {
    AppState.instance.authToken = 'valid-access-token';
    AppState.instance.isLoggedIn = true;
    final adapter = _Adapter((_) async => _Adapter.json(_ok, 201));

    await _service(adapter, useAppClient: true).submit(_draft());

    expect(
      adapter.requests.single.headers['Authorization'],
      'Bearer valid-access-token',
    );
  });

  test('all six supported feedback types use exact backend values', () async {
    final adapter = _Adapter((_) async => _Adapter.json(_ok, 201));
    final service = _service(adapter);

    for (final type in FeedbackType.values) {
      await service.submit(_draft(
        type: type,
        content: type == FeedbackType.contentReport
            ? const FeedbackContentReference(
                type: FeedbackContentType.article,
                id: _uuid,
              )
            : null,
      ));
    }

    expect(
      adapter.requests.map((request) => request.data['type']).toList(),
      [
        'general',
        'bug',
        'suggestion',
        'content_report',
        'ad_report',
        'account'
      ],
    );
  });

  test('content report sends UUID and paired type and ID', () async {
    final adapter = _Adapter((_) async => _Adapter.json(_ok, 201));

    await _service(adapter).submit(_draft(
      type: FeedbackType.contentReport,
      content: const FeedbackContentReference(
        type: FeedbackContentType.ugc,
        id: _uuid,
      ),
    ));

    expect(adapter.requests.single.data, containsPair('content_type', 'ugc'));
    expect(adapter.requests.single.data, containsPair('content_id', _uuid));
  });

  test('all supported content reference types send paired UUID fields',
      () async {
    final adapter = _Adapter((_) async => _Adapter.json(_ok, 201));
    final service = _service(adapter);

    for (final contentType in FeedbackContentType.values) {
      await service.submit(_draft(
        type: FeedbackType.contentReport,
        content: FeedbackContentReference(type: contentType, id: _uuid),
      ));
    }

    expect(
      adapter.requests.map((request) => request.data['content_type']).toList(),
      ['article', 'ugc', 'ad', 'poster', 'quote', 'poll', 'video'],
    );
    expect(
      adapter.requests.every((request) => request.data['content_id'] == _uuid),
      isTrue,
    );
  });

  test('blank fields and over-limit text are rejected before network',
      () async {
    final adapter = _Adapter((_) async => _Adapter.json(_ok, 201));
    final service = _service(adapter);

    for (final draft in [
      _draft(subject: ' ', message: ''),
      _draft(subject: List.filled(201, 's').join()),
      _draft(message: List.filled(2001, 'm').join()),
    ]) {
      await expectLater(
        service.submit(draft),
        throwsA(isA<FeedbackApiException>()),
      );
    }
    expect(adapter.requests, isEmpty);
  });

  test('missing or invalid content reference is rejected', () async {
    final adapter = _Adapter((_) async => _Adapter.json(_ok, 201));
    final service = _service(adapter);

    for (final content in [
      null,
      const FeedbackContentReference(
        type: FeedbackContentType.article,
        id: 'article-slug-not-uuid',
      ),
    ]) {
      await expectLater(
        service.submit(_draft(
          type: FeedbackType.contentReport,
          content: content,
        )),
        throwsA(isA<FeedbackApiException>()),
      );
    }
    expect(adapter.requests, isEmpty);
  });

  test('missing installation ID is not generated or sent in the body',
      () async {
    AppState.instance.deviceId = '';
    final adapter = _Adapter((_) async => _Adapter.json({
          'data': null,
          'errors': {
            'code': 400,
            'message': 'An error occurred.',
            'details': {
              'device_id': ['Guest feedback requires a device ID.'],
            },
          },
        }, 400));

    await expectLater(
      _service(adapter, useAppClient: true).submit(_draft()),
      throwsA(isA<FeedbackApiException>().having(
          (error) => error.fieldErrors.containsKey('device_id'),
          'device field error',
          isTrue)),
    );

    final request = adapter.requests.single;
    expect(request.headers.containsKey('X-Device-ID'), isFalse);
    expect(request.data, isNot(contains('device_id')));
    expect(AppState.instance.deviceId, isEmpty);
  });

  test('server field errors preserve arrays and strings; Retry-After is read',
      () async {
    final adapter = _Adapter((_) async => _Adapter.json({
          'data': null,
          'meta': {},
          'errors': {
            'code': 400,
            'message': 'An error occurred.',
            'details': {
              'subject': ['Required.', 'Must be nonblank.'],
              'message': 'Too long.',
            },
          },
        }, 400));

    await expectLater(
      _service(adapter).submit(_draft()),
      throwsA(
        isA<FeedbackApiException>()
            .having((error) => error.statusCode, 'status', 400)
            .having((error) => error.fieldErrors['subject'], 'array error', [
          'Required.',
          'Must be nonblank.'
        ]).having((error) => error.fieldErrors['message'], 'string error',
                'Too long.'),
      ),
    );
  });

  test('403 and 429 preserve message and Retry-After', () async {
    for (final status in [403, 429]) {
      final adapter = _Adapter((_) async => _Adapter.json(
            {
              'data': null,
              'errors': {'code': status, 'message': 'Rejected by policy.'},
            },
            status,
            headers: status == 429
                ? {
                    'retry-after': ['30']
                  }
                : const {},
          ));

      await expectLater(
        _service(adapter).submit(_draft()),
        throwsA(
          isA<FeedbackApiException>()
              .having((error) => error.statusCode, 'status', status)
              .having(
                  (error) => error.message, 'message', 'Rejected by policy.')
              .having((error) => error.retryAfter, 'retry after',
                  status == 429 ? '30' : isNull),
        ),
      );
    }
  });

  test('500 and network errors are surfaced without success', () async {
    final server = _Adapter((_) async => _Adapter.json({
          'data': null,
          'errors': {'code': 500, 'message': 'Server unavailable.'},
        }, 500));
    await expectLater(
      _service(server).submit(_draft()),
      throwsA(isA<FeedbackApiException>()
          .having((error) => error.statusCode, 'status', 500)),
    );

    final network = _Adapter((options) async {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    });

    await expectLater(
      _service(network).submit(_draft()),
      throwsA(isA<FeedbackApiException>()
          .having((error) => error.statusCode, 'status', isNull)),
    );
  });

  test('non-201 success-shaped responses are not accepted as submission',
      () async {
    final adapter = _Adapter((_) async => _Adapter.json(_ok, 200));

    await expectLater(
      _service(adapter).submit(_draft()),
      throwsA(isA<FeedbackApiException>()
          .having((error) => error.statusCode, 'status', 200)),
    );
  });

  test('expired access token refreshes and retries as authenticated', () async {
    AppState.instance.authToken = 'expired-access-token';
    AppState.instance.refreshToken = 'valid-refresh-token';
    AppState.instance.isLoggedIn = true;
    var feedbackAttempts = 0;
    final adapter = _Adapter((options) async {
      if (options.path.contains('/auth/token/refresh/')) {
        return _Adapter.json({
          'data': {
            'access': 'refreshed-access-token',
            'refresh': 'rotated-refresh-token',
          }
        }, 200);
      }
      if (options.path == '/api/v1/feedback/' && feedbackAttempts++ == 0) {
        expect(options.headers['Authorization'], 'Bearer expired-access-token');
        expect(options.headers['Authorization'], 'Bearer expired-access-token');
        return _Adapter.json({
          'data': null,
          'errors': {'code': 401, 'message': 'Expired.'},
        }, 401);
      }
      return _Adapter.json(_ok, 201);
    });

    final result = await _service(adapter, useAppClient: true).submit(_draft());

    expect(result.id, '9f7f1a5f-a21d-45e1-876b-3053d1647356');
    final feedbackCalls = adapter.requests
        .where((request) => request.path == '/api/v1/feedback/')
        .toList();
    expect(feedbackCalls, hasLength(2));
    expect(feedbackCalls.last.headers['Authorization'],
        'Bearer refreshed-access-token');
  });
}
