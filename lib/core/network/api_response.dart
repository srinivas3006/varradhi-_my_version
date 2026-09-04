class ApiResponse<T> {
  final T? data;
  final PaginationMeta? meta;
  final dynamic errors;

  ApiResponse({this.data, this.meta, this.errors});

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromJsonT,
  ) {
    return ApiResponse<T>(
      data: json['data'] != null ? fromJsonT(json['data']) : null,
      meta: json['meta'] != null ? PaginationMeta.fromJson(json['meta']) : null,
      errors: json['errors'],
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
    return PaginationMeta(
      count: json['count'] ?? 0,
      next: json['next']?.toString(),
      previous: json['previous']?.toString(),
    );
  }
}
