import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../errors/app_exception.dart';
import '../../services/dio_client.dart' show useMockBackend;
import '../../services/mock_interceptor.dart';
import '../../state/app_state.dart';

class CoreDioClient {
  static final CoreDioClient _instance = CoreDioClient._internal();
  factory CoreDioClient() => _instance;

  late final Dio dio;

  CoreDioClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

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
            await AppState.instance.logout();
          }
          final appError = _mapDioErrorToAppException(e);
          return handler.reject(
            DioException(
              requestOptions: e.requestOptions,
              error: appError,
              type: e.type,
              response: e.response,
            ),
          );
        },
      ),
    );
  }

  static AppException _mapDioErrorToAppException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return TimeoutException();
      case DioExceptionType.connectionError:
        return NetworkException();
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        final msg = e.response?.data?['errors']?['message'] ?? 'Server Error';
        return ServerException(msg, code);
      default:
        return NetworkException('Unexpected error occurred');
    }
  }
}
