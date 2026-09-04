import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_preview/device_preview.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!kIsWeb) {
    await Firebase.initializeApp();
  }
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    if (!kIsWeb) {
      await Firebase.initializeApp();
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      print('User granted permission: ${settings.authorizationStatus}');
      
      String? token = await messaging.getToken();
      if (token != null) {
        AppState.instance.fcmToken = token;
      }
      
      // Listen to token refreshes
      messaging.onTokenRefresh.listen((newToken) {
        AppState.instance.fcmToken = newToken;
        if (AppState.instance.isLoggedIn) {
          ApiService.instance.updateFcmToken(newToken);
        }
      });

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        if (message.notification != null) {
          scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message.notification!.title ?? 'New Notification', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(message.notification!.body ?? ''),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(top: 50, left: 16, right: 16),
              backgroundColor: AppTheme.light('English').primaryColor,
              duration: const Duration(seconds: 4),
              dismissDirection: DismissDirection.up,
            ),
          );
        }
      });
    }
  } catch (e) {
    debugPrint('Firebase initialization error (Missing google-services.json?): $e');
  }

  await AppState.instance.init();

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

  runApp(
    DevicePreview(
      enabled: !kReleaseMode,
      builder: (context) => const Way2NewsCloneApp(),
    ),
  );
}

class Way2NewsCloneApp extends StatelessWidget {
  const Way2NewsCloneApp({super.key});

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder rebuilds this whole subtree whenever AppState changes
    // (coins, login, and — critically for this feature — language), so
    // every tr('key') call downstream picks up the new language immediately.
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        return MaterialApp(
          locale: DevicePreview.locale(context),
          builder: DevicePreview.appBuilder,
          title: 'Vaaradhi',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: scaffoldMessengerKey,
          theme: AppTheme.light(AppState.instance.language),
          darkTheme: AppTheme.dark(AppState.instance.language),
          themeMode: AppState.instance.themeMode,
          themeAnimationDuration: const Duration(milliseconds: 400),
          themeAnimationCurve: Curves.easeInOut,
          home: const SplashScreen(),
        );
      },
    );
  }
}
