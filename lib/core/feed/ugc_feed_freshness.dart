import 'package:flutter/foundation.dart';

/// When an open citizen-news list should ask for page one again. The backend
/// never pushes records into a list, so a newly approved post only appears
/// after a new request.
class UgcFeedFreshness {
  UgcFeedFreshness._();

  /// Within the backend's recommended 30–60 seconds.
  static const staleAfter = Duration(seconds: 45);

  /// Bumped when a citizen-news notification arrives or is opened.
  static final ValueNotifier<int> published = ValueNotifier<int>(0);

  static void notifyPublished() => published.value++;

  /// Whether a feed last loaded at [loadedAt] is due for a refresh.
  static bool isStale(DateTime? loadedAt, {DateTime? now}) =>
      loadedAt == null ||
      (now ?? DateTime.now()).difference(loadedAt) >= staleAfter;
}
