class AdminBulkActionRequest {
  final List<String> ids;
  final String action;
  final String? notes;

  const AdminBulkActionRequest({required this.ids, required this.action, this.notes});

  Map<String, dynamic> toJson() => {
        'ids': ids,
        'action': action,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
      };
}

class AdminBulkActionResult {
  final int successCount;
  final int failedCount;
  final List<String> errors;

  const AdminBulkActionResult({required this.successCount, required this.failedCount, required this.errors});

  /// Defensive: falls back to `successCount = ids.length` if the backend
  /// just returns a bare `{status:"success"}` with no per-item counts, so
  /// the UI never crashes on a minimal response.
  factory AdminBulkActionResult.fromJson(dynamic rawResponse, int requestedCount) {
    final raw = rawResponse is Map && rawResponse['data'] is Map ? rawResponse['data'] as Map : rawResponse;
    if (raw is! Map) {
      return AdminBulkActionResult(successCount: requestedCount, failedCount: 0, errors: const []);
    }
    final hasCounts = raw['success_count'] != null || raw['failed_count'] != null;
    return AdminBulkActionResult(
      successCount: hasCounts ? int.tryParse(raw['success_count']?.toString() ?? '') ?? requestedCount : requestedCount,
      failedCount: hasCounts ? int.tryParse(raw['failed_count']?.toString() ?? '') ?? 0 : 0,
      errors: (raw['errors'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }
}
