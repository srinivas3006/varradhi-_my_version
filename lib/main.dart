import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/poll_exposure.dart';
import 'core/ads/ad_pacer.dart';
import 'widgets/ads/corner_three_d_ad_overlay.dart';
import 'core/navigation/app_navigator_observer.dart';
import 'screens/account_login_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';
import 'services/deep_link_service.dart';
import 'services/notification_service.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use the Android system photo picker for every ImagePicker in the app.
  //
  // Without this, image_picker falls back to an ACTION_GET_CONTENT intent,
  // which is the legacy broad-library path Play's Photo and Video Permissions
  // policy pushes apps off. This is a global on the platform implementation,
  // so it covers the call sites that construct ImagePicker() directly as well
  // as MediaPickerHelper. The picker returns only what the user selected, so
  // no READ_MEDIA_IMAGES/READ_MEDIA_VIDEO is needed.
  final picker = ImagePickerPlatform.instance;
  if (picker is ImagePickerAndroid) {
    picker.useAndroidPhotoPicker = true;
  }

  // Licences of the bundled article fonts (SIL OFL 1.1), shown in the
  // app's licence page.
  LicenseRegistry.addLicense(() async* {
    for (final font in const ['Ramabhadra', 'Mandali']) {
      final text = await rootBundle.loadString('assets/fonts/OFL-$font.txt');
      yield LicenseEntryWithLineBreaks(['google_fonts', font], text);
    }
  });

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
  // Poll frequency counts, so the first feed can honour them.
  unawaited(PollExposure.instance.ready());
  // Times active use for the ads that come and go (one clock per app run).
  AdPacer.instance.start();
  // Background push handler registered before runApp (notification
  // handover); Firebase itself still initialises after the first frame.
  if (!kIsWeb) {
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('[main] background handler registration deferred: $e');
    }
  }

  runApp(const VaaradhiApp());

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
      unawaited(ApiService.instance
          .updateFcmToken(AppState.instance.fcmToken!)
          .catchError((_) => {}));
    }

    if (AppState.instance.isLoggedIn) {
      unawaited(
          AppState.instance.refreshRolesFromServer().catchError((_) => null));
    }
  } catch (e) {
    debugPrint('[Main] Background services init error: $e');
  }
}

class VaaradhiApp extends StatelessWidget {
  const VaaradhiApp({super.key});

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder rebuilds MaterialApp only when themeMode or language
    // changes, preventing app-wide rebuilds and raster blur invalidations
    // when coins, likes, bookmarks, or profile data update.
    return AnimatedBuilder(
      animation: AppState.instance.themeAndLocaleNotifier,
      builder: (context, _) {
        return MaterialApp(
          title: 'VAARADHI',
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: scaffoldMessengerKey,
          navigatorObservers: [AppNavigatorObserver.instance],
          theme: AppTheme.light(AppState.instance.language),
          darkTheme: AppTheme.dark(AppState.instance.language),
          themeMode: AppState.instance.themeMode,
          themeAnimationDuration: const Duration(milliseconds: 400),
          themeAnimationCurve: Curves.easeInOut,
          // Every touch or scroll anywhere counts as active use for the
          // ads that come and go (AdPacer). Purely observes; never consumes.
          // The 3D / video corner ad sits above the Navigator, so it can
          // appear on every screen.
          //
          // Text scaling is capped at 130% app-wide — the cap the Spotlight
          // card and article page already use. Android's larger font
          // settings go to 200%, which pushed labels out of fixed-height
          // bars, chips and buttons and made them overlap on every phone.
          builder: (context, child) => MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => AdPacer.instance.reportActivity(),
              onPointerMove: (_) => AdPacer.instance.reportActivity(),
              child: Stack(
                children: [
                  if (child != null) Positioned.fill(child: child),
                  const Positioned.fill(child: CornerThreeDAdOverlay()),
                ],
              ),
            ),
          ),
          home: const SplashScreen(),
          routes: {
            '/login': (_) => const AccountLoginScreen(),
          },
        );
      },
    );
  }
}
