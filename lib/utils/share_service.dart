// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import '../models/news_article.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/article_typography.dart';

import '../widgets/sharing/news_share_card.dart';
import '../widgets/watermark/watermark_banner.dart';
import '../core/utils/url_normalizer.dart';
import '../services/sharing/share_content_builder.dart';

class ShareService {
  static final ScreenshotController _screenshotController =
      ScreenshotController();

  static bool _isSharing = false;

  /// Official Google Play Store link for app download
  static const String appDownloadUrl =
      'https://play.google.com/store/apps/details?id=com.varadhi';

  /// Official Vaaradhi web article domain
  static const String webBaseUrl = 'https://vaaradhinews.com';

  static String buildArticleDeepLink(NewsArticle article) {
    final route = article.isUgc ? 'ugc' : 'article';
    final identifier = article.isUgc
        ? article.id
        : (article.slug.isNotEmpty ? article.slug : article.id);
    return 'varadhi://$route/${Uri.encodeComponent(identifier)}';
  }

  static String buildWebArticleUrl(NewsArticle article) {
    // The API's share_url is authoritative when it is on our domain.
    final fromApi = ShareContentBuilder.trustedShareUrl(article.shareUrl);
    if (fromApi != null) return fromApi;
    final route = article.isUgc ? 'ugc' : 'article';
    final identifier = article.isUgc
        ? article.id
        : (article.slug.isNotEmpty ? article.slug : article.id);
    // Trailing slash: the canonical public routes are /article/{slug}/ and
    // /ugc/{id}/ (handover §16).
    return '$webBaseUrl/$route/${Uri.encodeComponent(identifier)}/';
  }

  /// Builds clean, professional share text with title, web article link, and app download link.
  static String buildShareText(NewsArticle article) {
    final webUrl = buildWebArticleUrl(article);
    return '📰 ${article.title.trim()}\n\n'
        '🔗 కథనం లింక్:\n'
        '$webUrl\n\n'
        '📲 వారధి యాప్ డౌన్‌లోడ్ చేసుకోండి:\n'
        '$appDownloadUrl';
  }

