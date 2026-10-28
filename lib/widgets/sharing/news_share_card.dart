import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/article_typography.dart';

/// The image a reader downloads or shares (built off-screen; the article
/// screen itself is untouched). 4:3 landscape, exported at 1600 × 1200:
///
///  ┌───────────────────────────────┐
///  │ V                             │  photo, 77% of the height, cover-cropped
///  │ A  photo                      │  "VAARADHI" watermark up the left edge
///  │ …                             │
///  ├───────────────────────────────┤
///  │ logo|వారధి|tagline|download    │  black brand banner, 7%
///  ├───────────────────────────────┤
///  │ ▌Sports | 06 Oct 2026         │  category + date (red)
///  │ Headline in bold Telugu       │  headline — the white area grows with
///  └───────────────────────────────┘  it instead of cutting or shrinking it
class NewsShareCard extends StatelessWidget {
  static const double width = 1600;
  static const double height = 1200;
  static const double photoHeight = height * 0.77; // 924
  static const double stripHeight = height * 0.07; // 84
  static const double textAreaMinHeight =
      height - photoHeight - stripHeight; // 192

  /// Same left edge for the logo, the category row and the headline.
  static const double sidePadding = 64;

  // Download: a tall portrait card (4:5, 1080 × 1350 or taller), so the
  // story text reads large when the saved image is opened on a phone.
  //
  //  ┌─────────────────┐
  //  │ V   photo  4:3  │  810
  //  ├─────────────────┤
  //  │ [logo] వారధి    │  96
  //  ├─────────────────┤
  //  │ ▌Cinema | date  │
  //  │ Headline        │  grows with the text
  //  │ Story text …    │
  //  └─────────────────┘
  static const double portraitWidth = 1080;
  static const double portraitMinHeight = 1350;
  static const double portraitPhotoHeight = portraitWidth * 3 / 4; // 810
  static const double portraitStripHeight = 96;
  static const double portraitTextAreaMinHeight =
      portraitMinHeight - portraitPhotoHeight - portraitStripHeight; // 444
  static const double portraitSidePadding = 56;

  /// Story lines on the portrait card before it ends in "…".
  static const int portraitSummaryMaxLines = 12;

  static const String logoAsset = 'assets/images/logo.png';

  /// The logo artwork's bridge + sun occupies its top 76%; the red wordmark
  /// under it is replaced by a white one in the strip.
  static const double _logoArtHeightFraction = 0.76;

  final String headline;
  final String meta; // "Sports  |  06 Oct 2026"

  /// Story text under the headline — Download sets it, Share leaves it
  /// empty.
  final String summary;
  final Uint8List? photo;

  /// The photo's width / height. Given, the photo area takes the photo's
  /// own shape (within [minPhotoAspect]..[maxPhotoAspect]) so the whole
  /// picture is shared, as the reader saw it — the fixed 1600 × 924 area
  /// cut the top and bottom off portrait photos. Null: the fixed area.
  final double? photoAspect;

  /// Tallest photo area (4:5); a taller photo keeps its top.
  static const double minPhotoAspect = 0.8;

  /// Widest photo area (1.91:1, the widest image chat apps show uncut).
  static const double maxPhotoAspect = 1.91;

  /// Height of the photo area on this card.
  double get photoAreaHeight {
    final a = photoAspect;
    if (a == null || a <= 0 || !a.isFinite) {
      return portrait ? portraitPhotoHeight : photoHeight;
    }
    return cardWidth / a.clamp(minPhotoAspect, maxPhotoAspect);
  }

  /// Download's tall layout (see [portraitWidth]); Share keeps the 4:3
  /// landscape card.
  final bool portrait;

  const NewsShareCard({
    super.key,
    required this.headline,
    required this.meta,
    this.photo,
    this.summary = '',
    this.portrait = false,
    this.photoAspect,
  });

  /// Width the card is laid out (and captured) at.
  double get cardWidth => portrait ? portraitWidth : width;

  static const _ink = Color(0xFF111111);
  static const _accent = Color(0xFFD71920);
  static const _body = Color(0xFF3A3A3A);

