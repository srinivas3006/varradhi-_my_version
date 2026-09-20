import 'dart:async';
import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/news_article.dart';
import '../models/redeem_request.dart';
import '../models/reporter_post.dart';
import '../models/app_notification.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../repositories/ad_repository.dart';

/// Simple app-wide state singleton. Scalar fields (onboarding completion,
/// language, location, coins, login, reporter status) survive app restarts
/// via shared_preferences. The auth token is the one exception: it's kept
/// out of shared_preferences (which is plaintext, unencrypted disk storage
/// on both Android and iOS) and instead lives in flutter_secure_storage,
/// which is backed by Keychain on iOS and EncryptedSharedPreferences /
/// Keystore on Android.
/// Lists (posts, redeem requests) are kept in-memory only for this demo —
/// a real backend would own them.
/// Dedicated notifier for theme and locale changes.
/// Listening to this instead of AppState prevents the entire MaterialApp
/// and heavy UI widgets from rebuilding whenever coins, likes, bookmarks,
/// or profile data change.
class ThemeAndLocaleNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

class AppState extends ChangeNotifier {
  static const _secureStorage = FlutterSecureStorage();
  static const _authTokenKey = 'authToken';
  static const _refreshTokenKey = 'refreshToken';
  static const _installationSecretKey = 'installation_secret';
  static const _sessionIdKey = 'session_id';
  static const _deviceIdKey = 'device_id';

  /// Scoped notifier for themeMode and language updates.
  final ThemeAndLocaleNotifier themeAndLocaleNotifier =
      ThemeAndLocaleNotifier();

  // Local persistence for likes/dislikes/comments until backend supports it
  Set<String> likedItemIds = {};
  Set<String> dislikedItemIds = {};
  Set<String> bookmarkedItemIds = {};
  Map<String, List<String>> localComments = {};

  AppState._internal();
  static final AppState instance = AppState._internal();

  /// UI language: buttons, labels, tabs, settings copy.
  String language = 'Telugu';

  /// The UI language as the backend's two-letter code.
  ///
  /// This is what `preferred_language` on the profile stores — the interface
  /// language follows the account across devices. Content language stays
  /// local and is deliberately not synced.
  String get uiLanguageCode =>
      language.toLowerCase().startsWith('en') ? 'en' : 'te';

  /// Language of the news itself, stored independently of [language].
  ///
  /// null means "All languages" and the feed request omits `lang` entirely,
  /// which is what the backend wants for an unfiltered feed. It is not
  /// derived from [language] any more: that made the two settings impossible
  /// to separate, and made every fresh install send lang=te — hiding every
  /// English article before the reader had chosen anything.
  String? _contentLanguage;

  /// 'en' | 'te', or null for all languages.
  String? get contentLanguage => _contentLanguage;

  /// Whether the reader has been asked yet.
  ///
  /// Separate from [_contentLanguage] being null, because null is also the
  /// valid answer "All languages" — without this the prompt would reappear
  /// every launch for anyone who picked All.
  bool contentLanguagePrompted = false;

  Future<void> markContentLanguagePrompted() async {
    if (contentLanguagePrompted) return;
    contentLanguagePrompted = true;
    await _persist();
  }

  /// Accepts 'all' / '' as null so callers can pass the UI value straight in.
  Future<void> setContentLanguage(String? value) async {
    final normalized = (value == null || value.isEmpty || value == 'all')
        ? null
        : value.toLowerCase();
    if (normalized == _contentLanguage) return;
    _contentLanguage = normalized;
    notifyListeners();
    await _persist();
  }
  String stateName = 'Telangana';
  String district = 'Hyderabad';
  String city = 'Hyderabad';
  String subdistrict = '';
  String village = '';
  String country = 'India';
  String? stateId;
  String? districtId;
  String? subdistrictId;
  String? villageId;
  double? latitude;
  double? longitude;
  bool isLoggedIn = false;

  /// Never persisted via SharedPreferences. See init()/setAuthToken()/
  /// _clearAuthToken() — this is loaded from and written to secure storage.
  String? authToken;

  /// The refresh token backing [authToken]. Same secure-storage treatment
  /// as authToken. Needed so the app can silently refresh the short-lived
  /// (15 min) access token instead of forcing a re-login, and so logout()
  /// can actually invalidate the session server-side.
  String? refreshToken;

  /// NOTE: this is a UI convenience flag only. It must never be trusted for
  /// authorization decisions — any admin-only API call must be re-checked
  /// server-side against the token, since a locally-stored bool can always
  /// be flipped on a rooted/jailbroken device.
  bool isAdmin = false;

  /// Same UI-convenience caveat as isAdmin above. Gates the Admin UGC
  /// Moderation console alongside isAdmin (isAdmin || isContributor).
  bool isContributor = false;
  String? userId;
  String userName = 'Guest User';
  String userPhone = '';
  String? userEmail;
  String? profileImagePath;

  void setUserName(String name) {
    userName = name;
    notifyListeners();
  }

  String? fcmToken;
  String deviceId = '';
  String? installationSecret;
  String? sessionId;

