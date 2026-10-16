import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../models/ad_banner.dart';
import '../../services/ad_manager.dart';
import 'ad_viewability_detector.dart';

/// The 3D formats the corner ad plays, after the motion-design ad formats
/// they imitate.
enum ThreeDAdStyle {
  /// 3D Product / Brand Showcase, 3D Promotional Video: one panel turning
  /// slowly like a coin, with a sweeping light.
  showcase,

  /// 3D Rotating Cube: four faces, turning a quarter at a time and holding.
  cube,

  /// 3D Rotating Prism: three faces, a third at a time.
  prism,

  /// Multi-panel pillar / rotating digital column: six tall panels turning
  /// continuously.
  pillar,

  /// 3D Corner Billboard (anamorphic look): two faces meeting at a corner,
  /// swinging gently so the depth reads.
  cornerBillboard;

  /// The order they take turns in when the backend names none.
  static const rotation = [cube, pillar, cornerBillboard, prism, showcase];

  /// The backend's name for a style (`three_d_style` / `animation_style` /
  /// `display_style`), or null when it names none we know.
  static ThreeDAdStyle? parse(String? raw) {
    final s =
        (raw ?? '').trim().toLowerCase().replaceAll(RegExp(r'[\s-]'), '_');
    if (s.isEmpty) return null;
    if (s.contains('cube')) return cube;
    if (s.contains('prism')) return prism;
    if (s.contains('pillar') || s.contains('column') || s.contains('panel')) {
      return pillar;
    }
    if (s.contains('corner') ||
        s.contains('billboard') ||
        s.contains('anamorphic')) {
      return cornerBillboard;
    }
    if (s.contains('showcase') ||
        s.contains('product') ||
        s.contains('brand') ||
        s.contains('promo') ||
        s.contains('video') ||
        s.contains('rotating_display')) {
      return showcase;
    }
    return null;
  }

  /// The style for the [rotationIndex]-th appearance of [ad].
  static ThreeDAdStyle forAd(AdBanner ad, int rotationIndex) =>
      parse(ad.displayStyle) ?? rotation[rotationIndex % rotation.length];

  /// Outer size of the ad on screen for a [base] edge length.
  Size boxSize(double base) => switch (this) {
        showcase => Size(base, base),
        cube || prism => Size(base * 1.08, base * 1.08),
        pillar => Size(base * 1.08, base * 1.25),
        cornerBillboard => Size(base * 1.18, base),
      };
}

/// A small 3D ad that floats in a screen corner for a few seconds, playing
/// one of the [ThreeDAdStyle] formats. Picture and video ads both work: a
/// video plays muted on the main face.
///
/// It is small and in a corner, so the screen underneath stays usable; it
/// can be closed, and [AdPacer] takes it away on its own.
class FloatingThreeDAd extends StatefulWidget {
  const FloatingThreeDAd({
    super.key,
    required this.ad,
    required this.onClose,
    this.size = 128,
    this.placementZone = 'feed',
    this.style = ThreeDAdStyle.showcase,
  });

  final AdBanner ad;
  final VoidCallback onClose;

  /// Base edge length; see [ThreeDAdStyle.boxSize].
  final double size;
  final String placementZone;
  final ThreeDAdStyle style;

  @override
  State<FloatingThreeDAd> createState() => _FloatingThreeDAdState();
}

enum _Face { media, brand, cta }

