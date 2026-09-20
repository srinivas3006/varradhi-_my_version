import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../state/app_state.dart';
import 'package:flutter/material.dart';
import '../localization/app_translations.dart';
import '../models/news_article.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'news_detail_screen.dart';
import '../services/ad_manager.dart';
import '../core/ads/ad_insertion.dart';
import '../widgets/ads/unified_ad_widget.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<NewsArticle> _results = [];
  List<FeedPresentationItem<NewsArticle>> _presentedResults = [];
  List<String> _recent = [];
  List<String> _trending = [];
  int _queryGeneration = 0;
  static const _recentKey = 'recent_searches';

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted && _queryGeneration == 0) {
      setState(() => _recent = prefs.getStringList(_recentKey) ?? []);
    }
  }

  Future<void> _saveRecent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentKey, List<String>.from(_recent));
  }

  @override
  void initState() {
    super.initState();
    _loadTrending();
    _loadRecent();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  Future<void> _loadTrending() async {
    try {
      final terms = await ApiService.instance.getTrendingSearchKeywords();
      if (mounted && terms.isNotEmpty) {
        setState(() => _trending = terms);
      }
    } catch (_) {
      // Trending is optional; do not present invented server suggestions.
    }
  }

  bool _isLoading = false;
  Timer? _debounce;

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    ++_queryGeneration;
    if (query.trim().length < 2) {
      setState(() { _results = []; _isLoading = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _runSearch(query));
  }

  void _runSearch(String query) async {
    _debounce?.cancel();
    final generation = ++_queryGeneration;
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      setState(() { _results = []; _isLoading = false; });
      return;
    }
    setState(() => _isLoading = true);

    final futureResponse = ApiService.instance.searchArticles(
      trimmed, lang: AppState.instance.contentLanguage,
    );
    final futureAds = AdManager.instance.getAdsForZone('search');
    
    final response = await futureResponse;
    final ads = await futureAds;

    if (!mounted || generation != _queryGeneration) return;
    if (response.hasErrors) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.errorMessage ?? tr('no_results'))),
      );
      return;
    }

    setState(() {
      _results = response.data ?? [];
      _presentedResults = insertAdsIntoFeed<NewsArticle>(
        contentItems: _results,
        eligibleAds: ads.cast(),
        allowTimed: false,
        contentKey: (article) => 'search:${article.id}',
      );
      _isLoading = false;
      if (!_recent.contains(trimmed)) {
        _recent.insert(0, trimmed);
        if (_recent.length > 6) _recent.removeLast();
      }
    });
    await _saveRecent();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final telugu = AppState.instance.language == 'Telugu';

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? AppColors.textLight : AppColors.textDark,
        ),
        title: Container(
          height: 44,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceElevatedDark : AppColors.chipBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            onSubmitted: _runSearch,
            onChanged: (value) {
              setState(() {});
              _onQueryChanged(value);
            },
            style: TextStyle(
              color: isDark ? AppColors.textLight : AppColors.textDark,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            cursorColor: AppColors.primary,
            decoration: InputDecoration(
              hintText: tr('search_hint'),
              hintStyle: TextStyle(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textMuted,
                fontSize: 13,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: isDark ? AppColors.iconMutedDark : AppColors.textMuted,
                size: 20,
              ),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear_rounded,
                        color: isDark ? AppColors.iconMutedDark : AppColors.textMuted,
                        size: 18,
                      ),
                      onPressed: () {
                        _controller.clear();
                        setState(() {
                          _results = [];
                          _presentedResults = [];
                          _isLoading = false;
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              tr('cancel'),
              style: TextStyle(
                color: isDark ? AppColors.textLight : AppColors.textDark,
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
      body: _controller.text.isEmpty
          ? _buildSuggestions(isDark, telugu)
          : _isLoading 
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ) 
              : _buildResults(isDark),
    );
  }

  Widget _buildSuggestions(bool isDark, bool telugu) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        if (_recent.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr('recent_searches'),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: isDark ? AppColors.textLight : AppColors.textDark,
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() => _recent.clear());
                  _saveRecent();
                },
                child: Text(
                  telugu ? 'అన్నీ తీసివేయి' : 'Clear all',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ..._recent.map((q) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  Icons.history_rounded,
                  color: isDark ? AppColors.iconMutedDark : AppColors.textMuted,
                  size: 20,
                ),
                title: Text(
                  q,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.textLight : AppColors.textDark,
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: isDark ? AppColors.iconMutedDark : AppColors.textMuted,
                  ),
                  onPressed: () {
                    setState(() => _recent.remove(q));
                    _saveRecent();
                  },
                ),
                onTap: () {
                  _controller.text = q;
                  _runSearch(q);
                },
              )),
          const SizedBox(height: 16),
        ],
        if (_trending.isNotEmpty) ...[
          Text(
            tr('trending_searches'),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: isDark ? AppColors.textLight : AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _trending
                .map((t) => GestureDetector(
                      onTap: () {
                        _controller.text = t;
                        _runSearch(t);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.surfaceElevatedDark
                              : AppColors.chipBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? AppColors.borderDark
                                : AppColors.borderLight,
                          ),
                        ),
                        child: Text(
                          t,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.textLight
                                : AppColors.textDark,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildResults(bool isDark) {
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 56,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
            const SizedBox(height: 12),
            Text(
              tr('no_results'),
              style: TextStyle(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textMuted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _presentedResults.length,
      separatorBuilder: (_, __) => Divider(
        height: 16,
        color: isDark ? AppColors.borderDark : AppColors.borderLight,
      ),
      itemBuilder: (context, index) {
        final item = _presentedResults[index];
        if (item.isAd) {
          return UnifiedAdWidget(
            ad: item.ad!,
            placementZone: 'search',
            exposureKey: item.stableKey,
          );
        }
        
        final article = item.content!;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: article.imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: article.imageUrl,
                    width: 60,
                    height: 60,
                    memCacheWidth: 160,
                    memCacheHeight: 160,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 60,
                      height: 60,
                      color: isDark ? AppColors.surfaceElevatedDark : Colors.black12,
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 60,
                      height: 60,
                      color: isDark ? AppColors.surfaceElevatedDark : Colors.black12,
                      child: Icon(
                        Icons.broken_image_rounded,
                        size: 20,
                        color: isDark ? Colors.white38 : Colors.black26,
                      ),
                    ),
                  )
                : Container(
                    width: 60,
                    height: 60,
                    color: isDark ? AppColors.surfaceElevatedDark : Colors.black12,
                    child: Icon(
                      Icons.newspaper_rounded,
                      size: 20,
                      color: isDark ? Colors.white38 : Colors.black26,
                    ),
                  ),
          ),
          title: Text(
            article.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              height: 1.3,
              color: isDark ? AppColors.textLight : AppColors.textDark,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              '${article.source} · ${article.timeAgo}',
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textMuted,
              ),
            ),
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NewsDetailScreen(article: article),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
