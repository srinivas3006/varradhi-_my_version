import 'package:flutter/material.dart';
import '../../data/models/admin_bulk_action_model.dart';
import '../../data/models/admin_paginated_response.dart';
import '../../data/models/admin_push_notification_payload.dart';
import '../../data/models/admin_ugc_status.dart';
import '../../data/models/admin_ugc_submission_model.dart';
import '../../data/repositories/admin_ugc_repository.dart';
import 'admin_load_status.dart';

enum AdminQueueRefinement { all, duplicatesOnly, reported }

class AdminUgcQueueController extends ChangeNotifier {
  final AdminUgcRepository _repository = AdminUgcRepository();

  final List<AdminUgcSubmissionModel> _items = [];
  final Set<String> _ids = {};

  AdminLoadStatus _status = AdminLoadStatus.initial;
  String? _errorMessage;
  String? _nextCursor;
  bool _hasMore = true;
  bool _isFetching = false;
  int _totalCount = 0;

  AdminUgcStatus? statusFilter;
  AdminQueueRefinement refinementFilter = AdminQueueRefinement.all;
  String searchQuery = '';

  bool isMultiSelectMode = false;
  final Set<String> selectedIds = {};

  List<AdminUgcSubmissionModel> get items => List.unmodifiable(_items);
  AdminLoadStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;
  int get totalCount => _totalCount;

