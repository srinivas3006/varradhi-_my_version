import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/navigation/auth_guard.dart';
import '../core/navigation/notification_deep_link_resolver.dart';
import '../core/navigation/notification_navigation_gate.dart';
import '../features/admin/data/repositories/admin_ugc_repository.dart';
import '../features/admin/presentation/screens/admin_ugc_detail_screen.dart';
import '../features/admin/presentation/screens/admin_ugc_screen.dart';
import '../features/admin/presentation/widgets/admin_access_guard.dart';
import '../models/notification_target.dart';
import '../models/news_article.dart';
import '../models/video_item.dart';
import '../repositories/news_article_repository.dart';
import '../repositories/video_repository.dart';
import '../screens/account_login_screen.dart';
import '../screens/bookmarks_screen.dart';
import '../screens/category_screen.dart';
import '../screens/create_post_screen.dart';
import '../screens/my_posts_screen.dart';
import '../screens/news_detail_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/notification_settings_screen.dart';
import '../screens/poll_detail_screen.dart';
import '../screens/poster_detail_screen.dart';
import '../screens/spotlight_screen.dart';
import '../screens/submission_status_screen.dart';
import '../spotlight/spotlight_controller.dart';
import '../features/reels/reel_model.dart';
import '../features/reels/reels_screen.dart';
import '../screens/ugc_feed_screen.dart';
import '../state/app_state.dart';
import 'analytics_queue.dart';
import '../models/app_notification.dart';
import '../theme/app_theme.dart';
import '../widgets/in_app_news_pill.dart';
import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!kIsWeb) {
    await Firebase.initializeApp();
  }
  if (kDebugMode) {
    debugPrint('Handling background notification');
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  bool _initialized = false;
  bool _permissionRequested = false;
  GlobalKey<NavigatorState>? _navigatorKey;
  GlobalKey<ScaffoldMessengerState>? _messengerKey;

  // Deduplication cache for foreground notifications
  final Set<String> _seenNotificationIds = {};

  /// Lightweight initialization during app boot:
  /// Initializes Firebase and registers background/foreground message listeners
  /// WITHOUT prompting permissions or blocking cold startup.
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// High importance so notifications produce a heads-up alert.
  ///
  /// Without an explicit channel, Android 8+ drops FCM messages into a
  /// low-importance fallback channel — they arrive, but silently and without
  /// a banner, which reads as "the push never came".
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'vaaradhi_news',
    'News alerts',
    description: 'Breaking news and updates from Vaaradhi',
    importance: Importance.high,
  );

  /// Pushes that arrive while the app is open: into the tray silently — no
  /// sound, vibration or heads-up popup over the story being read. The
  /// small in-app pill (InAppNewsPill) is the only alert then.
  static const AndroidNotificationChannel _quietChannel =
      AndroidNotificationChannel(
    'vaaradhi_news_quiet',
    'News while reading',
    description: 'News that arrives while you are using the app',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
  );

  /// Creates the channel and wires taps on locally-shown notifications.
  Future<void> _initLocalNotifications() async {
    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // FCM presents these itself in the foreground on iOS; requesting
          // here as well would double-prompt.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = Map<String, dynamic>.from(jsonDecode(payload) as Map);
          debugPrint('[Notifications] tap on local notification');
          unawaited(_handleTap(data));
        } catch (e) {
          debugPrint('[Notifications] could not parse tap payload: $e');
        }
      },
    );

    final android = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_channel);
    await android?.createNotificationChannel(_quietChannel);

    // A notification the app showed itself (it arrived while the app was
    // open) and was tapped after the app had been closed: the app starts
    // fresh, and onDidReceiveNotificationResponse never fires. Without this
    // the tap landed on Home instead of the story.
    try {
      final launch =
          await _localNotifications.getNotificationAppLaunchDetails();
      final payload = launch?.notificationResponse?.payload;
      if ((launch?.didNotificationLaunchApp ?? false) &&
          payload != null &&
          payload.isNotEmpty) {
        final data = jsonDecode(payload);
        if (data is Map) {
          debugPrint('[Notifications] app launched from a local notification');
          unawaited(_handleTap(Map<String, dynamic>.from(data)));
        }
      }
    } catch (e) {
      debugPrint('[Notifications] could not read launch details: $e');
    }
  }

  /// Shows a foreground message in the tray.
  ///
  /// Neither platform displays a push while the app is open — that is the
  /// app's job — so without this an admin testing with the app in the
  /// foreground sees nothing at all.
  /// Adds a tray-opened push to the in-app inbox, already read (the reader
  /// just tapped it). Works without login.
  /// The push's picture: FCM's notification image, else one in `data`.
  static String? _pushImage(RemoteMessage message) {
    for (final url in [
      message.notification?.android?.imageUrl,
      message.notification?.apple?.imageUrl,
    ]) {
      final u = _clean(url);
      if (u.isNotEmpty) return u;
    }
    return AppNotification.imageFrom(Map<String, dynamic>.from(message.data));
  }

  static String _clean(dynamic v) => v?.toString().trim() ?? '';

  /// The push's real title: the FCM notification's, else `data['title']`.
  /// Empty when it has none — never a made-up one.
  @visibleForTesting
  static String realTitle(RemoteMessage message) {
    final t = _clean(message.notification?.title);
    return t.isNotEmpty ? t : _clean(message.data['title']);
  }

  /// The push's real body, like [realTitle].
  @visibleForTesting
  static String realBody(RemoteMessage message) {
    final b = _clean(message.notification?.body);
    return b.isNotEmpty ? b : _clean(message.data['body']);
  }

  /// One push, whichever path delivers it: the backend's notification_id,
  /// else Firebase's messageId.
  @visibleForTesting
  static String dedupeKey(RemoteMessage message) {
    final id = _clean(message.data['notification_id']);
    return id.isNotEmpty ? id : _clean(message.messageId);
  }

  /// A push opened from the tray: into the inbox once (it is skipped when
  /// the same notification_id is already there), marked read, then the
  /// server inbox is merged in for the authoritative copy and its row id.
  Future<void> _recordInInbox(RemoteMessage message) async {
    final data = Map<String, dynamic>.from(message.data);
    await AppState.instance.recordPushNotification(
      data: data,
      title: realTitle(message),
      body: realBody(message),
      messageId: message.messageId,
      imageUrl: _pushImage(message),
    );
    final key = dedupeKey(message);
    AppState.instance.markNotificationReadByNotificationId(
        _clean(data['notification_id']).isNotEmpty ? key : 'push_$key');
    if (AppState.instance.isLoggedIn) {
      unawaited(AppState.instance.fetchNotifications());
    }
  }

  Future<void> _showLocalNotification(
    RemoteMessage message, {
    required String title,
    required String body,
  }) async {
    final data = message.data;

    await _localNotifications.show(
      id: message.hashCode,
      title: title,
      body: body,
      // The app is open: silent (quiet channel, no heads-up); it waits in
      // the tray, and the in-app pill is the alert.
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _quietChannel.id,
          _quietChannel.name,
          channelDescription: _quietChannel.description,
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          enableVibration: false,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: false,
          presentBanner: false,
          presentSound: false,
          presentList: true,
        ),
      ),
      payload: jsonEncode(data),
    );
  }

  Future<void> initEarly({
    required GlobalKey<ScaffoldMessengerState> messengerKey,
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    if (kIsWeb || _initialized) return;
    _initialized = true;
    _navigatorKey = navigatorKey;
    _messengerKey = messengerKey;

    try {
      // Each platform call is bounded separately so one slow step cannot eat
      // the whole startup budget and take the others down with it. main()
      // caps this method as a whole; these caps decide which parts still get
      // a chance when one of them stalls.
      await Firebase.initializeApp().timeout(const Duration(seconds: 4));
      // Bounded on its own: a failure here must not skip the FCM tap
      // handlers below, or tray taps open nothing.
      try {
        await _initLocalNotifications();
      } catch (e) {
        debugPrint('[Notifications] local notifications init failed: $e');
      }
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;

      // Tray taps are wired before the token fetch below, which can take
      // seconds without network: a tap must not wait on it.
      //
      // Background: the app was running and the reader tapped the tray.
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          debugPrint('App opened from notification');
        }
        unawaited(_recordInInbox(message));
        unawaited(_handleTap(Map<String, dynamic>.from(message.data)));
      });

      // Terminated: the tap launched the app. Not awaited and not timed
      // out — a slow read used to throw and drop the tap, leaving the
      // reader on Home. The gate holds the target until Home is ready.
      unawaited(messaging.getInitialMessage().then((initialMessage) {
        if (initialMessage == null) return;
        if (kDebugMode) {
          debugPrint('Initial notification on launch');
        }
        unawaited(_recordInInbox(initialMessage));
        unawaited(_handleTap(Map<String, dynamic>.from(initialMessage.data)));
      }).catchError((Object e) {
        debugPrint('[Notifications] could not read initial message: $e');
      }));

      // Acquire early FCM token so guest registration and login can send it immediately
      try {
        // Known to hang without network or Play Services. A missing token is
        // recoverable — onTokenRefresh below still delivers one later.
        final token =
            await messaging.getToken().timeout(const Duration(seconds: 3));
        if (kDebugMode) {
          debugPrint('[Notifications] token acquired: ${token != null}');
        }
        if (token != null && token.isNotEmpty) {
          AppState.instance.fcmToken = token;

          // Register it the moment we have it. Storing the token locally was
          // not enough: nothing sent it to the backend for a guest, so the
          // device had no record to target and guests received nothing.
          //
          // Splash also calls registerGuestDevice, but it races this method —
          // Firebase may not be initialised yet, getToken() throws, and that
          // call silently returns null. Registering here is the point where
          // the token is known to exist.
          //
          // updateFcmToken already picks the right contract: guest-device for
          // a guest, token handoff for a signed-in reader.
          unawaited(ApiService.instance.updateFcmToken(token).then((_) {
            if (kDebugMode) {
              debugPrint('[Notifications] token registered');
            }
          }).catchError((e) {
            if (kDebugMode) {
              debugPrint('[Notifications] token registration failed: $e');
            }
          }));
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              '[NotificationService] Early FCM token fetch deferred: $e');
        }
      }

      // 1. Listen to token refreshes
      messaging.onTokenRefresh.listen((newToken) {
        if (kDebugMode) {
          debugPrint('[Notifications] token refreshed, re-registering');
        }
        AppState.instance.fcmToken = newToken;
        ApiService.instance.updateFcmToken(newToken).then((_) {
          if (kDebugMode) {
            debugPrint('[Notifications] refreshed token registered');
          }
        }).catchError((e) {
          if (kDebugMode) {
            debugPrint('[Notifications] token registration failed: $e');
          }
        });
      });

      // 2. Foreground notification handler (Deduplicate & show interactive banner)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          debugPrint('[Notifications] foreground message '
              'notification=${message.notification != null} '
              'dataKeys=${message.data.keys.toList()}');
        }
        final data = message.data;

        // Validate before anything else: a push with neither a real title
        // nor a real body (silent or invalid) gets no tray entry, no pill
        // and no inbox card. A fallback title used to turn these into
        // "New Notification" cards.
        final title = realTitle(message);
        final body = realBody(message);
        if (title.isEmpty && body.isEmpty) {
          debugPrint('[Notifications] push without title/body ignored');
          return;
        }

        // Deduplicate foreground notifications
        final notificationId = dedupeKey(message);
        if (notificationId.isNotEmpty) {
          if (_seenNotificationIds.contains(notificationId)) return;
          _seenNotificationIds.add(notificationId);
          if (_seenNotificationIds.length > 100) {
            _seenNotificationIds.remove(_seenNotificationIds.first);
          }
        }

        // Only for display; never stored as the title.
        final displayTitle = title.isNotEmpty ? title : 'Vaaradhi News';

        // Into the tray silently; the small pill below is the only alert
        // while the reader is in the app.
        unawaited(
            _showLocalNotification(message, title: displayTitle, body: body));

        // Keep it in the in-app inbox — for guests too.
        unawaited(AppState.instance.recordPushNotification(
          data: Map<String, dynamic>.from(data),
          title: title,
          body: body,
          messageId: message.messageId,
          imageUrl: _pushImage(message),
        ));

        final pushTarget =
            NotificationDeepLinkResolver.resolveFromPayload(data);
        if (pushTarget.type == NotificationTargetType.ugc) {
          unawaited(AppState.instance.refreshReporterDashboard());
        }

        // One small line at the top — title only, ~3 s, tap opens, swipe up
        // dismisses. The full-text banner at the bottom covered a third of
        // the story being read, on top of the system popup.
        final overlay = _navigatorKey?.currentState?.overlay;
        if (overlay != null) {
          InAppNewsPill.show(
            overlay,
            title: displayTitle,
            onTap: () => unawaited(_handleTap(Map<String, dynamic>.from(data))),
          );
        }
      });
    } catch (e) {
      debugPrint('NotificationService early init error: $e');
    }
  }

  /// Prompts notification permission ONLY AFTER the user is viewing articles.
  /// Persists permission request status to avoid showing repeated prompts across app launches.
  Future<void> requestPermissionAfterArticlesLoaded() async {
    if (kIsWeb) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyRequested =
          prefs.getBool('hasRequestedNotificationPermission') ?? false;
      if (alreadyRequested || _permissionRequested) return;

      final messaging = FirebaseMessaging.instance;
      final currentSettings = await messaging.getNotificationSettings();

      // If user has already granted or determined permission, don't re-prompt
      if (currentSettings.authorizationStatus ==
              AuthorizationStatus.authorized ||
          currentSettings.authorizationStatus ==
              AuthorizationStatus.provisional ||
          currentSettings.authorizationStatus == AuthorizationStatus.denied) {
        _permissionRequested = true;
        await prefs.setBool('hasRequestedNotificationPermission', true);
        final token = await messaging.getToken();
        if (token != null) {
          AppState.instance.fcmToken = token;
          await ApiService.instance.updateFcmToken(token);
        }
        return;
      }

      _permissionRequested = true;
      await prefs.setBool('hasRequestedNotificationPermission', true);

      await Future.delayed(const Duration(milliseconds: 1500));

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('[Notifications] permission: ${settings.authorizationStatus}');
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint(
            '[Notifications] DENIED — no push will arrive on this device');
      }

      final token = await messaging.getToken();
      debugPrint('[Notifications] token after permission: ${token != null}');
      if (token != null) {
        AppState.instance.fcmToken = token;
        try {
          await ApiService.instance.updateFcmToken(token);
          debugPrint('[Notifications] token registered with backend');
        } catch (e) {
          debugPrint('[Notifications] backend registration FAILED: $e');
        }
      }
    } catch (e) {
      debugPrint('NotificationService deferred permission error: $e');
    }
  }

  /// Invoked by [HomeScreen] once it has mounted as the root navigation container.
  void onNavigationReady(BuildContext context) {
    NotificationNavigationGate.instance.onNavigationReady(
      context,
      (target, ctx) => navigateToTarget(target, context: ctx),
    );
  }

  /// Called after user logout to re-register the device as a guest device.
  Future<void> registerAsGuest() async {
    final token = AppState.instance.fcmToken;
    if (token != null && token.isNotEmpty) {
      await ApiService.instance.registerGuestDevice(
        deviceId: AppState.instance.deviceId,
        fcmToken: token,
        installationSecret: AppState.instance.installationSecret,
      );
    }
  }

  /// Entry point for parsing and dispatching notification payloads.
  Future<void> handleNotificationPayload(
    Map<String, dynamic> data, {
    BuildContext? context,
  }) async {
    // Firebase and the local-notification callback can both deliver the
    // same tap: one notification is handled once.
    if (!shouldHandle(data)) {
      debugPrint('[NotificationService] duplicate tap ignored');
      return;
    }
    final target = targetForTap(data);

    if (!NotificationNavigationGate.instance.isNavigationReady) {
      NotificationNavigationGate.instance.setPendingTarget(target);
      return;
    }

    await navigateToTarget(target, context: context);
  }

  /// Every notification tap — tray (background or launch), app-shown
  /// notification, in-app banner — comes through here, so one
  /// notification_id opens its content once. Before Home is ready the
  /// target is held by [NotificationNavigationGate].
  Future<void> _handleTap(Map<String, dynamic> data) async {
    if (!await claimNotificationTap(data)) {
      debugPrint('[NotificationService] notification already opened, '
          'ignoring tap');
      return;
    }
    await handleNotificationPayload(data);
  }

  static const _openedIdsKey = 'opened_notification_ids';
  final Set<String> _openedNotificationIds = {};

  /// False when this notification_id was already opened. Remembered across
  /// launches: Android re-delivers the launch notification when the app is
  /// reopened from Recents, which reopened a story already read.
  /// Payloads without an id are always handled.
  @visibleForTesting
  Future<bool> claimNotificationTap(Map<String, dynamic> data) async {
    final id = (data['notification_id'] ?? '').toString().trim();
    if (id.isEmpty) return true;
    // Claimed in memory first (synchronously), so two callbacks for the
    // same tap cannot both pass while prefs load.
    if (!_openedNotificationIds.add(id)) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final opened = prefs.getStringList(_openedIdsKey) ?? <String>[];
      if (opened.contains(id)) return false;
      opened.add(id);
      await prefs.setStringList(
        _openedIdsKey,
        opened.length > 100 ? opened.sublist(opened.length - 100) : opened,
      );
    } catch (e) {
      debugPrint('[NotificationService] could not persist opened id: $e');
    }
    return true;
  }

  String? _lastHandledId;
  DateTime? _lastHandledAt;

  /// False for the same notification_id again within 10 seconds.
  @visibleForTesting
  bool shouldHandle(Map<String, dynamic> data, {DateTime? now}) {
    final id = (data['notification_id'] ?? '').toString();
    final t = now ?? DateTime.now();
    if (id.isNotEmpty &&
        id == _lastHandledId &&
        _lastHandledAt != null &&
        t.difference(_lastHandledAt!) < const Duration(seconds: 10)) {
      return false;
    }
    _lastHandledId = id;
    _lastHandledAt = t;
    return true;
  }

  /// Where a tapped notification goes: its content, or Home when neither
  /// the content fields nor deep_link address anything (notification
  /// handover: "invalid destination: open Home").
  @visibleForTesting
  static NotificationTarget targetForTap(Map<String, dynamic> data) {
    final target = NotificationDeepLinkResolver.resolveFromPayload(data);
    if (target.type != NotificationTargetType.unknown) return target;
    debugPrint('[NotificationService] Unroutable payload, opening Home: $data');
    return NotificationTarget.screen(
      screenName: 'home',
      notificationId: data['notification_id']?.toString(),
      originalPayload: data,
    );
  }

  /// Tells the reader why a deep-linked item did not open. A 404 means the
  /// content was removed; anything else is most likely the connection.
  /// A link that opened the app points at nothing we can show (unknown
  /// path, bad id). The reader stays on Home with a short note rather than
  /// wondering why nothing happened. Waits briefly on a cold start so the
  /// first screen is up before the note appears.
  Future<void> showContentUnavailable({
    Duration delay = const Duration(milliseconds: 1200),
  }) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final messenger = _messengerKey?.currentState;
    if (messenger == null) return;
    final telugu = AppState.instance.language == 'Telugu';
    messenger
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content:
            Text(telugu ? 'ఈ కంటెంట్ అందుబాటులో లేదు' : 'Content unavailable'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ));
  }

  void _showLoadFailure(BuildContext context, Object error,
      {VoidCallback? retry}) {
    if (!context.mounted) return;
    final telugu = AppState.instance.language == 'Telugu';
    final gone = error is DioException && error.response?.statusCode == 404;
    final message = gone
        ? (telugu
            ? 'ఈ కంటెంట్ ఇకపై అందుబాటులో లేదు'
            : 'This content is no longer available')
        : (telugu
            ? 'కంటెంట్ లోడ్ కాలేదు. మీ కనెక్షన్‌ను తనిఖీ చేసి మళ్లీ ప్రయత్నించండి.'
            : 'Could not load this content. Check your connection and try again.');
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          // Offline / server trouble: the tap is not lost — Retry.
          duration: Duration(seconds: gone || retry == null ? 3 : 8),
          action: gone || retry == null
              ? null
              : SnackBarAction(
                  label: telugu ? 'మళ్లీ' : 'Retry',
                  onPressed: retry,
                ),
        ),
      );
  }

  OverlayEntry? _loadingOverlay;

  void _showLoadingIndicator(BuildContext context) {
    if (_loadingOverlay != null) return;
    try {
      final overlay = Overlay.maybeOf(context);
      if (overlay == null) return;

      _loadingOverlay = OverlayEntry(
        builder: (_) => Container(
          color: Colors.black.withValues(alpha: 0.35),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ),
      );
      overlay.insert(_loadingOverlay!);
    } catch (e) {
      debugPrint('[NotificationService] Could not insert loading overlay: $e');
    }
  }

  void _dismissLoadingIndicator() {
    try {
      _loadingOverlay?.remove();
    } catch (_) {}
    _loadingOverlay = null;
  }

  /// Opens a notification's screen and returns at once.
  ///
  /// Not AppNavigator.pushSafe: that drops any push within 375 ms of the
  /// previous one, and a notification opened at launch lands right after
  /// Splash → Home (and Spotlight), so the story was silently dropped. And
  /// not awaited: a push completes only when its screen is closed, and the
  /// dispatch lock was held all that time, so every later notification tap
  /// was refused while the reader stayed on the first story. Duplicate taps
  /// are already caught by [NotificationNavigationGate.acquireDispatchLock].
  /// Set by [_openRoute]: the notification's screen opened.
  bool _routeOpened = false;

  void _openRoute(BuildContext context, Route<Object?> route) {
    if (!context.mounted) return;
    unawaited(Navigator.of(context).push(route));
    _routeOpened = true;
  }

  /// Navigates to a typed [NotificationTarget] using [_openRoute]
  /// to ensure STEP 5 navigation stack safety, debounce protection, and auth challenge preservation.
  Future<void> navigateToTarget(
    NotificationTarget target, {
    BuildContext? context,
  }) async {
    // The caller's context (Home) when it is still mounted, else the app's
    // root navigator: Home can be rebuilt (login, logout), and a tap held
    // for its old context was never opened.
    final navContext = (context != null && context.mounted)
        ? context
        : _navigatorKey?.currentContext;
    if (navContext == null || !navContext.mounted) {
      NotificationNavigationGate.instance.setPendingTarget(target);
      return;
    }

    // Atomic concurrency guard: prevent double navigation if already in-flight or tapped in rapid succession
    if (!NotificationNavigationGate.instance.acquireDispatchLock(target)) {
      return;
    }

    _routeOpened = false;
    try {
      // Mark it read. The read endpoint takes the inbox row id, not the
      // push's notification_id: AppState maps one to the other (a
      // device-only copy is synced at the next inbox merge).
      if (target.notificationId != null && target.notificationId!.isNotEmpty) {
        AppState.instance
            .markNotificationReadByNotificationId(target.notificationId!);
      }

      // Handle authentication gate for protected targets
      if (target.requiresAuth && !AppState.instance.isLoggedIn) {
        final loginSuccess = await Navigator.of(navContext).push<bool>(
          MaterialPageRoute(builder: (_) => const AccountLoginScreen()),
        );

        if (loginSuccess != true || !navContext.mounted) {
          // User dismissed login or login failed; intent cancelled safely
          return;
        }
      }

      if (!navContext.mounted) return;

      switch (target.type) {
        case NotificationTargetType.article:
          final slug = target.identifier;
          if (slug != null && slug.isNotEmpty) {
            _showLoadingIndicator(navContext);
            try {
              final article = await NewsArticleRepository.instance
                  .getDetail(slug)
                  .timeout(const Duration(seconds: 8));

              _dismissLoadingIndicator();

              if (navContext.mounted) {
                _openInSpotlight(navContext, article);
              }
            } catch (e) {
              _dismissLoadingIndicator();
              debugPrint(
                  '[NotificationService] Article load error for slug "$slug": $e');
              if (navContext.mounted) {
                _showLoadFailure(navContext, e,
                    retry: () => navigateToTarget(target));
              }
            }
          }
          break;

        case NotificationTargetType.category:
          final categorySlug = target.identifier;
          if (categorySlug != null &&
              categorySlug.isNotEmpty &&
              navContext.mounted) {
            final categoryName = categorySlug.length > 1
                ? '${categorySlug[0].toUpperCase()}${categorySlug.substring(1)}'
                : categorySlug.toUpperCase();
            _openRoute(
              navContext,
              MaterialPageRoute(
                builder: (_) => CategoryScreen(
                  categorySlug: categorySlug,
                  categoryName: categoryName,
                  scope: categorySlug.toLowerCase() == 'local' ? 'local' : null,
                ),
              ),
            );
          }
          break;

        case NotificationTargetType.poster:
          final posterId = target.identifier;
          if (posterId != null && posterId.isNotEmpty) {
            _showLoadingIndicator(navContext);
            try {
              // Fetched by id. Scanning the first page of /posters/ missed
              // any older poster and then opened a blank one.
              final poster = await ApiService.instance
                  .getPosterDetail(posterId)
                  .timeout(const Duration(seconds: 8));

              _dismissLoadingIndicator();

              if (navContext.mounted) {
                _openRoute(
                  navContext,
                  MaterialPageRoute(
                      builder: (_) => PosterDetailScreen(poster: poster)),
                );
              }
            } catch (e) {
              _dismissLoadingIndicator();
              debugPrint(
                  '[NotificationService] Poster load error for "$posterId": $e');
              if (navContext.mounted) {
                _showLoadFailure(navContext, e,
                    retry: () => navigateToTarget(target));
              }
            }
          }
          break;

        case NotificationTargetType.poll:
          final pollId = target.identifier;
          if (pollId != null && pollId.isNotEmpty) {
            _showLoadingIndicator(navContext);
            try {
              final poll = await ApiService.instance
                  .fetchPollDetail(pollId)
                  .timeout(const Duration(seconds: 8));

              _dismissLoadingIndicator();

              if (navContext.mounted) {
                _openRoute(
                  navContext,
                  MaterialPageRoute(
                      builder: (_) => PollDetailScreen(poll: poll)),
                );
              }
            } catch (e) {
              _dismissLoadingIndicator();
              debugPrint(
                  '[NotificationService] Poll load error for "$pollId": $e');
              if (navContext.mounted) {
                _showLoadFailure(navContext, e,
                    retry: () => navigateToTarget(target));
              }
            }
          }
          break;

        case NotificationTargetType.video:
          await _openVideo(navContext, target.identifier);
          break;

        case NotificationTargetType.ugc:
          unawaited(AppState.instance.refreshReporterDashboard());
          if (target.screenName == 'dashboard') {
            _openRoute(
              navContext,
              MaterialPageRoute(builder: (_) => const MyPostsScreen()),
            );
          } else if (target.screenName == 'submit') {
            requireAuth(
              navContext,
              () => _openRoute(
                navContext,
                MaterialPageRoute(builder: (_) => const CreatePostScreen()),
              ),
            );
          } else if (target.identifier != null &&
              target.identifier!.isNotEmpty) {
            // "Your post is pending / approved / rejected": the reporter's
            // own submission, which the public endpoint does not serve
            // until it is approved (and then only in its area). Opening it
            // as a public post gave an empty story page.
            if (target.screenName == 'status' ||
                isSubmissionStatusNotice(target.originalPayload)) {
              _openRoute(
                navContext,
                MaterialPageRoute(
                  builder: (_) => SubmissionStatusScreen(
                    submissionId: target.identifier!,
                    initialTitle:
                        (target.originalPayload?['title'] ?? '').toString(),
                  ),
                ),
              );
              break;
            }
            // The citizen post in Spotlight, like a news notification.
            _showLoadingIndicator(navContext);
            try {
              final post = await ApiService.instance
                  .getUgcDetail(target.identifier!)
                  .timeout(const Duration(seconds: 8));
              _dismissLoadingIndicator();
              if (navContext.mounted) _openInSpotlight(navContext, post);
              break;
            } catch (e) {
              _dismissLoadingIndicator();
              debugPrint('[NotificationService] UGC load error for '
                  '"${target.identifier}": $e');
              if (!navContext.mounted) break;
              final article = _ugcArticleFromTarget(target);
              if (article != null && article.title.trim().isNotEmpty) {
                // The notification carried the post's text: show that,
                // and the detail screen retries the full post.
                _openRoute(
                  navContext,
                  MaterialPageRoute(
                      builder: (_) => NewsDetailScreen(article: article)),
                );
              } else {
                // Only an id, and the post is not available to this reader
                // (removed, not approved, outside their area) or the
                // connection failed. Say so, with Retry when it may help,
                // rather than opening an empty story page.
                _showLoadFailure(navContext, e,
                    retry: () => navigateToTarget(target));
              }
            }
          } else {
            _openRoute(
              navContext,
              MaterialPageRoute(builder: (_) => const UgcFeedScreen()),
            );
          }
          break;

        case NotificationTargetType.admin:
          // Being signed in is not enough: a forwarded moderation link must
          // not open the console for an ordinary reader.
          if (!hasAdminConsoleAccess) {
            debugPrint(
                '[NotificationService] Admin target refused for non-admin: $target');
            ScaffoldMessenger.of(navContext)
              ..removeCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text('ఈ లింక్ అడ్మిన్ ఖాతాలకు మాత్రమే.'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 3),
                ),
              );
            break;
          }

          final submissionId = target.identifier;
          if (submissionId != null && submissionId.isNotEmpty) {
            // The detail screen needs the full submission, so fetch before
            // pushing rather than opening an empty shell.
            _showLoadingIndicator(navContext);
            try {
              final submission = await AdminUgcRepository()
                  .getSubmissionDetail(submissionId)
                  .timeout(const Duration(seconds: 10));

              _dismissLoadingIndicator();

              if (navContext.mounted) {
                _openRoute(
                  navContext,
                  MaterialPageRoute(
                    builder: (_) => AdminUgcDetailScreen(initial: submission),
                  ),
                );
              }
            } catch (e) {
              _dismissLoadingIndicator();
              debugPrint(
                  '[NotificationService] Admin submission load error for "$submissionId": $e');
              if (navContext.mounted) {
                ScaffoldMessenger.of(navContext)
                  ..removeCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content:
                          Text('ఈ సమర్పణ అందుబాటులో లేదు లేదా తొలగించబడింది.'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 3),
                    ),
                  );
              }
            }
            break;
          }

          _openRoute(
            navContext,
            MaterialPageRoute(
              builder: (_) =>
                  AdminUgcScreen(initialTab: _adminTabFor(target.screenName)),
            ),
          );
          break;

        case NotificationTargetType.screen:
          switch (target.screenName?.toLowerCase()) {
            case 'bookmarks':
              _openRoute(
                navContext,
                MaterialPageRoute(builder: (_) => const BookmarksScreen()),
              );
              break;
            case 'notifications':
              _openRoute(
                navContext,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
              break;
            case 'settings':
              _openRoute(
                navContext,
                MaterialPageRoute(
                    builder: (_) => const NotificationSettingsScreen()),
              );
              break;
            case 'home':
              // Quotes and other feed-only content: back to the Home feed.
              Navigator.of(navContext).popUntil((route) => route.isFirst);
              _routeOpened = true;
              break;
            default:
              debugPrint(
                  '[NotificationService] Unhandled screen target: ${target.screenName}');
          }
          break;

        case NotificationTargetType.unknown:
          debugPrint(
              '[NotificationService] Unknown notification target: $target');
          break;
      }
      // Analytics: the tapped notification's screen really opened.
      if (_routeOpened) {
        final id = (target.originalPayload?['notification_id'] ??
                target.notificationId ??
                '')
            .toString();
        if (id.isNotEmpty) {
          unawaited(AnalyticsQueue.instance
              .notificationOpened(id, payload: target.originalPayload));
        }
      }
    } catch (e) {
      _dismissLoadingIndicator();
      debugPrint('[NotificationService] Error routing notification target: $e');
    } finally {
      NotificationNavigationGate.instance.releaseDispatchLock();
    }
  }

  /// True for a citizen reporter's submission-status notification ("your
  /// post is pending / approved / rejected"), as opposed to news about a
  /// published citizen post.
  @visibleForTesting
  static bool isSubmissionStatusNotice(Map<String, dynamic>? payload) =>
      NotificationDeepLinkResolver.isSubmissionStatusNotice(payload);

  /// Opens Spotlight with [article] as the first card, the reader's feed
  /// following it. A district/mandal/village story opens the Local tab
  /// when the reader has a place set.
  void _openInSpotlight(BuildContext context, NewsArticle article) {
    final isLocal = AppState.instance.hasValidLocation &&
        SpotlightController.isLocalStory(article);
    _openRoute(
      context,
      MaterialPageRoute(
        settings:
            RouteSettings(name: isLocal ? '/spotlight/local' : '/spotlight'),
        builder: (_) => SpotlightScreen(
          pinnedArticle: article,
          isLocal: isLocal,
        ),
      ),
    );
  }

  /// Opens the Reels viewer for a /video/{id}/ link.
  ///
  /// The backend has no public video-by-id endpoint yet, so the id is looked
  /// up in the first page of Shorts and of videos — never by paging on
  /// indefinitely. If it is not there the reader still lands in Reels, told
  /// that particular video could not be found.
  // TODO(backend): switch to GET /api/v1/videos/{id}/ once it exists.
  Future<void> _openVideo(BuildContext navContext, String? videoId) async {
    _showLoadingIndicator(navContext);
    final videos = <VideoItem>[];
    Object? lastError;
    for (final load in [
      () => VideoRepository.instance.getShortsFeed(),
      () => VideoRepository.instance.getVideoFeed(),
    ]) {
      try {
        final page = await load().timeout(const Duration(seconds: 8));
        if (page.hasErrors) throw Exception(page.errorMessage);
        final seen = videos.map((v) => v.id).toSet();
        videos.addAll(
            (page.data ?? const <VideoItem>[]).where((v) => seen.add(v.id)));
        if (videos.any((v) => v.id == videoId)) break;
      } catch (e) {
        lastError = e;
      }
    }
    _dismissLoadingIndicator();
    if (!navContext.mounted) return;

    if (videos.isEmpty) {
      _showLoadFailure(navContext, lastError ?? Exception('no videos'),
          retry: () => _openVideo(navContext, videoId));
      return;
    }

    final index = videos.indexWhere((v) => v.id == videoId);
    // Shown before the push: pushSafe completes only when the viewer is
    // closed, and the app-wide messenger keeps the bar over the new route.
    if (index < 0) {
      final telugu = AppState.instance.language == 'Telugu';
      ScaffoldMessenger.of(navContext)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(telugu
                ? 'ఈ వీడియో కనుగొనబడలేదు. తాజా వీడియోలు చూపిస్తున్నాం.'
                : 'That video could not be found. Showing the latest videos.'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
    }
    // The same full-screen Reels as the bottom bar, with the notification's
    // video first (it may be a regular video, not in the Shorts feed).
    _openRoute(
      navContext,
      ReelsScreen.route(
        initialReel: index < 0 ? null : Reel.fromVideo(videos[index]),
      ),
    );
  }

  /// Maps an `/admin/ugc/<section>` deep link onto a console tab.
  int _adminTabFor(String? section) {
    switch (section?.toLowerCase()) {
      case 'reports':
        return AdminConsoleTab.reports;
      case 'logs':
        return AdminConsoleTab.logs;
      case 'otp':
        return AdminConsoleTab.otp;
      default:
        return AdminConsoleTab.queue;
    }
  }

  NewsArticle? _ugcArticleFromTarget(NotificationTarget target) {
    final payload = target.originalPayload ?? const <String, dynamic>{};

    final title = (payload['title'] ?? payload['notification_title'])
            ?.toString()
            .trim() ??
        '';
    final summary = (payload['summary'] ??
                payload['message'] ??
                payload['body'] ??
                payload['description'])
            ?.toString()
            .trim() ??
        '';
    // A bare id (e.g. a shared https://vaaradhinews.com/ugc/{id}/ link) is
    // enough: the detail screen loads the post from GET /api/v1/ugc/{id}/.
    if (title.isEmpty && summary.isEmpty) {
      final id = target.identifier ?? payload['content_id']?.toString() ?? '';
      if (id.isEmpty) return null;
      return NewsArticle.fromJson({'id': id, 'feed_item_type': 'ugc'});
    }

    return NewsArticle.fromJson({
      ...payload,
      'id': target.identifier ?? payload['content_id'] ?? '',
      'title': title.isNotEmpty ? title : 'Citizen report',
      'summary': summary,
      'content': summary,
      'thumbnail_url': payload['thumbnail_url'] ?? payload['image_url'] ?? '',
      'feed_item_type': 'ugc',
      'category': 'UGC',
      // Without a date the story read "1 January 1970 · 20749 days ago".
      'published_at': payload['published_at'] ??
          payload['created_at'] ??
          DateTime.now().toIso8601String(),
    });
  }
}
