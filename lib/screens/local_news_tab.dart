import 'dart:ui' as dart_ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/navigation/app_navigator.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../models/news_article.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import 'news_detail_screen.dart';
import '../models/ad_banner.dart';
import '../widgets/ads/ad_banner_widget.dart';
import 'ugc_feed_screen.dart';
import 'location_selection_screen.dart';

class LocalNewsTab extends StatefulWidget {
  const LocalNewsTab({super.key});

  @override
  State<LocalNewsTab> createState() => _LocalNewsTabState();
}

class _LocalNewsTabState extends State<LocalNewsTab> {
  late String _location;
  bool _isLoading = true;
  bool _isDetectingLocation = false;
  final List<NewsArticle> _feed = [];
  List<AdBanner> _localAds = [];
  String? _nextCursor;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _location = AppState.instance.displayLocation;
    _loadAds();
    _loadFeed();
  }

  Future<void> _loadAds() async {
    try {
      final res = await ApiService.instance.getAds(
        zone: 'feed',
        scope: 'local',
        state: AppState.instance.stateName,
        district: AppState.instance.district,
        city: AppState.instance.city,
        lang: 'te',
      );
      if (mounted && res.data != null && res.data!.isNotEmpty) {
        setState(() => _localAds = res.data!);
      }
    } catch (_) {}
  }

  Future<void> _loadFeed() async {
    if (!_hasMore) return;

    try {
      final response = await ApiService.instance.getNewsFeed(
        cursor: _nextCursor,
        scope: 'local',
        state: AppState.instance.stateName,
        district: AppState.instance.district,
        city: AppState.instance.city,
        subdistrict: AppState.instance.subdistrict.isNotEmpty ? AppState.instance.subdistrict : null,
        village: AppState.instance.village.isNotEmpty ? AppState.instance.village : null,
        lang: 'te',
        latitude: AppState.instance.latitude,
        longitude: AppState.instance.longitude,
      );

      if (!mounted) return;
      var newArticles = response.data ?? [];
      if (newArticles.isEmpty && _feed.isEmpty && AppState.instance.subdistrict.isNotEmpty) {
        try {
          final fallback = await ApiService.instance.getNewsFeed(
            scope: 'local',
            state: AppState.instance.stateName,
            district: AppState.instance.district,
            lang: 'te',
          );
          newArticles = fallback.data ?? [];
        } catch (_) {}
      }

      setState(() {
        _feed.addAll(newArticles);
        _nextCursor = response.nextCursor;
        _hasMore = response.nextCursor != null;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
      _feed.clear();
      _nextCursor = null;
      _hasMore = true;
    });
    await Future.wait([
      _loadAds(),
      _loadFeed(),
    ]);
  }

  Future<void> _detectLocation() async {
    setState(() => _isDetectingLocation = true);

    try {
      final deviceLocation = await LocationService.detectLocation();
      await ApiService.instance.resolveAndSyncCanonicalLocation(deviceLocation);
      if (mounted) {
        setState(() {
          _location = AppState.instance.displayLocation;
        });
        _refresh();
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    } on LocationException catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exception.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isDetectingLocation = false);
      }
    }
  }

  Future<void> _changeLocation() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LocationSelectionScreen()),
    );
    if (changed == true && mounted) {
      setState(() {
        _location = AppState.instance.displayLocation;
      });
      _refresh();
    }
  }

  Widget _buildTopAppBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      child: BackdropFilter(
        filter: dart_ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            bottom: 12,
            left: 16,
            right: 16,
          ),
          decoration: BoxDecoration(
            color: isDark ? Colors.black.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.7),
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
              ),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _changeLocation,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 16),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(
                          _location,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded, color: Theme.of(context).textTheme.bodyLarge?.color, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: _isDetectingLocation
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      )
                    : const Icon(Icons.my_location_rounded, size: 20, color: AppColors.primary),
                tooltip: 'Detect current location via GPS',
                onPressed: _isDetectingLocation ? null : _detectLocation,
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UgcFeedScreen())),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.record_voice_over_rounded, color: Colors.amber, size: 15),
                      SizedBox(width: 4),
                      Text('Citizen Feed', style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.search_rounded, color: Theme.of(context).iconTheme.color),
                onPressed: () {
                  // TODO: Navigate to Search Screen
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_off_rounded, size: 34, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'మీ ప్రాంతానికి స్థానిక వార్తలు అందుబాటులో లేవు',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'No local news available for your area.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleCard(NewsArticle article, Color cardColor, Color borderColor) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        AppNavigator.pushSafe(
          context,
          MaterialPageRoute(builder: (_) => NewsDetailScreen(article: article, slug: article.slug)),
        );
      },
      child: Row(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: cardColor,
              border: Border.all(color: borderColor),
              image: article.imageUrl.isNotEmpty
                  ? DecorationImage(
                      image: CachedNetworkImageProvider(
                        article.imageUrl,
                        maxWidth: 300,
                        maxHeight: 300,
                      ),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    article.category.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  article.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 12, color: Theme.of(context).textTheme.bodySmall?.color),
                    const SizedBox(width: 4),
                    Text(
                      article.timeAgo,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text('•', style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color)),
                    ),
                    Icon(Icons.favorite_rounded, size: 12, color: Theme.of(context).textTheme.bodySmall?.color),
                    const SizedBox(width: 4),
                    Text(
                      '${article.likes}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          _isLoading && _feed.isEmpty
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : RefreshIndicator(
                  onRefresh: _refresh,
                  color: AppColors.primary,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (ScrollNotification scrollInfo) {
                      if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200 && !_isLoading) {
                        _loadFeed();
                      }
                      return false;
                    },
                    child: _feed.isEmpty && !_isLoading
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.only(
                              top: MediaQuery.of(context).padding.top + 70,
                              bottom: 120,
                            ),
                            child: _buildEmptyState(),
                          )
                        : CustomScrollView(
                            slivers: [
                              SliverPadding(
                                padding: EdgeInsets.only(
                                  top: MediaQuery.of(context).padding.top + 70,
                                  left: 16,
                                  right: 16,
                                  bottom: 120,
                                ),
                                sliver: SliverList.separated(
                                  itemCount: _feed.length + (_hasMore ? 1 : 0),
                                  separatorBuilder: (context, index) {
                                    if ((index + 1) % 4 == 0) {
                                      final adSlotIndex = ((index + 1) ~/ 4) - 1;
                                      final ad = _localAds.isNotEmpty
                                          ? _localAds[adSlotIndex % _localAds.length]
                                          : null;
                                      if (ad != null) {
                                        return Column(
                                          children: [
                                            const SizedBox(height: 16),
                                            AdBannerWidget(ad: ad),
                                            const SizedBox(height: 16),
                                          ],
                                        );
                                      }
                                    }
                                    return const SizedBox(height: 16);
                                  },
                                  itemBuilder: (context, index) {
                                    if (index == _feed.length) {
                                      return const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(16.0),
                                          child: CircularProgressIndicator(color: AppColors.primary),
                                        ),
                                      );
                                    }

                                    final article = _feed[index];
                                    return _buildArticleCard(article, cardColor, borderColor);
                                  },
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
          
          // Floating Top App Bar Layer
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopAppBar(),
          ),
        ],
      ),
    );
  }
}
