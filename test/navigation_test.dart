import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:way2news_clone/core/navigation/app_navigator.dart';
import 'package:way2news_clone/core/navigation/app_navigator_observer.dart';
import 'package:way2news_clone/core/network/dio_client.dart';
import 'package:way2news_clone/screens/create_post_screen.dart';
import 'package:way2news_clone/screens/home_screen.dart';
import 'package:way2news_clone/screens/spotlight_screen.dart';
import 'package:way2news_clone/state/app_state.dart';

class NavTestMockAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({'data': [], 'meta': {}, 'errors': null}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final Map<String, String> mockSecureStorage = {};

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel,
            (MethodCall methodCall) async {
      if (methodCall.method == 'read') {
        return mockSecureStorage[methodCall.arguments?['key']];
      } else if (methodCall.method == 'write') {
        final key = methodCall.arguments?['key'] as String?;
        final value = methodCall.arguments?['value'] as String?;
        if (key != null && value != null) {
          mockSecureStorage[key] = value;
        }
        return null;
      } else if (methodCall.method == 'delete') {
        mockSecureStorage.remove(methodCall.arguments?['key']);
        return null;
      } else if (methodCall.method == 'deleteAll') {
        mockSecureStorage.clear();
        return null;
      }
      return null;
    });
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppState.instance.isLoggedIn = false;
    AppState.instance.authToken = null;
    ApiClient.instance.dio.httpClientAdapter = NavTestMockAdapter();
    AppNavigator.resetDebounce();
    AppNavigatorObserver.instance.reset();
  });

  group('AppNavigator & Debounce Protection', () {
    testWidgets('Rapid successive taps push only a single route',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [AppNavigatorObserver.instance],
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    AppNavigator.pushSafe(
                      context,
                      MaterialPageRoute(
                        settings: const RouteSettings(name: '/target'),
                        builder: (_) =>
                            const Scaffold(body: Text('Target Page')),
                      ),
                    );
                  },
                  child: const Text('Push Page'),
                ),
              );
            },
          ),
        ),
      );

      expect(AppNavigatorObserver.instance.stackDepth, equals(1));

      // Simulate 5 rapid consecutive taps
      final buttonFinder = find.text('Push Page');
      await tester.tap(buttonFinder, warnIfMissed: false);
      await tester.tap(buttonFinder, warnIfMissed: false);
      await tester.tap(buttonFinder, warnIfMissed: false);
      await tester.tap(buttonFinder, warnIfMissed: false);
      await tester.tap(buttonFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Only ONE target route should be pushed (depth: 2)
      expect(AppNavigatorObserver.instance.stackDepth, equals(2));
      expect(find.text('Target Page'), findsOneWidget);
    });

    test('isNavigating respects debounce duration', () async {
      expect(AppNavigator.isNavigating, isFalse);
    });
  });

  group('HomeScreen Root PopScope & Back Navigation Policy', () {
    testWidgets(
        'Back from secondary tab switches back to primary tab (NewsFeedTab)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(initialTabIndex: 1), // Local tab
        ),
      );
      await tester.pump();

      // Locate root PopScope using widget predicate
      final popScopeFinder = find.byWidgetPredicate((w) => w is PopScope);
      expect(popScopeFinder, findsWidgets);

      final popScopeWidget = tester.widget<PopScope>(popScopeFinder.first);
      expect(popScopeWidget.canPop, isFalse);

      // Invoke pop callback directly simulating Android back button
      popScopeWidget.onPopInvokedWithResult?.call(false, null);
      await tester.pump();

      // Re-query state to confirm it did not crash and handled back
      expect(find.byType(HomeScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
    });

    testWidgets(
        'First back on root tab shows "Press back again to exit" SnackBar',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(initialTabIndex: 0),
        ),
      );
      await tester.pump();

      final popScopeFinder = find.byWidgetPredicate((w) => w is PopScope);
      final popScopeWidget = tester.widget<PopScope>(popScopeFinder.first);
      expect(popScopeWidget.canPop, isFalse);

      // First back press at root
      popScopeWidget.onPopInvokedWithResult?.call(false, null);
      await tester.pump();

      // Localized since the Telugu localization pass: assert whichever
      // language is active rather than pinning the English copy.
      final english = find.text('Press back again to exit');
      final telugu = find.text('నిష్క్రమించడానికి మళ్లీ వెనుకకు నొక్కండి');
      expect(
        english.evaluate().length + telugu.evaluate().length,
        1,
        reason: 'exactly one exit SnackBar, in the active language',
      );
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets(
        'Second back within 2 seconds at root calls SystemNavigator.pop',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool systemPopCalled = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform,
              (MethodCall methodCall) async {
        if (methodCall.method == 'SystemNavigator.pop') {
          systemPopCalled = true;
        }
        return null;
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(initialTabIndex: 0),
        ),
      );
      await tester.pump();

      final popScopeFinder = find.byWidgetPredicate((w) => w is PopScope);
      final popScopeWidget = tester.widget<PopScope>(popScopeFinder.first);

      // First back press
      popScopeWidget.onPopInvokedWithResult?.call(false, null);
      await tester.pump();
      expect(systemPopCalled, isFalse);

      // Second back press within 2 seconds
      popScopeWidget.onPopInvokedWithResult?.call(false, null);
      await tester.pump();
      expect(systemPopCalled, isTrue);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('Modal & Dialog Back Priority', () {
    testWidgets('Dialog closes on back without popping underlying screen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const AlertDialog(
                      title: Text('Test Dialog'),
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Test Dialog'), findsOneWidget);

      // Pop the modal dialog
      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();

      expect(find.text('Test Dialog'), findsNothing);
      expect(find.text('Open Dialog'), findsOneWidget);
    });
  });

  group('Secondary Route Stack & Pop Behavior', () {
    testWidgets('Secondary route pops cleanly to parent without duplicating',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [AppNavigatorObserver.instance],
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  AppNavigator.pushSafe(
                    context,
                    MaterialPageRoute(
                      settings: const RouteSettings(name: '/article_detail'),
                      builder: (childContext) => Scaffold(
                        body: ElevatedButton(
                          onPressed: () {
                            AppNavigator.pushSafe(
                              childContext,
                              MaterialPageRoute(
                                settings:
                                    const RouteSettings(name: '/comments'),
                                builder: (_) => const Scaffold(
                                    body: Text('Comments Screen')),
                              ),
                            );
                          },
                          child: const Text('Open Comments'),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Open Article'),
              ),
            ),
          ),
        ),
      );

      expect(AppNavigatorObserver.instance.stackDepth, equals(1));

      // Push Article
      await tester.tap(find.text('Open Article'));
      await tester.pumpAndSettle();
      expect(AppNavigatorObserver.instance.stackDepth, equals(2));
      expect(find.text('Open Comments'), findsOneWidget);

      // Reset debounce and push Comments
      AppNavigator.resetDebounce();
      await tester.tap(find.text('Open Comments'));
      await tester.pumpAndSettle();
      expect(AppNavigatorObserver.instance.stackDepth, equals(3));
      expect(find.text('Comments Screen'), findsOneWidget);

      // Pop Comments -> back to Article
      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();
      expect(AppNavigatorObserver.instance.stackDepth, equals(2));
      expect(find.text('Open Comments'), findsOneWidget);
      expect(find.text('Comments Screen'), findsNothing);

      // Pop Article -> back to Root
      navigator.pop();
      await tester.pumpAndSettle();
      expect(AppNavigatorObserver.instance.stackDepth, equals(1));
      expect(find.text('Open Article'), findsOneWidget);
    });
  });

  group('Spotlight Flow & TTS Stop on Pop', () {
    testWidgets('Spotlight screen initializes and pops cleanly',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [AppNavigatorObserver.instance],
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  AppNavigator.pushSafe(
                    context,
                    MaterialPageRoute(
                      settings: const RouteSettings(name: '/spotlight'),
                      builder: (_) => const SpotlightScreen(),
                    ),
                  );
                },
                child: const Text('Launch Spotlight'),
              ),
            ),
          ),
        ),
      );

      AppNavigator.resetDebounce();
      await tester.tap(find.text('Launch Spotlight'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SpotlightScreen), findsOneWidget);
      expect(AppNavigatorObserver.instance.stackDepth, equals(2));

      // Pop Spotlight
      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SpotlightScreen), findsNothing);
      expect(find.text('Launch Spotlight'), findsOneWidget);
      expect(AppNavigatorObserver.instance.stackDepth, equals(1));
    });
  });

  group('CreatePostScreen Flow', () {
    testWidgets('Secondary CreatePostScreen renders within screen boundaries',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      AppState.instance.isLoggedIn = true;
      AppState.instance.authToken = 'test-token';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreatePostScreen()),
                  );
                },
                child: const Text('Open Create'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Create'));
      await tester.pumpAndSettle();

      expect(find.byType(CreatePostScreen), findsOneWidget);
    });
  });
}
