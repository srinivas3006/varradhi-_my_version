import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/navigation/app_navigator.dart';
import '../core/navigation/notification_navigation_gate.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/ads/bottom_sticky_ad_banner.dart';
import '../models/ad_banner.dart';
import '../core/ads/home_ads.dart';
import 'create_post_screen.dart';
import 'news_feed_tab.dart';
import '../features/reels/reels_screen.dart';
import 'spotlight_screen.dart';
import '../services/notification_service.dart';
import '../services/ad_manager.dart';
import '../state/app_state.dart';

/// The navigation hub. Home, Post and Profile are tabs; Main News and Local
/// News open the full-screen Spotlight feed as its own route, so backing out
/// of Spotlight always lands here rather than closing the app.
class HomeScreen extends StatefulWidget {
  final int initialTabIndex;

  /// Pushes the Main News Spotlight feed on top as soon as Home mounts, so a
  /// cold launch opens straight into the feed. Skipped when a notification
  /// tap is pending — that target wins.
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
  AdBanner? _homeBottomAd;
  bool _stickyDismissed = false;

  /// The bottom sticky banner is picked from the one `/ads/` response Home
  /// already loaded (HomeAds), never from a request of its own. A location
  /// or language change reloads that response, and this follows it.
  void _onHomeAds() {
    if (!mounted || _stickyDismissed) return;
    final ad = AdManager.instance
        .selectAd(HomeAds.bottomSticky(HomeAds.current.value));
    if (ad?.id != _homeBottomAd?.id) setState(() => _homeBottomAd = ad);
  }

  @override
  void dispose() {
    HomeAds.current.removeListener(_onHomeAds);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    HomeAds.current.addListener(_onHomeAds);
    _onHomeAds();
    _navIndex = widget.initialTabIndex;
    _activatedIndices = {widget.initialTabIndex};
    final hadPendingNotification =
        NotificationNavigationGate.instance.hasPendingTarget;
    NotificationService.instance.onNavigationReady(context);

    if (widget.openSpotlightOnStart && !hadPendingNotification) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openSpotlight(isLocal: false);
      });
    }
  }

  void _handleBack(bool didPop) {
    if (didPop) return;

    // 1. If currently on a secondary tab, switch to Tab 0 (Home)
    if (_navIndex != 0) {
      setState(() {
        _activatedIndices.add(0);
        _navIndex = 0;
      });
      return;
    }

    // 2. We are at root (Tab 0). Apply 2-second double-back exit confirmation.
    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) >
            const Duration(milliseconds: 2000)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppState.instance.language == 'Telugu'
              ? 'నిష్క్రమించడానికి మళ్లీ వెనుకకు నొక్కండి'
              : 'Press back again to exit'),
          duration: const Duration(milliseconds: 2000),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Double-back within 2 seconds: close the application safely
    SystemNavigator.pop();
  }

  void _switchTab(int index) {
    setState(() {
      _activatedIndices.add(index);
      _navIndex = index;
    });
  }

  /// Opens the full-screen Spotlight feed over Home. _navIndex is left
  /// alone, so backing out of Spotlight lands on whichever tab it was
  /// opened from.
  void _openSpotlight({required bool isLocal}) {
    AppNavigator.pushSafe(
      context,
      MaterialPageRoute(
        settings: RouteSettings(
            name: isLocal ? '/spotlight/local' : '/spotlight'),
        builder: (_) => SpotlightScreen(isLocal: isLocal),
      ),
    );
  }

  /// Always opens the Post tab. A guest sees its "log in to post news" page
  /// with a Log in button, rather than the tap leading nowhere or jumping
  /// straight into a login screen with no context.
  void _handlePostTap() => _switchTab(2);

  @override
  Widget build(BuildContext context) {
    // Tabs are lazily mounted only when first activated, eliminating UI
    // thread starvation and duplicate network calls on cold launch. Indices
    // line up with the nav bar's; 1 and 4 open Spotlight and 3 opens Reels as a route, so
    // their slots here are placeholders that are never shown.
    final tabs = [
      _activatedIndices.contains(0)
          ? const NewsFeedTab()
          : const SizedBox.shrink(),
      const SizedBox.shrink(), // 1 — Main News Spotlight (pushed route)
      // 2 — Post, keeping the centre slot the nav bar's floating button
      // renders a gap for.
      _activatedIndices.contains(2)
          ? const CreatePostScreen()
          : const SizedBox.shrink(),
      // 3 — Reels opens full-screen over Home (ReelsScreen), with no
      // bottom bar; back returns here.
      const SizedBox.shrink(),
      const SizedBox.shrink(), // 4 — Local News Spotlight (pushed route)
    ];
    // Profile is not a tab: it opens from the Home header, top-left.

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _handleBack(didPop),
      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: [
            IndexedStack(
              index: _navIndex,
              children: tabs,
            ),
            if (_navIndex == 0 && _homeBottomAd != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.of(context).padding.bottom + 65,
                child: BottomStickyAdBanner(
                    key: ValueKey('home_bottom_${_homeBottomAd!.id}'),
                    ad: _homeBottomAd!,
                    placementZone: 'feed',
                    onDismiss: () {
                      if (mounted)
                        setState(() {
                          _stickyDismissed = true;
                          _homeBottomAd = null;
                        });
                    },
                  ),
              ),
          ],
        ),
        bottomNavigationBar: BottomNavBar(
          currentIndex: _navIndex,
          onTap: (index) {
            if (index == 1 || index == 4) {
              _openSpotlight(isLocal: index == 4);
              return;
            }
            if (index == 3) {
              ReelsScreen.open(context);
              return;
            }
            if (index == 2) {
              _handlePostTap();
              return;
            }
            _switchTab(index);
          },
        ),
      ),
    );
  }
}
