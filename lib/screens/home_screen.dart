import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/navigation/auth_guard.dart';
import '../core/navigation/app_navigator.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/ads/bottom_sticky_ad_banner.dart';
import '../models/ad_banner.dart';
import 'local_news_tab.dart';
import 'create_post_screen.dart';
import 'news_feed_tab.dart';
import 'profile_tab.dart';
import 'video_tab.dart';
import '../services/notification_service.dart';
import '../services/ad_manager.dart';
import '../state/app_state.dart';

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
  AdBanner? _homeBottomAd;
  bool _stickyDismissed = false;
  late String _adIdentity;
  String get _currentAdIdentity => [
        AppState.instance.contentLanguage,
        AppState.instance.stateName,
        AppState.instance.district,
        AppState.instance.city,
        AppState.instance.subdistrict,
        AppState.instance.village
      ].join('|');
  void _onAdContextChanged() {
    if (_adIdentity == _currentAdIdentity) return;
    _adIdentity = _currentAdIdentity;
    setState(() => _homeBottomAd = null);
    if (!_stickyDismissed) _loadHomeBottomAd();
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onAdContextChanged);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _adIdentity = _currentAdIdentity;
    AppState.instance.addListener(_onAdContextChanged);
    _navIndex = widget.initialTabIndex;
    _activatedIndices = {widget.initialTabIndex};
    final hadPendingNotification =
        NotificationNavigationGate.instance.hasPendingTarget;
    NotificationService.instance.onNavigationReady(context);

    if (widget.openSpotlightOnStart && !hadPendingNotification) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AppNavigator.pushSafe(
            context,
            MaterialPageRoute(
                builder: (_) => const SpotlightScreen(isLocal: false)),
          );
        }
      });
    }

    Future.microtask(_loadHomeBottomAd);
  }

  Future<void> _loadHomeBottomAd() async {
    if (_stickyDismissed) return;
    final identity = _adIdentity;
    final ad = await _selectFirstAvailableAd(
      zones: const ['feed'],
      preferType: 'bottom_sticky',
    );
    if (!mounted || _stickyDismissed || identity != _adIdentity || ad == null)
      return;
    setState(() => _homeBottomAd = ad);
  }

  Future<AdBanner?> _selectFirstAvailableAd({
    required List<String> zones,
    required String preferType,
  }) async {
    for (final zone in zones) {
      final ads = await AdManager.instance.getAdsForZone(zone, scope: 'main');
      final selected = AdManager.instance.selectAd(
        ads.where((ad) => ad.isBottomSticky).toList(),
      );
      if (selected != null) return selected;
    }
    return null;
  }

  void _handleBack(bool didPop) {
    if (didPop) return;

    // 1. If currently on a secondary tab, switch to Tab 0 (NewsFeedTab)
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
      _activatedIndices.contains(0)
          ? const NewsFeedTab()
          : const SizedBox.shrink(),
      _activatedIndices.contains(1)
          ? const LocalNewsTab()
          : const SizedBox.shrink(),
      _activatedIndices.contains(2)
          ? const CreatePostScreen()
          : const SizedBox.shrink(),
      _activatedIndices.contains(3)
          ? VideoTab(isActive: _navIndex == 3)
          : const SizedBox.shrink(),
      _activatedIndices.contains(4)
          ? const ProfileTab()
          : const SizedBox.shrink(),
    ];

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
            if (index == 2) {
              requireAuth(context, () {
                if (!mounted) return;
                setState(() {
                  _activatedIndices.add(2);
                  _navIndex = 2;
                });
              });
              return;
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
