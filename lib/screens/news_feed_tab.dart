import 'package:flutter/material.dart';
import '../data/mock_news.dart';
import '../data/mock_polls.dart';
import '../localization/app_translations.dart';
import '../models/feed_item.dart';
import '../models/news_article.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ads/interstitial_ad_overlay.dart';
import '../widgets/ads/native_ad_card.dart';
import '../widgets/category_bar.dart';
import '../widgets/news_feed_card.dart';
import '../widgets/poll_card.dart';
import '../widgets/trending_rail_card.dart';
import '../widgets/trending_rail_card.dart';
import '../widgets/poster_card.dart';
import '../widgets/info_card.dart';
import '../widgets/flip_page_view.dart';
import 'news_detail_screen.dart';
import 'comments_screen.dart';
import 'search_screen.dart';
import 'notifications_tab.dart';
import '../utils/share_service.dart';
import '../services/api_service.dart';

class NewsFeedTab extends StatefulWidget {
  const NewsFeedTab({super.key});

  @override
  State<NewsFeedTab> createState() => _NewsFeedTabState();
}

class _NewsFeedTabState extends State<NewsFeedTab> {
  int _selectedCategory = 0;
  late List<NewsArticle> _articles;
  late List<FeedItem> _currentFeed;
  late List<String> _displayCategories;
  final PageController _pageController = PageController(viewportFraction: 1);
  final bool _useFlipAnimation = true;
  bool _isLoadingMore = false;
  String? _nextCursor;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _articles = [];
    _currentFeed = [];
    _buildDisplayCategories();
    _pageController.addListener(_onScroll);
    _loadMore();
  }

  void _buildDisplayCategories() {
    final prefs = AppState.instance.preferredCategories;
    final base = ['For You', 'Trending'];
    final preferred = <String>[];
    final remaining = <String>[];
    
    for (var cat in categories) {
      if (base.contains(cat)) continue;
      if (prefs.contains(cat)) {
        preferred.add(cat);
      } else {
        remaining.add(cat);
      }
    }
    
    _displayCategories = [...base, ...preferred];
    if (preferred.isNotEmpty && remaining.isNotEmpty) {
      _displayCategories.add('|');
    }
    _displayCategories.addAll(remaining);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Rebuild categories if preferences change when popping back
    final oldLen = _displayCategories.length;
    _buildDisplayCategories();
    if (oldLen != _displayCategories.length) {
      if (mounted) setState(() {});
    }
  }

  void _onScroll() {
    if (_pageController.position.pixels >= _pageController.position.maxScrollExtent - 500 && !_isLoadingMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    
    final category = _displayCategories[_selectedCategory];
    // Don't fetch if it's the divider
    if (category == '|') {
      setState(() => _isLoadingMore = false);
      return;
    }

    final response = await ApiService.instance.getNewsFeed(
      cursor: _nextCursor,
      category: category,
    );
    
    if (!mounted) return;
    setState(() {
      final newArticles = response.data ?? [];
      _articles.addAll(newArticles);
      _nextCursor = response.nextCursor;
      _hasMore = _nextCursor != null;
      
      // We append to the current feed
      _currentFeed.addAll(_buildMixedFeed(newArticles, offset: _currentFeed.length));
      _isLoadingMore = false;
    });
  }

  Future<void> _refresh() async {
    _nextCursor = null;
    _hasMore = true;
    _articles.clear();
    _currentFeed.clear();
    await _loadMore();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feed updated')));
  }

  List<FeedItem> _buildMixedFeed(List<NewsArticle> articlesToAdd, {int offset = 0}) {
    // We only process the new articles to append them
    final items = <FeedItem>[];
    var articleCount = offset;

    for (var i = 0; i < articlesToAdd.length; i++) {
      items.add(FeedItem.article(articlesToAdd[i]));
      articleCount++;

      // Inject Trending Rail after the 1st article in the first batch
      if (offset == 0 && articleCount == 1) {
         items.add(FeedItem.trendingRail(mockTrendingArticles));
      }

      // Inject preferences prompt after the 2nd article if not yet prompted
      if (offset == 0 && articleCount == 2 && !AppState.instance.hasPromptedPreferences) {
        // We'll create a special feed item for the prompt, or just use a Poll slot temporarily if FeedItem lacks it.
        // Wait, FeedItem doesn't have a preferencesPrompt type. I will add it to FeedItem next.
        items.add(const FeedItem.preferencesPrompt());
      }

      if (articleCount == 3 && mockPolls.isNotEmpty) {
        items.add(FeedItem.poll(mockPolls[_selectedCategory % mockPolls.length]));
      }
      if (articleCount == 4) {
        items.add(const FeedItem.poster('https://images.unsplash.com/photo-1518599904199-0ca897819ddb?w=800'));
      }
      if (articleCount == 6) {
        items.add(const FeedItem.infoCard('Today\'s Jyothishyam'));
      }
      if (articleCount % 5 == 0) {
        items.add(const FeedItem.ad());
      }
    }
    return items;
  }

  void _toggleLike(NewsArticle article) {
    setState(() => article.isLiked = !article.isLiked);
  }

  void _toggleBookmark(NewsArticle article) {
    setState(() => article.isBookmarked = !article.isBookmarked);
  }

  void _share(NewsArticle article) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    await ShareService.shareArticle(article);
    if (mounted) Navigator.pop(context); // dismiss loading
  }

  Future<void> _onCategorySelected(int index) async {
    if (_displayCategories[index] == '|') return; // Cannot select divider
    setState(() {
      _selectedCategory = index;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    await _refresh();
    if (index.isOdd) {
      await showInterstitialAd(context);
    }
  }

  Widget _buildFeedItem(BuildContext context, int index) {
    final item = _currentFeed[index];
    Widget child;
    switch (item.type) {
      case FeedItemType.preferencesPrompt:
        child = _buildPreferencesPromptCard();
        break;
      case FeedItemType.ad:
        child = const NativeAdCard();
        break;
      case FeedItemType.poll:
        child = PollCard(poll: item.poll!);
        break;
      case FeedItemType.trendingRail:
        child = TrendingRailCard(articles: item.trendingArticles!);
        break;
      case FeedItemType.article:
        final article = item.article!;
        child = NewsFeedCard(
          article: article,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NewsDetailScreen(article: article),
              ),
            );
          },
          onLike: () => _toggleLike(article),
          onBookmark: () => _toggleBookmark(article),
          onShare: () => _share(article),
          onComment: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CommentsScreen(article: article),
              ),
            );
          },
        );
        break;
      case FeedItemType.poster:
        child = PosterCard(mediaUrl: item.mediaUrl!);
        break;
      case FeedItemType.infoCard:
        child = InfoCard(title: item.title!);
        break;
    }

    if (index == _currentFeed.length - 1) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 50.0),
        child: child,
      );
    }
    return child;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
            // Top app bar
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.bolt_rounded,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'DailyBuzz',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.search, color: AppColors.textDark),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SearchScreen()),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined, color: AppColors.textDark),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NotificationsTab()), // Ensure this is imported
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            CategoryBar(
              categories: _displayCategories,
              selectedIndex: _selectedCategory,
              onSelected: _onCategorySelected,
            ),
            const SizedBox(height: 6),
            // Vertical snapping mixed feed
            Expanded(
              child: _currentFeed.isEmpty
                  ? Center(
                      child: Text(
                        tr('no_stories'),
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      color: AppColors.primary,
                      child: _useFlipAnimation
                          ? FlipPageView(
                              key: ValueKey(_selectedCategory),
                              controller: _pageController,
                              itemCount: _currentFeed.length,
                              itemBuilder: (context, index) {
                                return _buildFeedItem(context, index);
                              },
                            )
                          : PageView.builder(
                              key: ValueKey(_selectedCategory),
                              controller: _pageController,
                              scrollDirection: Axis.vertical,
                              itemCount: _currentFeed.length,
                              itemBuilder: (context, index) {
                                return _buildFeedItem(context, index);
                              },
                            ),
                    ),
            ),
          ],
        );
  }

  @override
  void dispose() {
    _pageController.removeListener(_onScroll);
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildPreferencesPromptCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.tune, size: 48, color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            AppState.instance.language == 'Telugu' 
              ? 'మీ ఫీడ్‌ను అనుకూలీకరించండి' 
              : 'Customize your feed',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            AppState.instance.language == 'Telugu'
              ? 'మీకు ఆసక్తి ఉన్న 3 వర్గాలను ఎంచుకోండి మరియు మేము మీకు నచ్చే వార్తలను చూపుతాము.'
              : 'Pick your top categories for a tailored experience.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha(150)),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              AppState.instance.markPreferencesPrompted();
              Navigator.pushNamed(context, '/preferences');
              setState(() {
                _currentFeed.removeWhere((item) => item.type == FeedItemType.preferencesPrompt);
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: Text(AppState.instance.language == 'Telugu' ? 'ఎంచుకోండి' : 'Personalize Now'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              AppState.instance.markPreferencesPrompted();
              setState(() {
                _currentFeed.removeWhere((item) => item.type == FeedItemType.preferencesPrompt);
              });
            },
            child: Text(AppState.instance.language == 'Telugu' ? 'వద్దు, తర్వాత' : 'Not right now', style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}
