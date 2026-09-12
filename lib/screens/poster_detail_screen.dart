// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';

/// Screen 19: PosterDetailScreen
/// - APIs: None required after selected poster payload
/// - Handles: Image carousel, Share, Download
class PosterDetailScreen extends StatefulWidget {
  final Map<String, dynamic> poster;

  const PosterDetailScreen({super.key, required this.poster});

  @override
  State<PosterDetailScreen> createState() => _PosterDetailScreenState();
}

class _PosterDetailScreenState extends State<PosterDetailScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  List<String> _images = [];

  @override
  void initState() {
    super.initState();
    final rawImages = widget.poster['images'] as List?;
    if (rawImages != null && rawImages.isNotEmpty) {
      _images = rawImages
          .map((img) => (img['image_url'] ?? '').toString())
          .where((url) => url.isNotEmpty)
          .toList();
    }
    if (_images.isEmpty) {
      final mainImage = (widget.poster['image_url'] ?? widget.poster['thumbnail_url'] ?? '').toString();
      if (mainImage.isNotEmpty) _images.add(mainImage);
    }
  }

  void _shareCurrentPoster() {
    if (_images.isNotEmpty && _currentIndex < _images.length) {
      final url = _images[_currentIndex];
      final title = widget.poster['title'] ?? 'Greeting';
      Share.share('Check out this $title poster: $url');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.poster['title'] ?? 'Poster';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(title, style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: _shareCurrentPoster,
          ),
        ],
      ),
      body: _images.isEmpty
          ? const Center(
              child: Text(
                'No image available',
                style: TextStyle(color: Colors.white70),
              ),
            )
          : Stack(
              alignment: Alignment.bottomCenter,
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: _images.length,
                  onPageChanged: (idx) => setState(() => _currentIndex = idx),
                  itemBuilder: (context, index) {
                    return InteractiveViewer(
                      child: Center(
                        child: CachedNetworkImage(
                          imageUrl: _images[index],
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(color: AppColors.primary),
                          ),
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.broken_image_rounded,
                            size: 64,
                            color: Colors.white24,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Indicator and CTA
                Positioned(
                  bottom: 30,
                  left: 20,
                  right: 20,
                  child: Column(
                    children: [
                      if (_images.length > 1) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _images.length,
                            (i) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == _currentIndex ? 18 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: i == _currentIndex ? AppColors.primary : Colors.white24,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.share_rounded),
                        label: const Text(
                          'Share Greeting',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _shareCurrentPoster,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
