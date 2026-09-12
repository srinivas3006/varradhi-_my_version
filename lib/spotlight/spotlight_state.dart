import '../models/spotlight_item.dart';

class SpotlightState {
  final List<SpotlightItem> feed;
  final bool isLoading;
  final bool hasMore;
  final String? nextCursor;
  final bool isLocalNews;
  final bool showOverlays;
  final bool isFetching;
  final String? errorMessage;

  final String? selectedCategory;
  final String locationName;
  final int generation;

  const SpotlightState({
    required this.feed,
    required this.isLoading,
    required this.hasMore,
    this.nextCursor,
    this.isLocalNews = false,
    this.showOverlays = true,
    this.isFetching = false,
    this.errorMessage,
    this.selectedCategory,
    this.locationName = '',
    this.generation = 0,
  });

  factory SpotlightState.initial({String? category, String? locationName}) {
    return SpotlightState(
      feed: const [],
      isLoading: true,
      hasMore: true,
      nextCursor: null,
      isLocalNews: false,
      showOverlays: true,
      isFetching: false,
      errorMessage: null,
      selectedCategory: category,
      locationName: locationName ?? '',
      generation: 0,
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
    String? errorMessage,
    bool clearError = false,
    String? selectedCategory,
    bool clearCategory = false,
    String? locationName,
    int? generation,
  }) {
    return SpotlightState(
      feed: feed ?? this.feed,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      isLocalNews: isLocalNews ?? this.isLocalNews,
      showOverlays: showOverlays ?? this.showOverlays,
      isFetching: isFetching ?? this.isFetching,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      selectedCategory: clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      locationName: locationName ?? this.locationName,
      generation: generation ?? this.generation,
    );
  }
}
