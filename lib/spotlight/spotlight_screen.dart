import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/spotlight_item.dart';
import '../models/news_article.dart';
import '../widgets/ads/native_ad_card.dart';
import '../widgets/ads/ad_banner_widget.dart';
import '../widgets/parallax_page_flip.dart';
import '../widgets/spotlight/spotlight_carousel_card.dart';
import '../widgets/spotlight/spotlight_news_card.dart';
import '../widgets/spotlight/spotlight_promo_card.dart';
import '../widgets/spotlight/spotlight_shimmer_card.dart';
import '../widgets/spotlight/location_prompt_sheet.dart';
import '../widgets/poster_card.dart';
import '../widgets/info_card.dart';
import '../utils/share_service.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../localization/app_translations.dart';
import '../screens/home_screen.dart';
import '../screens/create_post_screen.dart';
import '../screens/account_login_screen.dart';
import '../screens/profile_tab.dart';

import 'spotlight_controller.dart';
import 'spotlight_state.dart';

class SpotlightScreenView extends StatefulWidget {
  const SpotlightScreenView({super.key});

  @override
  State<SpotlightScreenView> createState() => _SpotlightScreenViewState();
}

class _SpotlightScreenViewState extends State<SpotlightScreenView> {
  late final SpotlightController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SpotlightController();
  }

  @override
  void dispose() {
    _controller.dispose();
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

  void _shareArticle(NewsArticle article) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    await ShareService.shareArticle(article);
    if (mounted) Navigator.pop(context);
  }

  Widget _buildItem(
    BuildContext context,
    int index,
    bool isCurrent,
    double dragDelta,
    double dragProgress,
    double matchCutProgress,
  ) {
    final state = _controller.state;
    if (index >= state.feed.length) return const SizedBox();

    final item = state.feed[index];
    switch (item.type) {
      case SpotlightType.standard:
        return SpotlightNewsCard(
          article: item.article!,
          isCurrent: isCurrent,
          dragDelta: dragDelta,
          dragProgress: dragProgress,
          matchCutProgress: matchCutProgress,
          onTap: _controller.startOverlayTimer,
          onShare: () => _shareArticle(item.article!),
          onClose: _closeSpotlight,
        );
      case SpotlightType.carousel:
        return SpotlightCarouselCard(
          item: item,
          onTap: _controller.startOverlayTimer,
          onShare: () => _shareArticle(item.article!),
          onClose: _closeSpotlight,
        );
      case SpotlightType.promo:
        return GestureDetector(
          onTap: _controller.startOverlayTimer,
          child: SpotlightPromoCard(imageUrl: item.promoImageUrl!),
        );
      case SpotlightType.ad:
        return GestureDetector(
          onTap: _controller.startOverlayTimer,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              child: item.adBanner != null
                  ? AdBannerWidget(ad: item.adBanner!)
                  : NativeAdCard(ad: item.adBanner),
            ),
          ),
        );
      case SpotlightType.poster:
        return GestureDetector(
          onTap: _controller.startOverlayTimer,
          child: Center(child: PosterCard(mediaUrl: item.mediaUrl!)),
        );
      case SpotlightType.infoCard:
        return GestureDetector(
          onTap: _controller.startOverlayTimer,
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
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_off_rounded,
                  size: 48,
                  color: AppColors.primary,
                ),
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
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.my_location_rounded),
                  label: Text(
                    tr('detect_location'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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
                      _controller.refreshFeed();
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  const telanganaDistricts = [
                    'Hyderabad',
                    'Warangal',
                    'Nizamabad',
                    'Khammam',
                    'Karimnagar',
                    'Ramagundam',
                    'Mahbubnagar',
                    'Nalgonda',
                    'Adilabad',
                    'Suryapet',
                    'Miryalaguda',
                    'Jagtial'
                  ];
                  return telanganaDistricts.where((String option) {
                    return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                  });
                },
                onSelected: (String selection) {
                  HapticFeedback.selectionClick();
                  AppState.instance.setLocation('Telangana', selection);
                  _controller.refreshFeed();
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

  Widget _buildTopOverlay(SpotlightState state) {
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
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      alignment: !state.isLocalNews
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
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _controller.toggleMode(false),
                            child: Center(
                              child: Text(
                                tr('tab_main'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: !state.isLocalNews
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
                            onTap: () => _controller.toggleMode(true),
                            child: Center(
                              child: Text(
                                tr('tab_local'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: state.isLocalNews
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AccountLoginScreen()),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CreatePostScreen()),
                      );
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
    final locationName = AppState.instance.displayLocation;

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
          _controller.refreshFeed();
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
              IconButton(
                onPressed: _closeSpotlight,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              ),
              IconButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _controller.refreshFeed();
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
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final state = _controller.state;
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Stack(
              children: [
                GestureDetector(
                  onTap: _controller.startOverlayTimer,
                  child: state.isLoading && state.feed.isEmpty
                      ? const SpotlightShimmerCard()
                      : (state.isLocalNews && !AppState.instance.hasValidLocation)
                          ? _buildLocationFallback()
                          : ParallaxPageFlip(
                              key: ValueKey('feed_${state.isLocalNews}'),
                              itemCount: state.feed.length,
                              onPageChanged: (index) {
                                if (index >= state.feed.length - 2) {
                                  _controller.loadFeed();
                                }
                              },
                              itemBuilder: _buildItem,
                            ),
                ),
                
                // Top Frosted Glass Overlay
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  top: state.showOverlays ? 0 : -120,
                  left: 0,
                  right: 0,
                  child: _buildTopOverlay(state),
                ),

                // Local Location Strip (Only visible when Local mode is active)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  top: (state.showOverlays && state.isLocalNews)
                      ? MediaQuery.of(context).padding.top + 72
                      : -100,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: state.isLocalNews ? 1.0 : 0.0,
                      child: IgnorePointer(
                        ignoring: !state.isLocalNews,
                        child: _buildLocationStrip(),
                      ),
                    ),
                  ),
                ),

                // Bottom Floating Control Bar
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  bottom: state.showOverlays
                      ? MediaQuery.of(context).padding.bottom + 16
                      : -100,
                  left: 16,
                  right: 16,
                  child: _buildBottomOverlay(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