  List<AdminUgcSubmissionModel> get filteredItems {
    if (searchQuery.trim().isEmpty) return items;
    final q = searchQuery.trim().toLowerCase();
    return _items.where((item) {
      return item.title.toLowerCase().contains(q) ||
          item.district.toLowerCase().contains(q) ||
          item.stateName.toLowerCase().contains(q) ||
          item.reporterMobile.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> loadInitial() async {
    if (_isFetching) return;
    _isFetching = true;
    _status = AdminLoadStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _fetchPage(cursor: null);
      _items.clear();
      _ids.clear();
      for (final item in response.items) {
        if (_ids.add(item.id)) _items.add(item);
      }
      _nextCursor = response.next;
      _hasMore = response.hasMore;
      _totalCount = response.count;
      _status = _items.isEmpty ? AdminLoadStatus.empty : AdminLoadStatus.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      _status = AdminLoadStatus.error;
    } finally {
      _isFetching = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isFetching || !_hasMore || _nextCursor == null) return;
    // After a failure the scroll listener keeps arriving. Wait for an
    // explicit retryLoadMore() rather than re-requesting on every scroll.
    if (_status == AdminLoadStatus.error) return;
    _isFetching = true;
    _status = AdminLoadStatus.loadingMore;
    notifyListeners();

    try {
      final response = await _fetchPage(cursor: _nextCursor);
      for (final item in response.items) {
        if (_ids.add(item.id)) _items.add(item);
      }
      _nextCursor = response.next;
      _hasMore = response.hasMore;
      _totalCount = response.count;
      _status = AdminLoadStatus.loaded;
    } catch (e) {
      // Reporting `loaded` here claimed the page had arrived. The cursor was
      // never advanced and _hasMore stayed true, so the scroll listener
      // re-fired loadMore on every scroll — repeated silent requests against
      // a failing endpoint, while the moderator saw a queue that simply
      // stopped growing.
      //
      // _hasMore is left true on purpose: more items do exist, and retry()
      // below lets the moderator ask for them again deliberately.
      _errorMessage = e.toString();
      _status = AdminLoadStatus.error;
    } finally {
      _isFetching = false;
      notifyListeners();
    }
  }

  /// Retries the page that failed, after [loadMore] surfaced an error.
  Future<void> retryLoadMore() async {
    if (_status != AdminLoadStatus.error) return;
    _errorMessage = null;
    _status = AdminLoadStatus.loaded;
    notifyListeners();
    await loadMore();
  }

  Future<void> refresh() => loadInitial();

  Future<AdminPaginatedResponse<AdminUgcSubmissionModel>> _fetchPage({String? cursor}) {
    return _repository.getQueue(
      cursor: cursor,
      status: statusFilter?.wireValue,
      duplicateFlagged: refinementFilter == AdminQueueRefinement.duplicatesOnly ? true : null,
      reportCountMin: refinementFilter == AdminQueueRefinement.reported ? 1 : null,
    );
  }

  void setStatusFilter(AdminUgcStatus? status) {
    statusFilter = status;
    loadInitial();
  }

  void setRefinement(AdminQueueRefinement refinement) {
    refinementFilter = refinement;
    loadInitial();
  }

  void setSearchQuery(String query) {
    searchQuery = query;
    notifyListeners();
  }

  void toggleMultiSelect() {
    isMultiSelectMode = !isMultiSelectMode;
    if (!isMultiSelectMode) selectedIds.clear();
    notifyListeners();
  }

  void toggleSelection(String id) {
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
    } else {
      selectedIds.add(id);
    }
    notifyListeners();
  }

  void selectAll() {
    selectedIds
      ..clear()
      ..addAll(filteredItems.map((e) => e.id));
    notifyListeners();
  }

  void deselectAll() {
    selectedIds.clear();
    notifyListeners();
  }

  void _replaceItem(AdminUgcSubmissionModel updated) {
    final index = _items.indexWhere((e) => e.id == updated.id);
    if (index != -1) _items[index] = updated;
    notifyListeners();
  }

  Future<void> approveItem(
    String id, {
    required String notes,
    required String publicationLevel,
    AdminPushNotificationPayload? push,
  }) async {
    final updated = await _repository.approveSubmission(id, notes: notes, publicationLevel: publicationLevel, push: push);
    _replaceItem(updated);
  }

  Future<void> rejectItem(String id, {required String notes}) async {
    final updated = await _repository.rejectSubmission(id, notes: notes);
    _replaceItem(updated);
  }

  Future<void> flagItem(String id) async {
    final updated = await _repository.flagSubmission(id);
    _replaceItem(updated);
  }

  AdminUgcSubmissionModel _itemOrThrow(String id) {
    return _items.firstWhere((e) => e.id == id, orElse: () => throw StateError('Submission $id not found in queue'));
  }

  Future<void> increaseTrustFor(String id) async {
    await _repository.increaseTrust(id);
    final item = _itemOrThrow(id);
    _replaceItem(item.copyWith(trustScore: (item.trustScore + 10).clamp(0, 100)));
  }

  Future<void> decreaseTrustFor(String id) async {
    await _repository.decreaseTrust(id);
    final item = _itemOrThrow(id);
    _replaceItem(item.copyWith(trustScore: (item.trustScore - 10).clamp(0, 100)));
  }

  Future<void> toggleBlockFor(String id) async {
    final item = _itemOrThrow(id);
    if (item.uploaderBlocked) {
      await _repository.unblockUploader(id);
    } else {
      await _repository.blockUploader(id);
    }
    _replaceItem(item.copyWith(uploaderBlocked: !item.uploaderBlocked));
  }

  AdminUgcStatus? _statusForAction(String action) {
    switch (action) {
      case 'approve':
        return AdminUgcStatus.approved;
      case 'reject':
        return AdminUgcStatus.rejected;
      case 'flag':
        return AdminUgcStatus.flagged;
      default:
        return null;
    }
  }

  Future<AdminBulkActionResult> applyBulkAction(String action, {String? notes}) async {
    final ids = selectedIds.toList();
    final result = await _repository.bulkAction(AdminBulkActionRequest(ids: ids, action: action, notes: notes));

    final newStatus = _statusForAction(action);
    if (newStatus != null) {
      for (final id in ids) {
        final index = _items.indexWhere((e) => e.id == id);
        if (index != -1) _items[index] = _items[index].copyWith(status: newStatus);
      }
    }
    selectedIds.clear();
    isMultiSelectMode = false;
    notifyListeners();
    return result;
  }
}
