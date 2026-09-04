class ApiResponse<T> {
  final T? data;
  final Map<String, dynamic>? meta;
  final List<dynamic>? errors;
  final String? nextCursor;

  ApiResponse({
    this.data,
    this.meta,
    this.errors,
    this.nextCursor,
  });

  static String? _extractNextCursor(Map<String, dynamic>? meta) {
    if (meta == null) return null;
    if (meta['next'] != null) return meta['next'].toString();
    final pagination = meta['pagination'];
    if (pagination is Map<String, dynamic> && pagination['next'] != null) {
      return pagination['next'].toString();
    }
    return null;
  }

  factory ApiResponse.fromJson(Map<String, dynamic> json, T Function(dynamic) fromJsonT) {
    return ApiResponse(
      data: json['data'] != null ? fromJsonT(json['data']) : null,
      meta: json['meta'] as Map<String, dynamic>?,
      errors: json['errors'] as List<dynamic>?,
      nextCursor: _extractNextCursor(json['meta'] as Map<String, dynamic>?),
    );
  }
}
