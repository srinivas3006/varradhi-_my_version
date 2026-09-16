import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/navigation/app_navigator_observer.dart';
import 'screens/account_login_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';
import 'services/deep_link_service.dart';
import 'services/notification_service.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global Flutter framework error handling
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  // Global platform dispatcher async error handling
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[PlatformDispatcher] Unhandled async error: $error');
    return true;
  };

  // Graceful release mode fallback widget for widget-build failures
  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (kReleaseMode) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'ఏదో తప్పు జరిగింది. దయచేసి మళ్లీ ప్రయత్నించండి.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
        ),
      );
    }
    return ErrorWidget(details.exception);
  };

  // Set preferred orientations
  await _startupStep(
    'orientation',
    () => SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]),
    budget: const Duration(seconds: 2),
  );

  await _startupStep(
    'notifications',
    () => NotificationService.instance.initEarly(
      messengerKey: scaffoldMessengerKey,
      navigatorKey: navigatorKey,
    ),
    budget: const Duration(seconds: 6),
  );

  await _startupStep(
    'deep links',
    () => DeepLinkService.instance.init(),
    budget: const Duration(seconds: 3),
  );

  await _startupStep('app state', () => AppState.instance.init());

  // If we already logged in previously, sync the token we just fetched
  if (AppState.instance.isLoggedIn && AppState.instance.fcmToken != null) {
    ApiService.instance.updateFcmToken(AppState.instance.fcmToken!);
  }

  // Re-derive isAdmin/isContributor from the server on every cold start so
  // a role change on the backend takes effect without needing to log out
  // and back in. Fire-and-forget: it must not delay the first frame, and
  // AnimatedBuilder(animation: AppState.instance) at the MaterialApp root
  // already re-renders reactively once the flags land.
  if (AppState.instance.isLoggedIn) {
    unawaited(AppState.instance.refreshRolesFromServer());
  }

  runApp(const Way2NewsCloneApp());
}

/// Runs one startup step without letting it hold back the first frame.
///
/// Nothing awaited before [runApp] may run unbounded. The engine paints
/// nothing until the first frame is produced, so a single plugin call that
/// never returns is not a slow launch — it is a permanently black app. A
/// try/catch does not help either, because a hang is not an exception.
///
/// Firebase init and the deep-link platform channel are the realistic
/// offenders: both can stall indefinitely with no network, without Play
/// Services, or on a cold platform channel. A step that exceeds its budget is
/// abandoned here and left running, so a late FCM token still lands — the app
/// simply starts degraded instead of not starting at all.
Future<void> _startupStep(
  String name,
  Future<void> Function() step, {
  Duration budget = const Duration(seconds: 5),
}) async {
  try {
    await step().timeout(budget);
  } on TimeoutException {
    debugPrint(
        '[startup] "$name" exceeded ${budget.inSeconds}s; continuing without it');
  } catch (e, stack) {
    debugPrint('[startup] "$name" failed: $e');
    debugPrintStack(stackTrace: stack);
  }
}

class Way2NewsCloneApp extends StatelessWidget {
  const Way2NewsCloneApp({super.key});

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder rebuilds MaterialApp only when themeMode or language
    // changes, preventing app-wide rebuilds and raster blur invalidations
    // when coins, likes, bookmarks, or profile data update.
    return AnimatedBuilder(
      animation: AppState.instance.themeAndLocaleNotifier,
      builder: (context, _) {
        return MaterialApp(
          title: 'VARADHI',
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: scaffoldMessengerKey,
          navigatorObservers: [AppNavigatorObserver.instance],
          theme: AppTheme.light(AppState.instance.language),
          darkTheme: AppTheme.dark(AppState.instance.language),
          themeMode: AppState.instance.themeMode,
          themeAnimationDuration: const Duration(milliseconds: 400),
          themeAnimationCurve: Curves.easeInOut,
          home: const SplashScreen(),
          routes: {
            '/login': (_) => const AccountLoginScreen(),
          },
        );
      },
    );
  }
}
