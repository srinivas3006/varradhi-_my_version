import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/network_config.dart';
import '../errors/app_exception.dart';
import 'network_logger_interceptor.dart';
import '../../state/app_state.dart';

/// Central API Client for VARADHI.
/// Consolidates all network requests, interceptors, timeouts, authentication,
/// atomic token refresh, logging, in-flight deduplication, and structured exceptions.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  static ApiClient get instance => _instance;

  late final Dio dio;
  late NetworkConfig _config;

  // Serializes concurrent refresh attempts: refresh token rotation means the
  // old refresh token is blacklisted the moment it's used, so two 401s
  // firing at once must not both try to consume it.
  Future<String?>? _refreshInFlight;

  // In-flight request deduplication map to prevent redundant concurrent requests
  // triggered by tab switches, widget rebuilds, or rapid navigation.
  final Map<String, Future<Response<dynamic>>> _inFlightRequests = {};

  ApiClient._internal({NetworkConfig? config}) {
    _config = config ?? NetworkConfig();
    _initDio();
  }

  /// Reconfigure the client with a custom NetworkConfig if needed.
  void configure(NetworkConfig config) {
    _config = config;
    _initDio();
  }

  void _initDio() {
    dio = Dio(
      BaseOptions(
        baseUrl: _config.baseUrl,
        connectTimeout: _config.connectTimeout,
        sendTimeout: _config.sendTimeout,
        receiveTimeout: _config.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // 1. Authentication & Device Interceptor
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = AppState.instance.authToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          } else {
            options.headers.remove('Authorization');
          }

          final deviceId = AppState.instance.deviceId;
          if (deviceId.isNotEmpty) {
            options.headers['X-Device-ID'] = deviceId;
          }

          final sessionId = AppState.instance.sessionId;
          if (sessionId != null && sessionId.isNotEmpty) {
            options.headers['X-Session-ID'] = sessionId;
          } else {
            options.headers.remove('X-Session-ID');
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          final path = e.requestOptions.path;
          final isAuthEndpoint = path.contains('/auth/login/') ||
              path.contains('/auth/register/') ||
              path.contains('/auth/token/refresh/') ||
              path.contains('/auth/logout/');
          final refreshToken = AppState.instance.refreshToken;

          if (e.response?.statusCode == 401 &&
              !isAuthEndpoint &&
              refreshToken != null &&
              refreshToken.isNotEmpty) {
            final newAccessToken = await _refreshAccessToken(refreshToken);
            if (newAccessToken != null) {
              try {
                final retryOptions = e.requestOptions;
                retryOptions.headers['Authorization'] =
                    'Bearer $newAccessToken';
                final response = await dio.fetch(retryOptions);
                return handler.resolve(response);
              } catch (_) {
                // fall through to the standard error mapping below
              }
            } else {
              debugPrint(
                  'Token refresh failed for ${e.requestOptions.path}. Logging out.');
              await AppState.instance.logout();
            }
          } else if (e.response?.statusCode == 401 && !isAuthEndpoint) {
            if (AppState.instance.isLoggedIn) {
              debugPrint(
                  '401 Unauthorized encountered with no refresh token. Logging out.');
              await AppState.instance.logout();
            }
          }

          final appError = _mapDioErrorToAppException(e);
          return handler.reject(
            DioException(
              requestOptions: e.requestOptions,
              error: appError,
              type: e.type,
              response: e.response,
              message: appError.message,
            ),
          );
        },
      ),
    );

    // 2. Logging Interceptor (Development Only)
    if (_config.enableLogging) {
      dio.interceptors.add(NetworkLoggerInterceptor());
    }
  }

  /// Exchanges the stored refresh token for a new access token.
  /// Uses an independent Dio instance to avoid recursive interceptor loops.
  Future<String?> _refreshAccessToken(String refreshToken) {
    if (_refreshInFlight != null) return _refreshInFlight!;

    final future = () async {
      try {
        final rawDio = Dio(
          BaseOptions(
            baseUrl: _config.baseUrl,
            connectTimeout: _config.connectTimeout,
            receiveTimeout: _config.receiveTimeout,
          ),
        );
        rawDio.httpClientAdapter = dio.httpClientAdapter;
        final response =
            await rawDio.post('/api/v1/auth/token/refresh/', data: {
          'refresh': refreshToken,
          'device_id': AppState.instance.deviceId,
        });
        final data = response.data['data'] as Map<String, dynamic>;
        final newAccess = data['access'] as String?;
        final newRefresh = data['refresh'] as String?;
        if (newAccess == null) return null;
        await AppState.instance.updateTokensAfterRefresh(newAccess, newRefresh);
        return newAccess;
      } catch (e) {
        debugPrint('Token refresh request failed: $e');
        return null;
      }
    }();

    _refreshInFlight = future;
    return future.whenComplete(() => _refreshInFlight = null);
  }

  // --- Canonical In-flight Request Deduplication ---

  String _generateDeduplicationKey(
      String method, String path, Map<String, dynamic>? queryParams) {
    if (queryParams == null || queryParams.isEmpty) {
      return '$method:$path';
    }
    final sortedKeys = queryParams.keys.toList()..sort();
    final queryString = sortedKeys.map((k) => '$k=${queryParams[k]}').join('&');
    return '$method:$path?$queryString';
  }

  // --- High-Level HTTP Methods With Structured Error Handling ---

  /// Performs a GET request with in-flight deduplication.
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    bool deduplicate = true,
  }) {
    final key = _generateDeduplicationKey('GET', path, queryParameters);

    if (deduplicate && _inFlightRequests.containsKey(key)) {
      final cachedFuture = _inFlightRequests[key]! as Future<Response<T>>;
      return cachedFuture;
    }

    Future<Response<T>> execute() async {
      try {
        return await dio.get<T>(
          path,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken,
        );
      } on DioException catch (e) {
        throw _unwrapDioException(e);
      }
    }

    final future = execute();

    if (deduplicate) {
      _inFlightRequests[key] = future;
      future.whenComplete(() => _inFlightRequests.remove(key)).ignore();
    }

    return future;
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    try {
      return await dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
      );
    } on DioException catch (e) {
      throw _unwrapDioException(e);
    }
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _unwrapDioException(e);
    }
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _unwrapDioException(e);
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _unwrapDioException(e);
    }
  }

  // --- Exception Mapping Helpers ---

  static AppException _unwrapDioException(DioException e) {
    if (e.error is AppException) {
      return e.error as AppException;
    }
    return _mapDioErrorToAppException(e);
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
        final data = e.response?.data;
        String? message;
        dynamic details;

        if (data is Map<String, dynamic>) {
          if (data['errors'] is Map) {
            message = data['errors']['message']?.toString() ??
                data['errors']['detail']?.toString();
            details = data['errors'];
          } else if (data['errors'] is List &&
              (data['errors'] as List).isNotEmpty) {
            message = (data['errors'] as List).first.toString();
            details = data['errors'];
          } else if (data['message'] != null) {
            message = data['message'].toString();
          } else if (data['detail'] != null) {
            message = data['detail'].toString();
          }
        }

        if (code == 401) {
          return UnauthorizedException(
              message ?? 'సెషన్ గడువు ముగిసింది. దయచేసి మళ్లీ లాగిన్ అవ్వండి.',
              code,
              details);
        } else if (code == 403) {
          return ForbiddenException(
              message ?? 'ఈ విభాగాన్ని యాక్సెస్ చేయడానికి మీకు అనుమతి లేదు.',
              code,
              details);
        } else if (code == 404) {
          return NotFoundException(
              message ?? 'అభ్యర్థించిన కంటెంట్ కనుగొనబడలేదు.', code, details);
        } else if (code == 422 || (code == 400 && details is Map)) {
          return ValidationException(
            message ?? 'చెల్లని అభ్యర్థన సమాచారం.',
            code ?? 400,
            details is Map<String, dynamic> ? details : null,
            data,
          );
        } else if (code != null && code >= 500) {
          return ServerException(
              message ??
                  'సర్వర్ లోపం సంభవించింది. దయచేసి కాసేపటి తర్వాత ప్రయత్నించండి.',
              code,
              details);
        }

        return ApiException(
            message ?? 'నెట్‌వర్క్ అభ్యర్థన విఫలమైంది.', code, details);

      case DioExceptionType.cancel:
        return ApiException('అభ్యర్థన రద్దు చేయబడింది.');

      default:
        return NetworkException('నెట్‌వర్క్ కనెక్షన్ లోపం సంభవించింది.');
    }
  }
}

/// Backward compatibility alias
typedef CoreDioClient = ApiClient;
