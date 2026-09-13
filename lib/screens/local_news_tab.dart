import 'dart:ui' as dart_ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/navigation/auth_guard.dart';
import '../core/navigation/app_navigator.dart';
import '../core/network/api_response.dart';
import '../models/ad_banner.dart';
import '../models/news_article.dart';
import '../repositories/ugc_repository.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ads/unified_ad_widget.dart';
import 'create_post_screen.dart';
import 'location_selection_screen.dart';
import 'news_detail_screen.dart';
import 'search_screen.dart';
import 'ugc_feed_screen.dart';

class LocalNewsTab extends StatefulWidget {
  const LocalNewsTab({super.key});

  @override
  State<LocalNewsTab> createState() => _LocalNewsTabState();
}

class _LocalNewsTabState extends State<LocalNewsTab> {
  late String _location;
  bool _isLoadingInitial = true;
  bool _isDetectingLocation = false;
  List<AdBanner> _localAds = [];

  // Per-section article lists and pagination state
  List<NewsArticle> _villageArticles = [];
  String? _villageCursor;
  bool _villageHasMore = false;
  bool _isLoadingMoreVillage = false;

  List<NewsArticle> _mandalArticles = [];
  String? _mandalCursor;
  bool _mandalHasMore = false;
  bool _isLoadingMoreMandal = false;

  List<NewsArticle> _districtArticles = [];
  String? _districtCursor;
  bool _districtHasMore = false;
  bool _isLoadingMoreDistrict = false;

  List<NewsArticle> _stateArticles = [];
  List<NewsArticle> _globalArticles = [];
  String? _stateCursor;
  bool _stateHasMore = false;
  bool _isLoadingMoreState = false;

  String? _globalError;
  int _loadGeneration = 0;
  String get _feedLang => AppState.instance.contentLanguage;

  @override
  void initState() {
    super.initState();
    _location = AppState.instance.displayLocation;
    _loadAds();
    _loadAllSections();
  }

  Future<void> _loadAds() async {
    final locationKey = _currentLocationKey;
    try {
      final res = await ApiService.instance.getAds(
        zone: 'feed',
        scope: 'local',
        state: AppState.instance.stateName,
        district: AppState.instance.district,
        city: AppState.instance.city,
        lang: _feedLang,
      );
      if (mounted && locationKey == _currentLocationKey) {
        setState(() => _localAds = res.data ?? <AdBanner>[]);
      }
    } catch (_) {}
  }