  Future<void> setInstallationSecret(String? secret) async {
    installationSecret = secret;
    try {
      if (secret != null && secret.isNotEmpty) {
        await _secureStorage.write(key: _installationSecretKey, value: secret);
      } else {
        await _secureStorage.delete(key: _installationSecretKey);
      }
    } catch (e) {
      debugPrint('[AppState] Failed to persist installation secret in secure storage: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (secret != null && secret.isNotEmpty) {
        await prefs.setString(_installationSecretKey, secret);
      } else {
        await prefs.remove(_installationSecretKey);
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setDeviceId(String id) async {
    deviceId = id;
    try {
      await _secureStorage.write(key: _deviceIdKey, value: id);
    } catch (e) {
      debugPrint('[AppState] Failed to persist device ID in secure storage: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('deviceId', id);
    } catch (_) {}
    notifyListeners();
  }

  /// Preserves the stable device ID. Backend enforces that the same FCM token
  /// cannot be registered under a new device_id.
  Future<String> regenerateDeviceId() async {
    debugPrint('[AppState] Preserving stable deviceId: $deviceId');
    return deviceId;
  }

  Future<void> setSessionId(String? id) async {
    sessionId = id;
    try {
      if (id != null && id.isNotEmpty) {
        await _secureStorage.write(key: _sessionIdKey, value: id);
      } else {
        await _secureStorage.delete(key: _sessionIdKey);
      }
    } catch (e) {
      debugPrint('[AppState] Failed to persist session ID: $e');
    }
    notifyListeners();
  }

  ThemeMode themeMode = ThemeMode.light;

  /// User preferred font size for reading Telugu and article bodies (defaults to 19.0 px).
  double readingFontSize = 19.0;

  Future<void> setReadingFontSize(double size) async {
    // 12-24 matches what PATCH /auth/me/ accepts, so a size stored here is
    // always one the server will keep.
    final clamped = size.clamp(12.0, 24.0);
    if ((clamped - readingFontSize).abs() < 0.1) return;
    readingFontSize = clamped;
    notifyListeners();
    await _persist();
  }

  List<String> preferredCategories = [];
  bool hasPromptedPreferences = false;

  /// True once the user has completed language + location selection at
  /// least once. When true, the splash screen skips straight to Home.
  bool hasOnboarded = false;

  /// True if the user has already been prompted for location permission
  /// in the feed. Ensures we only ask once.
  bool locationPrompted = false;

  /// True if the user successfully granted location permissions and we fetched real GPS data
  bool hasValidLocation = false;

  /// True if the user has push notifications enabled globally in their profile
  bool pushNotificationsEnabled = true;

  // ---- Notifications state ----
  List<AppNotification> notifications = [];
  int get unreadNotificationsCount =>
      notifications.where((n) => !n.isRead).length;

  // ---- Comments state ----
  final Map<String, List<Comment>> articleComments = {};

  // ---- Reporter Program state ----

  /// True once the user has registered for the Reporter Program. This is
  /// instant (no approval needed) — only individual posts need admin review.
  bool isReporter = false;

  /// True once the user has completed the ONE-TIME OTP check that's
  /// required before their very first post submission. Never asked again
  /// after that.
  bool uploadVerified = false;

  /// 1 token = ₹5. Reporters can request a redeem once this reaches 100.
  int reporterTokens = 0;

  final List<ReporterPost> reporterPosts = [];
  final List<RedeemRequest> redeemRequests = [];

  static const int rupeesPerToken = 5;
  static const int tokensNeededToRedeem = 100;

  /// Loads persisted state. Call once, before runApp, so the very first
  /// frame already knows whether to show onboarding or go straight home.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    hasOnboarded = prefs.getBool('hasOnboarded') ?? false;
    language = prefs.getString('language') ?? 'Telugu';
    profileImageUrl = prefs.getString('profileImageUrl');
    // Absent key means never chosen — stays null so the feed is unfiltered.
    _contentLanguage = prefs.getString('content_language');
    contentLanguagePrompted =
        prefs.getBool('content_language_prompted') ?? false;
    stateName = prefs.getString('stateName') ?? stateName;
    district = prefs.getString('district') ?? district;
    city = prefs.getString('city') ?? city;
    subdistrict = prefs.getString('subdistrict') ?? subdistrict;
    village = prefs.getString('village') ?? village;
    country = prefs.getString('country') ?? country;
    stateId = prefs.getString('stateId');
    districtId = prefs.getString('districtId');
    subdistrictId = prefs.getString('subdistrictId');
    villageId = prefs.getString('villageId');
    latitude = prefs.getDouble('latitude');
    longitude = prefs.getDouble('longitude');
    isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    isAdmin = prefs.getBool('isAdmin') ?? false;
    isContributor = prefs.getBool('isContributor') ?? false;
    userName = prefs.getString('userName') ?? userName;
    userPhone = prefs.getString('userPhone') ?? userPhone;
    profileImagePath = prefs.getString('profileImagePath');
    isReporter = prefs.getBool('isReporter') ?? false;
    uploadVerified = prefs.getBool('uploadVerified') ?? false;
    reporterTokens = prefs.getInt('reporterTokens') ?? 0;
    readingFontSize = prefs.getDouble('readingFontSize') ?? 19.0;

    // Read deviceId from secure storage first, fallback to shared_preferences
    try {
      deviceId = (await _secureStorage.read(key: _deviceIdKey)) ?? '';
    } catch (_) {
      deviceId = '';
    }
    if (deviceId.isEmpty) {
      deviceId = prefs.getString('deviceId') ?? '';
    }
    if (deviceId.isEmpty) {
      deviceId =
          'dev_${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecondsSinceEpoch % 100000)}';
    }
    // Always ensure deviceId is synced to both storages
    await prefs.setString('deviceId', deviceId);
    try {
      await _secureStorage.write(key: _deviceIdKey, value: deviceId);
    } catch (_) {}

    // Read installationSecret from secure storage first, fallback to shared_preferences
    try {
      installationSecret =
          await _secureStorage.read(key: _installationSecretKey);
    } catch (_) {
      installationSecret = null;
    }
    if (installationSecret == null || installationSecret!.isEmpty) {
      installationSecret = prefs.getString(_installationSecretKey);
    }
    if (installationSecret != null && installationSecret!.isNotEmpty) {
      await prefs.setString(_installationSecretKey, installationSecret!);
      try {
        await _secureStorage.write(
            key: _installationSecretKey, value: installationSecret!);
      } catch (_) {}
    }

    // Auth tokens come from secure storage
    try {
      authToken = await _secureStorage.read(key: _authTokenKey);
      refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      sessionId = await _secureStorage.read(key: _sessionIdKey);
    } catch (e) {
      debugPrint(
          '[AppState] Secure storage auth read failed (keystore reset or corrupted): $e');
      authToken = null;
      refreshToken = null;
      sessionId = null;
    }

    // If we don't actually have a token, don't trust a stale isLoggedIn flag.
    if (authToken == null) {
      isLoggedIn = false;
    }

    final themeStr = prefs.getString('themeMode');
    if (themeStr == 'dark') {
      themeMode = ThemeMode.dark;
    } else if (themeStr == 'system') {
      themeMode = ThemeMode.system;
    } else {
      themeMode = ThemeMode.light;
    }

    preferredCategories = prefs.getStringList('preferredCategories') ?? [];
    hasPromptedPreferences = prefs.getBool('hasPromptedPreferences') ?? false;
    locationPrompted = prefs.getBool('locationPrompted') ?? false;
    hasValidLocation = prefs.getBool('hasValidLocation') ?? false;
    pushNotificationsEnabled =
        prefs.getBool('pushNotificationsEnabled') ?? true;

    likedItemIds = (prefs.getStringList('likedItemIds') ?? []).toSet();
    dislikedItemIds = (prefs.getStringList('dislikedItemIds') ?? []).toSet();
    bookmarkedItemIds =
        (prefs.getStringList('bookmarkedItemIds') ?? []).toSet();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasOnboarded', hasOnboarded);
    await prefs.setString('language', language);
    if (profileImageUrl != null && profileImageUrl!.isNotEmpty) {
      await prefs.setString('profileImageUrl', profileImageUrl!);
    }
    await prefs.setBool(
        'content_language_prompted', contentLanguagePrompted);
    if (_contentLanguage == null) {
      await prefs.remove('content_language');
    } else {
      await prefs.setString('content_language', _contentLanguage!);
    }
    await prefs.setString('stateName', stateName);
    await prefs.setString('district', district);
    await prefs.setString('city', city);
    await prefs.setString('subdistrict', subdistrict);
    await prefs.setString('village', village);
    await prefs.setString('country', country);
    if (stateId != null) {
      await prefs.setString('stateId', stateId!);
    } else {
      await prefs.remove('stateId');
    }
    if (districtId != null) {
      await prefs.setString('districtId', districtId!);
    } else {
      await prefs.remove('districtId');
    }
    if (subdistrictId != null) {
      await prefs.setString('subdistrictId', subdistrictId!);
    } else {
      await prefs.remove('subdistrictId');
    }
    if (villageId != null) {
      await prefs.setString('villageId', villageId!);
    } else {
      await prefs.remove('villageId');
    }
    if (latitude != null) await prefs.setDouble('latitude', latitude!);
    if (longitude != null) await prefs.setDouble('longitude', longitude!);
    await prefs.setBool('isLoggedIn', isLoggedIn);
    await prefs.setBool('isAdmin', isAdmin);
    await prefs.setBool('isContributor', isContributor);
    await prefs.setString('userName', userName);
    await prefs.setString('userPhone', userPhone);
    if (profileImagePath != null) {
      await prefs.setString('profileImagePath', profileImagePath!);
    } else {
      await prefs.remove('profileImagePath');
    }
    await prefs.setString('themeMode', themeMode.name);
    await prefs.setStringList('preferredCategories', preferredCategories);
    await prefs.setBool('hasPromptedPreferences', hasPromptedPreferences);
    await prefs.setBool('isReporter', isReporter);
    await prefs.setBool('uploadVerified', uploadVerified);
    await prefs.setInt('reporterTokens', reporterTokens);
    await prefs.setStringList('likedItemIds', likedItemIds.toList());
    await prefs.setStringList('dislikedItemIds', dislikedItemIds.toList());
    await prefs.setStringList('bookmarkedItemIds', bookmarkedItemIds.toList());
    await prefs.setBool('locationPrompted', locationPrompted);
    await prefs.setBool('hasValidLocation', hasValidLocation);
    await prefs.setBool('pushNotificationsEnabled', pushNotificationsEnabled);
    await prefs.setDouble('readingFontSize', readingFontSize);
    // Deliberately no authToken here — see setAuthToken/_clearAuthToken.
  }

  /// Stores a freshly-issued auth token (and, when available, its paired
  /// refresh token) in secure storage and marks the user logged in. This is
  /// the only path that should ever set authToken after login/register.
  Future<void> setAuthToken(String token, {String? refresh}) async {
    authToken = token;
    isLoggedIn = true;
    try {
      await _secureStorage.write(key: _authTokenKey, value: token);
      if (refresh != null && refresh.isNotEmpty) {
        refreshToken = refresh;
        await _secureStorage.write(key: _refreshTokenKey, value: refresh);
      }
    } catch (e) {
      debugPrint('[AppState] Failed to persist auth tokens: $e');
    }
    notifyListeners();
    await _persist();
  }

  /// Called by the Dio interceptor after a successful silent token refresh.
  /// Refresh token rotation means the backend issues a new refresh token on
  /// every refresh call, so both values are re-persisted.
  Future<void> updateTokensAfterRefresh(String access, String? refresh) async {
    authToken = access;
    try {
      await _secureStorage.write(key: _authTokenKey, value: access);
      if (refresh != null && refresh.isNotEmpty) {
        refreshToken = refresh;
        await _secureStorage.write(key: _refreshTokenKey, value: refresh);
      }
    } catch (e) {
      debugPrint('[AppState] Failed to persist refreshed tokens: $e');
    }
  }

  Future<void> _clearAuthToken() async {
    authToken = null;
    refreshToken = null;
    try {
      await _secureStorage.delete(key: _authTokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
    } catch (e) {
      debugPrint('[AppState] Failed to clear auth tokens: $e');
    }
  }

  /// Real gate for the Admin UGC Moderation console: fetches /auth/me/ and
  /// defensively derives isAdmin/isContributor from whichever role signals
  /// the backend actually sends. Never throws — a failed refresh just
  /// leaves the existing flags untouched, so it's safe to fire-and-forget
  /// from login/signup/app-startup without risking those flows.
  Future<void> refreshRolesFromServer() async {
    try {
      final me = await ApiService.instance.getMe();
      isAdmin = _hasAdminSignal(me);
      isContributor = isAdmin || _hasContributorSignal(me);
      if (me['name'] != null && me['name'].toString().isNotEmpty) {
        userName = me['name'].toString();
      } else if (me['username'] != null &&
          me['username'].toString().isNotEmpty) {
        userName = me['username'].toString();
      } else if (me['email'] != null && me['email'].toString().isNotEmpty) {
        userName = me['email'].toString();
      }
      // profile_image is read-only on /auth/me/ — the documented editable
      // fields are full_name, preferred_language, theme and font_size only.
      // The app could not display an avatar set anywhere else because it
      // never read this back.
      final serverImage = (me['profile_image'] ??
              me['profileImage'] ??
              (me['profile'] is Map ? me['profile']['profile_image'] : null))
          ?.toString();
      if (serverImage != null && serverImage.startsWith('http')) {
        profileImageUrl = serverImage;
      }

      if (me['phone'] != null) userPhone = me['phone'].toString();
      if (me['id'] != null) userId = me['id'].toString();
      // Apply the account's saved interface language. Without this the
      // field was write-only: a returning reader on a new device got the
      // default language regardless of what they had chosen.
      final serverLang = (me['preferred_language'] ??
              me['preferredLanguage'] ??
              (me['profile'] is Map ? me['profile']['preferred_language'] : null))
          ?.toString()
          .toLowerCase()
          .trim();
      if (serverLang != null && serverLang.isNotEmpty) {
        final resolved = serverLang.startsWith('en') ? 'English' : 'Telugu';
        if (resolved != language) {
          language = resolved;
          themeAndLocaleNotifier.notify();
        }
      }

      // Theme and reading size are profile fields too; reading them back
      // makes the account's preferences follow the reader to a new device.
      final serverTheme = me['theme']?.toString().toLowerCase().trim();
      if (serverTheme != null && serverTheme.isNotEmpty) {
        final resolved = switch (serverTheme) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        };
        if (resolved != themeMode) {
          themeMode = resolved;
          themeAndLocaleNotifier.notify();
        }
      }

      final serverFont = me['font_size'];
      if (serverFont != null) {
        final parsed = double.tryParse(serverFont.toString());
        if (parsed != null) await setReadingFontSize(parsed);
      }

      if (me['is_reporter'] == true) isReporter = true;
      if (me['tokens'] != null) {
        reporterTokens =
            int.tryParse(me['tokens'].toString()) ?? reporterTokens;
      }
      notifyListeners();
      await _persist();
    } catch (e) {
      debugPrint('refreshRolesFromServer: $e');
    }
  }

  static bool _matchesKeyword(dynamic value, List<String> keywords) {
    if (value == null) return false;
    if (value is String) {
      final lower = value.toLowerCase();
      return keywords.any(lower.contains);
    }
    if (value is List) {
      return value.any((e) => _matchesKeyword(e, keywords));
    }
    return false;
  }

  static bool _hasAdminSignal(Map<String, dynamic> me) {
    if (me['is_admin'] == true ||
        me['is_staff'] == true ||
        me['is_superuser'] == true) {
      return true;
    }
    const keywords = ['admin', 'staff', 'superuser'];
    return _matchesKeyword(me['role'], keywords) ||
        _matchesKeyword(me['roles'], keywords) ||
        _matchesKeyword(me['groups'], keywords) ||
        _matchesKeyword(me['permissions'], keywords);
  }

  static bool _hasContributorSignal(Map<String, dynamic> me) {
    if (me['is_contributor'] == true) return true;
    const keywords = ['contributor', 'reporter'];
    return _matchesKeyword(me['role'], keywords) ||
        _matchesKeyword(me['roles'], keywords) ||
        _matchesKeyword(me['groups'], keywords) ||
        _matchesKeyword(me['permissions'], keywords);
  }

  /// Marks onboarding (language + location) as done. Login stays optional/
  /// skippable on every future launch, matching Way2News's "no login
  /// required" behavior — only language+location gate the splash skip.
  void completeOnboarding([String? selectedLanguage]) {
    hasOnboarded = true;
    final normalizedLanguage = selectedLanguage?.trim();
    if (normalizedLanguage != null && normalizedLanguage.isNotEmpty) {
      language = normalizedLanguage;
    }
    themeAndLocaleNotifier.notify();
    notifyListeners();
    _persist();
  }

  void markLocationPrompted() {
    locationPrompted = true;
    notifyListeners();
    _persist();
  }

  void setLanguage(String lang) {
    language = lang;
    themeAndLocaleNotifier.notify();
    notifyListeners();
    _persist();
    // The UI language is what changed, so that is what gets patched. This
    // used to send contentLanguage, which is a different setting entirely —
    // and since that is null by default, the patch dropped the field and
    // sent nothing at all.
    _syncProfileToBackend(preferredLanguage: uiLanguageCode);
  }

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    themeAndLocaleNotifier.notify();
    notifyListeners();
    _persist();
    _syncProfileToBackend(theme: mode.name);
  }

  /// Best-effort sync of profile-level preferences to the backend. Never
  /// throws — a failed sync just leaves the change local-only until the
  /// next successful call, matching setPreferredCategories' pattern.
  Future<void> _syncProfileToBackend(
      {String? preferredLanguage, String? theme, String? fullName}) async {
    if (!isLoggedIn) return;
    try {
      await ApiService.instance.updateProfile({
        if (fullName != null) 'full_name': fullName,
        if (preferredLanguage != null) 'preferred_language': preferredLanguage,
        if (theme != null) 'theme': theme,
      });
    } catch (e) {
      debugPrint('Failed to sync profile preferences to backend: $e');
    }
  }

  void togglePushNotifications(bool value) {
    pushNotificationsEnabled = value;
    notifyListeners();
    _persist();
  }

  String get displayLocation {
    if (village.isNotEmpty) {
      return subdistrict.isNotEmpty
          ? '$village, $subdistrict'
          : '$village, $district';
    } else if (subdistrict.isNotEmpty &&
        district.isNotEmpty &&
        subdistrict != district) {
      return '$subdistrict, $district';
    } else if (city.isNotEmpty && district.isNotEmpty && city != district) {
      return '$city, $district';
    } else if (district.isNotEmpty) {
      return '$district, $stateName';
    } else if (city.isNotEmpty) {
      return '$city, $stateName';
    }
    return stateName;
  }

  void setLocation(
    String state,
    String district, {
    String? city,
    String? subdistrict,
    String? village,
    String? country,
    double? latitude,
    double? longitude,
    String? stateId,
    String? districtId,
    String? subdistrictId,
    String? villageId,
  }) {
    stateName = state;
    this.district = district;
    this.city = city ?? (district.isNotEmpty ? district : state);
    this.subdistrict = subdistrict ?? '';
    this.village = village ?? '';
    this.country = country ?? 'India';
    this.latitude = latitude;
    this.longitude = longitude;
    this.stateId = stateId;
    this.districtId = districtId;
    this.subdistrictId = subdistrictId;
    this.villageId = villageId;
    hasOnboarded = true;
    hasValidLocation = true;
    AdRepository.instance.clearCache();
    ApiService.instance.clearFeedCache();
    notifyListeners();
    _persist();
  }

  void setDeviceLocation(
    DeviceLocation loc, {
    String? stateId,
    String? districtId,
    String? subdistrictId,
    String? villageId,
  }) {
    setLocation(
      loc.state,
      loc.district,
      city: loc.city,
      subdistrict: loc.subdistrict ?? '',
      village: loc.village ?? '',
      country: loc.country,
      latitude: loc.latitude,
      longitude: loc.longitude,
      stateId: stateId,
      districtId: districtId,
      subdistrictId: subdistrictId,
      villageId: villageId,
    );
  }

  Future<void> setPreferredCategories(List<String> categories) async {
    preferredCategories = categories;
    hasPromptedPreferences = true;
    notifyListeners();
    await _persist();

    if (isLoggedIn) {
      try {
        // The on-device list mixes real content categories with location
        // and format filters (e.g. "Andhra Pradesh", "Videos") that are not
        // valid category slugs server-side. Sending an unknown slug makes
        // the whole PATCH fail validation, so only forward slugs that
        // actually exist in the backend's active category list.
        final validSlugs = (await ApiService.instance.getCategories())
            .map((c) => c.slug)
            .toSet();
        final Map<String, double> weights = {};
        for (var cat in categories) {
          final slug = _categoryToSlug(cat);
          if (slug.isNotEmpty && validSlugs.contains(slug)) {
            weights[slug] = 1.0;
          }
        }
        if (weights.isNotEmpty) {
          await ApiService.instance.updateCategoryPreferences(weights);
        }
      } catch (e) {
        debugPrint('Failed to sync category preferences to backend: $e');
      }
    }
  }

  static String _categoryToSlug(String cat) {
    return cat
        .trim()
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  void markPreferencesPrompted() {
    hasPromptedPreferences = true;
    notifyListeners();
    _persist();
  }

  /// Toggles a like and tells the server.
  ///
  /// setReaction alone only writes the local sets and SharedPreferences, so
  /// every caller of this method — double-tap on a spotlight card, the video
  /// tab's like button — changed the icon and lost the like on the next
  /// refresh, because the reaction never reached the backend. The spotlight
  /// action bar and the detail screen called the API themselves, which is why
  /// only some likes stuck.
  Future<void> toggleLike(String itemId) async {
    if (itemId.isEmpty) return;
    final wasLiked = likedItemIds.contains(itemId);
    final next = wasLiked ? 'none' : 'like';
    final previous = getReaction(itemId);

    setReaction(itemId, next);
    await _syncReaction(itemId, next, previous);
  }

  Future<void> toggleDislike(String itemId) async {
    if (itemId.isEmpty) return;
    final wasDisliked = dislikedItemIds.contains(itemId);
    final next = wasDisliked ? 'none' : 'dislike';
    final previous = getReaction(itemId);

    setReaction(itemId, next);
    await _syncReaction(itemId, next, previous);
  }

  /// Sends the reaction, restoring [previous] if the server rejects it, so
  /// the icon never claims a reaction the backend does not hold.
  Future<void> _syncReaction(
      String itemId, String next, String previous) async {
    try {
      await ApiService.instance.postArticleReaction(itemId, next);
    } catch (e) {
      debugPrint('[AppState] reaction sync failed for $itemId: $e');
      setReaction(itemId, previous);
    }
  }


  void setReaction(String itemId, String reaction) {
    if (itemId.isEmpty) return;
    final r = reaction.toLowerCase();
    if (r == 'like') {
      likedItemIds.add(itemId);
      dislikedItemIds.remove(itemId);
    } else if (r == 'dislike') {
      dislikedItemIds.add(itemId);
      likedItemIds.remove(itemId);
    } else {
      likedItemIds.remove(itemId);
      dislikedItemIds.remove(itemId);
    }
    notifyListeners();
    _persist();
  }

  void toggleBookmark(String itemId) {
    if (itemId.isEmpty) return;
    if (bookmarkedItemIds.contains(itemId)) {
      bookmarkedItemIds.remove(itemId);
    } else {
      bookmarkedItemIds.add(itemId);
    }
    notifyListeners();
    _persist();
  }

  /// Sets liked state explicitly.
  ///
  /// Distinct from [toggleLike] because a rollback has to restore an exact
  /// state, not flip whatever is there now — toggling twice on a failed
  /// request would leave the flag inverted.
  void setLiked(String itemId, bool liked) {
    if (itemId.isEmpty) return;
    final changed =
        liked ? likedItemIds.add(itemId) : likedItemIds.remove(itemId);
    if (!changed) return;
    notifyListeners();
    _persist();
  }

  /// Sets bookmarked state explicitly. See [setLiked].
  void setBookmarked(String itemId, bool bookmarked) {
    if (itemId.isEmpty) return;
    final changed = bookmarked
        ? bookmarkedItemIds.add(itemId)
        : bookmarkedItemIds.remove(itemId);
    if (!changed) return;
    notifyListeners();
    _persist();
  }

  bool isLiked(String itemId) {
    return likedItemIds.contains(itemId);
  }

  bool isDisliked(String itemId) {
    return dislikedItemIds.contains(itemId);
  }

  bool isBookmarked(String itemId) {
    return bookmarkedItemIds.contains(itemId);
  }

  String getReaction(String itemId) {
    if (likedItemIds.contains(itemId)) return 'like';
    if (dislikedItemIds.contains(itemId)) return 'dislike';
    return 'none';
  }

  /// Onboarding's quick phone login (skippable, used at first launch).
  void login(String phone) {
    userPhone = phone;
    notifyListeners();
    _persist();
  }

  void signup({
    required String fullName,
    required String phone,
    required String password,
  }) {
    userName = fullName;
    userPhone = phone;
    notifyListeners();
    _persist();
  }

  /// Records a full account login. Expects the caller (e.g. the login
  /// screen) to have already exchanged credentials for a token via
  /// ApiService and called setAuthToken with the real token — this method
  /// only updates the display name. It never accepts a password and never
  /// falls back to a mock-logged-in state on failure.
  void accountLogin({required String username}) {
    userName = username;
    notifyListeners();
    _persist();
  }

  Future<void> fetchNotifications() async {
    try {
      final remote = await ApiService.instance.getNotifications();
      if (remote.isNotEmpty) {
        notifications = remote;
        notifyListeners();
      }
    } catch (_) {}
  }

  void markNotificationRead(String id) {
    final index = notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !notifications[index].isRead) {
      notifications[index].isRead = true;
      notifyListeners();
      ApiService.instance.markNotificationRead(id);
    }
  }

  void markAllNotificationsRead() {
    bool changed = false;
    for (var n in notifications) {
      if (!n.isRead) {
        n.isRead = true;
        changed = true;
        ApiService.instance.markNotificationRead(n.id);
      }
    }
    if (changed) notifyListeners();
  }

  /// Avatar URL the backend holds, when it has one.
  ///
  /// Distinct from [profileImagePath], which is a local file the reader
  /// picked. There is no upload endpoint, so a locally picked image stays on
  /// the device — see the report accompanying this change.
  String? profileImageUrl;

  /// Saves the profile, uploading the avatar through the existing
  /// PATCH /api/v1/auth/me/ when [imagePath] is a local file.
  ///
  /// profile_image is an editable field on that endpoint and takes a real
  /// file via multipart, so the picked image is uploaded rather than kept as
  /// a device-local path that no other device could ever see. The URL the
  /// server returns becomes the canonical one.
  ///
  /// Returns false if the save failed, with the previous avatar restored.
  Future<bool> updateProfile({
    required String name,
    String? imagePath,
  }) async {
    final previousName = userName;
    final previousUrl = profileImageUrl;
    final previousPath = profileImagePath;

    userName = name;
    // Shown immediately so the reader sees their pick while it uploads.
    if (imagePath != null && imagePath.isNotEmpty) {
      profileImagePath = imagePath;
    }
    notifyListeners();

    final isLocalFile = imagePath != null &&
        imagePath.isNotEmpty &&
        !imagePath.startsWith('http');

    try {
      final updated = await ApiService.instance.updateProfile(
        {'full_name': name},
        imageFile: isLocalFile ? File(imagePath) : null,
      );

      final serverImage = (updated['profile_image'] ??
              updated['profileImage'])
          ?.toString();
      if (serverImage != null && serverImage.startsWith('http')) {
        profileImageUrl = serverImage;
        // The local copy has served its purpose; the server URL is canonical
        // and survives reinstall.
        profileImagePath = null;
      }

      notifyListeners();
      await _persist();
      return true;
    } catch (e) {
      debugPrint('[AppState] profile update failed: $e');
      userName = previousName;
      profileImageUrl = previousUrl;
      profileImagePath = previousPath;
      notifyListeners();
      return false;
    }
  }

  /// Clears local session state first. If the backend logout call that
  /// follows 401s (access token already expired — often why logout() is
  /// being called in the first place), the Dio interceptor sees
  /// refreshToken already null and just no-ops instead of recursing back
  /// into logout().
  Future<String?> _clearLocalSession() async {
    final tokenToRevoke = refreshToken;
    isLoggedIn = false;
    isAdmin = false;
    isContributor = false;
    userId = null;
    userName = 'Guest User';
    userPhone = '';
    sessionId = null;
    await _secureStorage.delete(key: _sessionIdKey);
    await _clearAuthToken();
    notifyListeners();
    await _persist();
    return tokenToRevoke;
  }

  Future<void> logout() async {
    final tokenToRevoke = await _clearLocalSession();
    // Best-effort server-side session revocation. ApiService.logout()
    // already swallows its own errors, so an unreachable backend never
    // blocks the local logout above.
    if (tokenToRevoke != null && tokenToRevoke.isNotEmpty) {
      await ApiService.instance.logout(tokenToRevoke, logoutAllDevices: false);
    }
    // Per Backend Flow 2: Logout -> call logout API, keep device_id + installation_secret, then call guest-device again
    unawaited(NotificationService.instance.registerAsGuest());
  }


  Future<void> logoutAllDevices() async {
    final tokenToRevoke = await _clearLocalSession();
    if (tokenToRevoke != null && tokenToRevoke.isNotEmpty) {
      await ApiService.instance.logout(tokenToRevoke, logoutAllDevices: true);
    }
    unawaited(NotificationService.instance.registerAsGuest());
  }

  // ---- Comments Program methods ----

  final Map<String, int> userAddedComments = {};

  List<Comment> getComments(String articleId) {
    return articleComments[articleId] ?? [];
  }

  int getDisplayCommentCount(String articleId, int baseCount) {
    return baseCount + (userAddedComments[articleId] ?? 0);
  }

  int getCommentCount(String articleId) {
    return getDisplayCommentCount(articleId, 0);
  }

  void addComment(String articleId, String text) {
    if (!articleComments.containsKey(articleId)) {
      articleComments[articleId] = [];
    }

    final newComment = Comment(
      id: 'c_${DateTime.now().millisecondsSinceEpoch}',
      username: isLoggedIn ? userName : 'Guest User',
      avatarUrl: profileImagePath ?? '',
      text: text,
      postedAt: DateTime.now(),
      likes: 0,
    );

    articleComments[articleId]!.insert(0, newComment);
    userAddedComments[articleId] = (userAddedComments[articleId] ?? 0) + 1;
    notifyListeners();
  }

  void setComments(String articleId, List<Comment> comments) {
    articleComments[articleId] = comments;
    notifyListeners();
  }

  void addReply(String articleId, String parentCommentId, String text) {
    if (!articleComments.containsKey(articleId)) {
      articleComments[articleId] = [];
    }
    final comments = articleComments[articleId]!;

    // Find parent comment
    for (var comment in comments) {
      if (comment.id == parentCommentId) {
        comment.replies.add(Comment(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          username: userName.isNotEmpty ? userName : 'Guest User',
          avatarUrl: profileImagePath ?? '',
          text: text,
          postedAt: DateTime.now(),
        ));
        userAddedComments[articleId] = (userAddedComments[articleId] ?? 0) + 1;
        break;
      }
    }
    notifyListeners();
  }

  void toggleCommentLike(String articleId, String commentId) {
    final comments = articleComments[articleId] ?? [];

    // Simple deep search for the comment (including replies)
    bool found = false;
    for (var comment in comments) {
      if (comment.id == commentId) {
        comment.isLikedByUser = !comment.isLikedByUser;
        comment.likes += comment.isLikedByUser ? 1 : -1;
        found = true;
        break;
      }
      for (var reply in comment.replies) {
        if (reply.id == commentId) {
          reply.isLikedByUser = !reply.isLikedByUser;
          reply.likes += reply.isLikedByUser ? 1 : -1;
          found = true;
          break;
        }
      }
      if (found) break;
    }
    notifyListeners();
  }

  void reportComment(String articleId, String commentId) {
    final comments = articleComments[articleId] ?? [];

    bool found = false;
    for (var comment in comments) {
      if (comment.id == commentId) {
        comment.isReported = true;
        found = true;
        break;
      }
      for (var reply in comment.replies) {
        if (reply.id == commentId) {
          reply.isReported = true;
          found = true;
          break;
        }
      }
      if (found) break;
    }
    notifyListeners();
  }

  // ---- Reporter Program methods ----

  /// Instantly registers the current account as a Reporter. No approval
  /// needed for the role itself — only individual posts need review.
  void registerAsReporter() {
    isReporter = true;
    notifyListeners();
    _persist();
  }

  /// Permanently marks the account as upload-verified after successful OTP verification.
  void markUploadVerified() {
    uploadVerified = true;
    notifyListeners();
    _persist();
  }

  /// Creates a new post in "pending review" state. Call only after
  /// confirming `uploadVerified` is true (verify via OTP first if not).
  ReporterPost submitReporterPost({
    required PostType type,
    required String caption,
    required String category,
    required String mediaUrl,
  }) {
    final post = ReporterPost(
      id: 'post_${DateTime.now().millisecondsSinceEpoch}',
      reporterName: userName,
      type: type,
      caption: caption,
      category: category,
      mediaUrl: mediaUrl,
      submittedAt: DateTime.now(),
    );
    reporterPosts.insert(0, post);
    notifyListeners();
    return post;
  }

  /// Demo admin action: approves a pending post and credits 1 token.
  void adminApprovePost(String postId) {
    final post = reporterPosts.firstWhere((p) => p.id == postId);
    post.status = PostStatus.approved;
    reporterTokens += 1;
    notifyListeners();
    _persist();
  }

  /// Demo admin action: rejects a pending post — no token awarded.
  void adminRejectPost(String postId, [String? reason]) {
    final post = reporterPosts.firstWhere((p) => p.id == postId);
    post.status = PostStatus.rejected;
    post.rejectionReason = reason;
    notifyListeners();
  }

  /// Requests a payout once the reporter has at least 100 tokens. Deducts
  /// 100 tokens immediately and files the request for (demo) admin payout.
  /// Returns null if the reporter doesn't have enough tokens yet.
  RedeemRequest? requestRedeem(String upiId) {
    if (reporterTokens < tokensNeededToRedeem) return null;
    reporterTokens -= tokensNeededToRedeem;
    final request = RedeemRequest(
      id: 'redeem_${DateTime.now().millisecondsSinceEpoch}',
      tokensRedeemed: tokensNeededToRedeem,
      amountRupees: tokensNeededToRedeem * rupeesPerToken,
      upiId: upiId,
      requestedAt: DateTime.now(),
    );
    redeemRequests.insert(0, request);
    notifyListeners();
    _persist();
    return request;
  }

  /// Demo admin action: advances a redeem request's status.
  void adminUpdateRedeemStatus(String requestId, RedeemStatus status) {
    final request = redeemRequests.firstWhere((r) => r.id == requestId);
    request.status = status;
    notifyListeners();
  }
}
