import 'dart:async';
import 'package:flutter/material.dart';

/// A mock interstitial ad screen: shows for a few seconds with a countdown,
/// then reveals a Skip button. Swap the body for a real interstitial ad
/// render (e.g. google_mobile_ads' InterstitialAd) when wiring up real
/// monetization. Call [showInterstitialAd] wherever the ad map calls for
/// one (category switches, every few videos, app resume, etc).
Future<void> showInterstitialAd(BuildContext context) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => const _InterstitialAdScreen(),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

class _InterstitialAdScreen extends StatefulWidget {
  const _InterstitialAdScreen();

  @override
  State<_InterstitialAdScreen> createState() => _InterstitialAdScreenState();
}

class _InterstitialAdScreenState extends State<_InterstitialAdScreen> {
  int _secondsLeft = 3;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSkip = _secondsLeft == 0;
    return Scaffold(
      backgroundColor: const Color(0xFF16123F),
      body: SafeArea(
        child: Stack(
          children: [
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.smartphone_rounded,
                      size: 72, color: Colors.white70),
                  SizedBox(height: 16),
                  Text(
                    'Full-screen Interstitial Ad',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Ad · placeholder slot',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: canSkip
                  ? GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Skip Ad',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12.5)),
                            SizedBox(width: 4),
                            Icon(Icons.close, color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_secondsLeft',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
