import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'spotlight_screen.dart';
import '../services/api_service.dart';
import '../core/navigation/notification_navigation_gate.dart';


import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/ad_manager.dart';
import '../models/ad_banner.dart';
import '../widgets/ads/ad_viewability_detector.dart';

import '../core/media/media_resolver.dart';
import '../core/media/media_source.dart';
import '../core/media/network_video_playback_controller.dart';
import '../core/media/video_player_widget.dart';


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

    // Smooth, instant logo visibility matching native splash screen perfectly
    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    // Fade gently from 0.85 to 1.0 so there is zero blank white frame
    _fadeAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // Subtle gentle slide up
    _slideAnimation = Tween<double>(begin: 12.0, end: 0.0).animate(
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
    final Widget nextScreen = hasPendingNotif
        ? const HomeScreen(openSpotlightOnStart: false)
        : const SpotlightScreen(isLocal: false);

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
          // Ran its full duration: a completed view, not a skip, so it is
          // not recorded as one.
          onComplete: () => Navigator.of(dialogContext).pop(),
          // Nothing renderable — never counted as a view.
          onFailed: () => Navigator.of(dialogContext).pop(),
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

/// Timing contract for the splash advertisement.
///
/// The ad holds the launch for at most [maxDurationSeconds], and the skip
/// control unlocks at the halfway mark — 15s of a full 30s run.
///
/// Skip is derived from the duration rather than fixed so a shorter creative
/// does not make the reader wait a disproportionate share of it, and it is
/// rounded up and floored at one second so the control is never already live
/// on the first frame.
@immutable
class SplashAdTiming {
  const SplashAdTiming._(this.durationSeconds, this.skipAfterSeconds);

  /// Used when the backend sends no duration.
  static const int defaultDurationSeconds = 30;

  /// Hard ceiling, however large a duration the backend sends.
  static const int maxDurationSeconds = 30;

  factory SplashAdTiming.forConfiguredSeconds(int configured) {
    final duration = configured <= 0
        ? defaultDurationSeconds
        : (configured > maxDurationSeconds ? maxDurationSeconds : configured);
    final half = (duration + 1) ~/ 2;
    return SplashAdTiming._(duration, half < 1 ? 1 : half);
  }

  /// How long the ad stays up before closing itself.
  final int durationSeconds;

  /// When the skip control becomes usable.
  final int skipAfterSeconds;
}

/// The app-open advertisement.
///
/// Two rules this screen must never break, because a reader trapped behind
/// an ad at launch is a reader who uninstalls: the skip control becomes
/// usable on a fixed short timer regardless of how long the creative runs,
/// and a creative that cannot render at all closes itself instead of
/// leaving a black screen.
class _SplashAdOverlay extends StatefulWidget {
  final AdBanner ad;
  final VoidCallback onTap;
  final VoidCallback onSkip;

  /// The ad ran its course on its own clock — not a reader-initiated skip.
  final VoidCallback onComplete;

  /// The creative could not be rendered at all (no video, no poster).
  final VoidCallback onFailed;

  const _SplashAdOverlay({
    required this.ad,
    required this.onTap,
    required this.onSkip,
    required this.onComplete,
    required this.onFailed,
  });

  @override
  State<_SplashAdOverlay> createState() => _SplashAdOverlayState();
}

class _SplashAdOverlayState extends State<_SplashAdOverlay> {
  NetworkVideoPlaybackController? _videoController;
  bool _videoInitialized = false;
  Timer? _clock;
  int _elapsed = 0;
  bool _closed = false;

  late final SplashAdTiming _timing =
      SplashAdTiming.forConfiguredSeconds(widget.ad.durationSeconds);

  int get _durationSeconds => _timing.durationSeconds;
  int get _skipAfterSeconds => _timing.skipAfterSeconds;

  bool get _canSkip => _elapsed >= _skipAfterSeconds;

  int get _secondsUntilSkippable {
    final remaining = _skipAfterSeconds - _elapsed;
    return remaining > 0 ? remaining : 0;
  }

  @override
  void initState() {
    super.initState();

    _clock = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _elapsed++);
      // The ad closes itself when its time is up, so the reader is never
      // left waiting for something to happen.
      if (_elapsed >= _durationSeconds) {
        timer.cancel();
        _close(widget.onComplete);
      }
    });

    // Initialize video player if this is a video ad
    if (widget.ad.isVideo && widget.ad.videoUrl.isNotEmpty) {
      _initVideoPlayer();
    }
  }

  /// Dismisses once. The clock, a tap and a failed creative can all race to
  /// close the ad; firing two of them would pop the screen underneath.
  void _close(VoidCallback action) {
    if (_closed || !mounted) return;
    _closed = true;
    action();
  }

  /// Nothing renderable is left, so get out of the reader's way rather than
  /// holding the launch behind a black screen.
  ///
  /// Deferred to after the frame: this can be reached synchronously from
  /// [initState] when the video URL does not resolve, and popping a route
  /// mid-build throws.
  void _failIfNothingToShow() {
    if (widget.ad.imageUrl.isNotEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _close(widget.onFailed);
    });
  }

  void _initVideoPlayer() {
    final mediaSource = MediaResolver.resolve(
      videoUrl: widget.ad.videoUrl,
      thumbnailUrl: widget.ad.imageUrl,
      isVideoFlag: true,
    );

    if (mediaSource.type == MediaSourceType.networkVideo) {
      _videoController = NetworkVideoPlaybackController(
        mediaSource,
        autoPlay: true,
        isMuted: false,
        loop: true,
      );

      final controller = _videoController!;
      controller.initialize().then((_) {
        if (mounted && identical(controller, _videoController)) {
          setState(() {
            _videoInitialized = true;
          });
          controller.play();
        }
      }).catchError((_) {
        // Fall back to the poster if there is one; otherwise there is
        // nothing to show and holding the reader here serves no one.
        if (mounted) _failIfNothingToShow();
      });
    } else {
      // The URL did not resolve to a playable video at all.
      _failIfNothingToShow();
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen Ad Creative (edge-to-edge, no padding)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              _close(widget.onTap);
            },
            child: AdViewabilityDetector(
              ad: widget.ad,
              placementZone: 'splash',
              exposureKey: 'splash_${widget.ad.id}',
              child: _buildMedia(),
            ),
          ),

          // Sponsored Badge (top-left, safe area aware)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.ad.isVideo)
                    const Padding(
                      padding: EdgeInsets.only(right: 5),
                      child: Icon(Icons.videocam_rounded, color: Colors.amber, size: 14),
                    ),
                  const Text(
                    'SPONSORED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom gradient with title
          if (widget.ad.title.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    60,
                    20,
                    MediaQuery.paddingOf(context).bottom + 24,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Text(
                    widget.ad.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          blurRadius: 8,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),

          // Skip Ad Button (top-right, safe area aware, with countdown)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 16,
            right: 16,
            child: GestureDetector(
              onTap: _canSkip
                  ? () {
                      HapticFeedback.lightImpact();
                      _close(widget.onSkip);
                    }
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _canSkip
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _canSkip ? Colors.white38 : Colors.white24,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _canSkip ? 'Skip Ad' : 'Skip Ad in $_secondsUntilSkippable',
                      style: TextStyle(
                        color: _canSkip
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_canSkip) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.skip_next_rounded,
                          color: Colors.white, size: 18),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Fills the screen behind a contained creative.
  ///
  /// BoxFit.contain guarantees the ad is never cropped or stretched, but that
  /// leaves bars on any device whose aspect ratio differs from the creative's
  /// — and on a black Scaffold those read as the app failing to load. A
  /// blurred, darkened copy of the creative fills them instead, so the slot
  /// looks deliberate at every size. Cropping the backdrop is fine: it is
  /// decoration, not the advertisement.
  Widget _backdrop() {
    if (widget.ad.imageUrl.isEmpty) return const SizedBox.shrink();
    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: 32, sigmaY: 32),
      child: Image.network(
        widget.ad.imageUrl,
        fit: BoxFit.cover,
        color: Colors.black.withValues(alpha: 0.55),
        colorBlendMode: BlendMode.darken,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }

  static const Widget _spinner = Center(
    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
  );

  Widget _buildMedia() {
    // Video ad — use VideoPlayerWidget with poster fallback
    if (widget.ad.isVideo && _videoController != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _backdrop(),
          if (_videoInitialized)
            Center(
              child: VideoPlayerWidget(
                controller: _videoController!,
                fit: BoxFit.contain,
                showControls: false,
              ),
            )
          else ...[
            // Hold the poster, contained like the video will be, so the
            // creative does not jump size when playback starts.
            if (widget.ad.imageUrl.isNotEmpty)
              Center(
                child: Image.network(
                  widget.ad.imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            _spinner,
          ],
        ],
      );
    }

    // Image ad — contained so it fits any screen whole, never cropped and
    // never stretched, with the blurred backdrop behind it.
    if (widget.ad.imageUrl.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _backdrop(),
          Center(
            child: Image.network(
              widget.ad.imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return _spinner;
              },
              errorBuilder: (_, __, ___) {
                // The only creative failed to decode; close rather than show a
                // placeholder icon the reader has to sit through.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _close(widget.onFailed);
                });
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      );
    }

    // No media at all — nothing to advertise, so do not hold the launch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _close(widget.onFailed);
    });
    return const SizedBox.shrink();
  }
}

