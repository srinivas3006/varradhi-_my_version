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
  });

  final String state;
  final String district;
  final String subdistrict;
  final String village;

  bool get isEmpty =>
      state.isEmpty && district.isEmpty && subdistrict.isEmpty &&
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
  const LocationDetectResult.success(this.place)
      : failure = null,
        latitude = null,
        longitude = null;
  const LocationDetectResult.failed(this.failure)
      : place = null,
        latitude = null,
        longitude = null;

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
  static const _fixTimeout = Duration(seconds: 12);

  Future<LocationDetectResult> detect() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationDetectResult.failed(
        LocationDetectFailure.serviceDisabled,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
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
      // Medium accuracy is plenty to name a village and is much faster and
      // cheaper on battery than a high-accuracy fix.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: _fixTimeout,
        ),
      );

      final marks = await geo.Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (marks.isEmpty) {
        return const LocationDetectResult.failed(
          LocationDetectFailure.noPlaceFound,
        );
      }

      final place = _toPlace(marks.first);
      if (place.isEmpty) {
        return const LocationDetectResult.failed(
          LocationDetectFailure.noPlaceFound,
        );
      }
      return LocationDetectResult.success(place);
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

  /// Maps Android's placemark fields onto the state/district/mandal/village
  /// hierarchy the feed uses.
  ///
  /// The mapping is deliberately loose: Android populates these
  /// inconsistently across Indian addresses — `subAdministrativeArea` is
  /// usually the district but is sometimes the mandal, and `locality` may be
  /// either the town or the village. That is exactly why the result is
  /// confirmed against the backend rather than trusted.
  DetectedPlace _toPlace(geo.Placemark mark) {
    String clean(String? value) => (value ?? '').trim();

    return DetectedPlace(
      state: clean(mark.administrativeArea),
      district: clean(mark.subAdministrativeArea),
      subdistrict: clean(mark.locality),
      village: clean(mark.subLocality),
    );
  }
}
