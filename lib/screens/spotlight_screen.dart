import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/spotlight_item.dart';
import '../models/news_article.dart';
import '../widgets/ads/native_ad_card.dart';
import '../widgets/ads/ad_banner_widget.dart';
import '../models/ad_banner.dart';
import '../widgets/parallax_page_flip.dart';
import '../widgets/spotlight/spotlight_carousel_card.dart';
import '../widgets/spotlight/spotlight_news_card.dart';
import '../widgets/spotlight/spotlight_promo_card.dart';
import '../widgets/spotlight/spotlight_promo_card.dart';
import '../widgets/spotlight/spotlight_shimmer_card.dart';
import '../widgets/spotlight/location_prompt_sheet.dart';
import '../widgets/poster_card.dart';
import '../widgets/info_card.dart';
import '../utils/share_service.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import 'home_screen.dart';
import 'create_post_screen.dart';
import 'account_login_screen.dart';
import 'profile_tab.dart';
import '../localization/app_translations.dart';

class SpotlightScreen extends StatefulWidget {
  const SpotlightScreen({super.key});

  @override
  State<SpotlightScreen> createState() => _SpotlightScreenState();
}

class _SpotlightScreenState extends State<SpotlightScreen> {
  bool _isLocalNews = false;
  bool _isLoading = true;
  final List<SpotlightItem> _feed = [];
  final List<dynamic> _postersPool = [];
  String? _nextCursor;
  bool _hasMore = true;
  bool _showOverlays = true;

  Timer? _overlayTimer;

  @override
  void initState() {
    super.initState();
    _loadFeed();
    _startOverlayTimer();
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();
    super.dispose();
  }

