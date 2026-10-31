import '../services/analytics_queue.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import '../widgets/search/universal_search_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../state/app_state.dart';
import 'package:flutter/material.dart';
import '../localization/app_translations.dart';
import '../models/news_article.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
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

  /// Backend keyword suggestions, shown when a search finds nothing.
  List<String> _suggestions = [];
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

  /// The latest completed search (kept on screen while the next one loads).
  SearchResult? _response;
  String _shownQuery = '';

  /// Why the latest search failed; the query stays in the box for Retry.
  SearchErrorKind? _errorKind;
  CancelToken? _inFlight;

  /// Typing pause before a live search (search handover: 400-500 ms).
  static const debounce = Duration(milliseconds: 450);

  void _clearResults() {
    _inFlight?.cancel();
    _results = [];
    _presentedResults = [];
    _response = null;
    _errorKind = null;
    _isLoading = false;
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    ++_queryGeneration;
    if (query.trim().isEmpty) {
      setState(_clearResults);
      return;
    }
    _debounce = Timer(debounce, () => _runSearch(query, submitted: false));
  }

  /// Runs [term] as a new search from a chip (suggestion, trend).
  void _searchTerm(String term) {
    _controller.text = term;
    _controller.selection = TextSelection.collapsed(offset: term.length);
    _runSearch(term);
  }

  /// [submitted]: the reader asked for this search (keyboard search, a
  /// recent / trending / suggested term) - only these are reported as
  /// `search_query`, not the live results while typing.
  void _runSearch(String query, {bool submitted = true}) async {
    _debounce?.cancel();
    final generation = ++_queryGeneration;
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(_clearResults);
      return;
    }
    // The previous request is dropped; its answer could not replace this
    // one anyway (generation check below).
    _inFlight?.cancel();
    final cancel = _inFlight = CancelToken();
    // Earlier results stay visible under a progress bar until this one is in.
    setState(() {
      _isLoading = true;
      _errorKind = null;
    });

    final futureResponse = ApiService.instance.search(
      trimmed,
      lang: AppState.instance.contentLanguage,
      cancelToken: cancel,
    );
    final futureAds = AdManager.instance.getAdsForZone('search');

    final response = await futureResponse;
    final ads = await futureAds;

    if (!mounted || generation != _queryGeneration) return;
    if (response.errorKind != null) {
      setState(() {
        _isLoading = false;
        _errorKind = response.errorKind;
      });
      return;
    }

    if (submitted) {
      unawaited(AnalyticsQueue.instance.track('search_query', metadata: {
        'q': trimmed,
        'result_count': response.universalResultCount,
      }));
    }

    setState(() {
      _response = response;
      _shownQuery = trimmed;
      // Universal search: the articles section; older backend: results.
      _results = response.articles;
      _suggestions = response.suggestions
          .where((s) => s.toLowerCase() != trimmed.toLowerCase())
          .take(8)
          .toList();
      _presentedResults = insertAdsIntoFeed<NewsArticle>(
        contentItems: _results,
        eligibleAds: ads.cast(),
        allowTimed: false,
        contentKey: (article) => 'search:${article.id}',
      );
      _isLoading = false;
      if (submitted && !_recent.contains(trimmed)) {
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
        backgroundColor:
            isDark ? AppColors.backgroundDark : AppColors.background,
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
                color:
                    isDark ? AppColors.textSecondaryDark : AppColors.textMuted,
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
                        color: isDark
                            ? AppColors.iconMutedDark
                            : AppColors.textMuted,
                        size: 18,
                      ),
                      onPressed: () {
                        _controller.clear();
                        ++_queryGeneration;
                        setState(_clearResults);
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
      body: _controller.text.trim().isEmpty
          ? _buildSuggestions(isDark, telugu)
          : _buildBody(isDark),
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
                    color:
                        isDark ? AppColors.iconMutedDark : AppColors.textMuted,
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

  Widget _buildBody(bool isDark) {
    if (_errorKind != null) return _buildError(isDark);
    final response = _response;
    if (response == null) {
      return _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : const SizedBox.shrink();
    }
    final Widget results;
    if (!response.hasSections || response.isEmpty) {
      // Older backend (articles only), or "No results found".
      results = _buildResults(isDark);
    } else {
      results = UniversalSearchResults(
        result: response,
        query: _shownQuery,
        presentedArticles: _presentedResults,
        onSearchTerm: _searchTerm,
      );
    }
    return Stack(
      children: [
        Positioned.fill(child: results),
        if (_isLoading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
                minHeight: 2, color: AppColors.primary),
          ),
      ],
    );
  }

  Widget _buildError(bool isDark) {
    final telugu = AppState.instance.language == 'Telugu';
    final kind = _errorKind!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              kind == SearchErrorKind.unavailable
                  ? Icons.cloud_off_rounded
                  : Icons.error_outline_rounded,
              size: 48,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            const SizedBox(height: 12),
            Text(
              searchErrorMessage(kind),
              key: const ValueKey('search_error_message'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.textLight : AppColors.textDark,
              ),
            ),
            // 429 gets no Retry button: the backend asks not to retry at
            // once; the reader can search again after a moment.
            if (kind == SearchErrorKind.unavailable) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('search_retry'),
                onPressed:
                    _isLoading ? null : () => _runSearch(_controller.text),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(telugu ? 'మళ్లీ ప్రయత్నించండి' : 'Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResults(bool isDark) {
    if (_results.isEmpty) {
      final telugu = AppState.instance.language == 'Telugu';
      final muted = isDark ? AppColors.textSecondaryDark : AppColors.textMuted;
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
                  color: isDark ? AppColors.textLight : AppColors.textDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                telugu ? 'మరో పదంతో ప్రయత్నించండి' : 'Try another keyword',
                style: TextStyle(color: muted, fontSize: 13),
              ),
              if (_suggestions.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  telugu ? 'ఇవి ప్రయత్నించండి' : 'Try these',
                  style: TextStyle(
                    color: muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in _suggestions)
                      ActionChip(
                        key: ValueKey('search_suggestion_$s'),
                        avatar: const Icon(Icons.search_rounded, size: 16),
                        label: Text(s),
                        onPressed: () => _searchTerm(s),
                      ),
                  ],
                ),
              ],
            ],
          ),
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
        return SearchArticleTile(article: article);
      },
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _inFlight?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
