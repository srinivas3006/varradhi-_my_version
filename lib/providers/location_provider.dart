import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/location_model.dart';
import '../localization/location_translations.dart';
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

    // The backend's nearest mapped village, from the GPS fix itself — exact
    // where village coordinates are loaded, and it works even when the
    // geocoder could not name the spot.
    LocationSearchResult? nearest;
    if (result.latitude != null && result.longitude != null) {
      try {
        nearest = await repository.nearest(
            result.latitude!, result.longitude!);
      } catch (_) {}
    }

    if (!result.isSuccess && nearest == null) {
      if (result.failure == LocationDetectFailure.permissionDenied) {
        AppState.instance.markLocationPermissionDenied();
      } else if (result.failure ==
          LocationDetectFailure.permissionDeniedForever) {
        AppState.instance.markLocationPermissionDenied(forever: true);
      }
      _isDetecting = false;
      _detectFailure = result.failure ?? LocationDetectFailure.unknown;
      notifyListeners();
      return;
    }

    final place = result.place ??
        DetectedPlace(
          state: nearest!.state,
          district: nearest.district,
          subdistrict: nearest.subdistrict,
          village: nearest.nameEn,
          names: [nearest.nameEn],
        );
    _detectedPlace = place;

    // Every detected name is searched and the results ranked together. The
    // old loop took the first name with any result: a village name that
    // exists in several districts (there are five Kesarams) returned the
    // wrong one, and a name the database spells differently fell straight
    // through to the state.
    final terms = <String>[];
    for (final t in [
      ...place.names,
      place.village,
      place.subdistrict,
      place.district,
      place.state,
    ]) {
      if (t.isNotEmpty &&
          !terms.any((x) => x.toLowerCase() == t.toLowerCase())) {
        terms.add(t);
      }
    }
    final found = <LocationSearchResult>[];
    for (final term in terms.take(6)) {
      try {
        found.addAll(await repository.search(term, limit: 50));
      } catch (_) {}
    }
    _detectMatches = withNearestFirst(
        nearest, rankDetectedMatches(place, found));

    if (_detectMatches.isEmpty) {
      _detectFailure = LocationDetectFailure.noPlaceFound;
    }
    _isDetecting = false;
    notifyListeners();
  }

  /// [nearest] (the backend's GPS match) as the first suggestion, followed
  /// by the name-ranked ones without repeating it.
  @visibleForTesting
  static List<LocationSearchResult> withNearestFirst(
    LocationSearchResult? nearest,
    List<LocationSearchResult> ranked, {
    int limit = 6,
  }) {
    if (nearest == null) return ranked;
    String key(LocationSearchResult r) =>
        '${r.type.name}|${r.nameEn.toLowerCase()}|${r.district.toLowerCase()}';
    return [
      nearest,
      ...ranked.where((r) =>
          (nearest.id.isEmpty || r.id != nearest.id) && key(r) != key(nearest)),
    ].take(limit).toList();
  }

  /// Orders backend search results by how well they agree with what the
  /// device detected: same state, same district, same mandal, and the name
  /// itself. Wrong-state and wrong-district places sink or drop out, so the
  /// reader's own village comes first. At most [limit] are kept.
  @visibleForTesting
  static List<LocationSearchResult> rankDetectedMatches(
    DetectedPlace place,
    List<LocationSearchResult> results, {
    int limit = 6,
  }) {
    String norm(String v) =>
        v.toLowerCase().replaceAll(RegExp(r'[^a-zఀ-౿]'), '');
    final state = norm(place.state);
    final district = norm(place.district);
    final names = {
      for (final n in [
        ...place.names,
        place.village,
        place.subdistrict,
      ])
        if (norm(n).isNotEmpty) norm(n),
    };

    // A place below state level needs evidence of its own (its district,
    // mandal or name was detected); sharing the state is not enough.
    bool evidenced(LocationSearchResult r) {
      if (r.type == LocationLevel.state) return true;
      final name = norm(r.nameEn);
      final rDistrict =
          r.type == LocationLevel.district ? name : norm(r.district);
      return (district.isNotEmpty && rDistrict == district) ||
          names.contains(name) ||
          (r.type == LocationLevel.village &&
              names.contains(norm(r.subdistrict)));
    }

    int score(LocationSearchResult r) {
      final name = norm(r.nameEn);
      final rState = r.type == LocationLevel.state ? name : norm(r.state);
      final rDistrict =
          r.type == LocationLevel.district ? name : norm(r.district);
      final rMandal =
          r.type == LocationLevel.subdistrict ? name : norm(r.subdistrict);
      var s = 0;
      if (state.isNotEmpty && rState.isNotEmpty) {
        s += rState == state ? 1 : -6;
      }
      if (district.isNotEmpty && rDistrict.isNotEmpty) {
        s += rDistrict == district ? 4 : -3;
      }
      if (r.type == LocationLevel.village &&
          rMandal.isNotEmpty &&
          names.contains(rMandal)) {
        s += 3;
      }
      if (names.contains(name)) {
        s += 3 +
            switch (r.type) {
              LocationLevel.village => 2,
              LocationLevel.subdistrict => 1,
              _ => 0,
            };
      }
      return s;
    }

    final seen = <String>{};
    final unique = [
      for (final r in results)
        if (seen.add('${r.type.name}:${r.id}:${r.nameEn}')) r,
    ];
    final scored = [
      for (final r in unique) (r, score(r)),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    final good = scored
        .where((e) => e.$2 > 0 && evidenced(e.$1))
        .map((e) => e.$1)
        .toList();
    if (good.isNotEmpty) return good.take(limit).toList();
    // Nothing agrees with the detection: offer only a state, never a
    // same-named village elsewhere. No state → "not found", pick manually.
    return unique
        .where((r) =>
            r.type == LocationLevel.state &&
            (state.isEmpty || norm(r.nameEn) == state))
        .take(1)
        .toList();
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
    // Keep the API's Telugu name for the chosen place, so it can be shown
    // in Telugu wherever the app names the reader's location.
    LocationTranslations.learn(result.nameEn, result.nameTe);
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
        subdistrictId:
            result.type == LocationLevel.subdistrict ? result.id : null,
        villageId: result.type == LocationLevel.village ? result.id : null,
      );

      final patchData = <String, dynamic>{};
      if (result.type == LocationLevel.village) {
        patchData['village_id'] = result.id;
      }
      if (result.type == LocationLevel.subdistrict) {
        patchData['subdistrict_id'] = result.id;
      }
      if (result.type == LocationLevel.district) {
        patchData['district_id'] = result.id;
      }
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
    // The parents picked on the way down carry their Telugu names too.
    for (final parent in [_selectedState, _selectedDistrict, _selectedSubdistrict]) {
      if (parent != null) LocationTranslations.learn(parent.nameEn, parent.nameTe);
    }
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
