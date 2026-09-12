import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/navigation/app_navigator.dart';
import '../widgets/bottom_nav_bar.dart';
import '../state/app_state.dart';
import 'local_news_tab.dart';
import 'create_post_screen.dart';
import 'news_feed_tab.dart';
import 'profile_tab.dart';
import 'video_tab.dart';
import 'account_login_screen.dart';
import '../services/notification_service.dart';

import 'spotlight_screen.dart';
import '../core/navigation/notification_navigation_gate.dart';

class HomeScreen extends StatefulWidget {
  final int initialTabIndex;
  final bool openSpotlightOnStart;

  const HomeScreen({
    super.key,
    this.initialTabIndex = 0,
    this.openSpotlightOnStart = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _navIndex;
  late final Set<int> _activatedIndices;
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    _navIndex = widget.initialTabIndex;
    _activatedIndices = {widget.initialTabIndex};
    final hadPendingNotification = NotificationNavigationGate.instance.hasPendingTarget;
    NotificationService.instance.onNavigationReady(context);

    if (widget.openSpotlightOnStart && !hadPendingNotification) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AppNavigator.pushSafe(
            context,
            MaterialPageRoute(builder: (_) => const SpotlightScreen(isLocal: false)),
          );
        }
      });
    }
  }

  void _handleBack(bool didPop) {
    if (didPop) return;

    // 1. If currently on a secondary tab, switch to Tab 0 (NewsFeedTab)
    if (_navIndex != 0) {
      setState(() => _navIndex = 0);
      return;
    }

    // 2. We are at root (Tab 0). Apply 2-second double-back exit confirmation.
    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(milliseconds: 2000)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(milliseconds: 2000),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Double-back within 2 seconds: close the application safely
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    // Secondary tabs are lazily mounted only when first activated, eliminating
    // UI thread starvation and duplicate network calls on cold launch.
    final tabs = [
      const NewsFeedTab(),
      _activatedIndices.contains(1) ? const LocalNewsTab() : const SizedBox.shrink(),
      _activatedIndices.contains(2) ? const CreatePostScreen() : const SizedBox.shrink(),
      _activatedIndices.contains(3) ? VideoTab(isActive: _navIndex == 3) : const SizedBox.shrink(),
      _activatedIndices.contains(4) ? const ProfileTab() : const SizedBox.shrink(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _handleBack(didPop),
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: _navIndex,
          children: tabs,
        ),
        bottomNavigationBar: BottomNavBar(
          currentIndex: _navIndex,
          onTap: (index) {
            if (index == 2) {
              if (!AppState.instance.isLoggedIn) {
                AppNavigator.pushSafe<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const AccountLoginScreen()),
                ).then((loggedIn) {
                  if (loggedIn == true && mounted) {
                    setState(() {
                      _activatedIndices.add(2);
                      _navIndex = 2;
                    });
                  }
                });
                return;
              }
            }
            setState(() {
              _activatedIndices.add(index);
              _navIndex = index;
            });
          },
        ),
      ),
    );
  }
}
