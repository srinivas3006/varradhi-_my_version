import 'package:flutter/material.dart';
import '../../data/models/admin_report_model.dart';
import '../../data/repositories/admin_ugc_repository.dart';
import 'admin_load_status.dart';

class AdminReportsController extends ChangeNotifier {
  static const _requestTimeout = Duration(seconds: 8);
  final AdminUgcRepository _repository = AdminUgcRepository();

  final List<AdminReportModel> _items = [];
  AdminLoadStatus _status = AdminLoadStatus.initial;
  String? _errorMessage;
  String? _nextCursor;
  bool _hasMore = true;
  bool _isFetching = false;

  String statusFilter = 'ALL';

  List<AdminReportModel> get items => List.unmodifiable(_items);
  AdminLoadStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;

  Future<void> loadInitial() async {
    if (_isFetching) return;
    _isFetching = true;
    _status = AdminLoadStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _repository
          .getReports(status: statusFilter == 'ALL' ? null : statusFilter)
          .timeout(_requestTimeout);
      _items
        ..clear()
        ..addAll(response.items);
      _nextCursor = response.next;
      _hasMore = response.hasMore;
      _status = _items.isEmpty ? AdminLoadStatus.empty : AdminLoadStatus.loaded;
    } catch (e) {
      _errorMessage = 'నివేదికలు లోడ్ కాలేదు. కనెక్షన్ చూసి మళ్లీ ప్రయత్నించండి.';
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
      final response = await _repository
          .getReports(cursor: _nextCursor, status: statusFilter == 'ALL' ? null : statusFilter)
          .timeout(_requestTimeout);
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

  void setStatusFilter(String status) {
    statusFilter = status;
    loadInitial();
  }

  Future<void> reviewReport(String id) async {
    await _repository.reviewReport(id);
    final index = _items.indexWhere((e) => e.id == id);
    if (index != -1) {
      final old = _items[index];
      _items[index] = AdminReportModel(
        id: old.id,
        status: 'REVIEWED',
        reason: old.reason,
        targetSubmissionId: old.targetSubmissionId,
        targetSubmissionTitle: old.targetSubmissionTitle,
        reporterNote: old.reporterNote,
        reporterEmail: old.reporterEmail,
        createdAt: old.createdAt,
      );
      notifyListeners();
    }
  }

  Future<void> dismissReport(String id) async {
    await _repository.dismissReport(id);
    final index = _items.indexWhere((e) => e.id == id);
    if (index != -1) {
      final old = _items[index];
      _items[index] = AdminReportModel(
        id: old.id,
        status: 'DISMISSED',
        reason: old.reason,
        targetSubmissionId: old.targetSubmissionId,
        targetSubmissionTitle: old.targetSubmissionTitle,
        reporterNote: old.reporterNote,
        reporterEmail: old.reporterEmail,
        createdAt: old.createdAt,
      );
      notifyListeners();
    }
  }
}
