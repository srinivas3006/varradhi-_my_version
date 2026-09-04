import 'package:flutter/material.dart';
import '../../data/models/article_model.dart';
import '../../data/repositories/article_repository.dart';

enum FeedStatus { initial, loading, loaded, loadingMore, error, empty }

class ArticleFeedController extends ChangeNotifier {
  final ArticleRepository _repository = ArticleRepository();

  final List<ArticleModel> _articles = [];
  final Set<String> _articleIds = {};

  FeedStatus _status = FeedStatus.initial;
  String? _errorMessage;
  String? _nextCursor;
  bool _hasMore = true;
  bool _isFetching = false;

  List<ArticleModel> get articles => List.unmodifiable(_articles);
  FeedStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;

  Future<void> loadInitialFeed({required String scope, String? category}) async {
    if (_isFetching) return;
    _isFetching = true;
    _status = FeedStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _repository.fetchFeed(scope: scope, category: category);
      final newItems = response.data ?? [];

      _articles.clear();
      _articleIds.clear();

      for (final item in newItems) {
        if (_articleIds.add(item.id)) {
          _articles.add(item);
        }
      }

      _nextCursor = response.meta?.next;
      _hasMore = _nextCursor != null && _nextCursor!.isNotEmpty;
      _status = _articles.isEmpty ? FeedStatus.empty : FeedStatus.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      _status = FeedStatus.error;
    } finally {
      _isFetching = false;
      notifyListeners();
    }
  }

  Future<void> loadMore({required String scope}) async {
    if (_isFetching || !_hasMore || _nextCursor == null) return;

    _isFetching = true;
    _status = FeedStatus.loadingMore;
    notifyListeners();

    try {
      final response = await _repository.fetchFeed(scope: scope, cursor: _nextCursor);
      final newItems = response.data ?? [];

      for (final item in newItems) {
        if (_articleIds.add(item.id)) {
          _articles.add(item);
        }
      }

      _nextCursor = response.meta?.next;
      _hasMore = _nextCursor != null && _nextCursor!.isNotEmpty;
      _status = FeedStatus.loaded;
    } catch (e) {
      _status = FeedStatus.loaded;
    } finally {
      _isFetching = false;
      notifyListeners();
    }
  }
}
