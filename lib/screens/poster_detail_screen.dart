// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../models/poster_images.dart';
import '../services/sharing/share_content_builder.dart';
import '../widgets/sharing/share_sheet.dart';

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
    // Shared with the spotlight feed: this screen used to parse the payload
    // itself, without sorting by sort_order, without removing duplicates and
    // without normalising URLs — so the same poster showed a different set of
    // designs, in a different order, than the feed did.
    _images = posterImageUrls(widget.poster);
  }

  void _shareCurrentPoster() {
    // One sheet, one wording, one canonical URL — this used to compose its
    // own sentence around a raw image link.
    ShareSheet.show(
      context,
      ShareContentBuilder.fromPoster(widget.poster),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.poster['title'] ?? 'Poster';

    final telugu = AppState.instance.language == 'Telugu';

    return Scaffold(
      backgroundColor: Colors.black,
      // Full screen: the poster runs behind the app bar and status bar.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black54, Colors.transparent],
            ),
          ),
        ),
        title: Text(title, style: const TextStyle(fontSize: 16)),
        // No share action here: the bottom button is the one Share control.
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
                      child: SizedBox.expand(
                        child: CachedNetworkImage(
                          imageUrl: _images[index],
                          // Cover: edge to edge, no black bands. Pinch to
                          // zoom still works for detail.
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
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

                // Scrim so the dots and button read on any artwork.
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 180,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black87, Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ),

                // Indicator and CTA
                Positioned(
                  bottom: MediaQuery.paddingOf(context).bottom + 20,
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
                        label: Text(
                          telugu ? 'షేర్ చేయండి' : 'Share',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
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
