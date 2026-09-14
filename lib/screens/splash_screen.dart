import 'dart:async';
import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'location_selection_screen.dart';
import '../services/api_service.dart';
import '../core/navigation/notification_navigation_gate.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/ad_manager.dart';
import '../models/ad_banner.dart';
import '../widgets/ads/unified_ad_widget.dart';
import '../widgets/ads/ad_viewability_detector.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _starting = false;
  bool _navigated = false;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    // 600ms allows the elastic animation to settle smoothly without blocking first useful frame
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Premium elastic pop for scale
    _scaleAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    // Quick, smooth fade in
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // Subtle slide up effect for dynamic entry
    _slideAnimation = Tween<double>(begin: 24.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _bootstrapApp();
  }

  Future<void> _bootstrapApp() async {
    if (_starting || _navigated) return;
    _starting = true;
    final state = AppState.instance;
    _controller.forward();
    final healthy = await ApiService.instance.checkHealth();
    if (!mounted) return;
    if (!healthy) {
      _starting = false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Unable to connect to the news service.'),
        duration: const Duration(days: 1),
        action: SnackBarAction(label: 'Retry', onPressed: _bootstrapApp),
      ));
      return;
    }

    // Fire non-critical background bootstrap tasks asynchronously without stalling cold boot
    if (!state.isLoggedIn) {
      unawaited(
        ApiService.instance
            .registerGuestDevice(
              deviceId: state.deviceId,
              fcmToken: state.fcmToken,
            )
            .catchError((_) => null),
      );
    } else {
      unawaited(state.refreshRolesFromServer().catchError((_) => null));
    }

    // Await smooth animation completion before presenting HomeScreen
    await _controller.forward();

    // Fetch and show Splash Ad before navigating
    final ads = await AdManager.instance.getAdsForZone('splash');
    // We don't filter by adType here because the backend might send any format for the splash placement,
    // and we force it to full_screen in the overlay.
    final ad = AdManager.instance.selectAd(ads);
    if (ad != null && mounted && !_navigated) {
      await _showSplashAd(ad);
    }

    if (!mounted || _navigated) return;
    _navigated = true;

    final hasPendingNotif = NotificationNavigationGate.instance.hasPendingTarget;
    final Widget nextScreen = state.hasOnboarded
        ? HomeScreen(openSpotlightOnStart: !hasPendingNotif)
        : const LocationSelectionScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => nextScreen,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  Future<void> _showSplashAd(AdBanner ad) async {
    if (ad.imageUrl.isNotEmpty && mounted) {
      precacheImage(NetworkImage(ad.imageUrl), context);
    }
    AdManager.instance.recordImpression(ad, placementZone: 'splash');

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (dialogContext, animation, secondaryAnimation) => FadeTransition(
        opacity: animation,
        child: _SplashAdOverlay(
          ad: ad,
          onTap: () async {
            AdManager.instance.recordClick(ad, placementZone: 'splash');
            if (ad.destinationUrl.isNotEmpty) {
              final uri = Uri.tryParse(ad.destinationUrl);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
            if (mounted) Navigator.of(dialogContext).pop();
          },
          onSkip: () {
            AdManager.instance.recordSkip(ad, placementZone: 'splash');
            Navigator.of(dialogContext).pop();
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Clean, distraction-free background
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _slideAnimation.value),
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          blurRadius: 40,
                          spreadRadius: 10,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 220,
                      height: 220,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SplashAdOverlay extends StatelessWidget {
  final AdBanner ad;
  final VoidCallback onTap;
  final VoidCallback onSkip;

  const _SplashAdOverlay({
    required this.ad,
    required this.onTap,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    // Force ad to display in a full-screen compatible format.
    final displayAd = ad.copyWith(adType: 'full_screen');

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background blur
          if (ad.imageUrl.isNotEmpty)
            Positioned.fill(
              child: Image.network(
                ad.imageUrl,
                fit: BoxFit.cover,
                color: Colors.black.withValues(alpha: 0.5),
                colorBlendMode: BlendMode.darken,
              ),
            ),
          
          // Centered Ad Creative
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 60, bottom: 24, left: 16, right: 16),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap();
                },
                child: AdViewabilityDetector(
                  ad: ad,
                  placementZone: 'splash',
                  exposureKey: 'splash_${ad.id}',
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (ad.imageUrl.isNotEmpty)
                          Image.network(
                            ad.imageUrl,
                            fit: BoxFit.cover,
                          ),
                        // Sponsored Badge
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Text(
                              'SPONSORED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        // Bottom gradient & CTA
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.8),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (ad.title.isNotEmpty)
                                  Text(
                                    ad.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(context).primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      onTap();
                                    },
                                    child: const Text(
                                      'Learn More',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Skip Button
          Positioned(
            top: MediaQuery.paddingOf(context).top + 16,
            right: 16,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onSkip();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Skip',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.close, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

