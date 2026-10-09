import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/news_article.dart';
import '../models/redeem_request.dart';
import '../models/reporter_post.dart';
import '../models/app_notification.dart';
import '../services/api_service.dart';
import '../services/content_engagement_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../repositories/ad_repository.dart';
import '../localization/location_translations.dart';
import '../core/utils/indian_mobile.dart';
import '../core/utils/log_safe.dart';
import '../core/utils/url_normalizer.dart';

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
  static const _ugcMobileKey = 'ugc_verified_mobile';
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
  Set<String> blockedUserIds = {};
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

  /// The `lang` every feed request sends: the news language, or `all`.
  ///
  /// Always explicit. With no `lang` the backend picks its own default —
  /// `en` for a guest, the account's language once logged in — so the same
  /// reader saw different Home / Spotlight stories before and after login.
  String get feedLang => _contentLanguage ?? 'all';

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
      debugPrint(
          '[AppState] Failed to persist installation secret in secure storage: $e');
    }
    // Clean up any legacy plaintext secret from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_installationSecretKey);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setDeviceId(String id) async {
    deviceId = id;
    try {
      await _secureStorage.write(key: _deviceIdKey, value: id);
    } catch (e) {
      debugPrint(
          '[AppState] Failed to persist device ID in secure storage: $e');
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
  int locationPromptShownCount = 0;
  int? locationPromptLastShownAtMs;
  int? locationPromptDismissedAtMs;
  int? locationPermissionDeniedAtMs;
  bool locationPermissionDeniedForever = false;

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

  /// True once the signed-in account has registered for the Reporter
  /// Program. This is instant (no approval needed) — only individual posts
  /// need admin review. Cleared on logout; restored per account by
  /// [refreshRolesFromServer].
  bool isReporter = false;

  /// Accounts (by user id) that joined as reporter on this device. The
  /// backend has no reporter flag, so this is what keeps "Join as reporter"
  /// from showing again after logging out and back in.
  final Set<String> _reporterAccountIds = {};
  static const _reporterAccountsKey = 'reporter_account_ids';

  /// Whether the Post tab should skip the "Join as reporter" screen. A
  /// verified UGC mobile means the account already went through it.
  bool get hasJoinedAsReporter => isReporter || uploadVerified;

  /// UGC phone verification (one-time per account). Cached only for UX —
  /// the backend is the source of truth and re-demands verification with
  /// "Mobile number is not verified." if this ever drifts.
  bool ugcMobileVerified = false;

  /// The 10-digit mobile the backend returned when verification succeeded.
  /// Every UGC submit / upload-media call must send exactly this.
  String ugcVerifiedMobile = '';

  /// The account's verified mobile from GET /auth/me/ (only when
  /// mobile_verified is true) — what the profile shows as "+91 …".
  String profileVerifiedMobile = '';

  /// Set when the backend answers "Daily upload limit reached."; uploads stay
  /// disabled until this moment (local midnight).
  DateTime? ugcUploadLockedUntil;

  /// Set when the backend answers "Uploader is blocked.". The backend block
  /// lasts until an admin lifts it; the app has no endpoint that reports the
  /// unblock, so it allows one submit probe per day — the backend re-blocks
  /// it if the block still stands, and an unblocked reporter gets through.
  DateTime? ugcBlockedAt;

  static const _ugcBlockCooldown = Duration(hours: 24);

  /// True when the account has a usable verified UGC mobile.
  /// Only the backend bridge (verify-firebase-phone / verify-otp) sets it,
  /// via [markUgcMobileVerified] — never the login/profile phone.
  bool get uploadVerified =>
      ugcMobileVerified && ugcVerifiedMobile.length == 10;

  bool get isUgcDailyLimitActive =>
      ugcUploadLockedUntil != null &&
      DateTime.now().isBefore(ugcUploadLockedUntil!);

  bool get isUgcUploaderBlocked =>
      ugcBlockedAt != null &&
      DateTime.now().difference(ugcBlockedAt!) < _ugcBlockCooldown;

  /// 1 token = ₹5. Reporters can request a redeem once this reaches 100.
  int reporterTokens = 0;

  final List<ReporterPost> reporterPosts = [];
  final List<RedeemRequest> redeemRequests = [];

  // ---- Reporter Dashboard Counts ----
  int? reporterPendingCount;
  int? reporterApprovedCount;
  int? reporterPublishedCount;
  int? reporterRejectedCount;
  int? reporterTotalSubmissions;

  // Dashboard counts exactly as GET /ugc/reporter/dashboard/ sends them —
  // never calculated on the phone (backend contract). 0 until loaded.
  int get pendingCount => reporterPendingCount ?? 0;
  int get approvedCount => reporterApprovedCount ?? 0;
  int get publishedCount => reporterPublishedCount ?? 0;
  int get rejectedCount => reporterRejectedCount ?? 0;
  int get totalSubmissionsCount => reporterTotalSubmissions ?? 0;

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
    _reporterAccountIds
      ..clear()
      ..addAll(prefs.getStringList(_reporterAccountsKey) ?? const []);
    ugcMobileVerified = prefs.getBool('ugc_mobile_verified') ?? false;
    // The number itself lives in encrypted storage (read below); a plaintext
    // copy from older builds is migrated and then removed.
    final legacyUgcMobile = prefs.getString('ugc_verified_mobile') ?? '';
    final lockedMs = prefs.getInt('ugc_upload_locked_until_ms');
    ugcUploadLockedUntil =
        lockedMs == null ? null : DateTime.fromMillisecondsSinceEpoch(lockedMs);
    final blockedMs = prefs.getInt('ugc_blocked_at_ms');
    ugcBlockedAt = blockedMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(blockedMs);
    // The legacy flag was set by an OTP sheet that verified a placeholder
    // number, so it proves nothing about the real mobile. Drop it.
    await prefs.remove('uploadVerified');
    reporterTokens = prefs.getInt('reporterTokens') ?? 0;
    readingFontSize = prefs.getDouble('readingFontSize') ?? 19.0;
    notifications = _decodeLocalInbox(prefs.getString(_localInboxKey));
    _loadDeviceSavedStories(prefs);

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

    // Read installationSecret from secure storage.
    // If a legacy plaintext secret exists in shared_preferences, migrate it to secure storage and purge plaintext.
    try {
      installationSecret =
          await _secureStorage.read(key: _installationSecretKey);
    } catch (_) {
      installationSecret = null;
    }
    if (installationSecret == null || installationSecret!.isEmpty) {
      final legacySecret = prefs.getString(_installationSecretKey);
      if (legacySecret != null && legacySecret.isNotEmpty) {
        installationSecret = legacySecret;
        try {
          await _secureStorage.write(
              key: _installationSecretKey, value: legacySecret);
        } catch (_) {}
      }
    }
    // Always purge plaintext copy from SharedPreferences to avoid leakage in device backups
    await prefs.remove(_installationSecretKey);

    // Auth tokens come from secure storage
    try {
      authToken = await _secureStorage.read(key: _authTokenKey);
      refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      sessionId = await _secureStorage.read(key: _sessionIdKey);
      // UGC verified mobile: encrypted storage, scoped to this account.
      ugcVerifiedMobile =
          await _secureStorage.read(key: _ugcMobileKey) ?? legacyUgcMobile;
      if (legacyUgcMobile.isNotEmpty) {
        await _secureStorage.write(key: _ugcMobileKey, value: legacyUgcMobile);
      }
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
      // Whoever logs in next gets their own reporter status on login.
      isReporter = false;
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
    locationPromptShownCount =
        prefs.getInt('locationPromptShownCount') ?? (locationPrompted ? 1 : 0);
    locationPromptLastShownAtMs = prefs.getInt('locationPromptLastShownAtMs');
    locationPromptDismissedAtMs = prefs.getInt('locationPromptDismissedAtMs');
    locationPermissionDeniedAtMs = prefs.getInt('locationPermissionDeniedAtMs');
    locationPermissionDeniedForever =
        prefs.getBool('locationPermissionDeniedForever') ?? false;
    hasValidLocation = prefs.getBool('hasValidLocation') ?? false;
    pushNotificationsEnabled =
        prefs.getBool('pushNotificationsEnabled') ?? true;

    likedItemIds = (prefs.getStringList('likedItemIds') ?? []).toSet();
    dislikedItemIds = (prefs.getStringList('dislikedItemIds') ?? []).toSet();
    bookmarkedItemIds =
        (prefs.getStringList('bookmarkedItemIds') ?? []).toSet();
    // Telugu names of the reader's places, as the location API sent them.
    try {
      final raw = prefs.getString(_locationNamesTeKey);
      if (raw != null && raw.isNotEmpty) {
        LocationTranslations.restoreLearned(
            Map<String, String>.from(jsonDecode(raw) as Map));
      }
    } catch (_) {}
    blockedUserIds = (prefs.getStringList('blockedUserIds') ?? []).toSet();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasOnboarded', hasOnboarded);
    await prefs.setString('language', language);
    if (profileImageUrl != null && profileImageUrl!.isNotEmpty) {
      await prefs.setString('profileImageUrl', profileImageUrl!);
    }
    await prefs.setBool('content_language_prompted', contentLanguagePrompted);
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
    await prefs.setStringList(
        _reporterAccountsKey, _reporterAccountIds.toList());
    await prefs.setBool('ugc_mobile_verified', ugcMobileVerified);
    await prefs.remove('ugc_verified_mobile'); // kept in secure storage
    if (ugcUploadLockedUntil != null) {
      await prefs.setInt('ugc_upload_locked_until_ms',
          ugcUploadLockedUntil!.millisecondsSinceEpoch);
    } else {
      await prefs.remove('ugc_upload_locked_until_ms');
    }
    if (ugcBlockedAt != null) {
      await prefs.setInt(
          'ugc_blocked_at_ms', ugcBlockedAt!.millisecondsSinceEpoch);
    } else {
      await prefs.remove('ugc_blocked_at_ms');
    }
    await prefs.setInt('reporterTokens', reporterTokens);
    await prefs.setStringList('likedItemIds', likedItemIds.toList());
    await prefs.setStringList('dislikedItemIds', dislikedItemIds.toList());
    await prefs.setStringList('bookmarkedItemIds', bookmarkedItemIds.toList());
    await prefs.setString(
        _locationNamesTeKey, jsonEncode(LocationTranslations.learnedNames));
    await prefs.setBool('locationPrompted', locationPrompted);
    await prefs.setInt('locationPromptShownCount', locationPromptShownCount);
    if (locationPromptLastShownAtMs != null) {
      await prefs.setInt(
          'locationPromptLastShownAtMs', locationPromptLastShownAtMs!);
    } else {
      await prefs.remove('locationPromptLastShownAtMs');
    }
    if (locationPromptDismissedAtMs != null) {
      await prefs.setInt(
          'locationPromptDismissedAtMs', locationPromptDismissedAtMs!);
    } else {
      await prefs.remove('locationPromptDismissedAtMs');
    }
    if (locationPermissionDeniedAtMs != null) {
      await prefs.setInt(
          'locationPermissionDeniedAtMs', locationPermissionDeniedAtMs!);
    } else {
      await prefs.remove('locationPermissionDeniedAtMs');
    }
    await prefs.setBool(
        'locationPermissionDeniedForever', locationPermissionDeniedForever);
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
    // Bookmarks made as a guest move into the account that just logged in.
    unawaited(ContentEngagementService.instance
        .syncGuestBookmarks()
        .catchError((Object e) => debugPrint('[Bookmark] guest copy: $e')));
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
      if (serverImage != null && serverImage.trim().isNotEmpty) {
        final url = UrlNormalizer.normalize(serverImage);
        if (url.startsWith('http')) profileImageUrl = url;
      }

      final phone = IndianMobile.normalize(
          me['phone']?.toString() ?? me['mobile']?.toString());
      // The login phone is NOT the UGC verified mobile: that is set only by
      // the backend verification bridge.
      if (phone != null && phone.length == 10) {
        userPhone = phone;
      } else if (me['phone'] != null) {
        userPhone = me['phone'].toString();
      }
      if (me['id'] != null) userId = me['id'].toString();
      // Only UGC-specific fields here: me's own `mobile` is the login phone,
      // which is never the verified UGC mobile.
      // GET /auth/me/: verified_mobile + mobile_verified (backend contract).
      // Shown on the profile only when mobile_verified is true.
      final meMobile = me['mobile_verified'] == true
          ? IndianMobile.normalize(me['verified_mobile']?.toString())
          : null;
      profileVerifiedMobile =
          (meMobile != null && meMobile.length == 10) ? meMobile : '';
      final ugcProfile = me['ugc_profile'];
      final serverMobile = profileVerifiedMobile.isNotEmpty
          ? profileVerifiedMobile
          : ugcProfile is Map
              ? serverVerifiedMobile(ugcProfile)
              : IndianMobile.normalize(me['ugc_verified_mobile']?.toString());
      if (!uploadVerified &&
          serverMobile != null &&
          serverMobile.length == 10) {
        await markUgcMobileVerified(serverMobile);
      }
      // Apply the account's saved interface language. Without this the
      // field was write-only: a returning reader on a new device got the
      // default language regardless of what they had chosen.
      final serverLang = (me['preferred_language'] ??
              me['preferredLanguage'] ??
              (me['profile'] is Map
                  ? me['profile']['preferred_language']
                  : null))
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

      // Maintain the active UI theme choice across login and guest states.
      // Do not let server defaults overwrite the active theme from light to dark.
      // Instead, keep the current theme and sync it to the backend profile.
      unawaited(_syncProfileToBackend(theme: themeMode.name));

      final serverFont = me['font_size'];
      if (serverFont != null) {
        final parsed = double.tryParse(serverFont.toString());
        if (parsed != null) await setReadingFontSize(parsed);
      }

      await _restoreReporterStatus(me);
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
  /// skippable on every future launch — only language+location gate the splash skip.
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
    locationPromptShownCount += 1;
    locationPromptLastShownAtMs = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
    _persist();
  }

  void markLocationPromptDismissed() {
    locationPrompted = true;
    locationPromptDismissedAtMs = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
    _persist();
  }

  void markLocationPermissionDenied({bool forever = false}) {
    locationPrompted = true;
    locationPermissionDeniedAtMs = DateTime.now().millisecondsSinceEpoch;
    locationPermissionDeniedForever = forever;
    notifyListeners();
    _persist();
  }

  bool shouldAutoPromptLocation({DateTime? now}) {
    if (hasValidLocation || locationPermissionDeniedForever) return false;
    if (locationPromptShownCount >= 2) return false;

    final current = now ?? DateTime.now();
    bool olderThan(int? epochMs, Duration cooldown) {
      if (epochMs == null) return true;
      final date = DateTime.fromMillisecondsSinceEpoch(epochMs);
      return current.difference(date) >= cooldown;
    }

    if (!olderThan(locationPromptDismissedAtMs, const Duration(days: 3))) {
      return false;
    }
    if (!olderThan(locationPermissionDeniedAtMs, const Duration(days: 7))) {
      return false;
    }
    if (!olderThan(locationPromptLastShownAtMs, const Duration(hours: 12))) {
      return false;
    }
    return true;
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

  static const _locationNamesTeKey = 'location_names_te_v1';

  /// Place names are shown in Telugu when the app is in Telugu.
  bool get showsTeluguPlaceNames =>
      uiLanguageCode == 'te' || language.toLowerCase().contains('telugu');

  String get displayLocation {
    if (showsTeluguPlaceNames) {
      return LocationTranslations.formatDisplayLocation(
        state: stateName,
        district: district,
        city: city,
        subdistrict: subdistrict,
        village: village,
      );
    }
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
    locationPermissionDeniedForever = false;
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
    setBookmarked(itemId, !bookmarkedItemIds.contains(itemId));
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
  ///
  /// Also records it as the reader's latest decision for [itemId], which
  /// [isStoryBookmarked] trusts over any `is_bookmarked` a screen still holds
  /// from an earlier fetch.
  void setBookmarked(String itemId, bool bookmarked) {
    if (itemId.isEmpty) return;
    final decisionChanged = _bookmarkDecisions[itemId] != bookmarked;
    _bookmarkDecisions[itemId] = bookmarked;
    final changed = bookmarked
        ? bookmarkedItemIds.add(itemId)
        : bookmarkedItemIds.remove(itemId);
    if (!changed && !decisionChanged) return;
    notifyListeners();
    if (changed) _persist();
  }

  /// Bookmark state set this session, by the reader or from the server's
  /// bookmark list. Each screen keeps its own copy of a story, so the copy's
  /// `is_bookmarked` goes stale the moment the story is bookmarked or removed
  /// somewhere else; this map is what keeps every screen in agreement.
  final Map<String, bool> _bookmarkDecisions = {};

  @visibleForTesting
  void resetBookmarksForTest() {
    bookmarkedItemIds.clear();
    _bookmarkDecisions.clear();
    _deviceSavedStories.clear();
  }

  /// The id the bookmark API and the local state are keyed by.
  static String bookmarkKey(NewsArticle story) =>
      story.id.isNotEmpty ? story.id : story.slug;

  /// Whether [story] is bookmarked — the one question every save icon and
  /// menu asks.
  bool isStoryBookmarked(NewsArticle story) {
    final id = bookmarkKey(story);
    if (id.isEmpty) return story.isBookmarked;
    final decided = _bookmarkDecisions[id];
    if (decided != null) return decided;
    return story.isBookmarked || bookmarkedItemIds.contains(id);
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

  // ---- Guest bookmarks kept on the device ----
  //
  // The server has no guest bookmarks, so a guest's are stored here (whole
  // story, so the Saved screen can show and open it). On login they are
  // copied into the account and removed from here
  // (ContentEngagementService.syncGuestBookmarks).

  static const _deviceSavedKey = 'device_saved_stories_v1';
  final Map<String, Map<String, dynamic>> _deviceSavedStories = {};

  /// Newest first.
  List<NewsArticle> get deviceSavedStories => _deviceSavedStories.values
      .map((json) => NewsArticle.fromJson(json)..isBookmarked = true)
      .toList()
      .reversed
      .toList();

  void _loadDeviceSavedStories(SharedPreferences prefs) {
    _deviceSavedStories.clear();
    final raw = prefs.getString(_deviceSavedKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw);
      if (map is Map) {
        map.forEach((k, v) {
          if (v is Map) {
            _deviceSavedStories[k.toString()] = Map<String, dynamic>.from(v);
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _persistDeviceSavedStories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_deviceSavedKey, jsonEncode(_deviceSavedStories));
    } catch (e) {
      debugPrint('[AppState] saving device stories failed: $e');
    }
  }

  Future<void> saveStoryOnDevice(NewsArticle story) async {
    final id = story.id.isNotEmpty ? story.id : story.slug;
    if (id.isEmpty) return;
    _deviceSavedStories.remove(id); // re-insert = newest
    _deviceSavedStories[id] = story.toJson();
    setBookmarked(id, true);
    await _persistDeviceSavedStories();
  }

  Future<void> removeDeviceSavedStory(String id) async {
    if (_deviceSavedStories.remove(id) == null) return;
    notifyListeners();
    await _persistDeviceSavedStories();
  }

  bool isSavedOnDevice(String id) => _deviceSavedStories.containsKey(id);

  // ---- Notification inbox (no login required) ----
  //
  // The inbox works for guests: the backend inbox is fetched with the
  // device's X-Device-ID (and the account token when logged in), and every
  // push the app receives is also kept on the device, so a reader who never
  // logs in still has a history of what they were sent.

  static const _localInboxKey = 'local_notification_inbox_v1';
  static const _localInboxMax = 60;

  static List<AppNotification> _decodeLocalInbox(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return list
          .whereType<Map>()
          .map((m) => AppNotification.fromJson(Map<String, dynamic>.from(m)))
          .where((n) => n.id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveLocalInbox() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final capped = notifications.take(_localInboxMax).toList();
      await prefs.setString(
          _localInboxKey, jsonEncode(capped.map((n) => n.toJson()).toList()));
    } catch (e) {
      debugPrint('[AppState] saving notification inbox failed: $e');
    }
  }

  /// Same notification, whichever id each side used.
  static String _inboxKey(AppNotification n) =>
      (n.notificationId?.isNotEmpty ?? false) ? n.notificationId! : n.id;

  /// Records a push the app just received (foreground, or opened from the
  /// tray). Safe to call twice for the same message.
  Future<void> recordPushNotification({
    required Map<String, dynamic> data,
    String? title,
    String? body,
    String? messageId,
  }) async {
    final notificationId = data['notification_id']?.toString();
    final id = notificationId ??
        'push_${messageId ?? DateTime.now().millisecondsSinceEpoch}';
    final incoming = AppNotification.fromJson({
      ...data,
      'id': id,
      if (notificationId != null) 'notification_id': notificationId,
      'title': title ?? data['title']?.toString() ?? '',
      'body': body ?? data['body']?.toString() ?? '',
      'created_at':
          data['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      'is_read': false,
    });
    if (incoming.title.isEmpty && incoming.message.isEmpty) return;

    final key = _inboxKey(incoming);
    if (notifications.any((n) => _inboxKey(n) == key)) return;
    notifications = [incoming, ...notifications];
    notifyListeners();
    await _saveLocalInbox();
  }

  /// Loads the backend inbox and merges it with pushes kept on the device.
  /// The backend copy wins for anything both sides have; a local read mark
  /// is never undone by a stale server flag.
  Future<void> fetchNotifications() async {
    try {
      final remote = await ApiService.instance.getNotifications();
      final readLocally = {
        for (final n in notifications)
          if (n.isRead) _inboxKey(n),
      };
      final remoteKeys = <String>{};
      for (final n in remote) {
        final key = _inboxKey(n);
        remoteKeys.add(key);
        if (readLocally.contains(key)) n.isRead = true;
      }
      final merged = [
        ...remote,
        ...notifications.where((n) => !remoteKeys.contains(_inboxKey(n))),
      ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      notifications = merged;
      notifyListeners();
      await _saveLocalInbox();
    } catch (_) {}
  }

  /// Only ids the backend issued can be marked read on the server; locally
  /// generated push ids stay on the device.
  static bool _isServerNotification(AppNotification n) =>
      !n.id.startsWith('push_');

  void markNotificationRead(String id) {
    final index = notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !notifications[index].isRead) {
      notifications[index].isRead = true;
      notifyListeners();
      if (_isServerNotification(notifications[index])) {
        ApiService.instance.markNotificationRead(id);
      }
      unawaited(_saveLocalInbox());
    }
  }

  void markAllNotificationsRead() {
    bool changed = false;
    for (var n in notifications) {
      if (!n.isRead) {
        n.isRead = true;
        changed = true;
        if (_isServerNotification(n)) {
          ApiService.instance.markNotificationRead(n.id);
        }
      }
    }
    if (changed) {
      notifyListeners();
      unawaited(_saveLocalInbox());
    }
  }

  /// Avatar URL the backend holds, when it has one.
  ///
  /// Distinct from [profileImagePath], which is a local file the reader
  /// picked. There is no upload endpoint, so a locally picked image stays on
  /// the device — see the report accompanying this change.
  String? profileImageUrl;

  /// The server avatar as an absolute URL, or null when none is set.
  String? get profilePhotoUrl {
    final raw = profileImageUrl;
    if (raw == null || raw.trim().isEmpty) return null;
    final url = UrlNormalizer.normalize(raw);
    return url.startsWith('http') ? url : null;
  }

  /// The image every avatar in the app draws: the reader's fresh local pick
  /// first (shown while it uploads), otherwise the server photo.
  ///
  /// After a successful upload [profileImagePath] is cleared, so screens
  /// that only looked at the local path fell back to the initial — the
  /// photo appeared not to have been saved.
  ImageProvider? get profileAvatar {
    final path = profileImagePath;
    if (path != null && path.isNotEmpty) {
      if (path.startsWith('http')) return CachedNetworkImageProvider(path);
      final file = File(path);
      if (file.existsSync()) return FileImage(file);
    }
    final url = profilePhotoUrl;
    return url == null ? null : CachedNetworkImageProvider(url);
  }

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

      final rawImage =
          (updated['profile_image'] ?? updated['profileImage'])?.toString();
      final serverImage = rawImage == null || rawImage.trim().isEmpty
          ? null
          : UrlNormalizer.normalize(rawImage);
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
    profileVerifiedMobile = '';
    // Bookmarks belong to the account that made them — both the server ones
    // and citizen posts kept on the device. Leaving the ids behind showed the
    // previous account's bookmarks to whoever logged in next; the next
    // account's own are restored from the server.
    bookmarkedItemIds.clear();
    _bookmarkDecisions.clear();
    _deviceSavedStories.clear();
    unawaited(_persistDeviceSavedStories());
    // The reporter role belongs to the account too; it is restored per
    // account on the next login (see _restoreReporterStatus).
    isReporter = false;
    reporterPosts.clear();
    reporterPendingCount = null;
    reporterApprovedCount = null;
    reporterPublishedCount = null;
    reporterRejectedCount = null;
    reporterTotalSubmissions = null;
    // UGC verification belongs to the account, not the device.
    ugcMobileVerified = false;
    ugcVerifiedMobile = '';
    await _writeUgcMobile(null);
    ugcUploadLockedUntil = null;
    ugcBlockedAt = null;
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

  bool isUserBlocked(String? idOrUsername) {
    if (idOrUsername == null || idOrUsername.isEmpty) return false;
    return blockedUserIds.contains(idOrUsername);
  }

  Future<void> blockUser(String idOrUsername) async {
    if (idOrUsername.isEmpty) return;
    blockedUserIds.add(idOrUsername);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('blockedUserIds', blockedUserIds.toList());
    notifyListeners();
  }

  Future<void> unblockUser(String idOrUsername) async {
    if (idOrUsername.isEmpty) return;
    blockedUserIds.remove(idOrUsername);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('blockedUserIds', blockedUserIds.toList());
    notifyListeners();
  }

  List<Comment> getComments(String articleId) {
    final list = articleComments[articleId] ?? [];
    if (blockedUserIds.isEmpty) return list;
    return list
        .where((c) => !isUserBlocked(c.authorId) && !isUserBlocked(c.username))
        .map((c) {
      if (c.replies.isNotEmpty) {
        c.replies.removeWhere(
            (r) => isUserBlocked(r.authorId) || isUserBlocked(r.username));
      }
      return c;
    }).toList();
  }

  /// The server count last shown for each story, and the one in effect when
  /// this reader added a comment.
  final Map<String, int> _commentBaseSeen = {};
  final Map<String, int> _commentBaseAtAdd = {};

  /// Count to show: the server's, plus this reader's own new comments only
  /// until the server count includes them. It used to add them on top of a
  /// server count that already had them — one comment showed as 2.
  int getDisplayCommentCount(String articleId, int baseCount) {
    final added = userAddedComments[articleId] ?? 0;
    if (added == 0) {
      _commentBaseSeen[articleId] = baseCount;
      return baseCount;
    }
    final before =
        _commentBaseAtAdd[articleId] ?? _commentBaseSeen[articleId] ?? baseCount;
    final optimistic = before + added;
    return baseCount > optimistic ? baseCount : optimistic;
  }

  /// This reader posted a comment (or reply) on [articleId].
  void recordUserComment(String articleId) {
    _commentBaseAtAdd.putIfAbsent(
        articleId, () => _commentBaseSeen[articleId] ?? 0);
    userAddedComments[articleId] = (userAddedComments[articleId] ?? 0) + 1;
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
      avatarUrl: profilePhotoUrl ?? '',
      text: text,
      postedAt: DateTime.now(),
      likes: 0,
    );

    articleComments[articleId]!.insert(0, newComment);
    recordUserComment(articleId);
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
          avatarUrl: profilePhotoUrl ?? '',
          text: text,
          postedAt: DateTime.now(),
        ));
        recordUserComment(articleId);
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
    final id = userId;
    if (id != null && id.isNotEmpty) _reporterAccountIds.add(id);
    notifyListeners();
    _persist();
  }

  /// Decides whether the signed-in account has already joined as reporter,
  /// so "Join as reporter" is not shown again. In order: the backend's own
  /// flag if it ever sends one, this device's record for the account, then
  /// the reporter dashboard — any past submission means they joined.
  Future<void> _restoreReporterStatus(Map<String, dynamic> me) async {
    final id = userId;
    var joined = isReporter ||
        me['is_reporter'] == true ||
        (id != null && _reporterAccountIds.contains(id));
    if (!joined) {
      try {
        final dash = await ApiService.instance.getReporterDashboard();
        final total = _applyDashboardCounts(dash) ?? 0;
        final recent = dash['recent_submissions'];
        joined = total > 0 || (recent is List && recent.isNotEmpty);
      } catch (e) {
        // No reporter profile yet, or offline: leave the flag as it is.
        debugPrint('[AppState] reporter dashboard probe: $e');
      }
    }
    if (!joined) return;
    isReporter = true;
    if (id != null && id.isNotEmpty) _reporterAccountIds.add(id);
  }

  /// Records the backend-confirmed UGC mobile. [mobile] must be the
  /// 10-digit value the backend returned (or verified, in the SMS fallback).
  Future<void> markUgcMobileVerified(String mobile) async {
    ugcMobileVerified = true;
    ugcVerifiedMobile = mobile;
    notifyListeners();
    await _writeUgcMobile(mobile);
    await _persist();
  }

  /// The verified mobile the backend reports for this account, if its reply
  /// carries one: `verified_mobile` / `mobile` (top level, or under
  /// `profile` / `ugc_profile`), with `mobile_verified` not false.
  @visibleForTesting
  static String? serverVerifiedMobile(Map<dynamic, dynamic> body) {
    String? from(Map<dynamic, dynamic> m) {
      if (m['mobile_verified'] == false || m['is_mobile_verified'] == false) {
        return null;
      }
      final raw = m['verified_mobile'] ?? m['ugc_verified_mobile'];
      final flagged = m['mobile_verified'] == true ||
          m['is_mobile_verified'] == true;
      final mobile =
          IndianMobile.normalize((raw ?? (flagged ? m['mobile'] : null))
              ?.toString());
      return (mobile != null && mobile.length == 10) ? mobile : null;
    }

    final top = from(body);
    if (top != null) return top;
    for (final k in ['ugc_profile', 'profile', 'reporter']) {
      final nested = body[k];
      if (nested is Map) {
        final v = from(nested);
        if (v != null) return v;
      }
    }
    return null;
  }

  // --- Whose Firebase phone session is kept on this phone ----------------
  //
  // After a successful verification the Firebase phone session is kept (not
  // signed out) so the next time this account needs verifying, a fresh ID
  // token can be sent to verify-firebase-phone/ BEFORE any OTP is sent. The
  // session is tagged with the VARADHI account that made it, and only that
  // account may reuse it — another account gets a new OTP.

  static const _ugcFirebaseOwnerKey = 'ugc_firebase_session_owner';

  Future<String?> readUgcFirebaseOwner() async {
    try {
      return await _secureStorage.read(key: _ugcFirebaseOwnerKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeUgcFirebaseOwner(String? accountId) async {
    try {
      if (accountId == null || accountId.isEmpty) {
        await _secureStorage.delete(key: _ugcFirebaseOwnerKey);
      } else {
        await _secureStorage.write(key: _ugcFirebaseOwnerKey, value: accountId);
      }
    } catch (e) {
      debugPrint('[AppState] Firebase session owner write failed: $e');
    }
  }

  /// Is this account already verified on the server? Checked before asking
  /// for an OTP (new phone, reinstall). True when it is — nothing to ask.
  Future<bool> syncUgcVerificationFromServer() async {
    if (uploadVerified) return true;
    if (!isLoggedIn) return false;
    try {
      final dash = await ApiService.instance.getReporterDashboard();
      final mobile = serverVerifiedMobile(dash);
      if (mobile != null) {
        await markUgcMobileVerified(mobile);
        return true;
      }
    } catch (e) {
      debugPrint('[AppState] verification check: ${LogSafe.scrub(e)}');
    }
    return false;
  }

  /// Forgets the cached verification, e.g. after the backend says the
  /// mobile is not (or no longer) verified.
  Future<void> clearUgcVerification() async {
    ugcMobileVerified = false;
    ugcVerifiedMobile = '';
    notifyListeners();
    await _writeUgcMobile(null);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('ugc_verified_mobile');
      await prefs.setBool('ugc_mobile_verified', false);
    } catch (_) {}
    await _persist();
  }

  Future<void> _writeUgcMobile(String? mobile) async {
    try {
      if (mobile == null || mobile.isEmpty) {
        await _secureStorage.delete(key: _ugcMobileKey);
      } else {
        await _secureStorage.write(key: _ugcMobileKey, value: mobile);
      }
    } catch (e) {
      debugPrint('[AppState] secure write of UGC mobile failed: $e');
    }
  }

  /// "Daily upload limit reached." — lock uploads until local midnight.
  Future<void> markUgcDailyLimitReached() async {
    final now = DateTime.now();
    ugcUploadLockedUntil = DateTime(now.year, now.month, now.day + 1);
    notifyListeners();
    await _persist();
  }

  /// "Uploader is blocked."
  Future<void> markUgcUploaderBlocked() async {
    ugcBlockedAt = DateTime.now();
    notifyListeners();
    await _persist();
  }

  /// A submission went through, so any earlier limit/block no longer holds.
  Future<void> clearUgcUploadRestrictions() async {
    if (ugcUploadLockedUntil == null && ugcBlockedAt == null) return;
    ugcUploadLockedUntil = null;
    ugcBlockedAt = null;
    notifyListeners();
    await _persist();
  }

  /// One count from GET /ugc/reporter/dashboard/, or null when the backend
  /// does not send it. Accepts the names seen across backend versions
  /// (`pending_count`, `pending`, `pending_submissions`…) at the top level or
  /// inside `counts` / `status_counts` / `totals` / `stats` / `summary`.
  ///
  /// Null is deliberate: a missing field must not become 0 — that wiped the
  /// +1 a fresh upload had just added and hid the locally loaded posts the
  /// counters otherwise fall back to.
  @visibleForTesting
  static int? dashboardCount(Map<dynamic, dynamic> dash, String status) {
    final names = [
      '${status}_count',
      status,
      '${status}_submissions',
      'total_$status',
      '${status}_total',
    ];
    int? read(Map<dynamic, dynamic> m) {
      for (final n in names) {
        final v = m[n];
        if (v is num) return v.toInt();
        if (v is String && int.tryParse(v.trim()) != null) {
          return int.parse(v.trim());
        }
      }
      return null;
    }

    final top = read(dash);
    if (top != null) return top;
    for (final k in ['counts', 'status_counts', 'totals', 'stats', 'summary']) {
      final nested = dash[k];
      if (nested is Map) {
        final v = read(nested);
        if (v != null) return v;
      }
    }
    return null;
  }

  /// Applies dashboard counts; returns the total (null when not sent).
  int? _applyDashboardCounts(Map<dynamic, dynamic> dash) {
    reporterPendingCount = dashboardCount(dash, 'pending');
    reporterApprovedCount = dashboardCount(dash, 'approved');
    reporterPublishedCount = dashboardCount(dash, 'published');
    reporterRejectedCount = dashboardCount(dash, 'rejected');
    // total_submissions / total / total_count / submissions_count.
    final total =
        dashboardCount(dash, 'total') ?? dashboardCount(dash, 'submissions');
    reporterTotalSubmissions = total;
    return total;
  }

  bool _isRefreshingReporterDashboard = false;

  /// Fetches latest reporter dashboard counts and updates in-memory stats.
  Future<void> refreshReporterDashboard() async {
    if (!isLoggedIn) return;
    if (_isRefreshingReporterDashboard) return;
    _isRefreshingReporterDashboard = true;
    try {
      final dash = await ApiService.instance.getReporterDashboard();
      final total = _applyDashboardCounts(dash);
      // The dashboard may report the account's verified mobile.
      final serverMobile = serverVerifiedMobile(dash);
      if (!uploadVerified && serverMobile != null) {
        await markUgcMobileVerified(serverMobile);
      }
      debugPrint('[AppState] reporter dashboard keys=${dash.keys.join(',')} '
          'total=$total pending=$reporterPendingCount');
      if ((total ?? 0) > 0) {
        isReporter = true;
        final id = userId;
        if (id != null && id.isNotEmpty) _reporterAccountIds.add(id);
      }
      if (dash['recent_submissions'] is List) {
        final recents = dash['recent_submissions'] as List;
        for (final item in recents) {
          if (item is Map) {
            final p = ApiService.reporterPostFromJson(item);
            final idx =
                reporterPosts.indexWhere((existing) => existing.id == p.id);
            if (idx >= 0) {
              reporterPosts[idx] = p;
            } else {
              reporterPosts.add(p);
            }
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[AppState] refreshReporterDashboard error: $e');
    } finally {
      _isRefreshingReporterDashboard = false;
    }
  }

  void syncReporterPosts(List<ReporterPost> posts) {
    for (final p in posts) {
      final idx = reporterPosts.indexWhere((existing) => existing.id == p.id);
      if (idx >= 0) {
        reporterPosts[idx] = p;
      } else {
        reporterPosts.add(p);
      }
    }
    notifyListeners();
  }

  /// Creates a new post in "pending review" state and updates dashboard counts.
  ReporterPost submitReporterPost({
    String? id,
    required PostType type,
    required String caption,
    required String category,
    required String mediaUrl,
  }) {
    final postId = id != null && id.isNotEmpty
        ? id
        : 'post_${DateTime.now().millisecondsSinceEpoch}';
    final post = ReporterPost(
      id: postId,
      reporterName: userName,
      type: type,
      caption: caption,
      category: category,
      mediaUrl: mediaUrl,
      submittedAt: DateTime.now(),
      status: PostStatus.pending,
    );
    reporterPosts.removeWhere((p) => p.id == postId);
    reporterPosts.insert(0, post);

    // Counts come only from the dashboard (backend contract: refresh after
    // every successful upload, never calculate locally).
    notifyListeners();
    unawaited(refreshReporterDashboard());
    return post;
  }

  void onPostStatusChanged(String postId, PostStatus newStatus,
      [String? rejectionReason]) {
    final idx = reporterPosts.indexWhere((p) => p.id == postId);
    if (idx >= 0) {
      reporterPosts[idx].status = newStatus;
      if (rejectionReason != null) {
        reporterPosts[idx].rejectionReason = rejectionReason;
      }
    }

    // Counts are the backend's (never calculated here): re-read them.
    notifyListeners();
    unawaited(refreshReporterDashboard());
  }

  void onPostsBulkAction(List<String> postIds, PostStatus newStatus) {
    for (final id in postIds) {
      final idx = reporterPosts.indexWhere((p) => p.id == id);
      if (idx >= 0) reporterPosts[idx].status = newStatus;
    }
    notifyListeners();
    unawaited(refreshReporterDashboard());
  }

  /// Admin action: approves a pending post and credits 1 token.
  void adminApprovePost(String postId) {
    onPostStatusChanged(postId, PostStatus.approved);
    reporterTokens += 1;
    _persist();
  }

  /// Admin action: rejects a pending post — no token awarded.
  void adminRejectPost(String postId, [String? reason]) {
    onPostStatusChanged(postId, PostStatus.rejected, reason);
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
