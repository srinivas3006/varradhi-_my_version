import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/ad_banner.dart';
import '../../services/ad_manager.dart';
import '../../theme/app_theme.dart';
import 'ad_viewability_detector.dart';
import 'full_screen_ad_image.dart';
import 'video_ad_card.dart';

/// Evaluates eligibility and displays an interstitial ad overlay at a natural break.
/// Returns true if an ad was actually presented, false if suppressed or unavailable.
Future<bool> showInterstitialAd(BuildContext context) async {
  // 1. Client UX eligibility check
  if (!AdManager.instance.canShowInterstitial()) {
    return false;
  }

  // 2. Fetch eligible interstitial ads
  final ads =
      await AdManager.instance.getAdsForZone('feed', forceRefresh: true);
  final ad = AdManager.instance.selectAd(
    ads.where((ad) => ad.isInterstitial || ad.isFullScreen).toList(),
  );
  if (ad == null) {
    return false;
  }

  if (!context.mounted) return false;

  await Navigator.of(context).push(
    PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => _InterstitialAdScreen(ad: ad),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );

  return true;
}

class _InterstitialAdScreen extends StatefulWidget {
  final AdBanner ad;

  const _InterstitialAdScreen({required this.ad});

  @override
  State<_InterstitialAdScreen> createState() => _InterstitialAdScreenState();
}

class _InterstitialAdScreenState extends State<_InterstitialAdScreen>
    with WidgetsBindingObserver {
  int _secondsLeft = 0;
  Timer? _timer;
  bool _canSkip = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _secondsLeft = widget.ad.displayDurationSeconds;
    if (_secondsLeft > 0) _startTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _timer?.cancel();
    if (state == AppLifecycleState.resumed && _secondsLeft > 0) _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _secondsLeft = 0;
          _canSkip = true;
        });
        AdManager.instance
            .recordHide(widget.ad, placementZone: widget.ad.placementZone);
        Navigator.of(context).pop();
      } else {
        setState(() => _secondsLeft--);
        if (_secondsLeft <= 2) {
          _canSkip = true;
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void _handleClose() {
    _timer?.cancel();
    HapticFeedback.lightImpact();
    AdManager.instance
        .recordDismiss(widget.ad, placementZone: widget.ad.placementZone);
    Navigator.of(context).pop();
  }

  void _handleSkip() {
    _timer?.cancel();
    HapticFeedback.lightImpact();
    AdManager.instance
        .recordSkip(widget.ad, placementZone: widget.ad.placementZone);
    Navigator.of(context).pop();
  }

  Future<void> _handleTap() async {
    HapticFeedback.selectionClick();
    AdManager.instance
        .recordClick(widget.ad, placementZone: widget.ad.placementZone);

    if (widget.ad.destinationUrl.isNotEmpty) {
      final uri = Uri.tryParse(widget.ad.destinationUrl);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdViewabilityDetector(
      ad: widget.ad,
      placementZone: widget.ad.placementZone,
      exposureKey: 'interstitial_${widget.ad.id}',
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // The creative fills the whole phone screen, edge to edge
            // (behind the status bar too) — see FullScreenAdImage.
            GestureDetector(
              key: const Key('interstitial_creative'),
              behavior: HitTestBehavior.opaque,
              onTap: _handleTap,
              child: widget.ad.videoUrl.isNotEmpty
                  ? Center(
                      child: VideoAdCard(
                          ad: widget.ad,
                          placementZone: widget.ad.placementZone,
                          exposureKey: 'interstitial_${widget.ad.id}'),
                    )
                  : FullScreenAdImage(
                      imageUrl: widget.ad.imageUrl,
                      errorBuilder: (_) => const Center(
                        child: Icon(Icons.campaign_rounded,
                            size: 72, color: Colors.white54),
                      ),
                    ),
            ),
            // Title and call to action on a fade at the bottom, over the
            // creative rather than taking space from it.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  height: 260,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xE6000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.ad.title.isNotEmpty
                              ? widget.ad.title
                              : 'Sponsored Promotion',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 6)
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.ad.destinationUrl.isNotEmpty
                              ? 'Sponsored · ${Uri.tryParse(widget.ad.destinationUrl)?.host ?? widget.ad.destinationUrl}'
                              : 'Sponsored Partner',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12.5),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _handleTap,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Learn More',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Top Bar: "Sponsored" Tag & Close/Skip Button
                  Positioned(
                    top: 12,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.campaign_rounded,
                              color: Colors.amber, size: 14),
                          SizedBox(width: 5),
                          Text(
                            'SPONSORED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Positioned(
                    top: 12,
                    right: 16,
                    child: _canSkip
                        ? GestureDetector(
                            onTap:
                                _secondsLeft == 0 ? _handleClose : _handleSkip,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _secondsLeft == 0 ? 'Close' : 'Skip Ad',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.close,
                                      color: Colors.white, size: 16),
                                ],
                              ),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              'Ad closes in $_secondsLeft s',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
