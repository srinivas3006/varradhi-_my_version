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

  // Parallelize lightweight essential initialization so the first frame renders in <100ms
  await Future.wait([
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]),
    AppState.instance.init(),
  ]);

  // Immediately mount the application so the logo splash screen renders with zero white screen delay
  runApp(const Way2NewsCloneApp());

  // Asynchronously initialize heavy background services (Firebase, FCM tokens, deep links, role sync)
  // without blocking UI frame drawing or causing a prolonged blank launch screen
  unawaited(_initBackgroundServices());
}

Future<void> _initBackgroundServices() async {
  try {
    await NotificationService.instance.initEarly(
      messengerKey: scaffoldMessengerKey,
      navigatorKey: navigatorKey,
    );
    await DeepLinkService.instance.init();

    if (AppState.instance.isLoggedIn && AppState.instance.fcmToken != null) {
      unawaited(ApiService.instance.updateFcmToken(AppState.instance.fcmToken!).catchError((_) => {}));
    }

    if (AppState.instance.isLoggedIn) {
      unawaited(AppState.instance.refreshRolesFromServer().catchError((_) => null));
    }
  } catch (e) {
    debugPrint('[Main] Background services init error: $e');
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
