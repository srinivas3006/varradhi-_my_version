import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/navigation/auth_guard.dart';
import '../core/navigation/app_navigator.dart';
import '../core/navigation/notification_deep_link_resolver.dart';
import '../core/navigation/notification_navigation_gate.dart';
import '../models/notification_target.dart';
import '../models/news_article.dart';
import '../repositories/news_article_repository.dart';
import '../screens/account_login_screen.dart';
import '../screens/bookmarks_screen.dart';
import '../screens/category_screen.dart';
import '../screens/create_post_screen.dart';
import '../screens/my_posts_screen.dart';
import '../screens/news_detail_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/notification_settings_screen.dart';
import '../screens/poster_detail_screen.dart';
import '../screens/ugc_feed_screen.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!kIsWeb) {
    await Firebase.initializeApp();
  }
  debugPrint("Handling background notification: ${message.messageId}");
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  bool _initialized = false;
  bool _permissionRequested = false;
  GlobalKey<NavigatorState>? _navigatorKey;

  // Deduplication cache for foreground notifications
  final Set<String> _seenNotificationIds = {};

  /// Lightweight initialization during app boot:
  /// Initializes Firebase and registers background/foreground message listeners
  /// WITHOUT prompting permissions or blocking cold startup.
  Future<void> initEarly({
    required GlobalKey<ScaffoldMessengerState> messengerKey,
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    if (kIsWeb || _initialized) return;
    _initialized = true;
    _navigatorKey = navigatorKey;

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;

      // 1. Listen to token refreshes
      messaging.onTokenRefresh.listen((newToken) {
        AppState.instance.fcmToken = newToken;
        ApiService.instance.updateFcmToken(newToken);
      });

      // 2. Foreground notification handler (Deduplicate & show interactive banner)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Foreground FCM message: ${message.messageId}');
        final data = message.data;
        final notificationId =
            data['notification_id']?.toString() ?? message.messageId;

        // Deduplicate foreground notifications
        if (notificationId != null) {
          if (_seenNotificationIds.contains(notificationId)) return;
          _seenNotificationIds.add(notificationId);
          if (_seenNotificationIds.length > 100) {
            _seenNotificationIds.remove(_seenNotificationIds.first);
          }
        }

        final title = message.notification?.title ??
            data['title']?.toString() ??
            'New Notification';
        final body =
            message.notification?.body ?? data['body']?.toString() ?? '';

        messengerKey.currentState?.showSnackBar(
          SnackBar(
            content: InkWell(
              onTap: () {
                messengerKey.currentState?.hideCurrentSnackBar();
                handleNotificationPayload(data);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(body, style: const TextStyle(color: Colors.white70)),
                  ],
                ],
              ),
            ),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(top: 50, left: 16, right: 16),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 4),
            dismissDirection: DismissDirection.up,
          ),
        );
      });

      // 3. Background tap notification handler (when user taps notification from system tray)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('App opened from notification: ${message.messageId}');
        handleNotificationPayload(message.data);
      });

      // 4. Terminated state launch handler: store in navigation gate
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint(
            'Initial notification on launch: ${initialMessage.messageId}');
        final target = NotificationDeepLinkResolver.resolveFromPayload(
            initialMessage.data);
        if (target.type != NotificationTargetType.unknown) {
          NotificationNavigationGate.instance.setPendingTarget(target);
        }
      }
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
      debugPrint(
          'User notification permission status: ${settings.authorizationStatus}');

      final token = await messaging.getToken();
      if (token != null) {
        AppState.instance.fcmToken = token;
        await ApiService.instance.updateFcmToken(token);
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
    if (data.isEmpty) return;

    final target = NotificationDeepLinkResolver.resolveFromPayload(data);
    if (target.type == NotificationTargetType.unknown) {
      debugPrint(
          '[NotificationService] Unrecognized notification payload: $data');
      return;
    }

    if (!NotificationNavigationGate.instance.isNavigationReady) {
      NotificationNavigationGate.instance.setPendingTarget(target);
      return;
    }

    await navigateToTarget(target, context: context);
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

  /// Navigates to a typed [NotificationTarget] using [AppNavigator.pushSafe]
  /// to ensure STEP 5 navigation stack safety, debounce protection, and auth challenge preservation.
  Future<void> navigateToTarget(
    NotificationTarget target, {
    BuildContext? context,
  }) async {
    final navContext = context ?? _navigatorKey?.currentContext;
    if (navContext == null || !navContext.mounted) {
      NotificationNavigationGate.instance.setPendingTarget(target);
      return;
    }

    // Atomic concurrency guard: prevent double navigation if already in-flight or tapped in rapid succession
    if (!NotificationNavigationGate.instance.acquireDispatchLock(target)) {
      return;
    }

    try {
      // Mark as read asynchronously on backend if notification ID is available
      if (target.notificationId != null && target.notificationId!.isNotEmpty) {
        unawaited(
          ApiService.instance
              .markNotificationRead(target.notificationId!)
              .catchError((_) => false),
        );
      }

      // Handle authentication gate for protected targets
      if (target.requiresAuth && !AppState.instance.isLoggedIn) {
        final loginSuccess = await AppNavigator.pushSafe<bool>(
          navContext,
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
                await AppNavigator.pushSafe(
                  navContext,
                  MaterialPageRoute(
                    builder: (_) =>
                        NewsDetailScreen(article: article, slug: slug),
                  ),
                );
              }
            } catch (e) {
              _dismissLoadingIndicator();
              debugPrint(
                  '[NotificationService] Article load error for slug "$slug": $e');
              if (navContext.mounted) {
                ScaffoldMessenger.of(navContext)
                  ..removeCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content:
                          Text('ఈ కథనం అందుబాటులో లేదు లేదా తొలగించబడింది.'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 3),
                    ),
                  );
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
            await AppNavigator.pushSafe(
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
              final posters = await ApiService.instance
                  .getPosters()
                  .timeout(const Duration(seconds: 6));

              _dismissLoadingIndicator();

              final poster = posters.firstWhere(
                (p) => p['id']?.toString() == posterId,
                orElse: () => {
                  'id': posterId,
                  'image_url': target.originalPayload?['image_url'] ?? '',
                  'title': target.originalPayload?['title'] ?? 'Poster',
                },
              );
              if (navContext.mounted) {
                await AppNavigator.pushSafe(
                  navContext,
                  MaterialPageRoute(
                      builder: (_) => PosterDetailScreen(poster: poster)),
                );
              }
            } catch (_) {
              _dismissLoadingIndicator();
              if (navContext.mounted) {
                ScaffoldMessenger.of(navContext)
                  ..removeCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content:
                          Text('ఈ పోస్టర్ అందుబాటులో లేదు లేదా తొలగించబడింది.'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 3),
                    ),
                  );
              }
            }
          }
          break;

        case NotificationTargetType.ugc:
          if (target.screenName == 'dashboard') {
            AppNavigator.pushSafe(
              navContext,
              MaterialPageRoute(builder: (_) => const MyPostsScreen()),
            );
          } else if (target.screenName == 'submit') {
            requireAuth(
              navContext,
              () => AppNavigator.pushSafe(
                navContext,
                MaterialPageRoute(builder: (_) => const CreatePostScreen()),
              ),
            );
          } else if (target.identifier != null &&
              target.identifier!.isNotEmpty) {
            final article = _ugcArticleFromTarget(target);
            AppNavigator.pushSafe(
              navContext,
              MaterialPageRoute(
                builder: (_) => article != null
                    ? NewsDetailScreen(article: article)
                    : const UgcFeedScreen(),
              ),
            );
          } else {
            AppNavigator.pushSafe(
              navContext,
              MaterialPageRoute(builder: (_) => const UgcFeedScreen()),
            );
          }
          break;

        case NotificationTargetType.screen:
          switch (target.screenName?.toLowerCase()) {
            case 'bookmarks':
              AppNavigator.pushSafe(
                navContext,
                MaterialPageRoute(builder: (_) => const BookmarksScreen()),
              );
              break;
            case 'notifications':
              AppNavigator.pushSafe(
                navContext,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
              break;
            case 'settings':
              AppNavigator.pushSafe(
                navContext,
                MaterialPageRoute(
                    builder: (_) => const NotificationSettingsScreen()),
              );
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
    } catch (e) {
      _dismissLoadingIndicator();
      debugPrint('[NotificationService] Error routing notification target: $e');
    } finally {
      NotificationNavigationGate.instance.releaseDispatchLock();
    }
  }

  NewsArticle? _ugcArticleFromTarget(NotificationTarget target) {
    final payload = target.originalPayload;
    if (payload == null) return null;

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
    if (title.isEmpty && summary.isEmpty) return null;

    return NewsArticle.fromJson({
      ...payload,
      'id': target.identifier ?? payload['content_id'] ?? '',
      'title': title.isNotEmpty ? title : 'Citizen report',
      'summary': summary,
      'content': summary,
      'thumbnail_url': payload['thumbnail_url'] ?? payload['image_url'] ?? '',
      'feed_item_type': 'ugc',
      'category': 'UGC',
      'published_at': payload['published_at'] ?? payload['created_at'],
    });
  }
}
