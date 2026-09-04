import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationException implements Exception {
  final String message;

  LocationException(this.message);

  @override
  String toString() => 'LocationException: $message';
}

class DeviceLocation {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final String city;
  final String district;
  final String state;
  final String country;
  final String source;
  final String? subdistrict;
  final String? village;

  DeviceLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.city,
    required this.district,
    required this.state,
    required this.country,
    required this.source,
    this.subdistrict,
    this.village,
  });
}

class LocationService {
  static const Duration _primaryTimeout = Duration(seconds: 12);
  static const Duration _secondaryTimeout = Duration(seconds: 10);
  static const double _acceptableAccuracyMeters = 100.0;

  static Future<DeviceLocation> detectLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationException('Location services are disabled. Please enable GPS.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationException('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationException('Permissions are permanently denied. Please enable them from settings.');
    }

    Position position = await _fetchPosition(LocationAccuracy.best, _primaryTimeout);
    if (position.accuracy.isFinite && position.accuracy > _acceptableAccuracyMeters) {
      final retry = await _fetchPosition(LocationAccuracy.high, _secondaryTimeout);
      if (retry.accuracy.isFinite && retry.accuracy < position.accuracy) {
        position = retry;
      }
    }

    String city = 'Local City';
    String district = 'Local Area';
    String state = 'Telangana';
    String country = 'India';
    String? subdistrict;
    String? village;

    try {
      final placemarks = await Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
        locale: const Locale('en'),
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final rawCity = place.locality?.trim();
        final rawDistrict = place.subAdministrativeArea?.trim();
        final rawState = place.administrativeArea?.trim();

        state = (rawState != null && rawState.isNotEmpty) ? rawState : 'Telangana';
        country = place.country ?? 'India';
        district = (rawDistrict != null && rawDistrict.isNotEmpty)
            ? rawDistrict
            : ((rawCity != null && rawCity.isNotEmpty) ? rawCity : 'Local Area');
        city = (rawCity != null && rawCity.isNotEmpty)
            ? rawCity
            : district;
        subdistrict = (place.subLocality != null && place.subLocality!.isNotEmpty)
            ? place.subLocality
            : district;
        village = (place.thoroughfare != null && place.thoroughfare!.isNotEmpty) ? place.thoroughfare : null;
      }
    } catch (_) {
      // Reverse geocoding failed or timed out — preserve real GPS coordinates
      city = 'GPS Location';
      district = 'Nearby';
    }

    return DeviceLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      city: city,
      district: district,
      state: state,
      country: country,
      source: 'gps',
      subdistrict: subdistrict,
      village: village,
    );
  }

  static Future<Position> _fetchPosition(LocationAccuracy accuracy, Duration timeout) async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeout,
        ),
      );
    } on TimeoutException {
      throw LocationException('Location request timed out. Please try again from an open sky view.');
    } catch (error) {
      rethrow;
    }
  }
}
