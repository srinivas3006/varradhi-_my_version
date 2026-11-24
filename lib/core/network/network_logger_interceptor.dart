import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../utils/log_safe.dart';

/// Development-only network logger interceptor.
/// Records HTTP method, path, status code, duration, request ID, response size, and errors.
/// Never logs passwords, OTPs, tokens, or private user credentials.
class NetworkLoggerInterceptor extends Interceptor {
  static const _sensitiveKeys = {
    'password',
    'new_password',
    'new_password_confirm',
    'current_password',
    'token',
    'access',
    'refresh',
    'otp',
    'secret',
    'installation_secret',
    'authorization',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!kDebugMode) {
      return handler.next(options);
    }

    options.extra['request_start_time'] = DateTime.now().millisecondsSinceEpoch;

    final sanitizedParams = _sanitizeMap(options.queryParameters);
    final buffer = StringBuffer();
    buffer.write('🌐 [REQ] ${options.method.toUpperCase()} ${options.path}');
    if (sanitizedParams.isNotEmpty) {
      buffer.write(' ? $sanitizedParams');
    }

    // Feedback text is user-written and may contain private details.
    if (options.data is Map<String, dynamic>) {
      final requestBody = options.data as Map<String, dynamic>;
      final sanitizedData = options.path == '/api/v1/feedback/'
          ? {
              ..._sanitizeMap(requestBody),
              if (requestBody.containsKey('subject'))
                'subject': '***REDACTED***',
              if (requestBody.containsKey('message'))
                'message': '***REDACTED***',
            }
          : _sanitizeMap(requestBody);
      buffer.write(' | Body: $sanitizedData');
    }

    debugPrint(buffer.toString());
    return handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (!kDebugMode) {
      return handler.next(response);
    }

    final startTime =
        response.requestOptions.extra['request_start_time'] as int?;
    final durationMs = startTime != null
        ? DateTime.now().millisecondsSinceEpoch - startTime
        : null;
    final statusCode = response.statusCode;
    final requestId = response.headers.value('x-request-id') ??
        response.headers.value('request-id');

    final size = response.data?.toString().length ?? 0;
    final durationStr =
        durationMs != null ? '${durationMs}ms' : 'unknown duration';

    final buffer = StringBuffer();
    buffer.write(
        '✅ [RESP] ${response.requestOptions.method.toUpperCase()} ${response.requestOptions.path}');
    buffer.write(
        ' -> Status: $statusCode | Duration: $durationStr | Size: ~${size}B');
    if (requestId != null) {
      buffer.write(' | ReqId: $requestId');
    }

    debugPrint(buffer.toString());
    return handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (!kDebugMode) {
      return handler.next(err);
    }

    final startTime = err.requestOptions.extra['request_start_time'] as int?;
    final durationMs = startTime != null
        ? DateTime.now().millisecondsSinceEpoch - startTime
        : null;
    final statusCode = err.response?.statusCode;
    final durationStr =
        durationMs != null ? '${durationMs}ms' : 'unknown duration';

    final path = err.requestOptions.uri.path;
    final privateMessage = path.startsWith('/api/v1/polls/') ||
        path == '/api/v1/auth/locations/guest/';
    final message = privateMessage ? '' : ' | Message: ${LogSafe.scrub(err.message)}';
    debugPrint(
      '❌ [ERR] ${err.requestOptions.method.toUpperCase()} ${err.requestOptions.path} '
      '-> Status: $statusCode | Duration: $durationStr | Type: ${err.type}$message',
    );

    return handler.next(err);
  }

  Map<String, dynamic> _sanitizeMap(Map<dynamic, dynamic> map) {
    final sanitized = <String, dynamic>{};
    for (final entry in map.entries) {
      final keyStr = entry.key.toString();
      final keyLower = keyStr.toLowerCase();
      if (keyLower.contains('mobile') || keyLower.contains('phone')) {
        sanitized[keyStr] = LogSafe.maskMobile(entry.value?.toString());
      } else if (_sensitiveKeys.any((s) => keyLower.contains(s))) {
        sanitized[keyStr] = '***REDACTED***';
      } else if (entry.value is Map) {
        sanitized[keyStr] = _sanitizeMap(entry.value as Map);
      } else {
        sanitized[keyStr] = entry.value;
      }
    }
    return sanitized;
  }
}