  void _startOverlayTimer() {
    _overlayTimer?.cancel();
    setState(() => _showOverlays = true);
    _overlayTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showOverlays = false);
    });
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
    
    // Fetch a random quote for this batch
    final quoteResponse = await ApiService.instance.getRandomQuote();
    
    // Fetch active ads for the feed
    final adsResponse = await ApiService.instance.getAds(
      zone: 'feed',
      scope: _isLocalNews ? 'local' : 'main',
      state: _isLocalNews ? AppState.instance.stateName : null,
      district: _isLocalNews ? AppState.instance.district : null,
    );
    final activeAds = adsResponse.data ?? [];

    // Fetch posters if pool is running low
    if (_postersPool.length < 5) {
      final fetchedPosters = await ApiService.instance.getPosters(pageSize: 10);
      _postersPool.addAll(fetchedPosters);
    }
    
    for (int i = 0; i < newArticles.length; i++) {
      newItems.add(SpotlightItem.standard(newArticles[i]));
      int count = offset + i + 1;
      
      if (count == 2) {
         newItems.add(SpotlightItem.promo(id: 'promo_$count', imageUrl: 'https://images.unsplash.com/photo-1542204165-65bf26472b9b?w=800'));
      }
      
      // Inject a real poster every 4 items
      if (count % 4 == 0 && _postersPool.isNotEmpty) {
         final posterData = _postersPool.removeAt(0);
         final imageUrl = posterData['image_url'] ?? 'https://images.unsplash.com/photo-1518599904199-0ca897819ddb?w=800';
         newItems.add(SpotlightItem.poster(posterData['id'] ?? 'poster_$count', imageUrl));
      }

      if (count == 6) {
         if (quoteResponse != null) {
            newItems.add(SpotlightItem.infoCard(quoteResponse['id'] ?? 'info_$count', quoteResponse['text'] ?? 'Today\'s Jyothishyam'));
         } else {
            newItems.add(SpotlightItem.infoCard('info_$count', 'Today\'s Jyothishyam'));
         }
      }
      
      // Inject ads dynamically based on their specific display frequency
      if (activeAds.isNotEmpty) {
        for (var ad in activeAds) {
          if (ad.displayFrequency > 0 && count % ad.displayFrequency == 0) {
            newItems.add(SpotlightItem.ad(ad));
            break; // Only inject one ad at a time to prevent stacking
          }
        }
      }
    }

    // If we have items already, remove the trailing shimmer placeholder if it exists
    if (_feed.isNotEmpty && _feed.last.type == SpotlightType.shimmer) {
      _feed.removeLast();
    }

    setState(() {
      _feed.addAll(newItems);
      _nextCursor = response.nextCursor ?? "0"; // loop back if reached end
      _hasMore = true; // always true for infinite scroll
      
      // Inject a shimmer card at the end since we always expect more to load
      if (_feed.isNotEmpty) {
        _feed.add(SpotlightItem.shimmer());
      }
      
      _isLoading = false;
    });
    
    // Delayed Location Prompt Trigger
    if (!AppState.instance.locationPrompted && _feed.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _promptLocationIfNeeded();
      });
    }
  }

  void _promptLocationIfNeeded() async {
    if (AppState.instance.locationPrompted) return;
    AppState.instance.markLocationPrompted();
    
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const LocationPromptSheet(),
    );

    if (result == true && _isLocalNews && mounted) {
      _refreshFeed();
    }
  }

  Future<void> _refreshFeed() async {
    setState(() {
      _isLoading = true;
      _feed.clear();
      _nextCursor = null;
      _hasMore = true;
    });
    await _loadFeed();
  }

  void _onToggle(bool isLocal) {
    if (_isLocalNews == isLocal) return;
    HapticFeedback.selectionClick();
    setState(() => _isLocalNews = isLocal);
    _startOverlayTimer();
    _refreshFeed();
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

  void _shareArticle(NewsArticle article) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    await ShareService.shareArticle(article);
    if (mounted) Navigator.pop(context); // dismiss loading
  }

  Widget _buildItem(BuildContext context, int index, bool isCurrent, double dragDelta, double dragProgress, double matchCutProgress) {
    final item = _feed[index];
    switch (item.type) {
      case SpotlightType.standard:
        return SpotlightNewsCard(
          article: item.article!,
          isCurrent: isCurrent,
          dragDelta: dragDelta,
          dragProgress: dragProgress,
          matchCutProgress: matchCutProgress,
          onTap: _startOverlayTimer, // Tapping resets the timer and shows overlays
          onShare: () => _shareArticle(item.article!),
          onClose: _closeSpotlight,
        );
      case SpotlightType.carousel:
        return SpotlightCarouselCard(
          item: item,
          onTap: _startOverlayTimer,
          onShare: () => _shareArticle(item.article!),
          onClose: _closeSpotlight,
        );
      case SpotlightType.promo:
        return GestureDetector(
          onTap: _startOverlayTimer,
          child: SpotlightPromoCard(imageUrl: item.promoImageUrl!),
        );
      case SpotlightType.ad:
        return GestureDetector(
          onTap: _startOverlayTimer,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              child: item.adBanner != null ? AdBannerWidget(ad: item.adBanner!) : const NativeAdCard(),
            ),
          ),
        );
      case SpotlightType.poster:
        return GestureDetector(
          onTap: _startOverlayTimer,
          child: Center(child: PosterCard(mediaUrl: item.mediaUrl!)),
        );
      case SpotlightType.infoCard:
        return GestureDetector(
          onTap: _startOverlayTimer,
          child: Center(child: InfoCard(title: item.title!)),
        );
      case SpotlightType.shimmer:
        return const SpotlightShimmerCard();
    }
  }

  Widget _buildLocationFallback() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_off_rounded, size: 48, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              Text(
                tr('location_required'),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                tr('location_required_sub'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.my_location_rounded),
                  label: Text(tr('detect_location'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final granted = await showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => const LocationPromptSheet(),
                    );
                    if (granted == true && mounted) {
                      _refreshFeed();
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              // Functional Auto-complete Search Box
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  const telanganaDistricts = [
                    'Hyderabad', 'Warangal', 'Nizamabad', 'Khammam',
                    'Karimnagar', 'Ramagundam', 'Mahbubnagar', 'Nalgonda',
                    'Adilabad', 'Suryapet', 'Miryalaguda', 'Jagtial'
                  ];
                  return telanganaDistricts.where((String option) {
                    return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                  });
                },
                onSelected: (String selection) {
                  HapticFeedback.selectionClick();
                  // Manually set location in AppState and trigger refresh
                  AppState.instance.setLocation('Telangana', selection);
                  _refreshFeed();
                },
                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  return TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: tr('search_hint_city'),
                      hintStyle: const TextStyle(color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                      filled: true,
                      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300,
                        ),
                      ),
                    ),
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 8.0,
                      borderRadius: BorderRadius.circular(12),
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final String option = options.elementAt(index);
                            return InkWell(
                              onTap: () => onSelected(option),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black87,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopOverlay() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          color: Colors.black.withValues(alpha: 0.4),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            bottom: 12,
            left: 16,
            right: 16,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Profile Action Button
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        appBar: AppBar(
                          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                          elevation: 0,
                          leading: const BackButton(),
                        ),
                        body: const ProfileTab(),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 26),
              ),

              // Animated Sliding Toggle Pill
              Container(
                width: 190,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Stack(
                  children: [
                    // Sliding White Indicator
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      alignment: !_isLocalNews
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: FractionallySizedBox(
                        widthFactor: 0.5,
                        child: Container(
                          margin: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(17),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Tap Options
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _onToggle(false),
                            child: Center(
                              child: Text(
                                tr('tab_main'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: !_isLocalNews
                                      ? Colors.black
                                      : Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _onToggle(true),
                            child: Center(
                              child: Text(
                                tr('tab_local'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: _isLocalNews
                                      ? Colors.black
                                      : Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Create Post Action Button
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFF3B30),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () {
                    if (!AppState.instance.isLoggedIn) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountLoginScreen()));
                    } else {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostScreen()));
                    }
                  },
                  icon: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationStrip() {
    // Determine display location (fallback to mock if null)
    final locationName = AppState.instance.district ?? AppState.instance.stateName ?? 'Hyderabad, Telangana';

    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        final granted = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => const LocationPromptSheet(),
        );
        if (granted == true && mounted) {
          _refreshFeed();
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 16),
                const SizedBox(width: 6),
                Text(
                  locationName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomOverlay() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back Home Action
              IconButton(
                onPressed: _closeSpotlight,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              ),
              
              // Refresh Feed Action
              IconButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _refreshFeed();
                },
                icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            // Feed
            GestureDetector(
              onTap: _startOverlayTimer,
              child: _isLoading && _feed.isEmpty
                  ? const SpotlightShimmerCard()
                  : (_isLocalNews && !AppState.instance.hasValidLocation)
                      ? _buildLocationFallback()
                      : ParallaxPageFlip(
                          key: ValueKey('feed_$_isLocalNews'),
                          itemCount: _feed.length,
                          onPageChanged: (index) {
                            if (index == _feed.length - 2) {
                              _loadFeed();
                            }
                          },
                          itemBuilder: _buildItem,
                        ),
            ),
            
            // Top Frosted Glass Overlay Bar
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              top: _showOverlays ? 0 : -120,
              left: 0,
              right: 0,
              child: _buildTopOverlay(),
            ),

            // Local Location Strip (Only visible in Local Mode)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              top: (_showOverlays && _isLocalNews) ? MediaQuery.of(context).padding.top + 72 : -100,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _isLocalNews ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !_isLocalNews,
                    child: _buildLocationStrip(),
                  ),
                ),
              ),
            ),

            // Bottom Floating Control Bar
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              bottom: _showOverlays ? MediaQuery.of(context).padding.bottom + 16 : -100,
              left: 16,
              right: 16,
              child: _buildBottomOverlay(),
            ),
          ],
        ),
      ),
    );
  }
}
