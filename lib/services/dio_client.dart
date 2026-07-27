import 'package:dio/dio.dart';
import '../state/app_state.dart';
import 'mock_interceptor.dart';

// Toggle this to false to connect to the real backend
const bool useMockBackend = true;

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
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          // The backend returns {"data": ..., "meta": ..., "errors": ...}
          // We unwrap the data here if the request was successful
          // For simplicity in pagination, we might also want to pass meta,
          // but typically we can just return the entire response data map.
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          // Handle global errors, e.g., token expiration
          return handler.next(e);
        },
      ),
    );
  }
}
