 import 'dart:async' hide TimeoutException;
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:way2news_clone/core/errors/app_exception.dart';
import 'package:way2news_clone/core/network/api_response.dart';
import 'package:way2news_clone/core/network/dio_client.dart';
import 'package:way2news_clone/repositories/news_article_repository.dart';
import 'package:way2news_clone/state/app_state.dart';

/// Lightweight mock adapter for Dio without third-party dependencies.
class TestMockAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;

  TestMockAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}

  static ResponseBody jsonResponse(dynamic body, int statusCode) {
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final Map<String, String> mockSecureStorage = {};

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'read') {
        return mockSecureStorage[methodCall.arguments?['key']];
      } else if (methodCall.method == 'write') {
        final key = methodCall.arguments?['key'] as String?;
        final value = methodCall.arguments?['value'] as String?;
        if (key != null && value != null) {
          mockSecureStorage[key] = value;
        }
        return null;
      } else if (methodCall.method == 'delete') {
        mockSecureStorage.remove(methodCall.arguments?['key']);
        return null;
      } else if (methodCall.method == 'deleteAll') {
        mockSecureStorage.clear();
        return null;
      } else if (methodCall.method == 'containsKey') {
        return mockSecureStorage.containsKey(methodCall.arguments?['key']);
      }
      return null;
    });
  });

  setUp(() async {
    mockSecureStorage.clear();
    SharedPreferences.setMockInitialValues({});
    await AppState.instance.init();
  });

  group('1. API Response Parsing', () {
    test('parses successful list with cursor', () {
      final json = {
        'data': [
          {'id': '1', 'title': 'Item 1'},
          {'id': '2', 'title': 'Item 2'},
        ],
        'meta': {'next': 'https://api.varadhi.com/feed/?cursor=next_token_123'},
        'errors': null,
      };

      final response = ApiResponse<List<String>>.fromJson(
        json,
        (data) => (data as List).map((e) => (e as Map)['title'].toString()).toList(),
      );

      expect(response.isSuccess, isTrue);
      expect(response.hasErrors, isFalse);
      expect(response.data?.length, 2);
      expect(response.data?.first, 'Item 1');
      expect(response.nextCursor, 'next_token_123');
    });

    test('parses successful object data', () {
      final json = {
        'data': {'id': '42', 'name': 'Telangana News'},
        'meta': null,
        'errors': null,
      };

      final response = ApiResponse<Map<String, dynamic>>.fromJson(
        json,
        (data) => data as Map<String, dynamic>,
      );

      expect(response.isSuccess, isTrue);
      expect(response.data?['name'], 'Telangana News');
    });

    test('parses empty data list safely', () {
      final json = {
        'data': [],
        'meta': {'count': 0},
        'errors': null,
      };

      final response = ApiResponse<List<dynamic>>.fromJson(
        json,
        (data) => data as List<dynamic>,
      );

      expect(response.isSuccess, isTrue);
      expect(response.data, isEmpty);
    });

    test('parses null data safely', () {
      final json = {
        'data': null,
        'meta': null,
        'errors': null,
      };

      final response = ApiResponse<String>.fromJson(
        json,
        (data) => data.toString(),
      );

      expect(response.data, isNull);
      expect(response.isSuccess, isFalse);
      expect(response.hasErrors, isFalse);
    });

    test('parses error object safely without throwing cast exception', () {
      final json = {
        'data': null,
        'meta': {},
        'errors': {
          'code': 400,
          'message': 'Invalid category requested',
          'details': {'category': 'Not recognized'},
        },
      };

      final response = ApiResponse<dynamic>.fromJson(
        json,
        (data) => data,
      );

      expect(response.isSuccess, isFalse);
      expect(response.hasErrors, isTrue);
      expect(response.errorMessage, 'Invalid category requested');
    });

    test('parses malformed errors field (string or list) safely', () {
      final jsonListError = {
        'data': null,
        'errors': ['First error message', 'Second error message'],
      };

      final response1 = ApiResponse<dynamic>.fromJson(jsonListError, (d) => d);
      expect(response1.hasErrors, isTrue);
      expect(response1.errorMessage, 'First error message');

      final jsonStrError = {
        'data': null,
        'errors': 'Simple string error',
      };
      final response2 = ApiResponse<dynamic>.fromJson(jsonStrError, (d) => d);
      expect(response2.errorMessage, 'Simple string error');
    });
  });

  group('2. Network Error Mapping', () {
    late ApiClient client;

    setUp(() {
      client = ApiClient();
    });

    test('maps connection timeout to TimeoutException', () async {
      client.dio.httpClientAdapter = TestMockAdapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        );
      });

      await expectLater(
        client.get('/test-timeout'),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('maps connection error to NetworkException', () async {
      client.dio.httpClientAdapter = TestMockAdapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      });

      await expectLater(
        client.get('/test-network-error'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('maps 401 without refresh to UnauthorizedException', () async {
      // Clear tokens
      AppState.instance.authToken = null;
      AppState.instance.refreshToken = null;

      client.dio.httpClientAdapter = TestMockAdapter((options) async {
        return TestMockAdapter.jsonResponse({
          'data': null,
          'errors': {'code': 401, 'message': 'Token expired'},
        }, 401);
      });

      await expectLater(
        client.get('/test-401'),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('maps 403 to ForbiddenException', () async {
      client.dio.httpClientAdapter = TestMockAdapter((options) async {
        return TestMockAdapter.jsonResponse({
          'data': null,
          'errors': {'code': 403, 'message': 'Access denied'},
        }, 403);
      });

      await expectLater(
        client.get('/test-403'),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('maps 404 to NotFoundException', () async {
      client.dio.httpClientAdapter = TestMockAdapter((options) async {
        return TestMockAdapter.jsonResponse({
          'data': null,
          'errors': {'code': 404, 'message': 'Article not found'},
        }, 404);
      });

      await expectLater(
        client.get('/test-404'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('maps 500 to ServerException', () async {
      client.dio.httpClientAdapter = TestMockAdapter((options) async {
        return TestMockAdapter.jsonResponse({
          'data': null,
          'errors': {'code': 500, 'message': 'Internal Server Error'},
        }, 500);
      });

      await expectLater(
        client.get('/test-500'),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('3. Authentication & Refresh Flow', () {
    late ApiClient client;

    setUp(() {
      client = ApiClient();
    });

    test('attaches Bearer token and X-Device-ID on requests', () async {
      AppState.instance.authToken = 'valid_access_token_123';
      AppState.instance.deviceId = 'device_xyz_789';

      String? sentAuth;
      String? sentDevice;

      client.dio.httpClientAdapter = TestMockAdapter((options) async {
        sentAuth = options.headers['Authorization']?.toString();
        sentDevice = options.headers['X-Device-ID']?.toString();
        return TestMockAdapter.jsonResponse({'data': 'ok'}, 200);
      });

      await client.get('/test-auth-headers');

      expect(sentAuth, 'Bearer valid_access_token_123');
      expect(sentDevice, 'device_xyz_789');
    });

    test('refreshes token on 401 and retries original request', () async {
      AppState.instance.authToken = 'expired_token';
      AppState.instance.refreshToken = 'valid_refresh_token';

      client.dio.httpClientAdapter = TestMockAdapter((options) async {
        if (options.path.contains('/auth/token/refresh/')) {
          return TestMockAdapter.jsonResponse({
            'data': {
              'access': 'newly_minted_access_token',
              'refresh': 'new_refresh_token',
            }
          }, 200);
        }

        if (options.headers['Authorization'] == 'Bearer newly_minted_access_token') {
          return TestMockAdapter.jsonResponse({'data': 'success_after_refresh'}, 200);
        }

        // Return 401 for old token
        return TestMockAdapter.jsonResponse({'errors': {'code': 401, 'message': 'Expired'}}, 401);
      });

      final response = await client.get('/protected-resource');
      expect(response.data['data'], 'success_after_refresh');
      expect(AppState.instance.authToken, 'newly_minted_access_token');
    });

    test('clears auth on failed refresh without navigation loop', () async {
      AppState.instance.authToken = 'expired_token';
      AppState.instance.refreshToken = 'invalid_refresh_token';

      client.dio.httpClientAdapter = TestMockAdapter((options) async {
        if (options.path.contains('/auth/token/refresh/')) {
          return TestMockAdapter.jsonResponse({'errors': {'code': 400, 'message': 'Invalid refresh token'}}, 400);
        }
        return TestMockAdapter.jsonResponse({'errors': {'code': 401, 'message': 'Unauthorized'}}, 401);
      });

      await expectLater(
        client.get('/protected-resource-fail'),
        throwsA(isA<UnauthorizedException>()),
      );

      expect(AppState.instance.isLoggedIn, isFalse);
      expect(AppState.instance.authToken, isNull);
    });

    test('deduplicates concurrent in-flight GET requests', () async {
      int serverCalls = 0;
      final completer = Completer<ResponseBody>();

      client.dio.httpClientAdapter = TestMockAdapter((options) async {
        serverCalls++;
        return completer.future;
      });

      // Fire two identical GET requests concurrently
      final f1 = client.get('/dedup-endpoint', queryParameters: {'tag': 'news'});
      final f2 = client.get('/dedup-endpoint', queryParameters: {'tag': 'news'});

      completer.complete(TestMockAdapter.jsonResponse({'data': 'dedup_result'}, 200));

      final r1 = await f1;
      final r2 = await f2;

      expect(serverCalls, 1); // Verified only one request dispatched to network!
      expect(r1.data['data'], 'dedup_result');
      expect(r2.data['data'], 'dedup_result');
    });
  });

  group('4. Repository (NewsArticleRepository)', () {
    setUp(() {
      NewsArticleRepository.instance.clearCache();
    });

    test('remote success populates repository cache', () async {
      ApiClient.instance.dio.httpClientAdapter = TestMockAdapter((options) async {
        return TestMockAdapter.jsonResponse({
          'data': {
            'id': 'art-1',
            'title': 'Telangana Tech Summit',
            'slug': 'telangana-tech-summit',
            'content': '<p>Full rich-text body</p>',
            'summary': 'Short summary',
            'category': 'Tech',
            'published_at': '2026-09-10T12:00:00Z',
          }
        }, 200);
      });

      final article = await NewsArticleRepository.instance.getDetail('telangana-tech-summit');
      expect(article.slug, 'telangana-tech-summit');
      expect(article.title, 'Telangana Tech Summit');

      // Subsequent call should hit cache without network
      int networkHits = 0;
      ApiClient.instance.dio.httpClientAdapter = TestMockAdapter((options) async {
        networkHits++;
        throw DioException(requestOptions: options, type: DioExceptionType.badResponse);
      });

      final cached = await NewsArticleRepository.instance.getDetail('telangana-tech-summit');
      expect(cached.title, 'Telangana Tech Summit');
      expect(networkHits, 0); // Cache hit!
    });
  });
}
