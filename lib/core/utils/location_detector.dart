import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';

/// Why a detection attempt could not produce a place.
enum LocationDetectFailure {
  /// The device has location switched off entirely.
  serviceDisabled,

  /// The reader said no. Recoverable — they can pick manually.
  permissionDenied,

  /// Denied with "don't ask again"; only Settings can undo it.
  permissionDeniedForever,

  /// A fix was obtained but reverse geocoding returned nothing usable.
  noPlaceFound,

  timeout,
  unknown,
}

/// A place read off the device, before it has been checked against the
/// backend's location database.
class DetectedPlace {
  const DetectedPlace({
    required this.state,
    required this.district,
    required this.subdistrict,
    required this.village,
    this.names = const [],
  });

  final String state;
  final String district;
  final String subdistrict;
  final String village;

  /// Every place name the geocoder offered, most specific first. Android
  /// returns several address candidates and spreads village, mandal and
  /// town names across different fields of different candidates, so all
  /// of them are matched against the backend, not just one field of one.
  final List<String> names;

  bool get isEmpty =>
      state.isEmpty &&
      district.isEmpty &&
      subdistrict.isEmpty &&
      village.isEmpty;

  /// Most specific name first — what to show the reader when confirming.
  String get displayName {
    for (final value in [village, subdistrict, district, state]) {
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  /// "Kesaram, Jajireddygudem, Suryapet" — the full trail, for confirmation.
  String get fullTrail => [village, subdistrict, district, state]
      .where((v) => v.isNotEmpty)
      .join(', ');
}

class LocationDetectResult {
  const LocationDetectResult.success(this.place,
      {this.latitude, this.longitude})
      : failure = null;
  const LocationDetectResult.failed(this.failure)
      : place = null,
        latitude = null,
        longitude = null;

  /// A GPS fix the geocoder could not name. The backend's nearest-village
  /// lookup can still place it.
  const LocationDetectResult.unnamed(
      {required double this.latitude, required double this.longitude})
      : place = null,
        failure = LocationDetectFailure.noPlaceFound;

  final DetectedPlace? place;
  final LocationDetectFailure? failure;
  final double? latitude;
  final double? longitude;

  bool get isSuccess => place != null && !place!.isEmpty;
}

/// Turns GPS coordinates into an Indian administrative place.
///
/// The backend's location endpoints are database lookups — they do not
/// reverse-geocode a latitude/longitude. So the device resolves coordinates
/// to names here, and those names are then confirmed against the backend
/// before anything is saved: a geocoder's spelling of a mandal will not
/// always match the one the feed filters on.
class LocationDetector {
  const LocationDetector();

  /// How long to wait for a fix before giving up. Rural GPS can be slow, but
  /// a first run that hangs is worse than one that offers manual selection.
  static const _fixTimeout = Duration(seconds: 15);
  static const _fallbackTimeout = Duration(seconds: 10);

  /// A real GPS fix. Medium accuracy on Android means mobile towers and
  /// Wi-Fi, which in a village can be kilometres off and named the wrong
  /// place. Medium is only the fallback when GPS gets no fix in time
  /// (indoors, under a roof).
  Future<Position> _fix() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _fixTimeout,
        ),
      );
    } on TimeoutException {
      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: _fallbackTimeout,
        ),
      );
    }
  }

  Future<LocationDetectResult> detect({bool requestPermission = true}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationDetectResult.failed(
        LocationDetectFailure.serviceDisabled,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestPermission) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationDetectResult.failed(
        LocationDetectFailure.permissionDeniedForever,
      );
    }
    if (permission == LocationPermission.denied) {
      return const LocationDetectResult.failed(
        LocationDetectFailure.permissionDenied,
      );
    }

    try {
      final position = await _fix();

      final lat = position.latitude, lng = position.longitude;
      List<geo.Placemark> marks;
      try {
        marks = await geo.Geocoding().placemarkFromCoordinates(lat, lng);
      } catch (_) {
        marks = const [];
      }
      final place = placeFromMarks(marks);
      if (place.isEmpty) {
        return LocationDetectResult.unnamed(latitude: lat, longitude: lng);
      }
      return LocationDetectResult.success(place,
          latitude: lat, longitude: lng);
    } on LocationServiceDisabledException {
      return const LocationDetectResult.failed(
        LocationDetectFailure.serviceDisabled,
      );
    } catch (error) {
      final isTimeout = error.toString().toLowerCase().contains('time');
      return LocationDetectResult.failed(
        isTimeout
            ? LocationDetectFailure.timeout
            : LocationDetectFailure.unknown,
      );
    }
  }

  /// Maps Android's placemarks onto the state/district/mandal/village
  /// hierarchy the feed uses.
  ///
  /// The mapping is deliberately loose: Android populates these
  /// inconsistently across Indian addresses — `subAdministrativeArea` is
  /// usually the district but is sometimes the mandal, and `locality` may be
  /// either the town or the village. That is exactly why the result is
  /// confirmed against the backend rather than trusted, and why every
  /// candidate's names are kept in [DetectedPlace.names].
  @visibleForTesting
  static DetectedPlace placeFromMarks(List<geo.Placemark> marks) {
    String first(String? Function(geo.Placemark m) field) {
      for (final m in marks) {
        final v = cleanName(field(m));
        if (v.isNotEmpty) return v;
      }
      return '';
    }

    final names = <String>[];
    final seen = <String>{};
    void add(String? raw) {
      final v = cleanName(raw);
      if (v.isEmpty || !_looksLikePlaceName(v)) return;
      if (seen.add(v.toLowerCase())) names.add(v);
    }

    // Most specific first, across all candidates.
    for (final m in marks) {
      add(m.subLocality);
    }
    for (final m in marks) {
      add(m.locality);
    }
    for (final m in marks) {
      add(m.name);
    }
    for (final m in marks) {
      add(m.subAdministrativeArea);
    }

    return DetectedPlace(
      state: first((m) => m.administrativeArea),
      district: first((m) => m.subAdministrativeArea),
      subdistrict: first((m) => m.locality),
      village: first((m) => m.subLocality),
      names: names,
    );
  }

  /// "Suryapet District" → "Suryapet". Geocoders append the level; the
  /// backend's names do not carry it.
  @visibleForTesting
  static String cleanName(String? value) => (value ?? '')
      .trim()
      .replaceAll(
          RegExp(r'\s+(district|mandal|division|taluk|tehsil)$',
              caseSensitive: false),
          '')
      .trim();

  /// Drops house numbers, plus codes ("7J4M+QX") and road names, which
  /// are not places.
  static bool _looksLikePlaceName(String v) =>
      !RegExp(r'[0-9+]').hasMatch(v) &&
      !RegExp(r'(road|rd|street|st|highway|nh)', caseSensitive: false)
          .hasMatch(v);
}
