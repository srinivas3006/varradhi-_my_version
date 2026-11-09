import 'package:flutter/material.dart';
import '../core/ads/ad_insertion.dart';
import '../core/ads/ad_placement.dart';
import '../core/ads/zone_ads.dart';
import '../core/feed/ugc_feed_freshness.dart';
import '../core/network/api_response.dart';
import '../models/ad_banner.dart';
import '../models/news_article.dart';
import '../widgets/ads/unified_ad_widget.dart';
import '../state/app_state.dart';
import '../widgets/article_media_carousel.dart';
import '../localization/app_translations.dart';
import '../repositories/ugc_repository.dart';
import '../theme/app_theme.dart';
import 'news_detail_screen.dart';

class UgcFeedScreen extends StatefulWidget {
  const UgcFeedScreen({super.key});

  @override
  State<UgcFeedScreen> createState() => _UgcFeedScreenState();
}

class _UgcFeedScreenState extends State<UgcFeedScreen>
    with WidgetsBindingObserver {
  final List<NewsArticle> _reports = [];
  bool _isLoading = false;
  int _generation = 0;
  late String _locationKey;
  String get _currentLocationKey => [
        AppState.instance.feedLang,
        AppState.instance.stateName,
        AppState.instance.district,
        AppState.instance.subdistrict,
        AppState.instance.village,
        AppState.instance.city
      ].join('|');
  void _onLocationChanged() {
    if (_locationKey == _currentLocationKey) return;
    _locationKey = _currentLocationKey;
    // Another language or place: nothing of the old list may stay on screen.
    setState(() {
      _reports.clear();
      _cursor = null;
      _hasMore = true;
    });
    _refresh();
  }

  /// When page one last loaded, for the refresh on returning to the app.
  DateTime? _pageOneLoadedAt;

  void _onPublished() => _refresh();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        UgcFeedFreshness.isStale(_pageOneLoadedAt)) {
      _refresh();
    }
  }

  String? _errorMessage;
  String? _cursor;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  /// `ugc_feed` zone ads, placed between posts.
  List<AdBanner> _zoneAds = const [];

  Future<void> _loadZoneAds() async {
    final generation = _generation;
    final ads = await ZoneAds.load(AdPlacement.ugcFeed);
    if (mounted && generation == _generation) {
      setState(() => _zoneAds = ads);
    }
  }

  @override
  void initState() {
    super.initState();
    _locationKey = _currentLocationKey;
    AppState.instance.addListener(_onLocationChanged);
    WidgetsBinding.instance.addObserver(this);
    UgcFeedFreshness.published.addListener(_onPublished);
    _loadZoneAds();
    _loadMore();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    final generation = _generation;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final firstPage = _cursor == null;
      final response = await _fetchPage(_cursor);

      if (!mounted || generation != _generation) return;
      if (response.hasErrors) throw Exception(response.errorMessage);
      setState(() {
        // Appended in the backend's order; never re-sorted here.
        final ids = _reports.map((item) => item.id).toSet();
        _reports
            .addAll((response.data ?? []).where((item) => ids.add(item.id)));
        _isLoading = false;
        _cursor = response.nextCursor;
        _hasMore =
            response.nextCursor != null && response.nextCursor!.isNotEmpty;
        if (firstPage) _pageOneLoadedAt = DateTime.now();
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _isLoading = false;
          if (_reports.isEmpty) {
            _errorMessage = tr('citizen_reports_load_failed');
          }
        });
      }
    }
  }

  Future<ApiResponse<List<NewsArticle>>> _fetchPage(String? cursor) {
    return UgcRepository.instance.getUgcFeed(
        cursor: cursor,
        pageSize: 20,
        scope: 'main',
        state: AppState.instance.feedPlace.state,
        district: AppState.instance.feedPlace.district,
        subdistrict: AppState.instance.feedPlace.subdistrict,
        village: AppState.instance.feedPlace.village);
  }

  /// Page one again, without the cursor. It replaces the list when it loads;
  /// the list stays as it is if the request fails.
  Future<void> _refresh() async {
    final generation = ++_generation;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _loadZoneAds();
    try {
      final response = await _fetchPage(null);
      if (!mounted || generation != _generation) return;
      if (response.hasErrors) throw Exception(response.errorMessage);
      setState(() {
        final ids = <String>{};
        _reports
          ..clear()
          ..addAll((response.data ?? []).where((item) => ids.add(item.id)));
        _isLoading = false;
        _cursor = response.nextCursor;
        _hasMore =
            response.nextCursor != null && response.nextCursor!.isNotEmpty;
        _pageOneLoadedAt = DateTime.now();
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _isLoading = false;
          if (_reports.isEmpty) {
            _errorMessage = tr('citizen_reports_load_failed');
          }
        });
      }
    }
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onLocationChanged);
    WidgetsBinding.instance.removeObserver(this);
    UgcFeedFreshness.published.removeListener(_onPublished);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // At least 5 posts apart.
    final adAfter = adSlotsAfter<NewsArticle>(
      contentItems: _reports,
      eligibleAds: _zoneAds,
      placementZone: AdPlacement.ugcFeed,
      policy: AdFrequencyPolicy.ugcFeed,
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(tr('citizen_reports')),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0.5,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        child: _reports.isEmpty && _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _reports.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                          height: MediaQuery.of(context).size.height * 0.25),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _errorMessage != null
                                  ? Icons.error_outline_rounded
                                  : Icons.dynamic_feed_rounded,
                              size: 56,
                              color: _errorMessage != null
                                  ? AppColors.error
                                  : AppColors.textMuted.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage != null
                                  ? tr('citizen_reports_load_failed')
                                  : tr('no_citizen_reports'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _errorMessage ?? tr('pull_to_refresh'),
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.textMuted),
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _refresh,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text(tr('retry')),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: _reports.length + (_hasMore ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index == _reports.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final report = _reports[index];
                      final ad = adAfter[index];
                      if (ad == null) return _UgcReportCard(report: report);
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _UgcReportCard(report: report),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                            child: UnifiedAdWidget(
                              key: ValueKey('ugc_ad_${ad.id}_$index'),
                              ad: ad,
                              placementZone: AdPlacement.ugcFeed,
                              exposureKey: 'ugc_feed_${ad.id}_$index',
                            ),
                          ),
                        ],
                      );
                    },
                  ),
      ),
    );
  }
}

class _UgcReportCard extends StatelessWidget {
  final NewsArticle report;

  const _UgcReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textDark;
    final mutedColor = isDark ? Colors.white60 : AppColors.textMuted;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                NewsDetailScreen(article: report, slug: report.slug),
          ),
        );
      },
      child: Container(
        color: cardColor,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: const Icon(Icons.person, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.source,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: textColor,
                        ),
                      ),
                      Text(
                        '${tr('local_reporter')} • ${report.timeAgo}',
                        style: TextStyle(
                          fontSize: 12,
                          color: mutedColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              report.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textColor,
                height: 1.3,
              ),
            ),
            if (report.body.isNotEmpty && report.body != report.title) ...[
              const SizedBox(height: 8),
              Text(
                report.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : AppColors.textDark,
                  height: 1.4,
                ),
              ),
            ],
            if (report.orderedMedia.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: ArticleMediaCarousel(article: report),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ActionItem(
                    icon: Icons.thumb_up_alt_outlined,
                    count: report.likes.toString()),
                _ActionItem(
                    icon: Icons.comment_outlined,
                    count: report.comments.toString()),
                _ActionItem(
                    icon: Icons.share_outlined,
                    count: report.shares.toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String count;

  const _ActionItem({required this.icon, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(count,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
      ],
    );
  }
}
