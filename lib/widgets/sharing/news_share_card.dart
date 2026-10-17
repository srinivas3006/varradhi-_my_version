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
///  │ [logo] వారధి                  │  black brand strip, 7%
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
              height: portrait ? portraitPhotoHeight : photoHeight,
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
              sidePadding: side,
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
      // Fill and centre-crop: no stretching, no empty bars.
      return Image.memory(p,
          fit: BoxFit.cover,
          alignment: Alignment.center,
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

/// Solid black bar under the photo: logo icon + white "వారధి". Nothing else.
class _BrandStrip extends StatelessWidget {
  const _BrandStrip({required this.height, required this.sidePadding});

  final double height;
  final double sidePadding;

  @override
  Widget build(BuildContext context) {
    const iconWidth = 74.0;
    return SizedBox(
      key: const Key('share_card_brand'),
      height: height,
      child: ColoredBox(
        color: Colors.black,
        child: Padding(
          padding: EdgeInsets.only(left: sidePadding),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: NewsShareCard._logoArtHeightFraction,
                    child: Image.asset(
                      NewsShareCard.logoAsset,
                      width: iconWidth,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'వారధి',
                style: ArticleTypography.heading(
                  fontSize: 46,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