  Future<void> _loadAllSections({bool clearExisting = false}) async {
    final generation = ++_loadGeneration;
    setState(() {
      _isLoadingInitial = true;
      _globalError = null;
      if (clearExisting) {
        _villageArticles = [];
        _mandalArticles = [];
        _districtArticles = [];
        _stateArticles = [];
        _globalArticles = [];
        _villageCursor = null;
        _mandalCursor = null;
        _districtCursor = null;
        _stateCursor = null;
        _villageHasMore = false;
        _mandalHasMore = false;
        _districtHasMore = false;
        _stateHasMore = false;
        _isLoadingMoreVillage = false;
        _isLoadingMoreMandal = false;
        _isLoadingMoreDistrict = false;
        _isLoadingMoreState = false;
      }
    });

    final state = AppState.instance.stateName;
    final district = AppState.instance.district;
    final subdistrict = AppState.instance.subdistrict;
    final village = AppState.instance.village;

    try {
      // 1. Village Tier (scope=local, village + subdistrict + district + state)
      final Future<ApiResponse<List<NewsArticle>>?> villageFuture =
          village.isNotEmpty
              ? ApiService.instance.getNewsFeed(
                  scope: 'local',
                  lang: _feedLang,
                  state: state,
                  district: district,
                  subdistrict: subdistrict.isNotEmpty ? subdistrict : null,
                  village: village,
                  pageSize: 10,
                  forceRefresh: true,
                )
              : Future<ApiResponse<List<NewsArticle>>?>.value(null);

      final Future<ApiResponse<List<NewsArticle>>?> villageUgcFuture =
          village.isNotEmpty
              ? UgcRepository.instance.getUgcFeed(
                  scope: 'local',
                  state: state,
                  district: district,
                  subdistrict: subdistrict.isNotEmpty ? subdistrict : null,
                  village: village,
                  pageSize: 10,
                )
              : Future<ApiResponse<List<NewsArticle>>?>.value(null);

      // 2. Mandal Tier (scope=local, subdistrict + district + state, NO village)
      final Future<ApiResponse<List<NewsArticle>>?> mandalFuture =
          subdistrict.isNotEmpty
              ? ApiService.instance.getNewsFeed(
                  scope: 'local',
                  lang: _feedLang,
                  state: state,
                  district: district,
                  subdistrict: subdistrict,
                  village: '',
                  pageSize: 10,
                  forceRefresh: true,
                )
              : Future<ApiResponse<List<NewsArticle>>?>.value(null);

      final Future<ApiResponse<List<NewsArticle>>?> mandalUgcFuture =
          subdistrict.isNotEmpty
              ? UgcRepository.instance.getUgcFeed(
                  scope: 'local',
                  state: state,
                  district: district,
                  subdistrict: subdistrict,
                  pageSize: 10,
                )
              : Future<ApiResponse<List<NewsArticle>>?>.value(null);

      // 3. District Tier (scope=main, district + state, NO mandal/village)
      final Future<ApiResponse<List<NewsArticle>>?> districtFuture =
          district.isNotEmpty
              ? ApiService.instance.getNewsFeed(
                  scope: 'main',
                  lang: _feedLang,
                  state: state,
                  district: district,
                  subdistrict: '',
                  village: '',
                  pageSize: 10,
                  forceRefresh: true,
                )
              : Future<ApiResponse<List<NewsArticle>>?>.value(null);

      final Future<ApiResponse<List<NewsArticle>>?> districtUgcFuture =
          district.isNotEmpty
              ? UgcRepository.instance.getUgcFeed(
                  scope: 'main',
                  state: state,
                  district: district,
                  pageSize: 10,
                )
              : Future<ApiResponse<List<NewsArticle>>?>.value(null);

      // 4. State / Global Fallback (scope=main, state, NO district/mandal/village)
      final stateFuture = ApiService.instance.getNewsFeed(
        scope: 'main',
        lang: _feedLang,
        state: state.isNotEmpty ? state : null,
        district: '',
        subdistrict: '',
        village: '',
        pageSize: 10,
        forceRefresh: true,
      );

      final Future<ApiResponse<List<NewsArticle>>?> stateUgcFuture =
          state.isNotEmpty
              ? UgcRepository.instance.getUgcFeed(
                  scope: 'main',
                  state: state,
                  pageSize: 10,
                )
              : Future<ApiResponse<List<NewsArticle>>?>.value(null);

      final results = await Future.wait<ApiResponse<List<NewsArticle>>?>([
        _settleFeed(villageFuture),
        _settleFeed(villageUgcFuture),
        _settleFeed(mandalFuture),
        _settleFeed(mandalUgcFuture),
        _settleFeed(districtFuture),
        _settleFeed(districtUgcFuture),
        _settleFeed(stateFuture),
        _settleFeed(stateUgcFuture),
      ]);

      if (!mounted || generation != _loadGeneration) return;

      final villageRes = results[0];
      final villageUgcRes = results[1];
      final mandalRes = results[2];
      final mandalUgcRes = results[3];
      final districtRes = results[4];
      final districtUgcRes = results[5];
      final stateRes = results[6];
      final stateUgcRes = results[7];
      final hasSuccessfulResponse = results.any(
        (response) => response != null && !response.hasErrors,
      );

      final villageNews = _articlesFrom(villageRes).where(
        (article) =>
            _isVillageArticle(article, state, district, subdistrict, village),
      );
      final villageUgc = _articlesFrom(villageUgcRes).where(
        (article) =>
            _matchesVillage(article, state, district, subdistrict, village),
      );
      final mergedVillage = _mergeAndSort(villageNews, villageUgc);

      final mandalNews = _articlesFrom(mandalRes).where(
        (article) => _isMandalArticle(article, state, district, subdistrict),
      );
      final mandalUgc = _articlesFrom(mandalUgcRes).where(
        (article) => _matchesMandal(article, state, district, subdistrict),
      );
      final mergedMandal = _deduplicateAgainst(
        _mergeAndSort(mandalNews, mandalUgc),
        mergedVillage,
      );

      final districtNews = _articlesFrom(districtRes).where(
        (article) =>
            _isCoverage(article, 'district') &&
            _same(article.district, district),
      );
      final districtUgc = _articlesFrom(districtUgcRes).where(
        (article) =>
            _same(article.state, state) && _same(article.district, district),
      );
      final mergedDistrict = _deduplicateAgainst(
        _mergeAndSort(districtNews, districtUgc),
        [...mergedVillage, ...mergedMandal],
      );

      final stateNews = _articlesFrom(stateRes).where(
        (article) =>
            _isCoverage(article, 'state') && _same(article.state, state),
      );
      final stateUgc = _articlesFrom(stateUgcRes).where(
        (article) => _same(article.state, state) && !_hasText(article.district),
      );
      final mergedState = _deduplicateAgainst(
        _mergeAndSort(stateNews, stateUgc),
        [...mergedVillage, ...mergedMandal, ...mergedDistrict],
      );
      final mergedGlobal = _deduplicateAgainst(
        _articlesFrom(stateRes)
            .where((article) => _isCoverage(article, 'global')),
        [...mergedVillage, ...mergedMandal, ...mergedDistrict, ...mergedState],
      );

      setState(() {
        _villageArticles = mergedVillage;
        _villageCursor = villageRes?.nextCursor;
        _villageHasMore = _villageCursor != null && _villageCursor!.isNotEmpty;

        _mandalArticles = mergedMandal;
        _mandalCursor = mandalRes?.nextCursor;
        _mandalHasMore = _mandalCursor != null && _mandalCursor!.isNotEmpty;

        _districtArticles = mergedDistrict;
        _districtCursor = districtRes?.nextCursor;
        _districtHasMore =
            _districtCursor != null && _districtCursor!.isNotEmpty;

        _stateArticles = mergedState;
        _globalArticles = mergedGlobal;
        _stateCursor = stateRes?.nextCursor;
        _stateHasMore = _stateCursor != null && _stateCursor!.isNotEmpty;

        _isLoadingInitial = false;
        _globalError = hasSuccessfulResponse
            ? null
            : 'Unable to load news for this location. Please try again.';
      });
    } catch (e) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _isLoadingInitial = false;
          _globalError =
              'వార్తలు లోడ్ చేయడం విఫలమైంది. దయచేసి మళ్ళీ ప్రయత్నించండి.';
        });
      }
    }
  }

  // --- Per-Section Pagination ---

  Future<void> _loadMoreVillage() async {
    if (_isLoadingMoreVillage || !_villageHasMore || _villageCursor == null) {
      return;
    }
    final locationKey = _currentLocationKey;
    setState(() => _isLoadingMoreVillage = true);

    try {
      final res = await ApiService.instance.getNewsFeed(
        cursor: _villageCursor,
        scope: 'local',
        lang: _feedLang,
        state: AppState.instance.stateName,
        district: AppState.instance.district,
        subdistrict: AppState.instance.subdistrict.isNotEmpty
            ? AppState.instance.subdistrict
            : null,
        village: AppState.instance.village,
        pageSize: 10,
      );

      if (!mounted || locationKey != _currentLocationKey) return;
      final newItems = (res.data ?? <NewsArticle>[]).where(
        (article) => _isVillageArticle(
          article,
          AppState.instance.stateName,
          AppState.instance.district,
          AppState.instance.subdistrict,
          AppState.instance.village,
        ),
      );
      final existingIds = _villageArticles.map((a) => a.id).toSet();
      final fresh = newItems.where((a) => !existingIds.contains(a.id)).toList();

      setState(() {
        _villageArticles.addAll(fresh);
        _villageCursor = res.nextCursor;
        _villageHasMore = res.nextCursor != null && res.nextCursor!.isNotEmpty;
        _isLoadingMoreVillage = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMoreVillage = false);
    }
  }

  Future<void> _loadMoreMandal() async {
    if (_isLoadingMoreMandal || !_mandalHasMore || _mandalCursor == null) {
      return;
    }
    final locationKey = _currentLocationKey;
    setState(() => _isLoadingMoreMandal = true);

    try {
      final res = await ApiService.instance.getNewsFeed(
        cursor: _mandalCursor,
        scope: 'local',
        lang: _feedLang,
        state: AppState.instance.stateName,
        district: AppState.instance.district,
        subdistrict: AppState.instance.subdistrict,
        village: '',
        pageSize: 10,
      );

      if (!mounted || locationKey != _currentLocationKey) return;
      final newItems = (res.data ?? <NewsArticle>[]).where(
        (article) => _isMandalArticle(
          article,
          AppState.instance.stateName,
          AppState.instance.district,
          AppState.instance.subdistrict,
        ),
      );
      final existingIds = {
        ..._villageArticles.map((a) => a.id),
        ..._mandalArticles.map((a) => a.id),
      };
      final fresh = newItems.where((a) => !existingIds.contains(a.id)).toList();

      setState(() {
        _mandalArticles.addAll(fresh);
        _mandalCursor = res.nextCursor;
        _mandalHasMore = res.nextCursor != null && res.nextCursor!.isNotEmpty;
        _isLoadingMoreMandal = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMoreMandal = false);
    }
  }

  Future<void> _loadMoreDistrict() async {
    if (_isLoadingMoreDistrict ||
        !_districtHasMore ||
        _districtCursor == null) {
      return;
    }
    final locationKey = _currentLocationKey;
    setState(() => _isLoadingMoreDistrict = true);

    try {
      final res = await ApiService.instance.getNewsFeed(
        cursor: _districtCursor,
        scope: 'main',
        lang: _feedLang,
        state: AppState.instance.stateName,
        district: AppState.instance.district,
        subdistrict: '',
        village: '',
        pageSize: 10,
      );

      if (!mounted || locationKey != _currentLocationKey) return;
      final newItems = (res.data ?? <NewsArticle>[]).where(
        (article) =>
            _isCoverage(article, 'district') &&
            _same(article.district, AppState.instance.district),
      );
      final existingIds = {
        ..._villageArticles.map((a) => a.id),
        ..._mandalArticles.map((a) => a.id),
        ..._districtArticles.map((a) => a.id),
      };
      final fresh = newItems.where((a) => !existingIds.contains(a.id)).toList();

      setState(() {
        _districtArticles.addAll(fresh);
        _districtCursor = res.nextCursor;
        _districtHasMore = res.nextCursor != null && res.nextCursor!.isNotEmpty;
        _isLoadingMoreDistrict = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMoreDistrict = false);
    }
  }

  Future<void> _loadMoreState() async {
    if (_isLoadingMoreState || !_stateHasMore || _stateCursor == null) return;
    final locationKey = _currentLocationKey;
    setState(() => _isLoadingMoreState = true);

    try {
      final res = await ApiService.instance.getNewsFeed(
        cursor: _stateCursor,
        scope: 'main',
        lang: _feedLang,
        state: AppState.instance.stateName.isNotEmpty
            ? AppState.instance.stateName
            : null,
        district: '',
        subdistrict: '',
        village: '',
        pageSize: 10,
      );

      if (!mounted || locationKey != _currentLocationKey) return;
      final newItems = res.data ?? <NewsArticle>[];
      final existingIds = {
        ..._villageArticles.map((a) => a.id),
        ..._mandalArticles.map((a) => a.id),
        ..._districtArticles.map((a) => a.id),
        ..._stateArticles.map((a) => a.id),
        ..._globalArticles.map((a) => a.id),
      };
      final freshState = newItems
          .where(
            (article) =>
                _isCoverage(article, 'state') &&
                _same(article.state, AppState.instance.stateName) &&
                !existingIds.contains(article.id),
          )
          .toList();
      final freshGlobal = newItems
          .where(
            (article) =>
                _isCoverage(article, 'global') &&
                !existingIds.contains(article.id),
          )
          .toList();

      setState(() {
        _stateArticles.addAll(freshState);
        _globalArticles.addAll(freshGlobal);
        _stateCursor = res.nextCursor;
        _stateHasMore = res.nextCursor != null && res.nextCursor!.isNotEmpty;
        _isLoadingMoreState = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMoreState = false);
    }
  }

  // --- Helper Methods ---

  Future<ApiResponse<List<NewsArticle>>?> _settleFeed(
    Future<ApiResponse<List<NewsArticle>>?> request,
  ) async {
    try {
      return await request;
    } catch (_) {
      return null;
    }
  }

  String get _currentLocationKey => [
        AppState.instance.stateName,
        AppState.instance.district,
        AppState.instance.subdistrict,
        AppState.instance.village,
      ].join('|').toLowerCase();

  List<NewsArticle> _articlesFrom(ApiResponse<List<NewsArticle>>? response) {
    return response?.data ?? <NewsArticle>[];
  }

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

  bool _same(String? actual, String expected) {
    if (!_hasText(actual) || expected.trim().isEmpty) return false;
    return actual!.trim().toLowerCase() == expected.trim().toLowerCase();
  }

  bool _isCoverage(NewsArticle article, String coverage) {
    return article.coverageLevel.trim().toLowerCase() == coverage;
  }

  bool _matchesVillage(
    NewsArticle article,
    String state,
    String district,
    String subdistrict,
    String village,
  ) {
    return village.isNotEmpty &&
        _same(article.state, state) &&
        _same(article.district, district) &&
        (subdistrict.isEmpty || _same(article.subdistrict, subdistrict)) &&
        _same(article.village, village);
  }

  bool _isVillageArticle(
    NewsArticle article,
    String state,
    String district,
    String subdistrict,
    String village,
  ) {
    return _isCoverage(article, 'local') &&
        _matchesVillage(article, state, district, subdistrict, village);
  }

  bool _matchesMandal(
    NewsArticle article,
    String state,
    String district,
    String subdistrict,
  ) {
    return subdistrict.isNotEmpty &&
        _same(article.state, state) &&
        _same(article.district, district) &&
        _same(article.subdistrict, subdistrict);
  }

  bool _isMandalArticle(
    NewsArticle article,
    String state,
    String district,
    String subdistrict,
  ) {
    return _isCoverage(article, 'local') &&
        _matchesMandal(article, state, district, subdistrict);
  }

  List<NewsArticle> _mergeAndSort(
    Iterable<NewsArticle> primary,
    Iterable<NewsArticle> secondary,
  ) {
    final seen = <String>{};
    final merged = <NewsArticle>[];
    for (final a in [...primary, ...secondary]) {
      if (seen.add(a.id)) merged.add(a);
    }
    merged.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return merged;
  }

  List<NewsArticle> _deduplicateAgainst(
    Iterable<NewsArticle> source,
    Iterable<NewsArticle> exclude,
  ) {
    final excludeIds = exclude.map((a) => a.id).toSet();
    return source.where((a) => !excludeIds.contains(a.id)).toList();
  }

  Future<void> _refresh() async {
    await Future.wait([
      _loadAds(),
      _loadAllSections(),
    ]);
  }

  Future<void> _detectLocation() async {
    final consent = await LocationService.showPrivacyDisclosure(context);
    if (!consent) return;

    setState(() => _isDetectingLocation = true);

    try {
      final deviceLocation = await LocationService.detectLocation();
      final match =
          await ApiService.instance.resolveCanonicalLocation(deviceLocation);
      if (!mounted) return;
      final confirmed = await LocationService.showCanonicalConfirmation(
        context,
        match,
      );
      if (!mounted) return;
      if (!confirmed) {
        await _changeLocation();
        return;
      }
      await ApiService.instance.applyCanonicalLocation(match);
      if (mounted) {
        setState(() {
          _location = AppState.instance.displayLocation;
        });
        await _loadAds();
        await _loadAllSections(clearExisting: true);
      }
    } on LocationException catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(exception.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('లొకేషన్ పొందడంలో సమస్య ఏర్పడింది: $e')));
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
      await _loadAds();
      await _loadAllSections(clearExisting: true);
    }
  }

  // --- UI Components ---

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
            color: isDark
                ? Colors.black.withValues(alpha: 0.75)
                : Colors.white.withValues(alpha: 0.85),
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05),
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
              const SizedBox(width: 8),

              // Refined Location Chip
              Expanded(
                child: GestureDetector(
                  onTap: _changeLocation,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_rounded,
                            color: AppColors.primary, size: 15),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            _location,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color:
                                  Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            color: AppColors.primary, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // GPS Button
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                icon: _isDetectingLocation
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      )
                    : const Icon(Icons.my_location_rounded,
                        size: 20, color: AppColors.primary),
                tooltip: 'Detect current location via GPS',
                onPressed: _isDetectingLocation ? null : _detectLocation,
              ),

              // Citizen Feed / UGC Button
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const UgcFeedScreen())),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.record_voice_over_rounded,
                          color: Colors.amber, size: 14),
                      SizedBox(width: 4),
                      Text('సిటిజెన్',
                          style: TextStyle(
                              color: Colors.amber,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),

              // Search Button
              IconButton(
                padding: const EdgeInsets.only(left: 4),
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                icon: Icon(Icons.search_rounded,
                    color: Theme.of(context).iconTheme.color, size: 22),
                tooltip: 'Search news',
                onPressed: () {
                  AppNavigator.pushSafe(
                    context,
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String teluguTitle,
    required String englishTitle,
    required String locationTag,
    IconData icon = Icons.location_city_rounded,
    Color accentColor = AppColors.primary,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      teluguTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        locationTag,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  englishTitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionEmptyCard({
    required String message,
    required String ctaText,
    required VoidCallback onCta,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 28, color: AppColors.primary.withValues(alpha: 0.7)),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, height: 1.3),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onCta,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 15),
            label: Text(ctaText,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreButton({
    required String title,
    required bool isLoading,
    required VoidCallback onLoadMore,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: OutlinedButton(
        onPressed: isLoading ? null : onLoadMore,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 11),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'ఇంకా చూడండి ($title)',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_downward_rounded,
                      size: 16, color: AppColors.primary),
                ],
              ),
      ),
    );
  }

  String _locationLabelFor(NewsArticle article) {
    if (_isCoverage(article, 'global')) return 'India / Global';
    if (_isCoverage(article, 'state')) {
      return _hasText(article.state)
          ? article.state!.trim()
          : AppState.instance.stateName;
    }
    if (_isCoverage(article, 'district')) {
      final district = _hasText(article.district)
          ? article.district!.trim()
          : AppState.instance.district;
      return district.isEmpty ? 'District' : '$district District';
    }
    if (_hasText(article.village)) return article.village!.trim();
    if (_hasText(article.subdistrict)) return article.subdistrict!.trim();
    if (_hasText(article.district)) {
      return '${article.district!.trim()} District';
    }
    return 'Local';
  }

  Widget _buildArticleCard(
      NewsArticle article, Color cardColor, Color borderColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            AppNavigator.pushSafe(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      NewsDetailScreen(article: article, slug: article.slug)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 95,
                    height: 85,
                    color: Colors.grey.withValues(alpha: 0.1),
                    child: article.imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: article.imageUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 300,
                            memCacheHeight: 300,
                            placeholder: (_, __) => Container(
                                color: Colors.grey.withValues(alpha: 0.1)),
                            errorWidget: (_, __, ___) => const Icon(
                                Icons.broken_image_rounded,
                                size: 28,
                                color: Colors.grey),
                          )
                        : const Icon(Icons.article_rounded,
                            size: 32, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: article.category.toUpperCase() == 'UGC'
                                  ? Colors.amber.withValues(alpha: 0.15)
                                  : AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              article.category.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: article.category.toUpperCase() == 'UGC'
                                    ? Colors.amber[800]
                                    : AppColors.primary,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            article.timeAgo,
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        article.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 12,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              _locationLabelFor(article),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.favorite_rounded,
                              size: 12,
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color),
                          const SizedBox(width: 4),
                          Text(
                            '${article.likes}',
                            style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlobalEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
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
              child: const Icon(Icons.location_off_rounded,
                  size: 34, color: AppColors.primary),
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
              'No local news available for your area yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
            if (_globalError != null) ...[
              const SizedBox(height: 12),
              Text(
                _globalError!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.error),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _refresh,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('మళ్లీ ప్రయత్నించండి'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _changeLocation,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('ప్రాంతం మార్చండి'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.03);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.06);

    final selectedVillage = AppState.instance.village;
    final selectedSubdistrict = AppState.instance.subdistrict;
    final selectedDistrict = AppState.instance.district;
    final selectedState = AppState.instance.stateName;

    final hasAnyContent = _villageArticles.isNotEmpty ||
        _mandalArticles.isNotEmpty ||
        _districtArticles.isNotEmpty ||
        _stateArticles.isNotEmpty ||
        _globalArticles.isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          _isLoadingInitial && !hasAnyContent
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : RefreshIndicator(
                  onRefresh: _refresh,
                  color: AppColors.primary,
                  child: !hasAnyContent && !_isLoadingInitial
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.only(
                            top: MediaQuery.of(context).padding.top + 70,
                            bottom: 120,
                          ),
                          child: _buildGlobalEmptyState(),
                        )
                      : CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverPadding(
                              padding: EdgeInsets.only(
                                top: MediaQuery.of(context).padding.top + 70,
                                bottom: 120,
                              ),
                              sliver: SliverList(
                                delegate: SliverChildListDelegate([
                                  // --- 1. Village Tier Section ---
                                  if (selectedVillage.isNotEmpty) ...[
                                    _buildSectionHeader(
                                      teluguTitle: 'గ్రామ వార్తలు',
                                      englishTitle:
                                          'గ్రామ ముఖ్యాంశాలు & నివేదికలు',
                                      locationTag: selectedVillage,
                                      icon: Icons.holiday_village_rounded,
                                      accentColor: AppColors.primary,
                                    ),
                                    if (_villageArticles.isNotEmpty) ...[
                                      ..._villageArticles.map((a) =>
                                          _buildArticleCard(
                                              a, cardColor, borderColor)),
                                      if (_villageHasMore)
                                        _buildLoadMoreButton(
                                          title: selectedVillage,
                                          isLoading: _isLoadingMoreVillage,
                                          onLoadMore: _loadMoreVillage,
                                        ),
                                    ] else ...[
                                      _buildSectionEmptyCard(
                                        message:
                                            '$selectedVillage గ్రామంలో ప్రస్తుతానికి వార్తలు లేవు. మీరే వార్తను పోస్ట్ చేయండి!',
                                        ctaText: 'సిటిజెన్ రిపోర్ట్ రాయండి',
                                        onCta: () => requireAuth(
                                          context,
                                          () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const CreatePostScreen(),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (_localAds.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      UnifiedAdWidget(
                                          ad: _localAds[0],
                                          placementZone: 'local'),
                                      const SizedBox(height: 10),
                                    ],
                                  ],

                                  // --- 2. Mandal Tier Section ---
                                  if (selectedSubdistrict.isNotEmpty) ...[
                                    _buildSectionHeader(
                                      teluguTitle: 'మండల వార్తలు',
                                      englishTitle: 'మండల సమగ్ర సమాచారం',
                                      locationTag: selectedSubdistrict,
                                      icon: Icons.location_city_rounded,
                                      accentColor: Colors.teal,
                                    ),
                                    if (_mandalArticles.isNotEmpty) ...[
                                      ..._mandalArticles.map((a) =>
                                          _buildArticleCard(
                                              a, cardColor, borderColor)),
                                      if (_mandalHasMore)
                                        _buildLoadMoreButton(
                                          title: selectedSubdistrict,
                                          isLoading: _isLoadingMoreMandal,
                                          onLoadMore: _loadMoreMandal,
                                        ),
                                    ] else ...[
                                      _buildSectionEmptyCard(
                                        message:
                                            '$selectedSubdistrict మండలంలో ప్రస్తుతానికి కొత్త వార్తలు లేవు.',
                                        ctaText: 'వార్తను రిపోర్ట్ చేయండి',
                                        onCta: () => requireAuth(
                                          context,
                                          () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const CreatePostScreen(),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (_localAds.length > 1) ...[
                                      const SizedBox(height: 10),
                                      UnifiedAdWidget(
                                          ad: _localAds[1],
                                          placementZone: 'local'),
                                      const SizedBox(height: 10),
                                    ],
                                  ],

                                  // --- 3. District Tier Section ---
                                  if (selectedDistrict.isNotEmpty) ...[
                                    _buildSectionHeader(
                                      teluguTitle: 'జిల్లా వార్తలు',
                                      englishTitle: 'జిల్లా ముఖ్యాంశాలు',
                                      locationTag: selectedDistrict,
                                      icon: Icons.domain_rounded,
                                      accentColor: Colors.indigo,
                                    ),
                                    if (_districtArticles.isNotEmpty) ...[
                                      ..._districtArticles.map((a) =>
                                          _buildArticleCard(
                                              a, cardColor, borderColor)),
                                      if (_districtHasMore)
                                        _buildLoadMoreButton(
                                          title: '$selectedDistrict జిల్లా',
                                          isLoading: _isLoadingMoreDistrict,
                                          onLoadMore: _loadMoreDistrict,
                                        ),
                                    ] else ...[
                                      _buildSectionEmptyCard(
                                        message:
                                            '$selectedDistrict జిల్లాలో తాజా కథనాలు అందుబాటులో లేవు.',
                                        ctaText: 'మళ్ళీ రిఫ్రెష్ చేయండి',
                                        onCta: _refresh,
                                      ),
                                    ],
                                  ],

                                  // --- 4. State Tier ---
                                  if (_stateArticles.isNotEmpty) ...[
                                    _buildSectionHeader(
                                      teluguTitle: 'రాష్ట్ర ముఖ్యాంశాలు',
                                      englishTitle: 'రాష్ట్ర వార్తా సమాచారం',
                                      locationTag: selectedState,
                                      icon: Icons.map_rounded,
                                      accentColor: Colors.deepOrange,
                                    ),
                                    ..._stateArticles.map((a) =>
                                        _buildArticleCard(
                                            a, cardColor, borderColor)),
                                  ],

                                  // --- 5. Global Tier ---
                                  if (_globalArticles.isNotEmpty) ...[
                                    _buildSectionHeader(
                                      teluguTitle: 'జాతీయ వార్తలు',
                                      englishTitle:
                                          'దేశీయ & అంతర్జాతీయ వార్తలు',
                                      locationTag: 'జాతీయం / అంతర్జాతీయం',
                                      icon: Icons.public_rounded,
                                      accentColor: Colors.blueGrey,
                                    ),
                                    ..._globalArticles.map((a) =>
                                        _buildArticleCard(
                                            a, cardColor, borderColor)),
                                    if (_stateHasMore)
                                      _buildLoadMoreButton(
                                        title: 'మరిన్ని ముఖ్యాంశాలు',
                                        isLoading: _isLoadingMoreState,
                                        onLoadMore: _loadMoreState,
                                      ),
                                  ],

                                  const SizedBox(height: 24),
                                ]),
                              ),
                            ),
                          ],
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
