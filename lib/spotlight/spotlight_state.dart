import '../models/spotlight_item.dart';

class SpotlightState {
  final List<SpotlightItem> feed;
  final bool isLoading;
  final bool hasMore;
  final String? nextCursor;
  final bool isLocalNews;
  final bool showOverlays;
  final bool isFetching;

  const SpotlightState({
    required this.feed,
    required this.isLoading,
    required this.hasMore,
    this.nextCursor,
    this.isLocalNews = false,
    this.showOverlays = true,
    this.isFetching = false,
  });

  factory SpotlightState.initial() {
    return const SpotlightState(
      feed: [],
      isLoading: true,
      hasMore: true,
      nextCursor: null,
      isLocalNews: false,
      showOverlays: true,
      isFetching: false,
    );
  }

  SpotlightState copyWith({
    List<SpotlightItem>? feed,
    bool? isLoading,
    bool? hasMore,
    String? nextCursor,
    bool? isLocalNews,
    bool? showOverlays,
    bool? isFetching,
  }) {
    return SpotlightState(
      feed: feed ?? this.feed,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      isLocalNews: isLocalNews ?? this.isLocalNews,
      showOverlays: showOverlays ?? this.showOverlays,
      isFetching: isFetching ?? this.isFetching,
    );
  }
}
