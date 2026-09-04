import 'package:flutter/material.dart';
import '../../data/models/admin_otp_delivery_model.dart';
import '../../data/repositories/admin_ugc_repository.dart';
import 'admin_load_status.dart';

class AdminOtpDeliveriesController extends ChangeNotifier {
  final AdminUgcRepository _repository = AdminUgcRepository();

  final List<AdminOtpDeliveryModel> _items = [];
  AdminLoadStatus _status = AdminLoadStatus.initial;
  String? _errorMessage;
  String? _nextCursor;
  bool _hasMore = true;
  bool _isFetching = false;

  String statusFilter = 'ALL';
  String mobileQuery = '';

  AdminLoadStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;

  List<AdminOtpDeliveryModel> get items {
    Iterable<AdminOtpDeliveryModel> result = _items;
    if (statusFilter != 'ALL') {
      result = result.where((e) => e.status == statusFilter);
    }
    if (mobileQuery.trim().isNotEmpty) {
      result = result.where((e) => e.mobile.contains(mobileQuery.trim()));
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
      final response = await _repository.getOtpDeliveries(
        status: statusFilter == 'ALL' ? null : statusFilter,
        mobile: mobileQuery.isEmpty ? null : mobileQuery,
      );
      _items
        ..clear()
        ..addAll(response.items);
      _nextCursor = response.next;
      _hasMore = response.hasMore;
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
    _isFetching = true;
    _status = AdminLoadStatus.loadingMore;
    notifyListeners();

    try {
      final response = await _repository.getOtpDeliveries(
        cursor: _nextCursor,
        status: statusFilter == 'ALL' ? null : statusFilter,
        mobile: mobileQuery.isEmpty ? null : mobileQuery,
      );
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
    notifyListeners();
    loadInitial();
  }

  void setMobileQuery(String mobile) {
    mobileQuery = mobile;
    notifyListeners();
  }
}
