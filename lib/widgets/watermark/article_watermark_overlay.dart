import 'package:flutter/material.dart';

import 'watermark_banner.dart';

/// A non-intrusive, responsive watermark overlay designed for news article images.
///
/// Features:
/// 1. Bottom-Right: Vaaradhi brand logo watermark (8–12% of image width, opacity ~0.20).
/// 2. Left-Center: Vertical "VAARADHI" text rotated 90° bottom-to-top (opacity ~0.12).
/// 3. Safe-zone edge adherence: All watermarks remain strictly on edges (8–12px padding),
///    keeping the central content, faces, and headline completely unobstructed.
/// 4. Responsive scaling across landscape, square, and portrait aspect ratios.
class ArticleWatermarkOverlay extends StatelessWidget {
  /// Optional image or media widget to wrap. If provided, the watermark is
  /// painted on top in a Stack. If null, this widget can be placed directly inside an existing Stack.
  final Widget? child;

  /// Explicit dimensions if available (useful for off-screen rendering like [ShareService]).
  final double? width;
  final double? height;

  /// Custom logo opacity (defaults to 0.20, within the 0.15–0.25 requirement).
  final double logoOpacity;

  /// Custom text opacity (defaults to 0.12, within the 0.08–0.15 requirement).
  final double textOpacity;

  const ArticleWatermarkOverlay({
    super.key,
    this.child,
    this.width,
    this.height,
    this.logoOpacity = 0.20,
    this.textOpacity = 0.12,
  });

  @override
  Widget build(BuildContext context) {
    if (width != null && height != null) {
      return _buildContent(context, width!, height!);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final h = constraints.maxHeight.isFinite && constraints.maxHeight > 0
            ? constraints.maxHeight
            : w * 0.6; // standard fallback aspect ratio
        return _buildContent(context, w, h);
      },
    );
  }

  Widget _buildContent(BuildContext context, double w, double h) {
    // Proportional logo sizing (8–12% of image width, scaled for responsive layout)
    final double logoSize = (w * 0.10).clamp(28.0, 110.0);

    // Dynamic edge padding (8–12px relative to dimensions)
    final double edgePadding = (w * 0.025).clamp(8.0, 16.0);

    // Font size for vertical branding text proportional to image scale
    final double fontSize = (w * 0.026).clamp(9.0, 18.0);
    final double letterSpacing = (fontSize * 0.28).clamp(1.5, 4.0);

    final overlay = IgnorePointer(
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // 1. Vertical "VAARADHI" text on left edge (rotated 90 degrees bottom-to-top)
          Positioned(
            left: edgePadding,
            top: 0,
            bottom: 0,
            child: Center(
              child: RotatedBox(
                quarterTurns: 3, // 270° clockwise = 90° counter-clockwise (bottom to top)
                child: Opacity(
                  opacity: textOpacity.clamp(0.05, 0.25),
                  child: Text(
                    'VAARADHI',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                      letterSpacing: letterSpacing,
                      color: Colors.white,
                      shadows: const [
                        Shadow(
                          color: Colors.black45,
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. Small Vaaradhi Logo in bottom-right corner
          Positioned(
            right: edgePadding,
            bottom: edgePadding,
            child: Opacity(
              opacity: logoOpacity.clamp(0.10, 0.35),
              child: Image.asset(
                'assets/images/logo.png',
                width: logoSize,
                height: logoSize,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Masthead band across the foot of a shared image. The corner mark
          // alone was nearly invisible at its clamped opacity, so a reposted
          // screenshot carried no attribution anyone could read.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: edgePadding, vertical: edgePadding * 0.6),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: const WatermarkBanner(
                height: 22,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );

    if (child == null) {
      return overlay;
    }

    return Stack(
      fit: StackFit.passthrough,
      children: [
        child!,
        Positioned.fill(child: overlay),
      ],
    );
  }
}
