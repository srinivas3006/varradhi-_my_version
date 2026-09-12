/// Standard API Error representation matching backend contract:
/// `{ "code": 400, "message": "...", "details": {} }`
class ApiError {
  final int? code;
  final String? message;
  final dynamic details;

  const ApiError({
    this.code,
    this.message,
    this.details,
  });

  factory ApiError.fromJson(dynamic json) {
    if (json == null) {
      return const ApiError();
    }
    if (json is Map) {
      final map = Map<String, dynamic>.from(json);
      final rawCode = map['code'];
      int? parsedCode;
      if (rawCode is int) {
        parsedCode = rawCode;
      } else if (rawCode != null) {
        parsedCode = int.tryParse(rawCode.toString());
      }

      final msg = map['message']?.toString() ??
          map['detail']?.toString() ??
          map['error']?.toString();

      return ApiError(
        code: parsedCode,
        message: msg,
        details: map['details'],
      );
    }
    if (json is String) {
      return ApiError(message: json);
    }
    if (json is List && json.isNotEmpty) {
      return ApiError(message: json.first.toString(), details: json);
    }
    return ApiError(message: json.toString());
  }

  Map<String, dynamic> toJson() => {
        if (code != null) 'code': code,
        if (message != null) 'message': message,
        if (details != null) 'details': details,
      };

  @override
  String toString() => message ?? 'Unknown API Error';
}

/// Standardized API response wrapper handling `{ "data": ..., "meta": ..., "errors": ... }`.
class ApiResponse<T> {
  final T? data;
  final Map<String, dynamic>? meta;
  final dynamic errors;
  final ApiError? apiError;
  final String? nextCursor;
  final int? statusCode;

  ApiResponse({
    this.data,
    this.meta,
    this.errors,
    this.apiError,
    this.nextCursor,
    this.statusCode,
  });

  bool get isSuccess => errors == null && data != null;
  bool get hasErrors => errors != null;

  String? get errorMessage {
    if (apiError?.message != null && apiError!.message!.isNotEmpty) {
      return apiError!.message;
    }
    if (errors == null) return null;
    if (errors is Map) {
      final map = errors as Map;
      if (map['message'] != null) return map['message'].toString();
      if (map['detail'] != null) return map['detail'].toString();
      if (map['error'] != null) return map['error'].toString();
      return map.toString();
    }
    if (errors is List) {
      final list = errors as List;
      if (list.isNotEmpty) return list.first.toString();
      return null;
    }
    if (errors is String) return errors as String;
    return errors.toString();
  }

  PaginationMeta? get paginationMeta {
    if (meta == null) return null;
    return PaginationMeta.fromJson(meta!);
  }

  static String? _extractNextCursor(Map<String, dynamic>? meta) {
    if (meta == null) return null;
    String? next;
    if (meta['next'] != null) {
      next = meta['next'].toString();
    } else if (meta['cursor'] != null) {
      next = meta['cursor'].toString();
    } else {
      final pagination = meta['pagination'];
      if (pagination is Map && pagination['next'] != null) {
        next = pagination['next'].toString();
      }
    }
    if (next == null || next.trim().isEmpty) return null;

    // Backend returns a full URL (e.g. ".../feed/?cursor=abc123"). Extract
    // just the opaque cursor token so it can be sent back as ?cursor=...
    // on the next request instead of nesting the whole URL as the value.
    final uri = Uri.tryParse(next.trim());
    if (uri != null && uri.queryParameters.containsKey('cursor')) {
      return uri.queryParameters['cursor'];
    }
    return next.trim();
  }

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromJsonT, {
    int? statusCode,
  }) {
    final rawMeta = json['meta'];
    final metaMap = rawMeta is Map ? Map<String, dynamic>.from(rawMeta) : null;
    final rawErrors = json['errors'];
    final parsedApiError = rawErrors != null ? ApiError.fromJson(rawErrors) : null;

    return ApiResponse<T>(
      data: json['data'] != null ? fromJsonT(json['data']) : null,
      meta: metaMap,
      errors: rawErrors,
      apiError: parsedApiError,
      nextCursor: _extractNextCursor(metaMap),
      statusCode: statusCode,
    );
  }

  factory ApiResponse.success(
    T data, {
    Map<String, dynamic>? meta,
    String? nextCursor,
    int? statusCode = 200,
  }) {
    return ApiResponse<T>(
      data: data,
      meta: meta,
      errors: null,
      apiError: null,
      nextCursor: nextCursor ?? _extractNextCursor(meta),
      statusCode: statusCode,
    );
  }

  factory ApiResponse.error({
    String? message,
    dynamic errors,
    ApiError? apiError,
    int? statusCode,
    T? fallbackData,
  }) {
    final effectiveError = apiError ??
        (errors != null
            ? ApiError.fromJson(errors)
            : (message != null ? ApiError(message: message) : null));

    return ApiResponse<T>(
      data: fallbackData,
      meta: null,
      errors: errors ?? (message != null ? {'message': message} : effectiveError?.toJson()),
      apiError: effectiveError,
      nextCursor: null,
      statusCode: statusCode,
    );
  }
}

class PaginationMeta {
  final int count;
  final String? next;
  final String? previous;

  PaginationMeta({
    required this.count,
    this.next,
    this.previous,
  });

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    int parsedCount = 0;
    final rawCount = json['count'];
    if (rawCount is int) {
      parsedCount = rawCount;
    } else if (rawCount is num) {
      parsedCount = rawCount.toInt();
    } else if (rawCount != null) {
      parsedCount = int.tryParse(rawCount.toString().trim()) ?? 0;
    }

    return PaginationMeta(
      count: parsedCount,
      next: json['next']?.toString(),
      previous: json['previous']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'count': count,
        if (next != null) 'next': next,
        if (previous != null) 'previous': previous,
      };
}