  @override
  Widget build(BuildContext context) {
    // Portrait type is set against a 1080 px width, so the same point sizes
    // read about 1.5× larger on the phone than on the 1600 px landscape card.
    final side = portrait ? portraitSidePadding : sidePadding;
    final metaSize = portrait ? 34.0 : 36.0;
    final headlineSize = portrait ? 60.0 : 54.0;
    final summarySize = portrait ? 46.0 : 50.0;
    final summaryLines = portrait ? portraitSummaryMaxLines : 8;

    return SizedBox(
      width: cardWidth,
      child: ColoredBox(
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              key: const Key('share_card_photo'),
              height: photoAreaHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _photo(),
                  const _VerticalWatermark(),
                ],
              ),
            ),
            _BrandStrip(
              height: portrait ? portraitStripHeight : stripHeight,
              cardWidth: cardWidth,
            ),
            ConstrainedBox(
              key: const Key('share_card_text_area'),
              constraints: BoxConstraints(
                  minHeight: portrait
                      ? portraitTextAreaMinHeight
                      : textAreaMinHeight),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    side, portrait ? 30 : 26, side, portrait ? 40 : 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (meta.isNotEmpty) ...[
                      Row(
                        key: const Key('share_card_meta'),
                        children: [
                          Container(
                            width: 8,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _accent,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 18),
                          Flexible(
                            child: Text(
                              meta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ArticleTypography.body(
                                fontSize: metaSize,
                                color: _accent,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: portrait ? 18 : 14),
                    ],
                    // No maxLines: a long headline makes the card taller
                    // rather than being cut or shrunk.
                    Text(
                      headline,
                      key: const Key('share_card_headline'),
                      style: ArticleTypography.heading(
                        fontSize: headlineSize,
                        color: _ink,
                        height: 1.35,
                      ),
                    ),
                    // Download only: the start of the story under the headline
                    // (Share passes none). The white area grows to fit it.
                    if (summary.isNotEmpty) ...[
                      SizedBox(height: portrait ? 26 : 22),
                      Text(
                        summary,
                        key: const Key('share_card_summary'),
                        maxLines: summaryLines,
                        overflow: TextOverflow.ellipsis,
                        style: ArticleTypography.body(
                          fontSize: summarySize,
                          color: _body,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photo() {
    final p = photo;
    if (p != null) {
      // The area has the photo's own shape, so cover shows all of it. Only
      // a photo beyond the 4:5 / 1.91:1 limits is trimmed: a tall one keeps
      // its top (faces, headlines), as on the app's cards.
      final a = photoAspect;
      final tall = a != null && a < minPhotoAspect;
      return Image.memory(p,
          fit: BoxFit.cover,
          alignment: tall ? const Alignment(0, -0.4) : Alignment.center,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true);
    }
    // No photo: the app's branded placeholder (orange gradient + logo), the
    // same look the feed uses for stories without a picture.
    return Container(
      key: const Key('share_card_placeholder'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF57C00), Color(0xFFD71920)],
        ),
      ),
      alignment: Alignment.center,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: Image.asset(logoAsset,
            width: 360, height: 360, filterQuality: FilterQuality.high),
      ),
    );
  }
}

/// Bold sans-serif, white at 35%.
TextStyle get watermarkStyle => GoogleFonts.poppins(
      fontSize: 78,
      fontWeight: FontWeight.w800,
      letterSpacing: 10,
      color: Colors.white.withValues(alpha: 0.35),
      height: 1,
    );

/// "VAARADHI" up the left edge of the photo, bottom to top, white at 35%.
class _VerticalWatermark extends StatelessWidget {
  const _VerticalWatermark();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 22),
        child: RotatedBox(
          key: const Key('share_card_watermark'),
          quarterTurns: 3, // reads bottom → top
          child: Text(
            'VAARADHI',
            // Poppins: the app's own Latin font, bundled via google_fonts and
            // preloaded before capture (a named system font is not
            // guaranteed on every phone).
            style: watermarkStyle,
          ),
        ),
      ),
    );
  }
}

/// The brand banner under the photo (Oct 2026 design): app icon | white
/// "వారధి" with an orange swoosh | "మీ ప్రాంతం.. మీ వార్తలు" | "ఇప్పుడే
/// డౌన్‌లోడ్ చేయండి" with Play and App Store badges, on black with orange
/// glow waves at the bottom corners.
///
/// Designed once on a 1600 px canvas (the share card's width) and scaled
/// evenly to the card, so Share and the narrower Download card match.
class _BrandStrip extends StatelessWidget {
  const _BrandStrip({required this.height, required this.cardWidth});

  final double height;
  final double cardWidth;

  static const double designWidth = 1600;

  @override
  Widget build(BuildContext context) {
    final scale = cardWidth / designWidth;
    return SizedBox(
      key: const Key('share_card_brand'),
      height: height,
      child: FittedBox(
        fit: BoxFit.fill,
        child: SizedBox(
          width: designWidth,
          height: height / scale,
          child: const _BrandBanner(),
        ),
      ),
    );
  }
}

