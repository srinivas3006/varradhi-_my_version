import 'package:flutter/foundation.dart' show debugPrint;
import 'package:dio/dio.dart';
import '../state/app_state.dart';
import 'mock_interceptor.dart';

// Enable mock backend via compile-time flag. In production leave undefined.
// To enable locally: `flutter run --dart-define=USE_MOCK_BACKEND=true`
const bool useMockBackend = bool.fromEnvironment('USE_MOCK_BACKEND', defaultValue: false);

class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;

  late Dio dio;

  DioClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: 'https://incite-backend.onrender.com',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptors
    if (useMockBackend) {
      dio.interceptors.add(MockInterceptor());
    }

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = AppState.instance.authToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          } else {
            options.headers.remove('Authorization');
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          return handler.next(response);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            debugPrint('401 Unauthorized encountered for ${e.requestOptions.path}. Logging out and falling back to guest mode.');
            await AppState.instance.logout();
          }
          return handler.next(e);
        },
      ),
    );
  }
}