class _FloatingThreeDAdState extends State<FloatingThreeDAd>
    with TickerProviderStateMixin {
  static const _red = Color(0xFFE0001B);

  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  /// Drives the endless motion; one loop = one full turn of the shape.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: _loopFor(widget.style),
  )..repeat();

  VideoPlayerController? _video;
  bool _videoReady = false;
  bool _imageFailed = false;

  static Duration _loopFor(ThreeDAdStyle s) => switch (s) {
        ThreeDAdStyle.showcase => const Duration(seconds: 6),
        ThreeDAdStyle.cube => const Duration(milliseconds: 4 * 2600),
        ThreeDAdStyle.prism => const Duration(milliseconds: 3 * 2600),
        ThreeDAdStyle.pillar => const Duration(seconds: 10),
        ThreeDAdStyle.cornerBillboard => const Duration(seconds: 5),
      };

  bool get _hasImage => widget.ad.imageUrl.trim().isNotEmpty && !_imageFailed;

  @override
  void initState() {
    super.initState();
    _startVideo();
  }

  Future<void> _startVideo() async {
    final url = widget.ad.videoUrl.trim();
    final uri = Uri.tryParse(url);
    if (url.isEmpty || uri == null || !uri.hasScheme) return;
    try {
      final c = VideoPlayerController.networkUrl(uri,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
      _video = c;
      await c.initialize();
      await c.setVolume(0);
      await c.setLooping(true);
      if (!mounted) return;
      await c.play();
      setState(() => _videoReady = true);
    } catch (_) {
      // No video: the picture (or the brand panel) stands in.
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _loop.dispose();
    final v = _video;
    if (v != null) {
      v.pause().catchError((_) {});
      v.dispose().catchError((_) {});
    }
    super.dispose();
  }

  Future<void> _open() async {
    HapticFeedback.selectionClick();
    AdManager.instance
        .recordClick(widget.ad, placementZone: widget.placementZone);
    final uri = Uri.tryParse(widget.ad.destinationUrl.trim());
    if (uri != null && uri.hasScheme && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _close() {
    AdManager.instance
        .recordDismiss(widget.ad, placementZone: widget.placementZone);
    widget.onClose();
  }

  // --- Faces ----------------------------------------------------------------

  Widget _picture() => CachedNetworkImage(
        imageUrl: widget.ad.imageUrl,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_imageFailed) setState(() => _imageFailed = true);
          });
          return _brand();
        },
      );

  /// The ad's picture, or its video once it plays ([withVideo]).
  Widget _media({bool withVideo = true}) {
    final v = _video;
    if (withVideo && v != null && _videoReady && v.value.isInitialized) {
      final size = v.value.size;
      return FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: size.width <= 0 ? 16 : size.width,
          height: size.height <= 0 ? 9 : size.height,
          child: VideoPlayer(v),
        ),
      );
    }
    return _hasImage ? _picture() : _brand();
  }

  Widget _brand() => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_red, Color(0xFF7A0010)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Center(
            child: Text(
              widget.ad.title,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.25,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      );

  Widget _cta() => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1F1F1F), Color(0xFF000000)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          // Narrow faces (pillar, corner) shrink the content, never overflow.
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  widget.ad.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'చూడండి →',
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  /// Video plays on the first media face only (one decoder).
  Widget _face(_Face f, {required bool primary, double radius = 6}) {
    final content = switch (f) {
      _Face.media => _media(withVideo: primary),
      _Face.brand => _brand(),
      _Face.cta => _cta(),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }

  // --- Shapes ---------------------------------------------------------------

  /// [faces] arranged around a vertical axis ([n]-sided), turned to [angle];
  /// back faces are dropped and the rest painted far-to-near, with faces
  /// turned away shaded darker.
  Widget _ring({
    required List<_Face> faces,
    required double faceW,
    required double faceH,
    required double angle,
    double tilt = -0.12,
    double radius = 6,
  }) {
    final n = faces.length;
    final r = faceW / (2 * math.tan(math.pi / n));
    final drawn = <({double depth, Widget child})>[];
    var firstMedia = true;
    for (var i = 0; i < n; i++) {
      final primary = faces[i] == _Face.media && firstMedia;
      if (faces[i] == _Face.media) firstMedia = false;
      final th = angle + i * 2 * math.pi / n;
      final facing = math.cos(th);
      if (facing <= 0.01) continue;
      final m = Matrix4.identity()
        ..setEntry(3, 2, 0.0022)
        ..rotateX(tilt)
        ..rotateY(th)
        ..translateByDouble(0.0, 0.0, -r, 1.0);
      drawn.add((
        depth: facing,
        child: Transform(
          alignment: Alignment.center,
          transform: m,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _face(faces[i], primary: primary, radius: radius),
              // Light from the front: faces turned away get darker.
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    color: Colors.black
                        .withValues(alpha: ((1 - facing) * 0.3).clamp(0, 0.3)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ));
    }
    drawn.sort((a, b) => a.depth.compareTo(b.depth));
    return SizedBox(
      width: faceW,
      height: faceH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [for (final d in drawn) Positioned.fill(child: d.child)],
      ),
    );
  }

  /// Turn by one face, then hold — the stepping motion of rotating cube and
  /// prism displays. [v] runs 0→1 over a full turn of [n] faces.
  static double _stepAngle(double v, int n) {
    final phase = v * n;
    final step = phase.floor();
    final frac = phase - step;
    const hold = 0.55;
    final move = frac < hold
        ? 0.0
        : Curves.easeInOutCubic.transform((frac - hold) / (1 - hold));
    return -(step + move) * 2 * math.pi / n;
  }

  Widget _shape(double v, bool still) {
    final base = widget.size;
    switch (widget.style) {
      case ThreeDAdStyle.cube:
        return _ring(
          // Every side shows the advertiser's picture.
          faces: const [_Face.media, _Face.media, _Face.media, _Face.media],
          faceW: base * 0.78,
          faceH: base * 0.78,
          angle: still ? 0 : _stepAngle(v, 4),
        );
      case ThreeDAdStyle.prism:
        return _ring(
          faces: const [_Face.media, _Face.media, _Face.media],
          faceW: base * 0.86,
          faceH: base * 0.8,
          angle: still ? 0 : _stepAngle(v, 3),
        );
      case ThreeDAdStyle.pillar:
        return _ring(
          faces: const [
            _Face.media,
            _Face.media,
            _Face.media,
            _Face.media,
            _Face.media,
            _Face.media,
          ],
          faceW: base * 0.5,
          faceH: base * 1.15,
          angle: still ? 0 : -v * 2 * math.pi,
          tilt: -0.06,
          radius: 3,
        );
      case ThreeDAdStyle.cornerBillboard:
        // Looking straight at a cube's edge: two faces meet at the corner.
        return _ring(
          faces: const [_Face.media, _Face.media, _Face.media, _Face.media],
          faceW: base * 0.66,
          faceH: base * 0.86,
          angle: math.pi / 4 + (still ? 0 : math.sin(v * 2 * math.pi) * 0.32),
          tilt: -0.1,
          radius: 2,
        );
      case ThreeDAdStyle.showcase:
        final t = v * 2 * math.pi;
        final turn = still ? 0.0 : math.sin(t) * 0.55;
        final tilt = still ? 0.0 : math.cos(t * 2) * 0.08;
        final m = Matrix4.identity()
          ..setEntry(3, 2, 0.0016)
          ..rotateY(turn)
          ..rotateX(tilt);
        return Transform(
          alignment: Alignment.center,
          transform: m,
          child: SizedBox(
            width: base * 0.92,
            height: base * 0.92,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _face(_Face.media, primary: true, radius: 18),
                // Sweeping light.
                IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(-1 + turn * 2.4, -1),
                          end: Alignment(1 + turn * 2.4, 1),
                          colors: [
                            Colors.white.withValues(alpha: 0.28),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.12),
                          ],
                          stops: const [0, 0.45, 1],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo = widget.ad.videoUrl.trim().isNotEmpty;
    if (!_hasImage && !hasVideo && widget.ad.title.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final box = widget.style.boxSize(widget.size);
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return AdViewabilityDetector(
      ad: widget.ad,
      placementZone: widget.placementZone,
      child: SizedBox(
        key: Key('floating_3d_${widget.style.name}'),
        width: box.width,
        height: box.height + 12,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Motion: fly-in, the shape's own turn, a bob and a shadow.
            Positioned(
              left: 0,
              top: 0,
              width: box.width,
              height: box.height,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_enter, _loop]),
                  builder: (context, _) {
                    final e = Curves.easeOutBack
                        .transform(_enter.value.clamp(0.0, 1.0));
                    final bob =
                        still ? 0.0 : math.sin(_loop.value * 4 * math.pi) * 3;
                    final k = 0.4 + 0.6 * e;
                    return Opacity(
                      opacity: _enter.value.clamp(0.0, 1.0),
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            left: box.width * 0.2,
                            right: box.width * 0.2,
                            bottom: -6 - bob / 2,
                            height: 10,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 14,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.0016)
                              ..translateByDouble(0.0, bob, 0.0, 1.0)
                              ..rotateY((1 - e) * 1.2)
                              ..scaleByDouble(k, k, k, 1.0),
                            child: Center(child: _shape(_loop.value, still)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            // "Ad" label, outside the 3D motion so it is always readable.
            Positioned(
              left: 2,
              top: 2,
              child: IgnorePointer(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Ad',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            // Touch targets sit outside the 3D transform: hit testing does
            // not map correctly through a perspective matrix.
            Positioned(
              left: 0,
              top: 0,
              width: box.width,
              height: box.height,
              child: Semantics(
                button: true,
                label: 'Sponsored: ${widget.ad.title}',
                child: GestureDetector(
                  key: const Key('floating_3d_ad'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _open,
                ),
              ),
            ),
            // Plain gesture, no Material: the corner ad also sits above the
            // Navigator, where there is no Material or Overlay ancestor.
            Positioned(
              right: -6,
              top: -6,
              width: 36,
              height: 36,
              child: Semantics(
                button: true,
                label: 'Close ad',
                child: GestureDetector(
                  key: const Key('floating_3d_close'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.black87,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
