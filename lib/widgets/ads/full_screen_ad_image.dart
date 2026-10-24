import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A full-screen ad creative that fills the phone's screen.
///
/// A creative made in (or close to) the phone's own ratio is drawn edge to
/// edge — BoxFit.cover, trimming at most a sliver. One far from it (a wide
/// banner on a tall phone) would lose too much to cover, including the call
/// to action near its edge, so it is shown whole over a blurred, darkened
/// copy of itself that fills the rest of the screen.
///
/// Best result: upload full-screen ads at the phone ratio, 1080 × 2340
/// (9 : 19.5), with the important parts away from the top and bottom edges.
class FullScreenAdImage extends StatefulWidget {
  const FullScreenAdImage({
    super.key,
    required this.imageUrl,
    this.errorBuilder,
  });

  final String imageUrl;
  final WidgetBuilder? errorBuilder;

  /// How far a creative's ratio may be from the screen's and still fill it.
  static const fillTolerance = 0.20;

  /// Whether a creative of [imageRatio] (width / height) fills a screen of
  /// [screenRatio] edge to edge.
  static bool fills(double imageRatio, double screenRatio) {
    if (imageRatio <= 0 || screenRatio <= 0) return false;
    final diff = (imageRatio - screenRatio).abs() / screenRatio;
    return diff <= fillTolerance;
  }

  @override
  State<FullScreenAdImage> createState() => _FullScreenAdImageState();
}

class _FullScreenAdImageState extends State<FullScreenAdImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  double? _ratio;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant FullScreenAdImage old) {
    super.didUpdateWidget(old);
    if (old.imageUrl != widget.imageUrl) {
      _ratio = null;
      _failed = false;
      _resolve();
    }
  }

  /// Reads the creative's size once it loads (from the image cache).
  void _resolve() {
    _unlisten();
    if (widget.imageUrl.trim().isEmpty) return;
    final stream = CachedNetworkImageProvider(widget.imageUrl)
        .resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener((info, _) {
      final w = info.image.width.toDouble();
      final h = info.image.height.toDouble();
      if (mounted && h > 0) setState(() => _ratio = w / h);
    }, onError: (_, __) {
      if (mounted) setState(() => _failed = true);
    });
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  void _unlisten() {
    final l = _listener;
    if (l != null) _stream?.removeListener(l);
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _unlisten();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed || widget.imageUrl.trim().isEmpty) {
      return widget.errorBuilder?.call(context) ?? const SizedBox.expand();
    }
    return LayoutBuilder(builder: (context, c) {
      final screenRatio = c.maxHeight > 0 && c.maxWidth.isFinite
          ? c.maxWidth / c.maxHeight
          : 0.0;
      final ratio = _ratio;
      if (ratio == null) {
        return const Center(
            child: CircularProgressIndicator(color: Colors.white70));
      }
      final fill = FullScreenAdImage.fills(ratio, screenRatio);
      final image = CachedNetworkImage(
        key: Key(fill ? 'full_screen_ad_fill' : 'full_screen_ad_whole'),
        imageUrl: widget.imageUrl,
        width: double.infinity,
        height: double.infinity,
        fit: fill ? BoxFit.cover : BoxFit.contain,
        fadeInDuration: Duration.zero,
      );
      if (fill) return image;
      return Stack(
        fit: StackFit.expand,
        children: [
          // Fills the rest of the screen; cropping this is fine, it is
          // only backdrop.
          IgnorePointer(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
              child: CachedNetworkImage(
                imageUrl: widget.imageUrl,
                fit: BoxFit.cover,
                color: Colors.black.withValues(alpha: 0.5),
                colorBlendMode: BlendMode.darken,
              ),
            ),
          ),
          image,
        ],
      );
    });
  }
}
