import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A news photo that never looks zoomed or stretched in its frame.
///
/// When the photo's shape is close to the frame's, it fills the frame
/// (`BoxFit.cover`, trimming only a sliver). When the shapes differ a lot —
/// a wide 16:9 photo or a tall portrait in a near-square slot — cover would
/// crop heavily and read as "zoomed in", so the whole photo is shown
/// (`BoxFit.contain`) over a blurred copy of itself instead of bare bars.
class SmartFitImage extends StatefulWidget {
  const SmartFitImage({
    super.key,
    required this.imageUrl,
    this.maxDecodeWidth = 1080,
    this.coverTolerance = 0.25,
  });

  final String imageUrl;

  /// Decode width cap, as memCacheWidth elsewhere.
  final int maxDecodeWidth;

  /// How far the photo's aspect may differ from the frame's (as a fraction)
  /// and still be shown with cover.
  final double coverTolerance;

  /// Whether [imageAspect] should fill a [frameAspect] frame (cover) rather
  /// than be shown whole (contain). Aspects are width / height.
  @visibleForTesting
  static bool shouldCover(
      double imageAspect, double frameAspect, double tolerance) {
    if (imageAspect <= 0 || frameAspect <= 0) return true;
    return ((imageAspect / frameAspect) - 1).abs() <= tolerance;
  }

  @override
  State<SmartFitImage> createState() => _SmartFitImageState();
}

class _SmartFitImageState extends State<SmartFitImage> {
  ImageProvider? _provider;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  double? _imageAspect;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant SmartFitImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.maxDecodeWidth != widget.maxDecodeWidth) {
      _imageAspect = null;
      _failed = false;
      _resolve();
    }
  }

  void _resolve() {
    if (widget.imageUrl.isEmpty) {
      _failed = true;
      return;
    }
    final provider = CachedNetworkImageProvider(
      widget.imageUrl,
      maxWidth: widget.maxDecodeWidth,
    );
    final stream = provider.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key && _provider != null) return;
    _detach();
    _provider = provider;
    _stream = stream;
    _listener = ImageStreamListener(
      (info, _) {
        final w = info.image.width, h = info.image.height;
        if (!mounted || h == 0) return;
        final aspect = w / h;
        if (aspect != _imageAspect) setState(() => _imageAspect = aspect);
      },
      onError: (_, __) {
        if (mounted) setState(() => _failed = true);
      },
    );
    stream.addListener(_listener!);
  }

  void _detach() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    if (_failed || provider == null) {
      return Container(
        color: AppColors.chipBg,
        child: const Center(
          child: Icon(Icons.image_not_supported_outlined,
              color: AppColors.textMuted, size: 40),
        ),
      );
    }
    final aspect = _imageAspect;
    if (aspect == null) {
      return Container(color: AppColors.chipBg);
    }

    return LayoutBuilder(builder: (context, constraints) {
      final frameAspect = constraints.hasBoundedHeight &&
              constraints.maxHeight > 0
          ? constraints.maxWidth / constraints.maxHeight
          : aspect;
      if (SmartFitImage.shouldCover(
          aspect, frameAspect, widget.coverTolerance)) {
        return Image(image: provider, fit: BoxFit.cover, gaplessPlayback: true);
      }
      return RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Same decoded image, blurred to fill the frame edge to edge.
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Image(
                  image: provider, fit: BoxFit.cover, gaplessPlayback: true),
            ),
            const ColoredBox(color: Color(0x33000000)),
            Image(image: provider, fit: BoxFit.contain, gaplessPlayback: true),
          ],
        ),
      );
    });
  }
}
