import 'dart:async';
import '../repositories/ad_repository.dart';
import '../core/ads/ad_placement.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dio/dio.dart';
import '../models/api_response.dart';
import '../models/news_article.dart';
import '../models/live_news.dart';
import '../models/video_item.dart';
import '../models/category.dart';
import '../models/unified_feed_item.dart';
import '../models/ad_banner.dart';
import '../models/reporter_post.dart';
import '../models/poll.dart';
import '../models/app_notification.dart';
import 'dio_client.dart';
import 'location_service.dart';
import '../state/app_state.dart';
import '../core/utils/date_parser.dart';
import '../core/errors/app_exception.dart';

/// Outcome of an account-deletion attempt.
///
/// Only [deleted] means the server account is gone. Everything else leaves it
/// possibly intact, so the local session must survive for a retry.
enum AccountDeletionResult {
  deleted,
  unauthorized,
  networkFailure,
  serverError,
  unknown,
}

class ApiService {
  ApiService._internal();
  static final ApiService instance = ApiService._internal();

  final Dio _dio = DioClient().dio;

  static String get deviceType {
    if (kIsWeb) return 'web';
    return Platform.isIOS ? 'ios' : 'android';
  }

  // --- System Bootstrap & Guest Device ---
  Future<bool> checkHealth() async {
    try {
      final response = await _dio.get('/api/v1/health/');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // --- Auth ---
  Future<Map<String, dynamic>> login(String email, String password,
      {String? fcmToken}) async {
    var token = fcmToken ?? AppState.instance.fcmToken;

    // 1. Resolve FCM token if not yet cached in AppState
    if (token == null || token.isEmpty) {
      if (!kIsWeb) {
        try {
          token = await FirebaseMessaging.instance.getToken();
          if (token != null && token.isNotEmpty) {
            AppState.instance.fcmToken = token;
          }
        } catch (_) {}
      }
    }

    // 2. Recommended backend flow: If installation_secret is missing,
    // ensure guest registration is performed first so backend generates and returns installation_secret.
    if (AppState.instance.installationSecret == null ||
        AppState.instance.installationSecret!.isEmpty) {
      try {
        await registerGuestDevice(fcmToken: token);
      } catch (e) {
        debugPrint(
            '[ApiService] Pre-login guest registration attempt failed: $e');
      }
    }

    Map<String, dynamic> buildPayload() => {
          'email': email,
          'password': password,
          'device_id': AppState.instance.deviceId,
          'device_name': 'Mobile Device',
          'device_type': 'android',
          'app_version': '1.0.0',
          if (token != null && token.isNotEmpty) 'fcm_token': token,
          if (AppState.instance.installationSecret != null &&
              AppState.instance.installationSecret!.isNotEmpty)
            'installation_secret': AppState.instance.installationSecret,
        };

    try {
      final response =
          await _dio.post('/api/v1/auth/login/', data: buildPayload());
      final data = response.data['data'] as Map<String, dynamic>;
      if (data['installation_secret'] != null) {
        await AppState.instance
            .setInstallationSecret(data['installation_secret'].toString());
      }
      return data;
    } on DioException catch (dioErr) {
      final respStr = dioErr.response?.data?.toString() ?? '';
      final isInstallationError = dioErr.response?.statusCode == 403 ||
          respStr.toLowerCase().contains('installation');

      if (isInstallationError) {
        debugPrint(
            '[ApiService] 403 Installation credential required/mismatched. Regenerating device ID and re-registering guest device...');
        // The backend expects the installation_secret matching this device_id,
        // but this client lost or does not have that secret.
        // As per backend contract: Generate fresh device_id, register guest-device to obtain a new installation_secret, and retry login.
        await AppState.instance.regenerateDeviceId();
        await registerGuestDevice(fcmToken: token);

        final retryResponse =
            await _dio.post('/api/v1/auth/login/', data: buildPayload());
        final data = retryResponse.data['data'] as Map<String, dynamic>;
        if (data['installation_secret'] != null) {
          await AppState.instance
              .setInstallationSecret(data['installation_secret'].toString());
        }
        return data;
      }
      rethrow;
    }
  }

  /// 1. APK Guest Notification Flow: POST /api/v1/notifications/guest-device/
  Future<Map<String, dynamic>?> registerGuestDevice({
    String? deviceId,
    String? fcmToken,
    String? installationSecret,
  }) async {
    final devId = deviceId ?? AppState.instance.deviceId;
    var token = fcmToken ?? AppState.instance.fcmToken;
    final secret = installationSecret ?? AppState.instance.installationSecret;

    if (token == null || token.isEmpty) {
      if (!kIsWeb) {
        try {
          token = await FirebaseMessaging.instance.getToken();
          if (token != null && token.isNotEmpty) {
            AppState.instance.fcmToken = token;
          }
        } catch (_) {}
      }
    }

    if (token == null || token.isEmpty) return null;

    final lang = AppState.instance.language == 'English' ? 'en' : 'te';

    try {
      final response =
          await _dio.post('/api/v1/notifications/guest-device/', data: {
        'device_id': devId,
        'device_name': 'Mobile Device',
        'device_type': 'android',
        'app_version': '1.0.0',
        'fcm_token': token,
        if (secret != null && secret.isNotEmpty) 'installation_secret': secret,
        'state': AppState.instance.stateName,
        'district': AppState.instance.district,
        'subdistrict': AppState.instance.subdistrict,
        'village': AppState.instance.village,
        'country': AppState.instance.country,
        'preferences': {
          'enabled': true,
          'content_language': lang,
          'articles': true,
          'posters': true,
          'quotes': true,
          'ugc': true,
          'breaking_news': true,
          'local_news': true,
          'quiet_hours_start': '22:00:00',
          'quiet_hours_end': '06:00:00',
          'timezone': 'Asia/Kolkata',
          'max_per_hour': 5,
          'max_per_day': 25,
        },
      });

      final data = response.data['data'] as Map<String, dynamic>?;
      if (data != null && data['installation_secret'] != null) {
        await AppState.instance
            .setInstallationSecret(data['installation_secret'].toString());
      }
      return data;
    } on DioException catch (dioErr) {
      final respStr = dioErr.response?.data?.toString() ?? '';
      if (dioErr.response?.statusCode == 403 ||
          respStr.toLowerCase().contains('installation') ||
          respStr.toLowerCase().contains('upgrade')) {
        await AppState.instance.setInstallationSecret(null);
        try {
          final retryResp =
              await _dio.post('/api/v1/notifications/guest-device/', data: {
            'device_id': devId,
            'device_name': 'Mobile Device',
            'device_type': 'android',
            'app_version': '1.0.0',
            'fcm_token': token,
            'state': AppState.instance.stateName,
            'district': AppState.instance.district,
            'subdistrict': AppState.instance.subdistrict,
            'village': AppState.instance.village,
            'country': AppState.instance.country,
            'preferences': {
              'enabled': true,
              'content_language': lang,
              'articles': true,
              'posters': true,
              'quotes': true,
              'ugc': true,
              'breaking_news': true,
              'local_news': true,
              'quiet_hours_start': '22:00:00',
              'quiet_hours_end': '06:00:00',
              'timezone': 'Asia/Kolkata',
              'max_per_hour': 5,
              'max_per_day': 25,
            },
          });
          final data = retryResp.data['data'] as Map<String, dynamic>?;
          if (data != null && data['installation_secret'] != null) {
            await AppState.instance
                .setInstallationSecret(data['installation_secret'].toString());
          }
          return data;
        } catch (_) {}
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 2. APK Login Handoff Flow: POST /api/v1/notifications/device-token/
  Future<Map<String, dynamic>?> handoffDeviceToken({
    String? sessionId,
    String? fcmToken,
    String? installationSecret,
  }) async {
    final sessId = sessionId ?? AppState.instance.sessionId;
    final token = fcmToken ?? AppState.instance.fcmToken;
    final secret = installationSecret ?? AppState.instance.installationSecret;

    if (token == null || token.isEmpty) return null;

    try {
      final response =
          await _dio.post('/api/v1/notifications/device-token/', data: {
        if (sessId != null && sessId.isNotEmpty) 'session_id': sessId,
        'fcm_token': token,
        if (secret != null && secret.isNotEmpty) 'installation_secret': secret,
      });
      return response.data['data'] as Map<String, dynamic>?;
    } on DioException catch (dioErr) {
      if (dioErr.response?.statusCode == 403) {
        await registerGuestDevice(fcmToken: token);
        if (AppState.instance.isLoggedIn) {
          try {
            final retryResp =
                await _dio.post('/api/v1/notifications/device-token/', data: {
              if (sessId != null && sessId.isNotEmpty) 'session_id': sessId,
              'fcm_token': token,
              if (AppState.instance.installationSecret != null)
                'installation_secret': AppState.instance.installationSecret,
            });
            return retryResp.data['data'] as Map<String, dynamic>?;
          } catch (_) {}
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> updateFcmToken(String token) async {
    if (AppState.instance.isLoggedIn) {
      await handoffDeviceToken(fcmToken: token);
    } else {
      await registerGuestDevice(fcmToken: token);
    }
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    final response = await _dio.post('/api/v1/auth/register/', data: data);
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Initiates account deletion for Play Store compliance.
  ///
  /// Returns *why* it ended rather than a bool: the caller has to know
  /// whether the server account is gone before it destroys the local session,
  /// and "request failed" is not the same claim as "account still exists".
  /// Endpoints and their order are unchanged.
  Future<AccountDeletionResult> deleteAccount() async {
    AccountDeletionResult worst = AccountDeletionResult.unknown;

    // Keeps the most informative failure seen so far, so a network error on
    // the last attempt does not mask a 401 from an earlier one.
    void record(AccountDeletionResult r) {
      const rank = {
        AccountDeletionResult.unknown: 0,
        AccountDeletionResult.networkFailure: 1,
        AccountDeletionResult.serverError: 2,
        AccountDeletionResult.unauthorized: 3,
      };
      if ((rank[r] ?? 0) > (rank[worst] ?? 0)) worst = r;
    }

    Future<AccountDeletionResult?> attempt(
        Future<Response<dynamic>> Function() send) async {
      try {
        final response = await send();
        final code = response.statusCode ?? 0;
        if (code == 200 || code == 204) return AccountDeletionResult.deleted;
        record(_classifyStatus(code));
        return null;
      } on DioException catch (e) {
        final code = e.response?.statusCode;
        record(code != null
            ? _classifyStatus(code)
            : (_isNetworkError(e)
                ? AccountDeletionResult.networkFailure
                : AccountDeletionResult.unknown));
        return null;
      } catch (_) {
        record(AccountDeletionResult.unknown);
        return null;
      }
    }

    for (final endpoint in const [
      '/api/v1/auth/delete-account/',
      '/api/v1/auth/me/',
    ]) {
      final r = await attempt(() => _dio.delete(endpoint));
      if (r == AccountDeletionResult.deleted) {
        return AccountDeletionResult.deleted;
      }
    }

    final r = await attempt(() => _dio.post('/api/v1/auth/account/delete/'));
    return r ?? worst;
  }

  static AccountDeletionResult _classifyStatus(int code) {
    if (code == 401 || code == 403) return AccountDeletionResult.unauthorized;
    if (code >= 500) return AccountDeletionResult.serverError;
    return AccountDeletionResult.unknown;
  }

  static bool _isNetworkError(DioException e) =>
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.receiveTimeout;

  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    final response = await _dio.post('/api/v1/auth/token/refresh/', data: {
      'refresh': refreshToken,
      'device_id': AppState.instance.deviceId,
    });
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<void> logout(String refreshToken,
      {bool logoutAllDevices = false}) async {
    try {
      await _dio.post('/api/v1/auth/logout/', data: {
        'refresh': refreshToken,
        'logout_all_devices': logoutAllDevices,
      });
    } catch (e) {
      // Silently fail logout if network is unreachable
    }
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await _dio.get('/api/v1/auth/me/');
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final response = await _dio.patch('/api/v1/auth/me/', data: data);
    return response.data['data'] as Map<String, dynamic>;
  }

  // --- Passwords ---
  Future<void> changePassword(
      String currentPassword, String newPassword) async {
    await _dio.post('/api/v1/auth/password/change/', data: {
      'current_password': currentPassword,
      'new_password': newPassword,
      'new_password_confirm': newPassword,
    });
  }

  Future<void> requestPasswordReset(String email) async {
    await _dio
        .post('/api/v1/auth/password/reset/request/', data: {'email': email});
  }

  Future<void> verifyPasswordReset(String email, String token) async {
    await _dio.post('/api/v1/auth/password/reset/verify/', data: {
      'email': email,
      'token': token,
    });
  }

  Future<void> confirmPasswordReset(
      String email, String token, String newPassword) async {
    await _dio.post('/api/v1/auth/password/reset/confirm/', data: {
      'email': email,
      'token': token,
      'new_password': newPassword,
      'new_password_confirm': newPassword,
    });
  }

  // --- Device Sessions ---
  Future<List<dynamic>> getDeviceSessions() async {
    final response = await _dio.get('/api/v1/auth/sessions/');
    return response.data['data'] as List<dynamic>? ?? [];
  }

  Future<void> revokeDeviceSession(String sessionId) async {
    await _dio.delete('/api/v1/auth/sessions/$sessionId/');
  }

  // --- Location & Preferences ---
  /// Syncs user location with backend if logged in.
  /// If the user is a guest, POST /api/v1/user/location/ MUST NOT be called.
  Future<void> updateUserLocation(Map<String, dynamic> locationData) async {
    if (!AppState.instance.isLoggedIn ||
        AppState.instance.authToken == null ||
        AppState.instance.authToken!.isEmpty) {
      debugPrint('Guest mode: Skipping POST /api/v1/user/location/');
      return;
    }
    await _dio.post('/api/v1/user/location/', data: locationData);
  }

  Future<void> updateUserLocationDevice(DeviceLocation location) async {
    if (!AppState.instance.isLoggedIn ||
        AppState.instance.authToken == null ||
        AppState.instance.authToken!.isEmpty) {
      debugPrint('Guest mode: Skipping POST /api/v1/user/location/');
      return;
    }
    await updateUserLocation({
      'lat': location.latitude,
      'lon': location.longitude,
      'city': location.city,
      'district': location.district,
      'subdistrict': location.subdistrict ?? location.district,
      'village': location.village ?? '',
      'state': location.state,
      'country': location.country,
      'location_source': location.source,
      'accuracy_meters': location.accuracyMeters,
    });
  }

  /// Helper to sync current AppState location to backend for logged-in users.
  Future<void> syncUserLocation() async {
    if (!AppState.instance.isLoggedIn ||
        AppState.instance.authToken == null ||
        AppState.instance.authToken!.isEmpty) {
      debugPrint('Guest mode: Skipping syncUserLocation');
      return;
    }
    try {
      await updateUserLocation({
        'lat': AppState.instance.latitude,
        'lon': AppState.instance.longitude,
        'city': AppState.instance.city,
        'district': AppState.instance.district,
        'subdistrict': AppState.instance.subdistrict,
        'village': AppState.instance.village,
        'state': AppState.instance.stateName,
        'country': AppState.instance.country,
        'location_source': 'gps',
      });
    } catch (e) {
      debugPrint('Failed to sync location to server: $e');
    }
  }

  Future<CanonicalLocationMatch> resolveCanonicalLocation(
    DeviceLocation location,
  ) async {
    final queryTerms = <String>{
      if (location.village?.trim().isNotEmpty == true) location.village!.trim(),
      if (location.subdistrict?.trim().isNotEmpty == true)
        location.subdistrict!.trim(),
      if (location.city.trim().isNotEmpty) location.city.trim(),
      if (location.district.trim().isNotEmpty) location.district.trim(),
    };

    final searchGroups = await Future.wait(
      queryTerms.map(searchLocations),
    );
    final searchItems = searchGroups
        .expand((items) => items)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final searchMatch = _bestCanonicalSearchMatch(
      searchItems,
      queryTerms,
      location,
    );

    final requestedState = _canonicalField(searchMatch, 'state').isNotEmpty
        ? _canonicalField(searchMatch, 'state')
        : location.state;
    final states = await getStates();
    final stateItem = _findCanonicalItem(states, requestedState);
    if (stateItem == null) {
      return CanonicalLocationMatch(
        detected: location,
        state: '',
        district: '',
        subdistrict: '',
        village: '',
      );
    }

    final state = _canonicalName(stateItem);
    final requestedDistrict =
        _canonicalField(searchMatch, 'district').isNotEmpty
            ? _canonicalField(searchMatch, 'district')
            : location.district;
    final districts = await getDistricts(state);
    final districtItem = _findCanonicalItem(districts, requestedDistrict);
    final district = districtItem == null ? '' : _canonicalName(districtItem);

    final requestedSubdistrict = _canonicalField(searchMatch, 'subdistrict');
    Map<String, dynamic>? subdistrictItem;
    if (district.isNotEmpty && requestedSubdistrict.isNotEmpty) {
      final subdistricts = await getSubdistricts(district, state: state);
      subdistrictItem = _findCanonicalItem(subdistricts, requestedSubdistrict);
    }
    final subdistrict =
        subdistrictItem == null ? '' : _canonicalName(subdistrictItem);

    final requestedVillage =
        searchMatch?['type']?.toString().trim().toLowerCase() == 'village'
            ? _canonicalName(searchMatch!)
            : '';
    Map<String, dynamic>? villageItem;
    if (subdistrict.isNotEmpty && requestedVillage.isNotEmpty) {
      final villages = await getVillages(
        subdistrict,
        state: state,
        district: district,
      );
      villageItem = _findCanonicalItem(villages, requestedVillage);
    }

    return CanonicalLocationMatch(
      detected: location,
      state: state,
      district: district,
      subdistrict: subdistrict,
      village: villageItem == null ? '' : _canonicalName(villageItem),
      stateId: stateItem['id']?.toString(),
      districtId: districtItem?['id']?.toString(),
      subdistrictId: subdistrictItem?['id']?.toString(),
      villageId: villageItem?['id']?.toString(),
    );
  }

  Future<void> applyCanonicalLocation(CanonicalLocationMatch match) async {
    if (!match.isVerified) {
      throw LocationException(
        'We could not match this GPS result to the location database. Please select your location manually.',
      );
    }

    final location = match.canonicalDeviceLocation;
    AppState.instance.setDeviceLocation(
      location,
      stateId: match.stateId,
      districtId: match.districtId,
      subdistrictId: match.subdistrictId,
      villageId: match.villageId,
    );

    if (AppState.instance.isLoggedIn &&
        AppState.instance.authToken?.isNotEmpty == true) {
      updateUserLocationDevice(location).catchError((error) {
        debugPrint('Failed to send GPS telemetry: $error');
      });
    }

    final patchData = <String, dynamic>{};
    if (match.villageId != null) patchData['village_id'] = match.villageId;
    if (match.subdistrictId != null) {
      patchData['subdistrict_id'] = match.subdistrictId;
    }
    if (match.districtId != null) patchData['district_id'] = match.districtId;
    if (match.stateId != null) patchData['state_id'] = match.stateId;

    if (patchData.isNotEmpty) {
      try {
        await updateLocationProfile(patchData);
      } catch (e) {
        debugPrint('Failed to patch canonical location profile: $e');
      }
    }
  }

  Future<void> resolveAndSyncCanonicalLocation(DeviceLocation location) async {
    final match = await resolveCanonicalLocation(location);
    await applyCanonicalLocation(match);
  }

  String _canonicalName(Map<String, dynamic> item) {
    return (item['name_en'] ?? item['name'] ?? '').toString().trim();
  }

  String _canonicalField(Map<String, dynamic>? item, String field) {
    return item?[field]?.toString().trim() ?? '';
  }

  String _normaliseLocationName(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\b(state|district|mandal)\b'), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  Map<String, dynamic>? _findCanonicalItem(
    List<dynamic> items,
    String requestedName,
  ) {
    final requested = _normaliseLocationName(requestedName);
    if (requested.isEmpty) return null;
    for (final rawItem in items) {
      if (rawItem is! Map) continue;
      final item = Map<String, dynamic>.from(rawItem);
      if (_normaliseLocationName(_canonicalName(item)) == requested)
        return item;
    }
    return null;
  }

  Map<String, dynamic>? _bestCanonicalSearchMatch(
    List<Map<String, dynamic>> items,
    Set<String> queryTerms,
    DeviceLocation location,
  ) {
    final normalisedTerms = queryTerms.map(_normaliseLocationName).toSet();
    final expectedState = _normaliseLocationName(location.state);
    final expectedDistrict = _normaliseLocationName(location.district);
    Map<String, dynamic>? best;
    var bestScore = -1;
    var isAmbiguous = false;

    for (final item in items) {
      if (!normalisedTerms
          .contains(_normaliseLocationName(_canonicalName(item)))) {
        continue;
      }
      final itemState = _normaliseLocationName(_canonicalField(item, 'state'));
      if (expectedState.isNotEmpty &&
          itemState.isNotEmpty &&
          itemState != expectedState) {
        continue;
      }

      final type = item['type']?.toString().toLowerCase() ?? '';
      var score = const {
            'village': 40,
            'subdistrict': 30,
            'district': 20,
            'state': 10,
          }[type] ??
          0;
      if (itemState == expectedState && itemState.isNotEmpty) score += 20;
      final itemDistrict =
          _normaliseLocationName(_canonicalField(item, 'district'));
      if (itemDistrict == expectedDistrict && itemDistrict.isNotEmpty)
        score += 20;
      if (score > bestScore) {
        best = item;
        bestScore = score;
        isAmbiguous = false;
      } else if (score == bestScore &&
          best?['id']?.toString() != item['id']?.toString()) {
        isAmbiguous = true;
      }
    }
    return isAmbiguous ? null : best;
  }

  // --- Canonical Locations (States / Districts / Subdistricts / Villages / Search) ---
  Future<List<dynamic>> searchLocations(String query) async {
    try {
      final response =
          await _dio.get('/api/v1/locations/search/', queryParameters: {
        'q': query,
        'limit': 50,
      });
      return (response.data['data'] as List?) ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> getStates() async {
    try {
      final response =
          await _dio.get('/api/v1/locations/states/', queryParameters: {
        'page_size': 100,
      });
      return (response.data['data'] as List?) ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> getDistricts(String state) async {
    try {
      final response =
          await _dio.get('/api/v1/locations/districts/', queryParameters: {
        'state': state,
        'page_size': 100,
      });
      return (response.data['data'] as List?) ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> getSubdistricts(String district,
      {String? state}) async {
    try {
      final response =
          await _dio.get('/api/v1/locations/subdistricts/', queryParameters: {
        if (state != null && state.isNotEmpty) 'state': state,
        'district': district,
        'page_size': 100,
      });
      return (response.data['data'] as List?) ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> getVillages(
    String subdistrict, {
    String? state,
    String? district,
  }) async {
    try {
      final response =
          await _dio.get('/api/v1/locations/villages/', queryParameters: {
        if (state != null && state.isNotEmpty) 'state': state,
        if (district != null && district.isNotEmpty) 'district': district,
        'subdistrict': subdistrict,
        'page_size': 100,
      });
      return (response.data['data'] as List?) ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getLocationProfile() async {
    try {
      final endpoint = AppState.instance.isLoggedIn
          ? '/api/v1/auth/locations/profile/'
          : '/api/v1/auth/locations/guest/';
      final response = await _dio.get(endpoint);
      return response.data['data'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateLocationProfile(Map<String, dynamic> data) async {
    try {
      final endpoint = AppState.instance.isLoggedIn
          ? '/api/v1/auth/locations/profile/'
          : '/api/v1/auth/locations/guest/';
      final response = await _dio.patch(endpoint, data: data);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> updateCategoryPreferences(
      Map<String, double> categoryWeights) async {
    final response = await _dio.patch('/api/v1/users/me/preferences/',
        data: {'category_weights': categoryWeights});
    return response.data['data'] as Map<String, dynamic>;
  }

  // --- Feeds ---
  Future<NewsArticle> getArticleDetail(String slug) async {
    final response = await _dio.get('/api/v1/articles/$slug/');
    final payload = response.data is Map
        ? ((response.data as Map<String, dynamic>)['data'] ?? response.data)
        : response.data;

    if (payload is! Map<String, dynamic>) {
      throw Exception('Unexpected detail payload format for article $slug');
    }

    return NewsArticle.fromJson(payload);
  }

  Future<List<NewsArticle>> getFeaturedArticles({String? lang}) async {
    final response =
        await _dio.get('/api/v1/articles/featured/', queryParameters: {
      if (lang != null) 'lang': lang,
    });
    return (response.data['data'] as List)
        .map((i) => NewsArticle.fromJson(i))
        .toList();
  }

  Future<List<NewsArticle>> getRecommendations({
    int? limit,
    String? lang,
    String? state,
    String? district,
    String? city,
    String? village,
    String? subdistrict,
    String? category,
  }) async {
    final response =
        await _dio.get('/api/v1/articles/recommendations/', queryParameters: {
      if (limit != null) 'limit': limit,
      if (lang != null) 'lang': lang,
      if (state != null) 'state': state,
      if (district != null) 'district': district,
      if (city != null) 'city': city,
      if (village != null) 'village': village,
      if (subdistrict != null) 'subdistrict': subdistrict,
      if (category != null) 'category': category,
    });
    return (response.data['data'] as List)
        .map((i) => NewsArticle.fromJson(i))
        .toList();
  }

  // --- Recommendation Tracking ---
  Future<void> trackArticleImpression(
      String articleId, String sessionId) async {
    try {
      await _dio.post('/api/v1/articles/recommendation/impression/', data: {
        'article_id': articleId,
        'session_id': sessionId,
      });
    } catch (_) {
      // Fail silently to avoid interrupting user experience
    }
  }

  Future<void> trackArticleClick(String articleId, String sessionId) async {
    try {
      await _dio.post('/api/v1/articles/recommendation/click/', data: {
        'article_id': articleId,
        'session_id': sessionId,
      });
    } catch (_) {
      // Fail silently
    }
  }

  Future<void> trackArticleDwell(
      String articleId, String sessionId, int seconds) async {
    try {
      await _dio.post('/api/v1/articles/recommendation/dwell/', data: {
        'article_id': articleId,
        'session_id': sessionId,
        'seconds': seconds,
      });
    } catch (_) {
      // Fail silently
    }
  }

  /// Set or remove a like/dislike reaction for an article.
  /// Backend contract:
  /// PUT /api/v1/articles/{article_id}/reaction/ with {"reaction_type": "like" | "dislike"}
  /// DELETE /api/v1/articles/{article_id}/reaction/ when reaction is 'none' or empty
  Future<Map<String, dynamic>> postArticleReaction(
      String articleId, Object reaction) async {
    final String r =
        (reaction is String ? reaction : reaction.toString().split('.').last)
            .toLowerCase();
    if (r == 'none' || r.isEmpty) {
      return deleteArticleReaction(articleId);
    }
    final response =
        await _dio.put('/api/v1/articles/$articleId/reaction/', data: {
      'reaction_type': r,
    });
    if (response.data is Map) {
      final map = response.data as Map;
      if (map['data'] is Map<String, dynamic>) {
        return map['data'] as Map<String, dynamic>;
      }
      return Map<String, dynamic>.from(map);
    }
    return <String, dynamic>{};
  }

  /// Remove reaction via DELETE /api/v1/articles/{article_id}/reaction/
  Future<Map<String, dynamic>> deleteArticleReaction(String articleId) async {
    final response = await _dio.delete('/api/v1/articles/$articleId/reaction/');
    if (response.data is Map) {
      final map = response.data as Map;
      if (map['data'] is Map<String, dynamic>) {
        return map['data'] as Map<String, dynamic>;
      }
      return Map<String, dynamic>.from(map);
    }
    return <String, dynamic>{};
  }

  // --- Comments ---
  Future<List<Comment>> getComments(String articleId,
      {String? cursor, int pageSize = 20}) async {
    try {
      final response = await _dio
          .get('/api/v1/articles/$articleId/comments/', queryParameters: {
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'page_size': pageSize,
      });
      final List data = response.data['data'] as List? ?? [];
      return data
          .map((json) => Comment.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Failed to fetch comments for article $articleId: $e');
      return [];
    }
  }

  Future<Comment> postComment(String articleId, String content,
      {String? parentId}) async {
    final response =
        await _dio.post('/api/v1/articles/$articleId/comments/', data: {
      'content': content,
      if (parentId != null && parentId.isNotEmpty) 'parent_id': parentId,
    });
    return Comment.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Comment> editComment(String commentId, String content) async {
    final response =
        await _dio.patch('/api/v1/articles/comments/$commentId/', data: {
      'content': content,
    });
    return Comment.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<bool> deleteComment(String commentId) async {
    final response = await _dio.delete('/api/v1/articles/comments/$commentId/');
    return response.statusCode == 200 || response.statusCode == 204;
  }

  Future<bool> reportComment(String commentId,
      {required String reason, String? notes}) async {
    final response =
        await _dio.post('/api/v1/articles/comments/$commentId/report/', data: {
      'reason': reason,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return response.statusCode == 200 || response.statusCode == 201;
  }

  // --- Feeds ---
  Future<ApiResponse<List<UnifiedFeedItem>>> getUnifiedFeed({
    String? cursor,
    int? pageSize,
    String? include,
    String? lang,
    String? category,
    String? state,
    String? district,
    String? city,
    String? subdistrict,
    String? village,
  }) async {
    final response = await _dio.get('/api/v1/feed/', queryParameters: {
      if (cursor != null) 'cursor': cursor,
      if (pageSize != null) 'page_size': pageSize,
      if (include != null) 'include': include,
      if (lang != null) 'lang': lang,
      if (category != null) 'category': category,
      if (state != null) 'state': state,
      if (district != null) 'district': district,
      if (city != null) 'city': city,
      if (subdistrict != null) 'subdistrict': subdistrict,
      if (village != null) 'village': village,
    });
    return ApiResponse<List<UnifiedFeedItem>>.fromJson(response.data, (json) {
      if (json is List) {
        return json.map((i) => UnifiedFeedItem.fromJson(i)).toList();
      }
      return <UnifiedFeedItem>[];
    });
  }

  Future<List<LiveNews>> getLiveNews() async {
    try {
      final response = await _dio.get('/api/v1/articles/live/');
      final List data = response.data['data'] as List? ?? [];
      return data
          .map((i) => LiveNews.fromJson(i as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // In-memory feed cache for zero-latency instant article responses
  final Map<String, ApiResponse<List<NewsArticle>>> _feedCache = {};

  void clearFeedCache() {
    _feedCache.clear();
  }

  Future<ApiResponse<List<NewsArticle>>> getNewsFeed({
    String? cursor,
    int? pageSize,
    String? scope,
    String? lang,
    String? category,
    bool? breaking,
    String? state,
    String? district,
    String? city,
    String? subdistrict,
    String? village,
    double? latitude,
    double? longitude,
    bool forceRefresh = false,
  }) async {
    // Generate cache key for initial page
    final isInitial = cursor == null || cursor.isEmpty;
    final cacheKey = [
      scope,
      category,
      lang,
      breaking,
      state,
      district,
      city,
      subdistrict,
      village,
      pageSize,
    ].map((e) => e?.toString() ?? '').join('|');

    // Fast-path: Return cached feed immediately on initial page
    if (isInitial && !forceRefresh && _feedCache.containsKey(cacheKey)) {
      // Fire-and-forget background revalidation
      _fetchFeedFromNetwork(
        cursor: cursor,
        pageSize: pageSize,
        scope: scope,
        lang: lang,
        category: category,
        breaking: breaking,
        state: state,
        district: district,
        city: city,
        subdistrict: subdistrict,
        village: village,
        latitude: latitude,
        longitude: longitude,
      ).then((fresh) {
        _feedCache[cacheKey] = fresh;
      }).catchError((_) {});

      return _feedCache[cacheKey]!;
    }

    final freshResponse = await _fetchFeedFromNetwork(
      cursor: cursor,
      pageSize: pageSize,
      scope: scope,
      lang: lang,
      category: category,
      breaking: breaking,
      state: state,
      district: district,
      city: city,
      subdistrict: subdistrict,
      village: village,
      latitude: latitude,
      longitude: longitude,
    );

    if (isInitial && (freshResponse.data?.isNotEmpty ?? false)) {
      _feedCache[cacheKey] = freshResponse;
    }

    return freshResponse;
  }

  Future<ApiResponse<List<NewsArticle>>> _fetchFeedFromNetwork({
    String? cursor,
    int? pageSize,
    String? scope,
    String? lang,
    String? category,
    bool? breaking,
    String? state,
    String? district,
    String? city,
    String? subdistrict,
    String? village,
    double? latitude,
    double? longitude,
  }) async {
    // Default to a fat response of 25 articles per page for rapid browsing
    //
    // No `?? 'te'`: null must stay null all the way to the query string.
    // Defaulting here is what made every fresh install request Telugu-only
    // and hide English articles before the reader had chosen anything.
    final effectiveLang = lang;
    final effectiveState = state != null
        ? (state.isNotEmpty ? state : null)
        : (scope == 'local' ? AppState.instance.stateName : null);
    final effectiveDistrict = district != null
        ? (district.isNotEmpty ? district : null)
        : (scope == 'local' ? AppState.instance.district : null);
    final effectiveCity = city != null
        ? (city.isNotEmpty ? city : null)
        : (scope == 'local' ? AppState.instance.city : null);
    final effectiveSubdistrict = subdistrict != null
        ? (subdistrict.isNotEmpty ? subdistrict : null)
        : (scope == 'local' && AppState.instance.subdistrict.isNotEmpty
            ? AppState.instance.subdistrict
            : null);
    final effectiveVillage = village != null
        ? (village.isNotEmpty ? village : null)
        : (scope == 'local' && AppState.instance.village.isNotEmpty
            ? AppState.instance.village
            : null);
    final effectivePageSize = pageSize ?? 25;

    final response = await _dio.get('/api/v1/articles/feed/', queryParameters: {
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      'page_size': effectivePageSize,
      if (scope != null && scope.isNotEmpty) 'scope': scope,
      // Omitted entirely when null: no lang means all languages, which is
      // what a reader who has not chosen one should get.
      if (effectiveLang != null && effectiveLang.isNotEmpty)
        'lang': effectiveLang,
      if (category != null && category != 'For You' && category != 'Trending')
        'category': category.toLowerCase(),
      if (breaking != null) 'breaking': breaking,
      if (effectiveState != null && effectiveState.isNotEmpty)
        'state': effectiveState,
      if (effectiveDistrict != null && effectiveDistrict.isNotEmpty)
        'district': effectiveDistrict,
      if (effectiveCity != null && effectiveCity.isNotEmpty)
        'city': effectiveCity,
      if (effectiveSubdistrict != null && effectiveSubdistrict.isNotEmpty)
        'subdistrict': effectiveSubdistrict,
      if (effectiveVillage != null && effectiveVillage.isNotEmpty)
        'village': effectiveVillage,
      if (latitude != null) ...{
        'latitude': latitude,
        'lat': latitude,
      },
      if (longitude != null) ...{
        'longitude': longitude,
        'lng': longitude,
        'lon': longitude,
      },
    });
    final parsed =
        ApiResponse<List<NewsArticle>>.fromJson(response.data, (json) {
      if (json is List) {
        return json.map((i) => NewsArticle.fromJson(i)).toList();
      }
      return <NewsArticle>[];
    });

    return parsed;
  }

  Future<ApiResponse<List<NewsArticle>>> getBlogsFeed({String? cursor}) async {
    final response =
        await _dio.get('/api/v1/articles/blogs/', queryParameters: {
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    });
    return ApiResponse<List<NewsArticle>>.fromJson(response.data, (json) {
      if (json is List) {
        return json.map((i) => NewsArticle.fromJson(i)).toList();
      }
      return <NewsArticle>[];
    });
  }

  // --- TTS (Text to Speech) ---
  Future<Map<String, dynamic>> generateTTS({
    required String content,
    required String language,
    required String objectType,
    required String objectId,
    bool forceRegenerate = false,
  }) async {
    final response = await _dio.post('/api/v1/articles/tts/', data: {
      'content': content,
      'language': language,
      'object_type': objectType,
      'object_id': objectId,
      'force_regenerate': forceRegenerate,
    });
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTTSStatus(String taskId) async {
    final response = await _dio.get('/api/v1/articles/tts/status/$taskId/');
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<ApiResponse<List<VideoItem>>> getVideoFeed({
    String? cursor,
    int? pageSize,
    String? lang,
    String? scope,
    String? state,
    String? district,
    String? city,
    String? subdistrict,
    String? village,
  }) async {
    final response =
        await _dio.get('/api/v1/articles/video-feed/', queryParameters: {
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      if (pageSize != null) 'page_size': pageSize,
      if (lang != null) 'lang': lang,
      if (scope != null) 'scope': scope,
      if (state != null) 'state': state,
      if (district != null) 'district': district,
      if (city != null) 'city': city,
      if (subdistrict != null) 'subdistrict': subdistrict,
      if (village != null) 'village': village,
    });
    return ApiResponse<List<VideoItem>>.fromJson(response.data, (json) {
      if (json is List) {
        return json.map((i) => VideoItem.fromJson(i)).toList();
      }
      return <VideoItem>[];
    });
  }

  Future<ApiResponse<List<VideoItem>>> getShortsFeed({
    String? cursor,
    int? pageSize,
    String? lang,
    String? scope,
    String? state,
    String? district,
    String? city,
    String? subdistrict,
    String? village,
  }) async {
    final response =
        await _dio.get('/api/v1/articles/shorts-feed/', queryParameters: {
      if (cursor != null) 'cursor': cursor,
      if (pageSize != null) 'page_size': pageSize,
      if (lang != null) 'lang': lang,
      if (scope != null) 'scope': scope,
      if (state != null) 'state': state,
      if (district != null) 'district': district,
      if (city != null) 'city': city,
      if (subdistrict != null) 'subdistrict': subdistrict,
      if (village != null) 'village': village,
    });
    return ApiResponse<List<VideoItem>>.fromJson(response.data, (json) {
      if (json is List) {
        return json.map((i) => VideoItem.fromJson(i)).toList();
      }
      return <VideoItem>[];
    });
  }

  Future<ApiResponse<List<AdBanner>>> getAds({
    String? zone,
    String? scope,
    String? state,
    String? district,
    String? city,
    String? lang,
    String? areaId,
  }) async {
    return AdRepository.instance.getAds(
      placementZone: zone ?? 'feed',
      scope: scope,
      state: state,
      district: district,
      city: city,
      lang: lang,
      areaId: areaId,
    );
  }

  Future<void> trackAdEvent(String adId, String eventType,
      {String placementZone = 'feed'}) async {
    try {
      await _dio.post('/api/v1/ads/event/', data: {
        'ad_id': adId,
        'event_type': eventType,
        'placement_zone': AdPlacement.canonical(placementZone),
      });
    } catch (e) {
      // Silently fail for analytics tracking
    }
  }

  Future<ApiResponse<List<NewsArticle>>> searchArticles(
    String query, {
    String? lang,
    String? category,
  }) async {
    try {
      final response = await _dio.get('/api/v1/search/', queryParameters: {
        'q': query,
        if (lang != null) 'lang': lang,
        if (category != null) 'category': category,
      });
      // Search API wraps items in data['results'] instead of directly in data.
      return ApiResponse<List<NewsArticle>>.fromJson(response.data, (json) {
        if (json is Map<String, dynamic> && json['results'] is List) {
          return (json['results'] as List)
              .map((i) => NewsArticle.fromJson(i))
              .toList();
        } else if (json is List) {
          return json.map((i) => NewsArticle.fromJson(i)).toList();
        }
        return <NewsArticle>[];
      });
    } catch (e) {
      return ApiResponse.error(
        message: e is AppException ? e.message : e.toString(),
        fallbackData: <NewsArticle>[],
      );
    }
  }

  Future<List<String>> getTrendingSearches() async {
    try {
      final response = await _dio.get('/api/v1/search/trending/');
      return (response.data['data'] as List).map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> getZeroResultsSearches() async {
    try {
      final response = await _dio.get('/api/v1/search/zero-results/');
      return (response.data['data'] as List).map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  // --- Categories ---
  Future<List<Category>> getCategories() async {
    try {
      final response = await _dio.get('/api/v1/categories/');
      return (response.data['data'] as List)
          .map((i) => Category.fromJson(i))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Category> createCategory(Map<String, dynamic> data) async {
    final response = await _dio.post('/api/v1/categories/admin/', data: data);
    return Category.fromJson(response.data['data']);
  }

  Future<Category> updateCategory(
      String slug, Map<String, dynamic> data) async {
    final response =
        await _dio.patch('/api/v1/categories/admin/$slug/', data: data);
    return Category.fromJson(response.data['data']);
  }

  Future<void> deleteCategory(String slug) async {
    await _dio.delete('/api/v1/categories/admin/$slug/');
  }

  // --- Bookmarks ---
  Future<List<NewsArticle>> getBookmarks() async {
    final articles = <NewsArticle>[];
    final seen = <String>{};
    final visited = <String>{};
    String? cursor;
    do {
      final response = await _dio.get('/api/v1/bookmarks/', queryParameters: {
        'page_size': 20,
        if (cursor != null) 'cursor': cursor,
      });
      final parsed =
          ApiResponse<List<NewsArticle>>.fromJson(response.data, (json) {
        return (json as List? ?? []).map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          final nested = map['article'];
          return NewsArticle.fromJson(
              nested is Map<String, dynamic> ? nested : map);
        }).toList();
      });
      if (parsed.hasErrors) {
        throw ApiException(
            parsed.errorMessage ?? 'Unable to load saved articles.');
      }
      articles
          .addAll((parsed.data ?? []).where((article) => seen.add(article.id)));
      cursor = parsed.nextCursor;
    } while (cursor != null && cursor.isNotEmpty && visited.add(cursor));
    return articles;
  }

  Future<void> addBookmark(String articleId) async {
    await _dio.post('/api/v1/bookmarks/', data: {'article_id': articleId});
  }

  Future<bool> toggleBookmark(String articleId) async {
    final response = await _dio
        .post('/api/v1/bookmarks/toggle/', data: {'article_id': articleId});
    return response.statusCode == 200 || response.statusCode == 201;
  }

  Future<void> removeBookmark(String bookmarkId) async {
    await _dio.delete('/api/v1/bookmarks/$bookmarkId/');
  }

  // --- Contributor / Reporter ---
  Future<Map<String, dynamic>> createArticle(Map<String, dynamic> data,
      {String? thumbnailPath}) async {
    dynamic requestData;

    if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
      // Use Multipart FormData if there's a file upload
      final formDataMap = Map<String, dynamic>.from(data);
      formDataMap['thumbnail_upload'] =
          await MultipartFile.fromFile(thumbnailPath);
      requestData = FormData.fromMap(formDataMap);
    } else {
      // Standard JSON
      requestData = data;
    }

    final response = await _dio.post('/api/v1/articles/', data: requestData);
    return response.data['data'] as Map<String, dynamic>;
  }

  // --- UGC Creation ---
  Future<bool> sendOtp(String phone) async {
    final response =
        await _dio.post('/api/v1/ugc/send-otp/', data: {'mobile': phone});
    return response.statusCode == 200;
  }

  Future<bool> verifyOtp(String phone, String otp) async {
    final response = await _dio.post('/api/v1/ugc/verify-otp/', data: {
      'mobile': phone,
      'otp': otp,
    });
    return response.statusCode == 200;
  }

  Future<ApiResponse<List<UnifiedFeedItem>>> getUgcFeed({
    String? state,
    String? district,
    String? subdistrict,
    String? village,
    String? scope,
    int pageSize = 20,
    String? cursor,
  }) async {
    final Map<String, dynamic> params = {
      'page_size': pageSize,
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    };
    if (state != null) params['state'] = state;
    if (district != null) params['district'] = district;
    if (subdistrict != null && subdistrict.isNotEmpty)
      params['subdistrict'] = subdistrict;
    if (village != null && village.isNotEmpty) params['village'] = village;
    if (scope != null) params['scope'] = scope;

    try {
      final response =
          await _dio.get('/api/v1/ugc/feed/', queryParameters: params);
      return ApiResponse<List<UnifiedFeedItem>>.fromJson(response.data, (json) {
        if (json is! List) return <UnifiedFeedItem>[];
        return json.map((item) {
          final map = item is Map<String, dynamic> ? item : <String, dynamic>{};
          return UnifiedFeedItem(
            id: map['id']?.toString() ?? '',
            type: map['type']?.toString() ?? 'ugc',
            title: map['title']?.toString() ?? '',
            summary: map['description']?.toString() ?? '',
            thumbnailUrl: map['thumbnail_url']?.toString() ?? '',
            mediaUrl: map['media_url']?.toString() ?? '',
            createdAt: DateParser.tryParse(map['created_at']) ?? DateTime.now(),
            district: map['district']?.toString() ?? '',
            subdistrict: map['subdistrict']?.toString() ?? '',
            village: map['village']?.toString() ?? '',
            state: map['state']?.toString() ?? '',
            priorityScore: map['priority_score'] is num
                ? (map['priority_score'] as num).toInt()
                : 0,
            source: map['source']?.toString() ??
                map['uploader']?.toString() ??
                'UGC',
            trustScore: map['trust_score'] is num
                ? (map['trust_score'] as num).toInt()
                : 50,
            metadata: {
              if (map['metadata'] is Map)
                ...Map<String, dynamic>.from(map['metadata']),
              'media_items': map['media_items'] ?? map['media'],
              'image_urls': map['image_urls'],
              'media_type': map['media_type'],
              'trust_level': map['trust_level'],
            },
          );
        }).toList();
      });
    } catch (e) {
      return ApiResponse.error(
        message: e is AppException ? e.message : e.toString(),
        fallbackData: <UnifiedFeedItem>[],
      );
    }
  }

  Future<Map<String, dynamic>> submitUgc(Map<String, dynamic> data) async {
    final response = await _dio.post('/api/v1/ugc/submit/', data: data);
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadMedia({
    required String submissionId,
    required String mobile,
    required String mediaType,
    required String filePath,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final formData = FormData.fromMap({
      'submission_id': submissionId,
      'mobile': mobile,
      'media_type': mediaType,
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await _dio.post(
      '/api/v1/ugc/upload-media/',
      data: formData,
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Upload multiple media files for one UGC submission in a single request.
  /// Falls back to the single-file `file`/`media_type` shape when there's
  /// only one path, matching the backend contract exactly for both cases.
  Future<Map<String, dynamic>> uploadMediaBatch({
    required String submissionId,
    required String mobile,
    required List<String> filePaths,
    required List<String> mediaTypes,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    if (filePaths.length == 1) {
      return uploadMedia(
        submissionId: submissionId,
        mobile: mobile,
        mediaType: mediaTypes.first,
        filePath: filePaths.first,
        onSendProgress: onSendProgress,
        cancelToken: cancelToken,
      );
    }
    final files =
        await Future.wait(filePaths.map((p) => MultipartFile.fromFile(p)));
    final formData = FormData.fromMap({
      'submission_id': submissionId,
      'mobile': mobile,
      'media_type': mediaTypes.first,
      'media_types': mediaTypes.join(','),
      'files': files,
    });
    final response = await _dio.post(
      '/api/v1/ugc/upload-media/',
      data: formData,
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getReporterDashboard() async {
    final response = await _dio.get('/api/v1/ugc/reporter/dashboard/');
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<List<ReporterPost>> getReporterSubmissions({
    String? status,
    int pageSize = 20,
    int page = 1,
  }) async {
    try {
      final query = <String, dynamic>{
        'page_size': pageSize,
        'page': page,
      };
      if (status != null &&
          status.isNotEmpty &&
          status.toLowerCase() != 'all') {
        query['status'] = status.toLowerCase();
      }
      final response = await _dio.get('/api/v1/ugc/reporter/submissions/',
          queryParameters: query);
      final List data = response.data['data'] ?? [];
      return data.map((json) {
        PostStatus postStatus = PostStatus.pending;
        final raw = (json['status'] ?? '').toString().toLowerCase();
        if (raw == 'approved') {
          postStatus = PostStatus.approved;
        } else if (raw == 'published') {
          postStatus = PostStatus.published;
        } else if (raw == 'rejected') {
          postStatus = PostStatus.rejected;
        } else {
          postStatus = PostStatus.pending;
        }

        return ReporterPost(
          id: json['id'] ?? '',
          reporterName: json['uploader'] ?? 'Me',
          type:
              json['content_type'] == 'video' ? PostType.video : PostType.image,
          caption: json['title'] ?? '',
          category: json['category'] ?? 'local',
          mediaUrl: json['thumbnail_url'] ?? json['media_url'] ?? '',
          status: postStatus,
          submittedAt: json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now(),
          rejectionReason: json['rejection_reason'],
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> reportUgcSubmission({
    required String submissionId,
    required String reason,
    String? notes,
  }) async {
    final response = await _dio.post('/api/v1/ugc/report/', data: {
      'submission_id': submissionId,
      'reason': reason,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return response.statusCode == 200 || response.statusCode == 201;
  }

  // --- Rewards ---
  Future<Map<String, dynamic>> getRewardWallet() async {
    final response = await _dio.get('/api/v1/rewards/wallet/');
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<List<dynamic>> getRewardTransactions({int pageSize = 20}) async {
    final response = await _dio.get('/api/v1/rewards/transactions/',
        queryParameters: {'page_size': pageSize});
    return response.data['data'] as List<dynamic>? ?? [];
  }

  Future<List<dynamic>> getRewardPayouts({int pageSize = 20}) async {
    final response = await _dio.get('/api/v1/rewards/payouts/',
        queryParameters: {'page_size': pageSize});
    return response.data['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> createRewardPayout(
      Map<String, dynamic> data) async {
    final response = await _dio.post('/api/v1/rewards/payouts/', data: data);
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getRewardPayoutDetails(String payoutId) async {
    final response = await _dio.get('/api/v1/rewards/payouts/$payoutId/');
    return response.data['data'] as Map<String, dynamic>;
  }

  // --- Admin Moderation ---
  // Note: UGC submission moderation (queue/approve/reject/flag/bulk-action/
  // trust/block) now lives entirely in lib/features/admin/ against the
  // real /admin/api/ugc/... endpoints. Only the unrelated article
  // moderation calls below remain here.
  Future<bool> approveArticle(String articleId) async {
    final response = await _dio.post('/admin/api/articles/$articleId/approve/');
    return response.statusCode == 200 || response.statusCode == 201;
  }

  Future<bool> rejectArticle(String articleId, String? reason) async {
    final data = reason != null && reason.isNotEmpty
        ? {'status': 'rejected', 'reason': reason}
        : {'status': 'rejected'};
    final response =
        await _dio.post('/admin/api/articles/$articleId/reject/', data: data);
    return response.statusCode == 200 || response.statusCode == 201;
  }

  // --- Posters ---
  Future<List<dynamic>> getPosters({
    String? category,
    String? lang,
    String? cursor,
    int pageSize = 20,
  }) async {
    final effectiveLang = lang;
    final Map<String, dynamic> params = {
      'page_size': pageSize,
      if (effectiveLang != null && effectiveLang.isNotEmpty)
        'lang': effectiveLang,
    };
    if (category != null) params['category'] = category;
    if (cursor != null) params['cursor'] = cursor;

    try {
      final response =
          await _dio.get('/api/v1/posters/', queryParameters: params);
      return response.data['data'] as List<dynamic>? ?? [];
    } catch (_) {
      return [];
    }
  }

  // --- Ad Booking ---
  Future<List<dynamic>> getAdAreas() async {
    final response = await _dio.get('/api/v1/ads/areas/');
    return response.data['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> getAdPricing({
    required String adType,
    String? areaId,
    required int durationDays,
  }) async {
    final response = await _dio.get('/api/v1/ads/pricing/', queryParameters: {
      'ad_type': adType,
      if (areaId != null && areaId.isNotEmpty) 'area_id': areaId,
      'duration_days': durationDays,
    });
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitAdBooking(
      Map<String, dynamic> data) async {
    final response = await _dio.post('/api/v1/ads/bookings/', data: data);
    return response.data['data'] as Map<String, dynamic>;
  }

  // --- Notifications ---
  Future<List<AppNotification>> getNotifications({bool? unread}) async {
    final Map<String, dynamic> params = {};
    if (unread != null) params['unread'] = unread;
    try {
      final response = await _dio.get('/api/v1/notifications/inbox/',
          queryParameters: params);
      final List data = response.data['data'] as List? ?? [];
      return data
          .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<int> getUnreadNotificationCount() async {
    try {
      final response =
          await _dio.get('/api/v1/notifications/inbox/unread-count/');
      return response.data['data']['unread_count'] ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<Map<String, dynamic>?> getNotificationDetails(
      String notificationId) async {
    try {
      final response =
          await _dio.get('/api/v1/notifications/inbox/$notificationId/');
      return response.data['data'] as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<bool> markNotificationRead(String notificationId) async {
    try {
      final response =
          await _dio.post('/api/v1/notifications/inbox/$notificationId/read/');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  // --- Notification Preferences & Subscriptions ---
  Future<Map<String, dynamic>?> getNotificationPreferences() async {
    try {
      final response = await _dio.get('/api/v1/notifications/preferences/');
      return response.data['data'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateNotificationPreferences(Map<String, dynamic> data) async {
    try {
      final response =
          await _dio.patch('/api/v1/notifications/preferences/', data: data);
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getNotificationSubscriptions() async {
    try {
      final response = await _dio.get('/api/v1/notifications/subscriptions/');
      final List data = response.data['data'] as List? ?? [];
      return data.map((e) => e as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> createNotificationSubscription(Map<String, dynamic> data) async {
    try {
      final response =
          await _dio.post('/api/v1/notifications/subscriptions/', data: data);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteNotificationSubscription(String subscriptionId) async {
    try {
      final response = await _dio
          .delete('/api/v1/notifications/subscriptions/$subscriptionId/');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  // --- Admin Notifications (Flow 7) ---
  Future<Map<String, dynamic>> getAdminNotifications({String? status}) async {
    final response =
        await _dio.get('/admin/api/notifications/', queryParameters: {
      if (status != null && status.isNotEmpty) 'status': status,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> previewAdminNotificationTarget(
      Map<String, dynamic> data) async {
    final response =
        await _dio.post('/admin/api/notifications/target-preview/', data: data);
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendAdminNotification(
      Map<String, dynamic> data) async {
    final response =
        await _dio.post('/admin/api/notifications/send/', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAdminNotificationDetail(String id) async {
    final response = await _dio.get('/admin/api/notifications/$id/');
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> retryAdminNotificationFailed(String id) async {
    final response =
        await _dio.post('/admin/api/notifications/$id/retry-failed/');
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getAdminNotificationLogs(
      {required String notificationId, String? status}) async {
    final response =
        await _dio.get('/admin/api/notifications/logs/', queryParameters: {
      'notification': notificationId,
      if (status != null && status.isNotEmpty) 'status': status,
    });
    return (response.data['data'] as List?) ?? [];
  }

  // --- Polls ---
  Future<List<Poll>> getPolls() async {
    try {
      final response = await _dio.get('/api/v1/polls/');
      final List data = response.data['data'] ?? [];
      return data
          .map((json) => Poll.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Poll?> getPollDetails(String pollId) async {
    try {
      final response = await _dio.get('/api/v1/polls/$pollId/');
      if (response.data['data'] != null) {
        return Poll.fromJson(response.data['data'] as Map<String, dynamic>);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> submitPollVote(
    String pollId, {
    String? optionId,
    int? optionIndex,
  }) async {
    try {
      final Map<String, dynamic> body = {};
      if (optionId != null && optionId.isNotEmpty) {
        body['option_id'] = optionId;
      } else if (optionIndex != null) {
        body['choice'] = optionIndex == 0 ? 'a' : 'b';
      }
      final response =
          await _dio.post('/api/v1/polls/$pollId/vote/', data: body);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  // --- CMS ---
  Future<Map<String, dynamic>?> getCmsPage(String slug) async {
    try {
      final response = await _dio.get('/api/v1/cms/$slug/');
      return response.data['data'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  // --- Quotes / Daily Cards ---
  Future<Map<String, dynamic>?> getRandomQuote(
      {String? lang, bool forceRefresh = false}) async {
    try {
      final effectiveLang = lang;
      final response =
          await _dio.get('/api/v1/quotes/random/', queryParameters: {
        if (effectiveLang != null && effectiveLang.isNotEmpty)
          'lang': effectiveLang,
        if (forceRefresh) 't': DateTime.now().millisecondsSinceEpoch,
      });
      return response.data['data'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  // --- Trending Search Keywords ---
  Future<List<String>> getTrendingSearchKeywords({int days = 7}) async {
    try {
      final response = await _dio
          .get('/api/v1/search/trending/', queryParameters: {'days': days});
      final List data = response.data['data'] ?? [];
      return data
          .map<String>((item) => (item['keyword'] ?? '').toString())
          .where((k) => k.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
