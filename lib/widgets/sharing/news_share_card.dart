import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../theme/article_typography.dart';
import '../watermark/watermark_banner.dart';

/// The image a reader shares or downloads — a Way2News-style news card, so
/// the story can be read from the picture alone:
///
///  photo (if any) → category · date → headline → summary → Vaaradhi strip
///
/// Laid out at [width] logical pixels and captured at pixel ratio 1, so the
/// file is exactly [width] px wide.
class NewsShareCard extends StatelessWidget {
  static const double width = 1080;

  final String headline;
  final String summary;
  final String meta; // "Local News  |  06 Oct 2026"
  final Uint8List? photo;

  /// Photo height / width, already clamped by the caller.
  final double photoHeightRatio;

  const NewsShareCard({
    super.key,
    required this.headline,
    required this.summary,
    required this.meta,
    this.photo,
    this.photoHeightRatio = 9 / 16,
  });

  static const _ink = Color(0xFF151515);
  static const _body = Color(0xFF3A3A3A);
  static const _accent = Color(0xFFD71920);

  @override
  Widget build(BuildContext context) {
    final p = photo;
    return SizedBox(
      width: width,
      child: ColoredBox(
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (p != null)
              SizedBox(
                key: const Key('share_card_photo'),
                height: width * photoHeightRatio,
                child: Image.memory(p,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    gaplessPlayback: true),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(52, 40, 52, 44),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (meta.isNotEmpty) ...[
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 34,
                          decoration: BoxDecoration(
                            color: _accent,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Flexible(
                          child: Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ArticleTypography.body(
                              fontSize: 30,
                              color: _accent,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                  ],
                  Text(
                    headline,
                    key: const Key('share_card_headline'),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: ArticleTypography.heading(
                      fontSize: 56,
                      color: _ink,
                      height: 1.4,
                    ),
                  ),
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      summary,
                      key: const Key('share_card_summary'),
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: ArticleTypography.body(
                        fontSize: 40,
                        color: _body,
                        height: 1.55,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const _BrandStrip(),
          ],
        ),
      ),
    );
  }
}

/// The red Vaaradhi strip and logo, cropped out of the banner artwork's
/// black margins, on a black band.
class _BrandStrip extends StatelessWidget {
  const _BrandStrip();

  @override
  Widget build(BuildContext context) {
    const visible = WatermarkBanner.stripBottom - WatermarkBanner.stripTop;
    const fullHeight = NewsShareCard.width / WatermarkBanner.aspectRatio;
    return ColoredBox(
      key: const Key('share_card_brand'),
      color: Colors.black,
      child: SizedBox(
        height: fullHeight * visible,
        child: ClipRect(
          child: OverflowBox(
            // Shifts the artwork up by exactly its top black margin:
            // offset = (box − art)·(1 + y)/2 = −stripTop·art.
            alignment:
                const Alignment(0, 2 * WatermarkBanner.stripTop / (1 - visible) - 1),
            minHeight: fullHeight,
            maxHeight: fullHeight,
            child: Image.asset(
              WatermarkBanner.asset,
              width: NewsShareCard.width,
              height: fullHeight,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}
