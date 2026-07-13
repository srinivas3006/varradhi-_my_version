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

  factory ApiResponse.fromJson(Map<String, dynamic> json, T Function(dynamic) fromJsonT) {
    return ApiResponse(
      data: json['data'] != null ? fromJsonT(json['data']) : null,
      meta: json['meta'] as Map<String, dynamic>?,
      errors: json['errors'] as List<dynamic>?,
      // Handle Django Rest Framework pagination typically found in meta
      nextCursor: json['meta']?['next']?.toString(),
    );
  }
}
