import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../core/utils/url_normalizer.dart';

import '../theme/app_theme.dart';

/// A news photo that fills its frame edge to edge — no
/// blurred bands, no letterboxing, never stretched (aspect is kept; only
/// the overflow is trimmed).
///
/// Where the trim falls depends on the photo's shape: a photo taller than
/// the frame keeps its upper part (faces and headlines sit high in news
/// photos, and a centred crop cut heads off); anything else is centred.
class SmartFitImage extends StatefulWidget {
  const SmartFitImage({
    super.key,
    required this.imageUrl,
    this.fallbackUrls = const [],
    this.maxDecodeWidth = 1080,
  });

  final String imageUrl;

  /// Other photos of the same story, tried in order when [imageUrl] fails
  /// or stalls (the share/download code already did this, which is why a
  /// story whose card stayed grey still downloaded with its photo).
  final List<String> fallbackUrls;

  /// Decode width cap, as memCacheWidth elsewhere.
  final int maxDecodeWidth;

  /// A load that has produced nothing after this long is treated as failed
  /// and the next candidate is tried. The image cache's HTTP download has no
  /// timeout of its own, so a stalled connection left the card grey for good.
  static const stallTimeout = Duration(seconds: 12);

  /// The provider a card of [maxDecodeWidth] reads — shared with [precache]
  /// so a preloaded photo is a cache hit.
  ///
  /// Downscaled when decoded ([ResizeImage]), not on disk: the old
  /// `CachedNetworkImageProvider(maxWidth:)` resized each downloaded photo
  /// with the pure-Dart image package on the UI isolate before showing it —
  /// slow for phone-camera photos, and some files never came back, leaving
  /// the card grey.
  static ImageProvider providerFor(String url, {int maxDecodeWidth = 1080}) =>
      ResizeImage(
        CachedNetworkImageProvider(url),
        width: maxDecodeWidth,
        allowUpscaling: false,
      );

  /// [primary] then [fallbacks], cleaned up as the download code does
  /// (protocol-relative and backend-relative paths made absolute), without
  /// repeats or non-URLs.
  @visibleForTesting
  static List<String> candidates(String primary, List<String> fallbacks) {
    final seen = <String>{};
    return [
      for (final raw in [primary, ...fallbacks])
        if (UrlNormalizer.normalize(raw) case final url
            when (url.startsWith('http://') || url.startsWith('https://')) &&
                seen.add(url))
          url,
    ];
  }

  /// Downloads and decodes [imageUrl] ahead of time, under the same cache
  /// key a [SmartFitImage] of that width reads, so the card shows it at
  /// once instead of an empty frame. Failures are ignored: the card itself
  /// retries and shows its own error state.
  static Future<void> precache(
    BuildContext context,
    String imageUrl, {
    int maxDecodeWidth = 1080,
  }) {
    final url = UrlNormalizer.normalize(imageUrl);
    if (url.isEmpty) return Future<void>.value();
    return precacheImage(
      providerFor(url, maxDecodeWidth: maxDecodeWidth),
      context,
      onError: (_, __) {},
    );
  }

  /// Crop anchor for an [imageAspect] photo in a [frameAspect] frame
  /// (both width / height).
  @visibleForTesting
  static Alignment alignmentFor(double imageAspect, double frameAspect) {
    if (imageAspect <= 0 || frameAspect <= 0) return Alignment.center;
    return imageAspect < frameAspect
        ? const Alignment(0, -0.4) // taller than the frame: keep the top
        : Alignment.center;
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

  List<String> _candidates = const [];
  int _index = 0;
  bool _retried = false;
  Timer? _stall;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_provider == null && !_failed) _start();
  }

  @override
  void didUpdateWidget(covariant SmartFitImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.maxDecodeWidth != widget.maxDecodeWidth ||
        !_sameList(oldWidget.fallbackUrls, widget.fallbackUrls)) {
      _start();
    }
  }

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _start() {
    _candidates =
        SmartFitImage.candidates(widget.imageUrl, widget.fallbackUrls);
    _index = 0;
    _retried = false;
    _imageAspect = null;
    _failed = false;
    _resolve();
  }

  void _resolve() {
    _stall?.cancel();
    if (_index >= _candidates.length) {
      _detach();
      _provider = null;
      _failed = true;
      return;
    }
    final provider = SmartFitImage.providerFor(_candidates[_index],
        maxDecodeWidth: widget.maxDecodeWidth);
    final stream = provider.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _detach();
    _provider = provider;
    _stream = stream;
    _listener = ImageStreamListener(
      (info, _) {
        _stall?.cancel();
        final w = info.image.width, h = info.image.height;
        if (!mounted || h == 0) return;
        final aspect = w / h;
        if (aspect != _imageAspect) setState(() => _imageAspect = aspect);
      },
      onError: (_, __) => _next(),
    );
    stream.addListener(_listener!);
    if (_imageAspect == null) {
      _stall = Timer(SmartFitImage.stallTimeout, _next);
    }
  }

  /// The current candidate failed or stalled: drop it from the cache so a
  /// later attempt starts clean, then try the next photo — and the first
  /// one once more (a stalled connection often works on a fresh one).
  void _next() {
    _stall?.cancel();
    if (!mounted) return;
    final provider = _provider;
    if (provider != null) unawaited(provider.evict());
    if (_index + 1 < _candidates.length) {
      _index++;
    } else if (!_retried && _candidates.isNotEmpty) {
      _retried = true;
      _index = 0;
    } else {
      _index = _candidates.length;
    }
    setState(_resolve);
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
    _stall?.cancel();
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
      final frameAspect =
          constraints.hasBoundedHeight && constraints.maxHeight > 0
              ? constraints.maxWidth / constraints.maxHeight
              : aspect;
      return Image(
        image: provider,
        fit: BoxFit.cover,
        alignment: SmartFitImage.alignmentFor(aspect, frameAspect),
        gaplessPlayback: true,
      );
    });
  }
}
