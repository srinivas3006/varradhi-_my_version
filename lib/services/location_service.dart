import 'dart:async';
import 'package:flutter/material.dart';
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

class CanonicalLocationMatch {
  final DeviceLocation detected;
  final String state;
  final String district;
  final String subdistrict;
  final String village;
  final String? stateId;
  final String? districtId;
  final String? subdistrictId;
  final String? villageId;

  const CanonicalLocationMatch({
    required this.detected,
    required this.state,
    required this.district,
    required this.subdistrict,
    required this.village,
    this.stateId,
    this.districtId,
    this.subdistrictId,
    this.villageId,
  });

  bool get isVerified => state.isNotEmpty && stateId != null;

  String get displayName {
    if (village.isNotEmpty) return '$village, $subdistrict';
    if (subdistrict.isNotEmpty) return '$subdistrict, $district';
    if (district.isNotEmpty) return '$district, $state';
    return state;
  }

  DeviceLocation get canonicalDeviceLocation => DeviceLocation(
        latitude: detected.latitude,
        longitude: detected.longitude,
        accuracyMeters: detected.accuracyMeters,
        city: village.isNotEmpty
            ? village
            : (subdistrict.isNotEmpty ? subdistrict : district),
        district: district,
        state: state,
        country: detected.country,
        source: detected.source,
        subdistrict: subdistrict.isEmpty ? null : subdistrict,
        village: village.isEmpty ? null : village,
      );
}

class LocationService {
  static const Duration _primaryTimeout = Duration(seconds: 12);
  static const Duration _secondaryTimeout = Duration(seconds: 10);
  static const double _acceptableAccuracyMeters = 100.0;

  /// Shows a Google Play-compliant prominent disclosure sheet before requesting sensitive location permissions.
  static Future<bool> showPrivacyDisclosure(BuildContext context) async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      return true;
    }

    if (!context.mounted) return false;

    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).padding.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.location_on_rounded,
                        color: Theme.of(ctx).primaryColor, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'స్థాన సమాచార అనుమతి\n(Location Access)',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          height: 1.3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'మీ గ్రామం, మండలం మరియు జిల్లా వార్తలను అత్యంత వేగంగా, ఖచ్చితంగా అందించడానికి వార్ధికి మీ లొకేషన్ అనుమతి అవసరం.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Varadhi collects location data to provide hyper-local news and emergency alerts tailored to your village, mandal, and district even when the app is in use.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('రద్దు చేయండి'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(ctx).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('అనుమతించండి'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    return accepted == true;
  }

  static Future<bool> showCanonicalConfirmation(
    BuildContext context,
    CanonicalLocationMatch match,
  ) async {
    if (!context.mounted) return false;
    if (!match.isVerified) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('ప్రాంతం సరిపోలలేదు'),
          content: const Text(
            'మీ GPS స్థానం గుర్తించబడింది, కానీ మా డేటాబేస్‌లో సరిపోల్చలేకపోయాము. దయచేసి మీ ప్రాంతాన్ని మీరే ఎంచుకోండి.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('స్వయంగా ఎంచుకోండి'),
            ),
          ],
        ),
      );
      return false;
    }

    return await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          isDismissible: false,
          enableDrag: false,
          showDragHandle: true,
          useSafeArea: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (sheetContext) => SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(sheetContext)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.location_on_rounded,
                          color: Theme.of(sheetContext).colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'వార్తల ప్రాంతాన్ని నిర్ధారించండి',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    match.displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'వారధి లొకేషన్ రికార్డులతో ధృవీకరించబడింది. వార్తా విభాగాలు ఈ పేర్లతోనే ప్రదర్శించబడతాయి.',
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color:
                          Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext, false),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'సవరించండి',
                              maxLines: 1,
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: FilledButton.icon(
                          onPressed: () => Navigator.pop(sheetContext, true),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          icon: const Icon(Icons.check_rounded, size: 20),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'ఈ ప్రాంతాన్ని ఎంచుకోండి',
                              maxLines: 1,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;
  }

  static Future<DeviceLocation> detectLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationException(
          'లొకేషన్ సేవలు నిలిపివేయబడ్డాయి. దయచేసి GPS ఆన్ చేయండి.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationException('లొకేషన్ అనుమతులు నిరాకరించబడ్డాయి.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationException(
          'అనుమతులు శాశ్వతంగా నిరాకరించబడ్డాయి. దయచేసి సెట్టింగ్స్‌లో అనుమతించండి.');
    }

    Position position =
        await _fetchPosition(LocationAccuracy.best, _primaryTimeout);
    if (position.accuracy.isFinite &&
        position.accuracy > _acceptableAccuracyMeters) {
      final retry =
          await _fetchPosition(LocationAccuracy.high, _secondaryTimeout);
      if (retry.accuracy.isFinite && retry.accuracy < position.accuracy) {
        position = retry;
      }
    }

    String city = '';
    String district = '';
    String state = '';
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

        state = (rawState != null && rawState.isNotEmpty) ? rawState : '';
        country = place.country ?? 'India';
        district =
            (rawDistrict != null && rawDistrict.isNotEmpty) ? rawDistrict : '';
        city = (rawCity != null && rawCity.isNotEmpty) ? rawCity : district;
        // Android geocoders commonly expose a village or neighbourhood as
        // subLocality. A road/thoroughfare must never be treated as a village.
        village =
            (place.subLocality != null && place.subLocality!.trim().isNotEmpty)
                ? place.subLocality!.trim()
                : null;
        subdistrict = null;
      }
    } catch (_) {
      // Preserve coordinates, but do not invent feed location names.
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

  static Future<Position> _fetchPosition(
      LocationAccuracy accuracy, Duration timeout) async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeout,
        ),
      );
    } on TimeoutException {
      throw LocationException(
          'లొకేషన్ అభ్యర్థన సమయం ముగిసింది. దయచేసి మళ్లీ ప్రయత్నించండి.');
    } catch (error) {
      rethrow;
    }
  }
}
