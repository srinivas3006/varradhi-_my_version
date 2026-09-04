/// Admin list endpoints return `{items, count, next, previous}` — a flatter
/// shape than `core/network/api_response.dart`'s `{data, meta, errors}`
/// envelope used by the article feed. Parsed defensively with `results`/
/// `data` fallbacks in case a given endpoint's shape drifts slightly.
class AdminPaginatedResponse<T> {
  final List<T> items;
  final int count;
  final String? next;
  final String? previous;

  const AdminPaginatedResponse({
    required this.items,
    required this.count,
    this.next,
    this.previous,
  });

  factory AdminPaginatedResponse.fromJson(dynamic rawResponse, T Function(Map<String, dynamic>) itemFromJson) {
    final raw = rawResponse is Map && rawResponse['data'] is Map ? rawResponse['data'] as Map : rawResponse;

    final rawList = (raw is Map ? (raw['items'] ?? raw['results'] ?? raw['data']) : raw);
    final list = rawList is List ? rawList : const [];

    final items = list.whereType<Map>().map((e) => itemFromJson(Map<String, dynamic>.from(e))).toList();

    return AdminPaginatedResponse<T>(
      items: items,
      count: raw is Map && raw['count'] != null ? int.tryParse(raw['count'].toString()) ?? items.length : items.length,
      next: raw is Map ? raw['next']?.toString() : null,
      previous: raw is Map ? raw['previous']?.toString() : null,
    );
  }

  bool get hasMore => next != null && next!.isNotEmpty;
}
