// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_theme.dart';

/// One poster page.
///
/// Laid out the way the reference feed does it: a label row above, the
/// creative in a rounded card that fits it whole, and the title with a share
/// action below. The poster is not full-bleed, because a poster is a thing
/// you are meant to send to someone — it reads as an object on the page
/// rather than a background, and `BoxFit.contain` keeps its edges intact,
/// which cropping would destroy.
class PosterCard extends StatefulWidget {
  final String mediaUrl;
  final List<String> imageUrls;
  final VoidCallback? onClose;
  final int durationSeconds;

  /// Position of this page within its parent poster, for the "2 / 5" counter.
  final int pageIndex;
  final int pageCount;
  final String title;

  const PosterCard({
    super.key,
    required this.mediaUrl,
    this.imageUrls = const [],
    this.onClose,
    this.durationSeconds = 0,
    this.pageIndex = 1,
    this.pageCount = 1,
    this.title = '',
  });

  @override
  State<PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<PosterCard> {
  late int _secondsLeft;
  Timer? _countdownTimer;

  final PageController _pageController = PageController();
  int _index = 0;

  /// Every design in this poster, in backend order.
  List<String> get _images =>
      widget.imageUrls.isNotEmpty ? widget.imageUrls : [widget.mediaUrl];

  String get _imageUrl => _images[_index.clamp(0, _images.length - 1)];

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.durationSeconds;
    if (_secondsLeft > 0) _startTimer();
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        timer.cancel();
        widget.onClose?.call();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _share() {
    HapticFeedback.lightImpact();
    Share.share(_imageUrl);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final padding = MediaQuery.paddingOf(context);

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: EdgeInsets.only(
        top: padding.top + 76,
        bottom: padding.bottom + 96,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Text(
                  'పోస్టర్లు',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                if (_images.length > 1)
                  Row(
                    children: [
                      const Icon(Icons.photo_library_rounded,
                          size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        '${_index + 1}/${_images.length}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                if (widget.durationSeconds > 0 && _secondsLeft > 0) ...[
                  const SizedBox(width: 10),
                  Text('$_secondsLeft s',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted)),
                ],
              ],
            ),
          ),
          // A fixed 4:5 box, as the reference studio uses — not Expanded.
          // Expanded sized the creative from whatever was left after the
          // title and button, so a poster with no title got a taller box than
          // one with a title, and BoxFit.contain then drew each design at a
          // different size. Swiping between them made the image jump, which
          // is the glitch: the box must be the constant, not the leftovers.
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AspectRatio(
                  // 9:16 — posters are authored portrait for sharing, and a
                  // 4:5 box left the tall ones letterboxed under BoxFit.contain.
                  aspectRatio: 9 / 16,
                  child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                        color: isDark ? Colors.white10 : Colors.black12),
                    // Horizontal, so it never competes with the vertical feed
                    // for a drag. This is how the reader reaches the poster's
                    // other designs.
                    PageView.builder(
                      controller: _pageController,
                      physics: const ClampingScrollPhysics(),
                      itemCount: _images.length,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (_, i) => CachedNetworkImage(
                        imageUrl: _images[i],
                        // Contain, not cover: a poster is shared whole, so
                        // cropping its edges defeats the point of the slot.
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        errorWidget: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image_rounded,
                              size: 56, color: Colors.white38),
                        ),
                      ),
                    ),
                    if (_images.length > 1)
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: _Dots(count: _images.length, index: _index),
                      ),
                  ],
                ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.title.isNotEmpty) ...[
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                FilledButton.icon(
                  onPressed: _share,
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('షేర్ చేయండి'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Page dots, as on the media carousel.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == index ? Colors.white : Colors.white54,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}