class _BrandBanner extends StatelessWidget {
  const _BrandBanner();

  /// The logo's orange (sampled from assets/images/logo.png), for
  /// "మీ వార్తలు".
  static const _logoOrange = Color(0xFFF46A00);

  Widget _divider(double h) => Container(
        width: 1.5,
        height: h,
        margin: const EdgeInsets.symmetric(horizontal: 34),
        color: Colors.white.withValues(alpha: 0.28),
      );

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A1A1A), Color(0xFF050505)],
            ),
          ),
        ),
        const CustomPaint(painter: _GlowWavesPainter()),
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // App icon: the logo's bridge + sun (its red wordmark
                // trimmed off), on a rounded tile.
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: NewsShareCard._logoArtHeightFraction,
                      child: Image.asset(
                        NewsShareCard.logoAsset,
                        width: 78,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                ),
                _divider(46),
                // Wordmark with the orange swoosh under it.
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'వారధి',
                      style: ArticleTypography.heading(
                        fontSize: 54,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(
                      width: 180,
                      height: 22,
                      child: CustomPaint(painter: _SwooshPainter()),
                    ),
                  ],
                ),
                _divider(46),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: 'మీ ప్రాంతం.. ',
                      style: ArticleTypography.body(
                        fontSize: 36,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                    TextSpan(
                      text: 'మీ వార్తలు',
                      style: ArticleTypography.body(
                        fontSize: 42,
                        color: _logoOrange,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                  ]),
                ),
                _divider(46),
                Text(
                  'ఇప్పుడే డౌన్‌లోడ్ చేయండి',
                  style: ArticleTypography.body(
                    fontSize: 26,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
                const SizedBox(width: 20),
                const _StoreBadge(child: _PlayMark()),
                const SizedBox(width: 12),
                const _StoreBadge(
                  child: Icon(Icons.apple, color: Colors.white, size: 34),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A store badge tile: dark, rounded, hairline border.
class _StoreBadge extends StatelessWidget {
  const _StoreBadge({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// The Play Store triangle in its four colours.
class _PlayMark extends StatelessWidget {
  const _PlayMark();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 30,
        height: 32,
        child: CustomPaint(painter: _PlayMarkPainter()),
      );
}

class _PlayMarkPainter extends CustomPainter {
  const _PlayMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    const top = Offset.zero;
    final bottom = Offset(0, h), tip = Offset(w, h / 2);
    final centre = Offset(w * 0.46, h / 2);
    void tri(Offset a, Offset b, Offset c, Color color) => canvas.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..lineTo(c.dx, c.dy)
          ..close(),
        Paint()..color = color);
    tri(top, bottom, centre, const Color(0xFF2196F3)); // blue, left
    tri(top, centre, tip, const Color(0xFF34A853)); // green, top
    tri(bottom, tip, centre, const Color(0xFFEA4335)); // red, bottom
    // Yellow at the tip.
    tri(Offset(w * 0.68, h * 0.34), tip, Offset(w * 0.68, h * 0.66),
        const Color(0xFFFBBC04));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The #FF0000 swoosh under the wordmark.
class _SwooshPainter extends CustomPainter {
  const _SwooshPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // A solid #FF0000 crescent, thick in the middle.
    final path = Path()
      ..moveTo(0, size.height * 0.25)
      ..quadraticBezierTo(size.width * 0.5, size.height * 1.3, size.width, 0)
      ..quadraticBezierTo(
          size.width * 0.5, size.height * 0.55, 0, size.height * 0.25)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFFF0000));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Thick #FF0000 waves rising from the bottom corners.
class _GlowWavesPainter extends CustomPainter {
  const _GlowWavesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    const reach = 380.0; // how far each wave runs in from its corner
    const red = Color(0xFFFF0000);

    void wave(bool left) {
      double x(double v) => left ? v : w - v;
      Path curve() => Path()
        ..moveTo(x(0), h * 0.12)
        ..cubicTo(x(reach * 0.25), h * 0.62, x(reach * 0.6), h * 0.88,
            x(reach), h);
      final fill = curve()
        ..lineTo(x(0), h)
        ..close();
      // Red glow, the solid #FF0000 wave, then a thick red edge.
      canvas.drawPath(
        fill,
        Paint()
          ..color = red.withValues(alpha: 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      canvas.drawPath(fill, Paint()..color = red);
      canvas.drawPath(
        curve(),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = red,
      );
    }

    wave(true);
    wave(false);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
