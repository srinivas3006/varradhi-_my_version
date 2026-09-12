/// Discrete, predictable status states for feeds.
enum FeedStatus {
  initial,
  loading,
  success,
  empty,
  refreshing,
  loadingMore,
  error,
}

/// Production Feed State Machine supporting:
/// - Distinct EMPTY vs ERROR states
/// - Retention of cached/existing items during refresh failure (with non-blocking error)
/// - Type-safe cursor pagination
/// - Prevention of contradictory boolean states
class FeedState<T> {
  final FeedStatus status;
  final List<T> items;
  final String? nextCursor;
  final bool hasMore;
  final String? errorMessage;
  final String? refreshErrorMessage;
  final DateTime? cachedAt;

  const FeedState({
    required this.status,
    required this.items,
    this.nextCursor,
    this.hasMore = false,
    this.errorMessage,
    this.refreshErrorMessage,
    this.cachedAt,
  });

  factory FeedState.initial() => const FeedState(
        status: FeedStatus.initial,
        items: [],
        hasMore: false,
      );

  factory FeedState.loading({List<T> initialItems = const []}) => FeedState(
        status: FeedStatus.loading,
        items: initialItems,
        hasMore: initialItems.isNotEmpty,
      );

  factory FeedState.success({
    required List<T> items,
    String? nextCursor,
    bool? hasMore,
    DateTime? cachedAt,
  }) {
    if (items.isEmpty) {
      return FeedState<T>(
        status: FeedStatus.empty,
        items: const [],
        nextCursor: null,
        hasMore: false,
        cachedAt: cachedAt,
      );
    }
    return FeedState<T>(
      status: FeedStatus.success,
      items: items,
      nextCursor: nextCursor,
      hasMore: hasMore ?? (nextCursor != null && nextCursor.isNotEmpty),
      cachedAt: cachedAt,
    );
  }

  factory FeedState.empty({DateTime? cachedAt}) => FeedState<T>(
        status: FeedStatus.empty,
        items: const [],
        nextCursor: null,
        hasMore: false,
        cachedAt: cachedAt,
      );

  factory FeedState.error({
    required String message,
    List<T> previousItems = const [],
    String? previousCursor,
    bool? previousHasMore,
  }) {
    if (previousItems.isNotEmpty) {
      // Preserves existing content on refresh failure and exposes non-blocking error
      return FeedState<T>(
        status: FeedStatus.success,
        items: previousItems,
        nextCursor: previousCursor,
        hasMore: previousHasMore ?? (previousCursor != null),
        refreshErrorMessage: message,
      );
    }
    return FeedState<T>(
      status: FeedStatus.error,
      items: const [],
      errorMessage: message,
      hasMore: false,
    );
  }

  FeedState<T> toRefreshing() => copyWith(
        status: FeedStatus.refreshing,
        clearRefreshError: true,
      );

  FeedState<T> toLoadingMore() => copyWith(
        status: FeedStatus.loadingMore,
        clearRefreshError: true,
      );

  bool get isInitialLoading => status == FeedStatus.loading;
  bool get isRefreshing => status == FeedStatus.refreshing;
  bool get isLoadingMore => status == FeedStatus.loadingMore;
  bool get isSuccess => status == FeedStatus.success;
  bool get isEmpty => status == FeedStatus.empty;
  bool get isError => status == FeedStatus.error;
  bool get hasData => items.isNotEmpty;
  bool get hasRefreshError => refreshErrorMessage != null && refreshErrorMessage!.isNotEmpty;

  FeedState<T> copyWith({
    FeedStatus? status,
    List<T>? items,
    String? nextCursor,
    bool? hasMore,
    String? errorMessage,
    String? refreshErrorMessage,
    DateTime? cachedAt,
    bool clearRefreshError = false,
  }) {
    return FeedState<T>(
      status: status ?? this.status,
      items: items ?? this.items,
      nextCursor: nextCursor ?? this.nextCursor,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: errorMessage ?? this.errorMessage,
      refreshErrorMessage: clearRefreshError ? null : (refreshErrorMessage ?? this.refreshErrorMessage),
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }
}
