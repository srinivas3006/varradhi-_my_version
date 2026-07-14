import 'package:flutter/material.dart';
import '../models/spotlight_item.dart';
import '../models/news_article.dart';
import '../widgets/ads/native_ad_card.dart';
import '../widgets/magazine_page_flip.dart';
import '../widgets/spotlight/spotlight_carousel_card.dart';
import '../widgets/spotlight/spotlight_news_card.dart';
import '../widgets/spotlight/spotlight_promo_card.dart';
import '../widgets/poster_card.dart';
import '../widgets/info_card.dart';
import '../utils/share_service.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class SpotlightScreen extends StatefulWidget {
  const SpotlightScreen({super.key});

  @override
  State<SpotlightScreen> createState() => _SpotlightScreenState();
}

class _SpotlightScreenState extends State<SpotlightScreen> {
  int _currentIndex = 0;
  bool _isLocalNews = false;
  bool _isLoading = true;
  bool _showOverlay = true;
  final List<SpotlightItem> _feed = [];
  String? _nextCursor;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    if (!_hasMore) return;

    final response = await ApiService.instance.getNewsFeed(
      cursor: _nextCursor,
      category: _isLocalNews ? 'local' : null,
    );

    if (!mounted) return;

    final newArticles = response.data ?? [];
    
    // Convert articles to SpotlightItems and inject mocks
    final newItems = <SpotlightItem>[];
    int offset = _feed.length;
    
    for (int i = 0; i < newArticles.length; i++) {
      newItems.add(SpotlightItem.standard(newArticles[i]));
      int count = offset + i + 1;
      
      if (count == 2) {
         newItems.add(SpotlightItem.promo(id: 'promo_$count', imageUrl: 'https://images.unsplash.com/photo-1542204165-65bf26472b9b?w=800'));
      }
      if (count == 4) {
         newItems.add(SpotlightItem.poster('poster_$count', 'https://images.unsplash.com/photo-1518599904199-0ca897819ddb?w=800'));
      }
      if (count == 6) {
         newItems.add(SpotlightItem.infoCard('info_$count', 'Today\'s Jyothishyam'));
      }
      if (count % 5 == 0) {
         newItems.add(SpotlightItem.ad('ad_$count'));
      }
    }

    setState(() {
      _feed.addAll(newItems);
      _nextCursor = response.nextCursor;
      _hasMore = _nextCursor != null;
      _isLoading = false;
    });
  }

  Future<void> _refreshFeed() async {
    setState(() {
      _isLoading = true;
      _feed.clear();
      _nextCursor = null;
      _hasMore = true;
      _currentIndex = 0;
    });
    await _loadFeed();
  }

  void _onToggle(bool isLocal) {
    if (_isLocalNews == isLocal) return;
    setState(() => _isLocalNews = isLocal);
    _refreshFeed();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _closeSpotlight() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _toggleOverlay() {
    setState(() {
      _showOverlay = !_showOverlay;
    });
  }

  void _shareArticle(NewsArticle article) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    await ShareService.shareArticle(article);
    if (mounted) Navigator.pop(context); // dismiss loading
  }

  Widget _buildItem(SpotlightItem item) {
    switch (item.type) {
      case SpotlightType.standard:
        return SpotlightNewsCard(
          article: item.article!,
          onTap: _toggleOverlay,
          onShare: () => _shareArticle(item.article!),
          onClose: _closeSpotlight,
        );
      case SpotlightType.carousel:
        return SpotlightCarouselCard(
          item: item,
          onTap: _toggleOverlay,
          onShare: () => _shareArticle(item.article!),
          onClose: _closeSpotlight,
        );
      case SpotlightType.promo:
        return GestureDetector(
          onTap: _toggleOverlay,
          child: SpotlightPromoCard(
            imageUrl: item.promoImageUrl!,
          ),
        );
      case SpotlightType.ad:
        return GestureDetector(
          onTap: _toggleOverlay,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              child: const NativeAdCard(),
            ),
          ),
        );
      case SpotlightType.poster:
        return GestureDetector(
          onTap: _toggleOverlay,
          child: Center(
            child: PosterCard(mediaUrl: item.mediaUrl!),
          ),
        );
      case SpotlightType.infoCard:
        return GestureDetector(
          onTap: _toggleOverlay,
          child: Center(
            child: InfoCard(title: item.title!),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _closeSpotlight();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : MagazinePageFlip(
                    key: ValueKey('feed_$_isLocalNews'),
                    itemCount: _feed.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                      if (index == _feed.length - 2) {
                        _loadFeed();
                      }
                    },
                    itemBuilder: (context, index) {
                      return _buildItem(_feed[index]);
                    },
                  ),
            
            // Main / Local Overlay Toggle
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _showOverlay ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !_showOverlay,
                  child: Center(
                    child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => _onToggle(false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: !_isLocalNews ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Text('Main News',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _onToggle(true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _isLocalNews ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Text('Local News',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
            
            // Optional top bar for promo/ad skip since they don't have built-in close buttons
            Positioned(
              top: 16,
              right: 20,
              child: SafeArea(
                child: Builder(
                  builder: (context) {
                    if (_currentIndex < 0 || _currentIndex >= _feed.length) {
                      return const SizedBox.shrink();
                    }
                    final item = _feed[_currentIndex];
                    if (item.type == SpotlightType.promo || item.type == SpotlightType.ad) {
                      return AnimatedOpacity(
                        opacity: _showOverlay ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: IgnorePointer(
                          ignoring: !_showOverlay,
                          child: GestureDetector(
                            onTap: _closeSpotlight,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 22),
                            ),
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
