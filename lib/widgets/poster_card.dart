// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';

/// Full-screen, non-overlapping Poster / Advertisement card with a 5-second countdown
/// and an 'X' close button to immediately dismiss.
class PosterCard extends StatefulWidget {
  final String mediaUrl;
  final VoidCallback? onClose;
  final int durationSeconds;

  const PosterCard({
    super.key,
    required this.mediaUrl,
    this.onClose,
    this.durationSeconds = 5,
  });

  @override
  State<PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<PosterCard> {
  late int _secondsLeft;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.durationSeconds;
    _startTimer();
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
        widget.onClose?.call();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _handleManualClose() {
    HapticFeedback.lightImpact();
    _countdownTimer?.cancel();
    widget.onClose?.call();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black, // Fully opaque background prevents article text bleed-through
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Subtle Blurred Ambient Background
          Positioned.fill(
            child: Opacity(
              opacity: 0.35,
              child: CachedNetworkImage(
                imageUrl: widget.mediaUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox(),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(color: Colors.black.withValues(alpha: 0.4)),
            ),
          ),

          // 2. Main High-Res Poster Image (Fitted cleanly without clipping)
          Positioned.fill(
            child: SafeArea(
              top: false,
              bottom: false,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: widget.mediaUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(color: Colors.white70),
                  ),
                  errorWidget: (context, url, error) => const Center(
                    child: Icon(Icons.broken_image_rounded, size: 64, color: Colors.white38),
                  ),
                ),
              ),
            ),
          ),

          // 3. Top Header Bar: 'Sponsored' Badge & 5-Second Timer with 'X' Close Button
          Positioned(
            top: topPadding + 12,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Sponsored Badge
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.campaign_rounded, size: 14, color: Colors.amberAccent),
                          SizedBox(width: 6),
                          Text(
                            'Sponsored',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Timer Pill & Close 'X' Button
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.only(left: 12, right: 4, top: 4, bottom: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white30, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _secondsLeft > 0 ? '${_secondsLeft}s' : 'Done',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 6),
                          // 'X' Cross Close Icon Button
                          InkWell(
                            onTap: _handleManualClose,
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                color: Colors.white24,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. Floating Action Button for Sharing (Bottom Right)
          Positioned(
            bottom: bottomPadding + 24,
            right: 20,
            child: FloatingActionButton.small(
              heroTag: 'share_poster_${widget.mediaUrl.hashCode}',
              backgroundColor: Colors.white,
              elevation: 4,
              onPressed: () {
                HapticFeedback.lightImpact();
                Share.share(widget.mediaUrl);
              },
              child: const Icon(Icons.share_rounded, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
