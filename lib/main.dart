import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/splash_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    await Firebase.initializeApp();
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('User granted permission: ${settings.authorizationStatus}');
    
    String? token = await messaging.getToken();
    print('FCM Token: $token');
  } catch (e) {
    print('Firebase initialization error (Missing google-services.json?): $e');
  }

  await AppState.instance.init();
  runApp(const Way2NewsCloneApp());
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
          title: 'DailyBuzz — Way2News Clone',
          debugShowCheckedModeBanner: false,
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
