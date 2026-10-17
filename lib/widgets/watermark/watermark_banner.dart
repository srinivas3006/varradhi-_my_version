import 'package:flutter/material.dart';

/// The Vaaradhi masthead strip.
///
/// One widget for every place the brand band appears — between the media and
/// the story on the spotlight card and the article screen, and burned into
/// generated share images — so the artwork and its proportions are defined
/// once rather than per screen.
class WatermarkBanner extends StatelessWidget {
  const WatermarkBanner({
    super.key,
    this.height,
    this.opacity = 1.0,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
  });

  /// Artwork asset. 1600x533, so it is laid out at its own 3:1 ratio
  /// rather than being squeezed to whatever box it lands in.
  static const String asset = 'assets/images/watermark_bannerv1.jpeg';
  static const double aspectRatio = 1600 / 533;

  /// The artwork is an opaque JPEG: the red strip and logo circle sit in the
  /// middle, with plain black above and below. These are the strip's top and
  /// bottom as fractions of the artwork height — what share images crop to,
  /// so the black margins never cover the photo or bloat the card.
  static const double stripTop = 0.21;
  static const double stripBottom = 0.80;

  final double? height;
  final double opacity;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final banner = Image.asset(
      asset,
      fit: BoxFit.contain,
      // Decoded near its display width rather than at full size: this sits
      // in a scrolling feed.
      filterQuality: FilterQuality.medium,
    );

    return Padding(
      padding: padding,
      child: Opacity(
        opacity: opacity,
        child: height != null
            ? SizedBox(height: height, child: banner)
            : AspectRatio(aspectRatio: aspectRatio, child: banner),
      ),
    );
  }
}
