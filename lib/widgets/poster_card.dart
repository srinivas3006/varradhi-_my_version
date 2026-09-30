// ignore_for_file: deprecated_member_use
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/sharing/share_content_builder.dart';
import 'sharing/share_sheet.dart';

/// One poster page in Spotlight: the creative fills the whole screen, with a
/// label row on a top scrim and the title plus the single Share action on a
/// bottom scrim.
class PosterCard extends StatefulWidget {
  /// Poster id, so the card can build its canonical public URL. Without it
  /// there is nothing to share but the raw image link.
  final String posterId;

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
    this.posterId = '',
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
    // Was Share.share(_imageUrl), which put a raw CDN image URL on the wire.
    // Goes through the common sheet now, which shares the canonical public
    // poster link instead.
    ShareSheet.show(
      context,
      ShareContentBuilder.fromPoster({
        'id': widget.posterId,
        'title': widget.title,
        'image_url': _imageUrl,
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The poster, full screen: edge to edge, top to bottom, no
          // letterbox. Cover fills the whole page; the scrims below keep the
          // chrome legible. Sharing still sends the full, uncropped image.
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              physics: const ClampingScrollPhysics(),
              itemCount: _images.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => CachedNetworkImage(
                imageUrl: _images[i],
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                width: double.infinity,
                height: double.infinity,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white70),
                ),
                errorWidget: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_rounded,
                      color: Colors.white38, size: 40),
                ),
              ),
            ),
          ),

          // Top chrome over a scrim, so it stays legible on any artwork.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, padding.top + 12, 16, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    'పోస్టర్లు',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  if (_images.length > 1)
                    Row(
                      children: [
                        const Icon(Icons.photo_library_rounded,
                            size: 13, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text('${_index + 1}/${_images.length}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                  if (widget.durationSeconds > 0 && _secondsLeft > 0) ...[
                    const SizedBox(width: 10),
                    Text('$_secondsLeft s',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white70)),
                  ],
                ],
              ),
            ),
          ),

          // Title, dots and share over a bottom scrim.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding:
                  // Just clears Spotlight's 56pt bottom bar.
                  EdgeInsets.fromLTRB(16, 28, 8, padding.bottom + 64),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_images.length > 1) ...[
                    _Dots(count: _images.length, index: _index),
                    const SizedBox(height: 12),
                  ],
                  // Title left, a plain share icon bottom-right — the same as
                  // the poster screen. No full-width button over the poster.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        key: const Key('poster_share'),
                        onPressed: _share,
                        tooltip: 'షేర్ చేయండి',
                        icon: const Icon(Icons.share_rounded,
                            color: Colors.white, size: 26),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Page indicator for posters that carry more than one design.
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
