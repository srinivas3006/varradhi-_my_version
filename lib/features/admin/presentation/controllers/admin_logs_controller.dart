import 'package:flutter/material.dart';
import '../../data/models/admin_moderation_log_model.dart';
import '../../data/repositories/admin_ugc_repository.dart';
import 'admin_load_status.dart';

class AdminLogsController extends ChangeNotifier {
  static const _requestTimeout = Duration(seconds: 8);
  final AdminUgcRepository _repository = AdminUgcRepository();

  final List<AdminModerationLogModel> _items = [];
  AdminLoadStatus _status = AdminLoadStatus.initial;
  String? _errorMessage;
  String? _nextCursor;
  bool _hasMore = true;
  bool _isFetching = false;

  String actionFilter = 'ALL';
  String searchQuery = '';

  AdminLoadStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;

  /// Applies the action filter and search query client-side on top of
  /// whatever the server already returned — resilient whether or not the
  /// backend actually honors the `action`/`search` query params.
  List<AdminModerationLogModel> get items {
    Iterable<AdminModerationLogModel> result = _items;
    if (actionFilter != 'ALL') {
      result = result.where((e) => e.action == actionFilter);
    }
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      result = result.where((e) => e.submissionTitle.toLowerCase().contains(q) || e.adminEmail.toLowerCase().contains(q));
    }
    return result.toList();
  }

  Future<void> loadInitial() async {
    if (_isFetching) return;
    _isFetching = true;
    _status = AdminLoadStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _repository.getModerationLogs(
        action: actionFilter == 'ALL' ? null : actionFilter,
        search: searchQuery.isEmpty ? null : searchQuery,
      ).timeout(_requestTimeout);
      _items
        ..clear()
        ..addAll(response.items);
      _nextCursor = response.next;
      _hasMore = response.hasMore;
      _status = _items.isEmpty ? AdminLoadStatus.empty : AdminLoadStatus.loaded;
    } catch (e) {
      _errorMessage = 'మోడరేషన్ లాగ్‌లు లోడ్ కాలేదు. కనెక్షన్ చూసి మళ్లీ ప్రయత్నించండి.';
      _status = AdminLoadStatus.error;
    } finally {
      _isFetching = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isFetching || !_hasMore || _nextCursor == null) return;
    _isFetching = true;
    _status = AdminLoadStatus.loadingMore;
    notifyListeners();

    try {
      final response = await _repository.getModerationLogs(
        cursor: _nextCursor,
        action: actionFilter == 'ALL' ? null : actionFilter,
        search: searchQuery.isEmpty ? null : searchQuery,
      ).timeout(_requestTimeout);
      _items.addAll(response.items);
      _nextCursor = response.next;
      _hasMore = response.hasMore;
      _status = AdminLoadStatus.loaded;
    } catch (_) {
      _status = AdminLoadStatus.loaded;
    } finally {
      _isFetching = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => loadInitial();

  void setActionFilter(String action) {
    actionFilter = action;
    notifyListeners();
    loadInitial();
  }

  void setSearchQuery(String query) {
    searchQuery = query;
    notifyListeners();
  }
}
