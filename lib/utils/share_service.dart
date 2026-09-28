// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import '../models/news_article.dart';
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
      {NewsArticle? fallback}) async {
    if (_isSharing) {
      debugPrint('ShareService: share already in progress, ignoring duplicate tap');
      return;
    }
    _isSharing = true;

    try {
      final file = await generateArticleImage(article, fallback: fallback);
      final shareText = buildShareText(article);

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

  /// Where the red strip starts inside the sticker artwork, as a fraction of
  /// its height. Everything above it is transparent except the logo circle,
  /// which rises past the strip.
  static const double _stickerStripTop = 95 / 296;

  /// Generates the branded composite article image:
  /// - High-resolution news photo
  /// - Downscaled at decode time if > 3MB (OOM prevention on low-end devices)
  /// - Proportional scaling constrained to max 1440px width
  /// - Full-width Vaaradhi sticker at the bottom: the red strip begins
  ///   exactly at the photo's lower edge so it hides none of the photo, and
  ///   the logo circle overlaps the photo like a sticker
  /// - Painted over white, since JPEG has no alpha and the sticker's
  ///   transparent corners would otherwise encode as black
  /// - High quality filtering and anti-aliasing
  /// - Encoded to JPEG with quality 88 and JpegChroma.yuv420 for optimal file size and fast sharing
  static Future<File?> generateArticleImage(NewsArticle article,
      {NewsArticle? fallback}) async {
    try {
      final candidates = <String>{
        ..._imageCandidates(article),
        if (fallback != null) ..._imageCandidates(fallback),
      };

      // 1. First candidate that downloads AND decodes wins. Memory-safe
      // decoding: downscale at decode-time if very large (OOM prevention).
      ui.Image? decoded;
      for (final url in candidates) {
        final bytes = await _fetchImageBytes(url);
        if (bytes == null || bytes.isEmpty) continue;
        try {
          final codec = bytes.lengthInBytes > 3000000
              ? await ui.instantiateImageCodec(bytes, targetWidth: 1440)
              : await ui.instantiateImageCodec(bytes);
          decoded = (await codec.getNextFrame()).image;
          break;
        } catch (e) {
          debugPrint('[ShareService] Could not decode $url: $e');
        }
      }

      if (decoded == null) {
        return _buildWatermarkOnlyFile(article);
      }
      final ui.Image image = decoded;

      // 2. Banner decoding
      final bannerByteData =
          await rootBundle.load('assets/images/watermark_banner.png');
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
      final double bannerHeight =
          banner.height.toDouble() * targetWidth / banner.width.toDouble();
      final double bannerTop =
          targetHeight - bannerHeight * _stickerStripTop;
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

      // Draw the sticker: strip below the photo, logo circle over it.
      final bannerSrcRect =
          Rect.fromLTWH(0, 0, banner.width.toDouble(), banner.height.toDouble());
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
      final safeId = article.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file = File('${dir.path}/vaaradhi_$safeId.jpg');
      await file.writeAsBytes(jpgBytes);
      return file;
    } catch (e) {
      debugPrint('[ShareService] Error generating article image: $e');
      return null;
    }
  }

  /// Builds the branded image poster for sharing or downloading.
  static Future<File?> buildPosterFile(
    NewsArticle article, {
    bool includeText = false,
  }) =>
      generateArticleImage(article);

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
      final file = await buildPosterFile(article);
      if (file == null) return downloadFailed;

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
        await Gal.putImage(file.path, album: 'Vaaradhi');
        return downloadSaved;
      } catch (albumError) {
        debugPrint('ShareService: Album save error ($albumError), retrying root gallery...');
        try {
          await Gal.putImage(file.path);
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
      debugPrint('ShareService: poster download failed: $e');
      return downloadFailed;
    } finally {
      _isSharing = false;
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

