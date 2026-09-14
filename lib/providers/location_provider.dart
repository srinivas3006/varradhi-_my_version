import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/location_model.dart';
import '../core/utils/location_detector.dart';
import '../repositories/location_repository.dart';
import '../state/app_state.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

class LocationProvider extends ChangeNotifier {
  LocationProvider({
    required this.repository,
    this.detector = const LocationDetector(),
  });

  final LocationRepository repository;
  final LocationDetector detector;

  Timer? _debounce;
  String _query = '';
  List<LocationSearchResult> _results = const [];
  List<LocationNode> _states = const [];
  List<LocationNode> _districts = const [];
  List<LocationNode> _subdistricts = const [];
  List<LocationNode> _villages = const [];
  LocationNode? _selectedState;
  LocationNode? _selectedDistrict;
  LocationNode? _selectedSubdistrict;
  bool _isSearching = false;
  bool _isApplying = false;

  bool _isLoading = false;
  bool _hasError = false;
  Object? _error;

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  Object? get error => _error;

  // --- GPS detection ---
  bool _isDetecting = false;
  LocationDetectFailure? _detectFailure;
  DetectedPlace? _detectedPlace;
  List<LocationSearchResult> _detectMatches = const [];

  String get query => _query;
  List<LocationSearchResult> get results => _results;
  List<LocationNode> get states => _states;
  List<LocationNode> get districts => _districts;
  List<LocationNode> get subdistricts => _subdistricts;
  List<LocationNode> get villages => _villages;
  LocationNode? get selectedState => _selectedState;
  LocationNode? get selectedDistrict => _selectedDistrict;
  LocationNode? get selectedSubdistrict => _selectedSubdistrict;
  bool get isSearching => _isSearching;
  bool get isApplying => _isApplying;

  bool get isDetecting => _isDetecting;
  LocationDetectFailure? get detectFailure => _detectFailure;
  DetectedPlace? get detectedPlace => _detectedPlace;
  List<LocationSearchResult> get detectMatches => _detectMatches;

  bool get hasDetection => _detectedPlace != null || _detectFailure != null;
  bool get isSearchMode => _query.trim().length >= 2;

  Future<void> detectLocation() async {
    _isDetecting = true;
    _detectFailure = null;
    _detectedPlace = null;
    _detectMatches = const [];
    notifyListeners();

    final result = await detector.detect();
    if (!result.isSuccess) {
      _isDetecting = false;
      _detectFailure = result.failure ?? LocationDetectFailure.unknown;
      notifyListeners();
      return;
    }

    final place = result.place!;
    _detectedPlace = place;

    for (final term in [
      place.village,
      place.subdistrict,
      place.district,
      place.state,
    ]) {
      if (term.isEmpty) continue;
      try {
        final matches = await repository.search(term, limit: 10);
        if (matches.isNotEmpty) {
          _detectMatches = matches;
          break;
        }
      } catch (_) {}
    }

    if (_detectMatches.isEmpty) {
      _detectFailure = LocationDetectFailure.noPlaceFound;
    }
    _isDetecting = false;
    notifyListeners();
  }

  void clearDetection() {
    _isDetecting = false;
    _detectFailure = null;
    _detectedPlace = null;
    _detectMatches = const [];
    notifyListeners();
  }

  Future<void> load() async {
    _isLoading = true;
    _hasError = false;
    _error = null;
    notifyListeners();
    try {
      _states = await repository.states();
      final current = AppState.instance;
      if (current.stateName.isNotEmpty) {
        final match = _states.where((s) => s.nameEn == current.stateName);
        if (match.isNotEmpty) {
          await selectState(match.first);
        }
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _hasError = true;
      _error = e;
      notifyListeners();
    }
  }

  void onQueryChanged(String value) {
    _query = value;
    _debounce?.cancel();
    if (!isSearchMode) {
      _results = const [];
      notifyListeners();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), _runSearch);
    notifyListeners();
  }

  Future<void> _runSearch() async {
    _isSearching = true;
    notifyListeners();
    try {
      _results = await repository.search(_query, limit: 20);
    } catch (_) {
      _results = const [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  Future<void> selectState(LocationNode state) async {
    _selectedState = state;
    _selectedDistrict = null;
    _selectedSubdistrict = null;
    _districts = const [];
    _subdistricts = const [];
    _villages = const [];
    notifyListeners();
    try {
      _districts = await repository.districts(stateSlug: state.nameEn);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> selectDistrict(LocationNode district) async {
    _selectedDistrict = district;
    _selectedSubdistrict = null;
    _subdistricts = const [];
    _villages = const [];
    notifyListeners();
    try {
      _subdistricts = await repository.subdistricts(
        districtSlug: district.nameEn,
        stateSlug: _selectedState?.nameEn,
      );
    } catch (_) {}
    notifyListeners();
  }

  Future<void> selectSubdistrict(LocationNode subdistrict) async {
    _selectedSubdistrict = subdistrict;
    _villages = const [];
    notifyListeners();
    try {
      _villages = await repository.villages(
        subdistrictSlug: subdistrict.nameEn,
        districtSlug: _selectedDistrict?.nameEn,
        stateSlug: _selectedState?.nameEn,
      );
    } catch (_) {}
    notifyListeners();
  }

  void clearDrilldown() {
    _selectedState = null;
    _selectedDistrict = null;
    _selectedSubdistrict = null;
    _districts = const [];
    _subdistricts = const [];
    _villages = const [];
    notifyListeners();
  }

  Future<bool> apply(LocationSearchResult result) async {
    _isApplying = true;
    notifyListeners();
    try {
      // Map LocationSearchResult to DeviceLocation to pass to AppState
      final location = DeviceLocation(
        latitude: 0,
        longitude: 0,
        accuracyMeters: 0,
        city: result.nameEn,
        district: result.district,
        state: result.state,
        country: 'India',
        source: 'manual',
        subdistrict: result.subdistrict,
        village: result.type == LocationLevel.village ? result.nameEn : '',
      );

      AppState.instance.setDeviceLocation(
        location,
        stateId: result.type == LocationLevel.state ? result.id : null,
        districtId: result.type == LocationLevel.district ? result.id : null,
        subdistrictId: result.type == LocationLevel.subdistrict ? result.id : null,
        villageId: result.type == LocationLevel.village ? result.id : null,
      );

      final patchData = <String, dynamic>{};
      if (result.type == LocationLevel.village) patchData['village_id'] = result.id;
      if (result.type == LocationLevel.subdistrict) patchData['subdistrict_id'] = result.id;
      if (result.type == LocationLevel.district) patchData['district_id'] = result.id;
      if (result.type == LocationLevel.state) patchData['state_id'] = result.id;

      if (patchData.isNotEmpty) {
        await ApiService.instance.updateLocationProfile(patchData);
      }

      return true;
    } catch (error) {
      _hasError = true;
      _error = error;
      return false;
    } finally {
      _isApplying = false;
      notifyListeners();
    }
  }

  Future<bool> applyNode(LocationNode node, LocationLevel level) {
    return apply(
      LocationSearchResult(
        type: level,
        id: node.id,
        nameEn: node.nameEn,
        nameTe: node.nameTe,
        slug: node.slug,
        state: _selectedState?.nameEn ?? '',
        district: _selectedDistrict?.nameEn ?? '',
        subdistrict: _selectedSubdistrict?.nameEn ?? '',
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
