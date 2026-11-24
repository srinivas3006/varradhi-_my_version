import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/spotlight_item.dart';
import '../repositories/top_stories_repository.dart';

class TopStoriesController extends ChangeNotifier {
  TopStoriesController({TopStoriesRepository? repository})
      : _repository = repository ?? TopStoriesRepository.instance;

  final TopStoriesRepository _repository;
  TopStoriesQuery? _query;
  CancelToken? _request;

  String? get filterKey => _query?.cacheKey;
  List<SpotlightItem> stories = const [];
  TopStoriesFailure? failure;
  bool loading = false;

  Future<void> show(TopStoriesQuery query) async {
    if (query.cacheKey == filterKey) return;
    close();
    _query = query;
    loading = true;
    notifyListeners();

    final cached = await _repository.cached(query);
    if (!identical(_query, query)) return;
    if (cached.isNotEmpty) {
      stories = cached;
      notifyListeners();
    }
    await _fetch(query);
  }

  Future<void> refresh() async {
    final query = _query;
    if (query == null || loading) return;
    await _fetch(query);
  }

  Future<void> _fetch(TopStoriesQuery query) async {
    final request = _request = CancelToken();
    loading = true;
    failure = null;
    notifyListeners();
    try {
      final fresh = await _repository.fetch(query, request);
      if (!identical(_request, request)) return;
      stories = fresh;
    } catch (error) {
      if (!identical(_request, request)) return;
      final problem =
          error is TopStoriesFailure ? error : const TopStoriesFailure();
      failure = problem;
      if (problem.status == 400) stories = const [];
    } finally {
      if (identical(_request, request)) {
        _request = null;
        loading = false;
        notifyListeners();
      }
    }
  }

  void close() {
    _request?.cancel();
    _request = null;
    _query = null;
    stories = const [];
    failure = null;
    loading = false;
  }

  @override
  void dispose() {
    close();
    super.dispose();
  }
}
