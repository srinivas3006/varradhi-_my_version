import 'package:flutter/material.dart';
import '../localization/app_translations.dart';
import '../theme/app_theme.dart';
import '../widgets/quick_links_row.dart';
import '../models/news_article.dart';
import '../services/api_service.dart';
import 'news_detail_screen.dart';

class LocalNewsTab extends StatefulWidget {
  const LocalNewsTab({super.key});

  @override
  State<LocalNewsTab> createState() => _LocalNewsTabState();
}

class _LocalNewsTabState extends State<LocalNewsTab> {
  String _location = 'Hyderabad, Telangana';
  bool _isLoading = true;
  final List<NewsArticle> _feed = [];
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
      category: 'local',
    );

    if (!mounted) return;
    
    setState(() {
      final newArticles = response.data ?? [];
      _feed.addAll(newArticles);
      _nextCursor = response.nextCursor;
      _hasMore = _nextCursor != null;
      _isLoading = false;
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
      _feed.clear();
      _nextCursor = null;
      _hasMore = true;
    });
    await _loadFeed();
  }

  void _changeLocation() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final options = [
          'Hyderabad, Telangana',
          'Bengaluru, Karnataka',
          'Chennai, Tamil Nadu',
          'Mumbai, Maharashtra',
          'Delhi NCR',
        ];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(tr('change_location'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              ...options.map((loc) => ListTile(
                    leading: Icon(
                      Icons.location_on,
                      color: loc == _location
                          ? AppColors.primary
                          : AppColors.textMuted,
                    ),
                    title: Text(loc),
                    onTap: () {
                      setState(() => _location = loc);
                      Navigator.pop(context);
                    },
                  )),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: GestureDetector(
              onTap: _changeLocation,
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    _location,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          const QuickLinksRow(),
          const SizedBox(height: 4),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _feed.isEmpty
                    ? Center(
                        child: Text(tr('no_stories'), style: const TextStyle(color: AppColors.textMuted)),
                      )
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: _feed.length + (_hasMore ? 1 : 0),
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (index == _feed.length) {
                              _loadFeed();
                              return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()));
                            }
                            final article = _feed[index];
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NewsDetailScreen(article: article),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            article.imageUrl,
                            width: 84,
                            height: 84,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 84,
                              height: 84,
                              color: AppColors.chipBg,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                article.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  height: 1.25,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${article.source} · ${article.timeAgo}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    ),
    );
  }
}