  /// Pre-fetches the image bytes into memory so `Image.memory` paints synchronously
  /// during off-screen screenshot capture.
  static Future<Uint8List?> _fetchImageBytes(String url) async {
    // The photo is usually already on screen, so it is in the image cache:
    // read it from there instead of downloading it again.
    try {
      final cached = await DefaultCacheManager().getFileFromCache(url);
      if (cached != null) {
        final bytes = await cached.file.readAsBytes();
        if (bytes.isNotEmpty) return bytes;
      }
    } catch (_) {}
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode == 200) {
        return await consolidateHttpClientResponseBytes(response);
      }
    } catch (e) {
      debugPrint('[ShareService] Failed to pre-fetch image bytes: $e');
    }
    return null;
  }

  /// Every still the poster could be built from, best first.
  ///
  /// The first media item is not always a photo: the detail payload often
  /// leads with a video/YouTube URL, or carries its photos only in
  /// `image_urls`. Fetching that one URL failed and the share fell back to
  /// the sticker-only card, so each usable still is offered in turn —
  /// images as-is, videos through their thumbnail.
  static List<String> _imageCandidates(NewsArticle article) {
    final raw = <String>[
      for (final item in article.orderedMedia)
        item.isVideo ? item.thumbnailUrl : item.url,
      article.imageUrl,
      ...?article.imageUrls,
    ];
    final seen = <String>{};
    final result = <String>[];
    for (final value in raw) {
      final url = UrlNormalizer.normalize(value);
      if ((url.startsWith('http://') || url.startsWith('https://')) &&
          seen.add(url)) {
        result.add(url);
      }
    }
    return result;
  }

  /// Shares the branded article image and formatted caption via the native share sheet.
  /// One-tap guarded: ignores rapid duplicate taps while processing.
  ///
  /// [fallback] supplies extra image candidates — the detail screen passes
  /// the feed article it opened from, whose image Spotlight already shows.
  static Future<void> shareArticle(NewsArticle article,
      {NewsArticle? fallback, VoidCallback? onReady}) async {
    if (_isSharing) {
      debugPrint('ShareService: share already in progress, ignoring duplicate tap');
      return;
    }
    _isSharing = true;

    try {
      final file = await generateArticleImage(article, fallback: fallback);
      final shareText = buildShareText(article);
      // Image ready: the caller can drop its "preparing" message as the
      // share sheet opens.
      onReady?.call();

      if (file != null) {
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'image/jpeg')],
          text: shareText,
        );
      } else {
        await Share.share(shareText);
      }
    } catch (e) {
      debugPrint('Error sharing article: $e');
    } finally {
      _isSharing = false;
    }
  }

  /// Whether a shareable/downloadable poster can be built for [article].
  ///
  /// Gates the Download action: a poster is an image with text on it, so
  /// without a usable image there is nothing to generate and the control
  /// should not be offered.
  static bool canGeneratePoster(NewsArticle article) {
    // A video story has no still to download, but it still has something to
    // hand over: a black card carrying the masthead. So the control stays
    // offered rather than disappearing on exactly the items people most
    // want to pass on.
    if (article.isVideo) return true;

    return _imageCandidates(article).isNotEmpty;
  }

  /// The article image for Share and Download ([NewsShareCard]: Share is the
  /// 1600 × 1200 landscape card, Download a 1080 px portrait one): photo with the
  /// "VAARADHI" watermark, black logo strip, category | date, headline.
  /// [forDownload] adds the start of the story under the headline.
  /// JPEG, quality 88.
  static Future<File?> generateArticleImage(NewsArticle article,
      {NewsArticle? fallback, bool forDownload = false}) async {
    // Sharing the same story again reuses the card already made.
    final cacheKey = _cardCacheKey(article, forDownload);
    final ready = _madeCards[cacheKey];
    if (ready != null && await ready.exists()) return ready;
    try {
      final candidates = <String>{
        ..._imageCandidates(article),
        if (fallback != null) ..._imageCandidates(fallback),
      };

      // 1. First candidate that downloads AND decodes wins (checked at card
      // width, memory-safe on low-end phones). None → branded placeholder.
      Uint8List? photo;
      for (final url in candidates) {
        final bytes = await _fetchImageBytes(url);
        if (bytes == null || bytes.isEmpty) continue;
        try {
          final codec = await ui.instantiateImageCodec(bytes,
              targetWidth: NewsShareCard.width.toInt());
          (await codec.getNextFrame()).image.dispose();
          photo = bytes;
          break;
        } catch (e) {
          debugPrint('[ShareService] Could not decode $url: $e');
        }
      }

      // 2. One design for both: photo + watermark, black logo strip,
      // category | date, headline. Download also carries the start of the
      // story under the headline.
      final source = (fallback?.summary.trim().isNotEmpty ?? false) &&
              article.summary.trim().isEmpty
          ? fallback!
          : article;
      // Download is a tall portrait card with large story text; Share stays
      // the 4:3 landscape card.
      final cardWidget = NewsShareCard(
        headline: article.title.trim(),
        meta: shareMeta(article),
        photo: photo,
        summary: forDownload ? shareSummary(source) : '',
        portrait: forDownload,
      );
      final card = await _captureNewsCard(cardWidget,
          width: cardWidget.cardWidth);
      if (card == null) return _buildWatermarkOnlyFile(article);

      final dir = await getTemporaryDirectory();
      final safeId = article.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file = File(
          '${dir.path}/vaaradhi_$safeId${forDownload ? '_dl' : ''}.jpg');
      await file.writeAsBytes(card);
      _madeCards[cacheKey] = file;
      return file;
    } catch (e) {
      debugPrint('[ShareService] Error generating article image: $e');
      return null;
    }
  }

  /// Cards already made this session, by story + version + what is printed
  /// on them (an edited headline or summary makes a new card).
  static final Map<String, File> _madeCards = {};

  static String _cardCacheKey(NewsArticle a, bool forDownload) => [
        a.id.isNotEmpty ? a.id : a.slug,
        forDownload ? 'dl' : 'sh',
        a.title.hashCode,
        a.summary.hashCode,
        a.category,
        a.imageUrl,
      ].join('|');

  @visibleForTesting
  static void clearMadeCards() => _madeCards.clear();

  /// Top-level-style worker for [compute]: PNG bytes → JPEG bytes.
  static Uint8List _pngToJpg(Uint8List png) {
    final decoded = img.decodePng(png);
    if (decoded == null) return Uint8List(0);
    return Uint8List.fromList(
        img.encodeJpg(decoded, quality: 88, chroma: img.JpegChroma.yuv420));
  }

  /// The story text for the card: the summary, else the start of the body
  /// with any HTML removed.
  @visibleForTesting
  static String shareSummary(NewsArticle a) {
    final s = a.summary.trim();
    if (s.isNotEmpty) return s;
    return a.body
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// "Local News  |  06 Oct 2026" — category (if any) and the publish date.
  @visibleForTesting
  static String shareMeta(NewsArticle a) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final d = a.publishedAt.toLocal();
    final date = d.year > 2000
        ? '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}'
        : '';
    // "|" not "·": the Mandali font has no middle dot (drew a box).
    return [a.category.trim(), date].where((s) => s.isNotEmpty).join('  |  ');
  }

  /// Renders [card] off-screen (pixel ratio 1 → exactly 1080px wide) and
  /// returns it as JPEG bytes, or null if it could not be drawn.
  static Future<Uint8List?> _captureNewsCard(Widget card,
      {required double width}) async {
    try {
      // The Telugu fonts must be loaded before the frame is drawn, or the
      // capture would use a fallback font.
      await GoogleFonts.pendingFonts([
        ArticleTypography.heading(fontSize: 54, color: Colors.black),
        ArticleTypography.body(fontSize: 36, color: Colors.black),
        ArticleTypography.body(fontSize: 40, color: Colors.black),
        watermarkStyle,
      ]).timeout(const Duration(seconds: 8), onTimeout: () => const []);
      final png = await _screenshotController.captureFromLongWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Directionality(textDirection: TextDirection.ltr, child: card),
        ),
        pixelRatio: 1,
        delay: const Duration(milliseconds: 150),
        constraints: BoxConstraints(
            minWidth: width, maxWidth: width),
      );
      // PNG → JPEG is the slowest step for a 1600 px card: done on a
      // background isolate so the screen never freezes while it runs.
      final jpg = await compute(_pngToJpg, png);
      return jpg.isEmpty ? null : jpg;
    } catch (e) {
      debugPrint('[ShareService] news card capture failed: $e');
      return null;
    }
  }

  /// Brands any photo with the Vaaradhi sticker — the exact composite the
  /// reader share uses. For the admin "add brand" action on citizen news.
  /// Null when [bytes] is not a decodable image.
  static Future<File?> brandPhotoBytes(Uint8List bytes, String fileName) async {
    try {
      final codec = bytes.lengthInBytes > 3000000
          ? await ui.instantiateImageCodec(bytes, targetWidth: 1440)
          : await ui.instantiateImageCodec(bytes);
      final image = (await codec.getNextFrame()).image;
      final safe = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      return await _composeBranded(image, safe);
    } catch (e) {
      debugPrint('[ShareService] Could not brand photo: $e');
      return null;
    }
  }

  /// Photo + full-width sticker → JPEG file in the temp dir.
  static Future<File?> _composeBranded(ui.Image image, String fileName) async {
    try {
      // 2. Banner decoding
      final bannerByteData =
          await rootBundle.load(WatermarkBanner.asset);
      final bannerBytes = bannerByteData.buffer.asUint8List();
      final ui.Image banner = await decodeImageFromList(bannerBytes);

      // 3. Proportional scaling with maxWidth clamp (1440px)
      const double maxWidth = 1440.0;
      final double scale =
          image.width > maxWidth ? maxWidth / image.width.toDouble() : 1.0;
      final int targetWidth = (image.width * scale).round();
      final int targetHeight = (image.height * scale).round();

      // Scaled sticker height matching exact width ratio. It is placed so
      // the strip's top edge lands on the photo's bottom edge; only the part
      // from the strip down extends the canvas.
      // Only the red strip and logo (the artwork is an opaque JPEG with
      // black margins), placed directly BELOW the photo so none of the photo
      // is covered.
      final double srcTop = banner.height * WatermarkBanner.stripTop;
      final double srcHeight = banner.height *
          (WatermarkBanner.stripBottom - WatermarkBanner.stripTop);
      final double bannerHeight =
          srcHeight * targetWidth / banner.width.toDouble();
      final double bannerTop = targetHeight.toDouble();
      final int totalHeight = (bannerTop + bannerHeight).ceil();

      // 4. Paint to Canvas with high quality and anti-aliasing
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()
        ..filterQuality = FilterQuality.high
        ..isAntiAlias = true;

      // White base: JPEG drops alpha, so anything left transparent (the
      // sticker's corners, a transparent PNG photo) would turn black.
      canvas.drawRect(
        Rect.fromLTWH(0, 0, targetWidth.toDouble(), totalHeight.toDouble()),
        Paint()..color = Colors.white,
      );

      // Draw news image
      final imgSrcRect =
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
      final imgDstRect =
          Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble());
      canvas.drawImageRect(image, imgSrcRect, imgDstRect, paint);

      // Draw the cropped strip below the photo.
      final bannerSrcRect =
          Rect.fromLTWH(0, srcTop, banner.width.toDouble(), srcHeight);
      final bannerDstRect = Rect.fromLTWH(
          0, bannerTop, targetWidth.toDouble(), bannerHeight);
      canvas.drawImageRect(banner, bannerSrcRect, bannerDstRect, paint);

      final picture = recorder.endRecording();
      final compositeUiImg = await picture.toImage(targetWidth, totalHeight);

      // 5. Convert to raw RGBA for JPEG encoding
      final byteData =
          await compositeUiImg.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return null;

      final imgImage = img.Image.fromBytes(
        width: targetWidth,
        height: totalHeight,
        bytes: byteData.buffer,
        order: img.ChannelOrder.rgba,
      );

      // 6. Encode to JPEG with quality 88 and chroma yuv420 for optimal size & speed
      final jpgBytes = img.encodeJpg(
        imgImage,
        quality: 88,
        chroma: img.JpegChroma.yuv420,
      );

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName.jpg');
      await file.writeAsBytes(jpgBytes);
      return file;
    } catch (e) {
      debugPrint('[ShareService] Error composing branded image: $e');
      return null;
    }
  }

  /// Builds the branded image poster for sharing or downloading.
  static Future<File?> buildPosterFile(
    NewsArticle article, {
    bool includeText = false,
  }) async =>
      // Download is offered only where canGeneratePoster says so; anything
      // else gets no file (sharing still sends the text-only news card).
      canGeneratePoster(article) ? generateArticleImage(article) : null;

  /// The Download card for [article] (story text + red banner), or null when
  /// Download is not offered for it.
  static Future<File?> buildDownloadFile(NewsArticle article) async =>
      canGeneratePoster(article)
          ? generateArticleImage(article, forDownload: true)
          : null;

  /// Outcome of a download, so the UI can say what actually happened rather
  /// than guessing.
  static const int downloadSaved = 0;
  static const int downloadPermissionDenied = 1;
  static const int downloadFailed = 2;

  /// A plain black card carrying only the masthead.
  ///
  /// Used when there is no still to build a poster from — a video story, or
  /// artwork that failed to load. Keeps the download meaningful and branded
  /// rather than failing silently.
  static Future<File?> _buildWatermarkOnlyFile(NewsArticle article) async {
    const double width = 1080;
    const double height = 1350;

    try {
      final bytes = await _screenshotController.captureFromWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: width,
            height: height,
            child: ColoredBox(
              color: Colors.black,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 64),
                  child: WatermarkBanner(padding: EdgeInsets.zero),
                ),
              ),
            ),
          ),
        ),
        targetSize: const Size(width, height),
        delay: const Duration(milliseconds: 120),
      );
      if (bytes.isEmpty) return null;

      final dir = await getTemporaryDirectory();
      final safeId = article.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file =
          await File('${dir.path}/vaaradhi_card_$safeId.png').create();
      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      debugPrint('[ShareService] watermark-only card failed: $e');
      return null;
    }
  }

  /// Writes the watermarked PNG into the device gallery.
  ///
  /// Android 29+ goes through MediaStore and needs no permission; 28 and
  /// below use WRITE_EXTERNAL_STORAGE, declared with maxSdkVersion="28". iOS
  /// needs add-only Photos access. gal.hasAccess/requestAccess handles the
  /// difference, so this asks only when the platform actually requires it.
  static Future<int> downloadPoster(NewsArticle article) async {
    if (_isSharing) return downloadFailed;
    _isSharing = true;
    try {
      final file = await buildDownloadFile(article);
      if (file == null) return downloadFailed;
      return await saveFileToGallery(file.path);
    } finally {
      _isSharing = false;
    }
  }

  /// Saves a local image (or video, [isVideo]) to the phone's gallery, in a
  /// "Vaaradhi" album where the OEM allows it. Returns [downloadSaved],
  /// [downloadPermissionDenied] or [downloadFailed].
  static Future<int> saveFileToGallery(String path,
      {bool isVideo = false}) async {
    Future<void> put({String? album}) => isVideo
        ? Gal.putVideo(path, album: album)
        : Gal.putImage(path, album: album);
    try {
      // On Android 10+ (API 29+), Scoped Storage lets the app save its own files
      // to MediaStore without storage permissions. On Android <= 28 or iOS,
      // check and request access if needed.
      final hasAccess = await Gal.hasAccess(toAlbum: false);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: false);
        if (!granted) {
          return downloadPermissionDenied;
        }
      }

      // Tier 1: Try saving into the 'Vaaradhi' custom album.
      // Tier 2: If the OEM restricts custom album creation or folder ownership
      // conflicts occur on Android 13+ (e.g. MIUI/OneUI/ColorOS), seamlessly
      // fall back to saving directly to the root Pictures gallery without an album.
      try {
        await put(album: 'Vaaradhi');
        return downloadSaved;
      } catch (albumError) {
        debugPrint('ShareService: Album save error ($albumError), retrying root gallery...');
        try {
          await put();
          return downloadSaved;
        } catch (fallbackError) {
          debugPrint('ShareService: Fallback save also failed: $fallbackError');
          if (fallbackError is GalException &&
              fallbackError.type == GalExceptionType.accessDenied) {
            return downloadPermissionDenied;
          }
          return downloadFailed;
        }
      }
    } on GalException catch (e) {
      debugPrint('ShareService: gallery save failed: ${e.type}');
      return e.type == GalExceptionType.accessDenied
          ? downloadPermissionDenied
          : downloadFailed;
    } catch (e) {
      debugPrint('ShareService: gallery save failed: $e');
      return downloadFailed;
    }
  }

  /// Share: the same watermarked image, with the text sent beside it through
  /// the native sheet so every social target receives both.
  static Future<bool> sharePoster(NewsArticle article) async {
    if (_isSharing) return false;
    _isSharing = true;
    try {
      final file = await generateArticleImage(article);
      final shareText = buildShareText(article);

      if (file != null) {
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'image/jpeg')],
          text: shareText,
        );
        return true;
      } else {
        await Share.share(shareText);
        return true;
      }
    } catch (e) {
      debugPrint('ShareService: poster share failed: $e');
      return false;
    } finally {
      _isSharing = false;
    }
  }

  /// Shares plain text or deep links via native share sheet.
  static Future<void> shareText(String text, {String? subject}) async {
    try {
      await Share.share(text, subject: subject);
    } catch (e) {
      debugPrint('Error sharing text: $e');
    }
  }
}

