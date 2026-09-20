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

  /// Artwork asset. 1162x215, so it is laid out at its own 5.4:1 ratio
  /// rather than being squeezed to whatever box it lands in.
  static const String asset = 'assets/images/watermark_banner.png';
  static const double aspectRatio = 1162 / 215;

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
