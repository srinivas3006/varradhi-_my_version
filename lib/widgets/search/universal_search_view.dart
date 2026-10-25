import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ads/ad_insertion.dart';
import '../../core/navigation/notification_deep_link_resolver.dart';
import '../../core/utils/url_normalizer.dart';
import '../../models/category.dart';
import '../../models/live_news.dart';
import '../../models/news_article.dart';
import '../../models/notification_target.dart';
import '../../models/poll.dart';
import '../../models/unified_feed_item.dart';
import '../../models/video_item.dart';
import '../../screens/category_screen.dart';
import '../../screens/live_news_screen.dart';
import '../../screens/magazines_screen.dart';
import '../../screens/ugc_feed_screen.dart';
import '../../screens/news_detail_screen.dart';
import '../../screens/poll_detail_screen.dart';
import '../../screens/poster_detail_screen.dart';
import '../../screens/video_player_screen.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/article_typography.dart';
import '../ads/unified_ad_widget.dart';

bool get _telugu => AppState.instance.language == 'Telugu';

/// Section headings, in Telugu and English.
const Map<String, (String, String)> _sectionTitles = {
  'articles': ('వార్తలు', 'Articles'),
  'ugc': ('సిటిజన్ వార్తలు', 'Citizen news'),
  'live_news': ('లైవ్ న్యూస్', 'Live news'),
  'videos': ('వీడియోలు', 'Videos'),
  'posters': ('పోస్టర్లు', 'Posters'),
  'polls': ('పోల్స్', 'Polls'),
  'quotes': ('కోట్స్', 'Quotes'),
  'categories': ('విభాగాలు', 'Categories'),
  'blogs': ('బ్లాగులు', 'Blogs'),
  'epapers': ('ఈ-పేపర్లు', 'E-papers'),
  'trends': ('ట్రెండింగ్', 'Trending'),
  'recommendations': ('మీ కోసం', 'Recommended for you'),
};

String sectionTitle(String key) {
  final t = _sectionTitles[key];
  if (t == null) return key;
  return _telugu ? t.$1 : t.$2;
}

/// What a search item is called: its title, name, question, quote text or
/// trend term — whichever the section sends.
String searchItemTitle(Map<String, dynamic> item) {
  for (final k in [
    'title',
    'display_name',
    'name',
    'question',
    'text',
    'quote',
    'term',
    'keyword',
    'query',
  ]) {
    final v = item[k];
    if (v != null && v.toString().trim().isNotEmpty) {
      return v.toString().trim();
    }
  }
  return '';
}

/// The item's picture, if it has one.
String searchItemImage(Map<String, dynamic> item) {
  String norm(dynamic v) => UrlNormalizer.normalize(v?.toString());
  for (final k in ['thumbnail_url', 'image_url', 'cover_image', 'icon_url']) {
    final v = norm(item[k]);
    if (v.isNotEmpty) return v;
  }
  final urls = item['image_urls'];
  if (urls is List && urls.isNotEmpty) return norm(urls.first);
  final media = item['media_items'];
  if (media is List) {
    for (final m in media.whereType<Map>()) {
      final thumb = norm(m['thumbnail_url']);
      if (thumb.isNotEmpty) return thumb;
      final type = (m['media_type'] ?? m['type'] ?? '').toString().toLowerCase();
      final url = norm(m['url'] ?? m['media_url']);
      if (url.isNotEmpty && !type.contains('video')) return url;
    }
  }
  final yt = UrlNormalizer.extractYoutubeThumbnail(
      (item['youtube_url'] ?? item['video_url'])?.toString());
  return yt ?? '';
}

/// Opens a search item where its section belongs (search handover), using
/// the id / slug / url / deep link the backend returned — never one made
/// up from the title. [onSearchTerm] runs a new search (trends).
Future<void> openSearchItem(
  BuildContext context,
  String section,
  Map<String, dynamic> item, {
  required void Function(String term) onSearchTerm,
}) async {
  void push(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  switch (section) {
    case 'articles':
    case 'recommendations':
      push(NewsDetailScreen(article: NewsArticle.fromJson(item)));
      return;
    case 'ugc':
      // The same item shape as the citizen-news feed.
      push(NewsDetailScreen(
          article: UnifiedFeedItem.fromJson({...item, 'type': 'ugc'})
              .toArticle()));
      return;
    case 'polls':
      push(PollDetailScreen(poll: Poll.fromJson(item)));
      return;
    case 'posters':
      push(PosterDetailScreen(poster: item));
      return;
    case 'categories':
      final c = Category.fromJson(item);
      if (c.slug.isEmpty) break;
      push(CategoryScreen(categorySlug: c.slug, categoryName: c.localizedName));
      return;
    case 'videos':
      final v = VideoItem.fromJson(item);
      final url = (v.videoUrl?.isNotEmpty ?? false)
          ? v.videoUrl!
          : (v.youtubeUrl ?? '');
      if (url.isEmpty) break;
      push(VideoPlayerScreen(
          videoUrl: url, title: v.title, thumbnailUrl: v.thumbnailUrl));
      return;
    case 'live_news':
      final live = LiveNews.fromJson(item);
      if (live.youtubeUrl.isEmpty) break;
      push(VideoPlayerScreen(
          videoUrl: live.youtubeUrl,
          title: live.title,
          thumbnailUrl: live.thumbnailUrl));
      return;
    case 'trends':
      final term = searchItemTitle(item);
      if (term.isNotEmpty) onSearchTerm(term);
      return;
    case 'quotes':
      _showQuote(context, item);
      return;
  }
  // Blogs, e-papers, and anything the cases above could not open: the
  // item's own deep link or web address.
  await _openLinked(context, item);
}

Future<void> _openLinked(BuildContext context, Map<String, dynamic> item) async {
  final deepLink = item['deep_link']?.toString() ?? '';
  if (deepLink.isNotEmpty) {
    final target = NotificationDeepLinkResolver.resolveFromUri(deepLink);
    if (target.type != NotificationTargetType.unknown) {
      await NotificationService.instance
          .navigateToTarget(target, context: context);
      return;
    }
  }
  for (final k in ['pdf_url', 'file_url', 'url', 'web_url', 'share_url']) {
    final url = UrlNormalizer.normalize(item[k]?.toString());
    if (url.isEmpty) continue;
    final uri = Uri.tryParse(url);
    if (uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return;
    }
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(_telugu
          ? 'ఈ అంశాన్ని తెరవలేకపోయాం'
          : 'This item could not be opened'),
      behavior: SnackBarBehavior.floating,
    ));
}

void _showQuote(BuildContext context, Map<String, dynamic> item) {
  final text = searchItemTitle(item);
  final author = (item['author'] ?? item['author_name'] ?? '').toString();
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.format_quote_rounded,
                size: 36, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(text,
                style: ArticleTypography.heading(
                  fontSize: 18,
                  height: 1.5,
                  color: Theme.of(ctx).brightness == Brightness.dark
                      ? AppColors.textLight
                      : AppColors.textDark,
                )),
            if (author.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('— $author',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: AppColors.textMuted)),
            ],
          ],
        ),
      ),
    ),
  );
}

/// The universal search screen body: one block per non-empty section, in
/// the backend's recommended order. Articles are a list (with the search
/// ads, as before); the other sections are horizontal rows.
class UniversalSearchResults extends StatelessWidget {
  const UniversalSearchResults({
    super.key,
    required this.result,
    required this.query,
    required this.presentedArticles,
    required this.onSearchTerm,
  });

  final SearchResult result;
  final String query;

  /// `sections.articles` with the search ads placed between them.
  final List<FeedPresentationItem<NewsArticle>> presentedArticles;
  final void Function(String term) onSearchTerm;

  static const articlePreview = 5;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final children = <Widget>[];

    if (result.noDirectResults) {
      children.add(_NoDirectResults(
          suggestions: result.suggestions, onSearchTerm: onSearchTerm));
    }

    final keys = [
      ...result.orderedSections,
    ];
    // `sections` without an `articles` key: the legacy results stand in.
    if (!result.sectionKeys.contains('articles') &&
        result.results.isNotEmpty) {
      keys.insert(0, 'articles');
    }
    for (final key in keys) {
      final items = key == 'articles' && !result.sectionKeys.contains('articles')
          ? const <Map<String, dynamic>>[]
          : result.section(key);
      if (key == 'articles') {
        final shown = presentedArticles.take(articlePreview + 1).toList();
        final all = result.articles;
        children.add(_SectionHeader(
          title: sectionTitle(key),
          count: result.resultCount > 0 ? result.resultCount : items.length,
          onSeeAll: all.length > articlePreview
              ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SearchAllArticlesScreen(
                          query: query, articles: all)))
              : null,
        ));
        for (final entry in shown) {
          if (entry.isAd) {
            children.add(UnifiedAdWidget(
              ad: entry.ad!,
              placementZone: 'search',
              exposureKey: entry.stableKey,
            ));
          } else {
            children.add(SearchArticleTile(article: entry.content!));
          }
          children.add(Divider(
              height: 16,
              color: isDark ? AppColors.borderDark : AppColors.borderLight));
        }
        continue;
      }
      // Recommendations never add to the result count. A full section may
      // hold more than it shows: "See all" opens that content's own screen.
      final seeAll = items.length >= SearchResult.sectionLimit
          ? seeAllScreenFor(key)
          : null;
      children.add(_SectionHeader(
        title: sectionTitle(key),
        count: key == 'recommendations' ? null : items.length,
        onSeeAll: seeAll == null
            ? null
            : () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => seeAll)),
      ));
      children.add(_SectionRow(
          section: key, items: items, onSearchTerm: onSearchTerm));
      children.add(const SizedBox(height: 12));
    }

    return ListView(
      key: const ValueKey('universal_search_results'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: children,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.count, this.onSeeAll});

  final String title;
  final int? count;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              count == null ? title : '$title ($count)',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: isDark ? AppColors.textLight : AppColors.textDark,
              ),
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: Text(_telugu ? 'అన్నీ చూడండి' : 'See all'),
            ),
        ],
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.section,
    required this.items,
    required this.onSearchTerm,
  });

  final String section;
  final List<Map<String, dynamic>> items;
  final void Function(String term) onSearchTerm;

  @override
  Widget build(BuildContext context) {
    // Trends and categories are words, not stories: chips.
    if (section == 'trends' || section == 'categories') {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in items)
            ActionChip(
              label: Text(section == 'categories'
                  ? Category.fromJson(item).localizedName
                  : searchItemTitle(item)),
              avatar: Icon(
                  section == 'trends'
                      ? Icons.trending_up_rounded
                      : Icons.category_outlined,
                  size: 16),
              onPressed: () => openSearchItem(context, section, item,
                  onSearchTerm: onSearchTerm),
            ),
        ],
      );
    }
    return SizedBox(
      height: 196,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) => _SearchCard(
          section: section,
          item: items[i],
          onTap: () => openSearchItem(context, section, items[i],
              onSearchTerm: onSearchTerm),
        ),
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard(
      {required this.section, required this.item, required this.onTap});

  final String section;
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  static const _icons = {
    'ugc': Icons.campaign_outlined,
    'live_news': Icons.live_tv_rounded,
    'videos': Icons.play_circle_outline_rounded,
    'posters': Icons.image_outlined,
    'polls': Icons.how_to_vote_outlined,
    'quotes': Icons.format_quote_rounded,
    'blogs': Icons.article_outlined,
    'epapers': Icons.picture_as_pdf_outlined,
    'recommendations': Icons.newspaper_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final image = searchItemImage(item);
    final title = searchItemTitle(item);
    final placeholder = Container(
      color: isDark ? AppColors.surfaceElevatedDark : AppColors.chipBg,
      child: Icon(_icons[section] ?? Icons.search_rounded,
          color: isDark ? Colors.white38 : AppColors.textMuted, size: 28),
    );
    return SizedBox(
      width: 150,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 150,
                height: 100,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (image.isEmpty)
                      placeholder
                    else
                      CachedNetworkImage(
                        imageUrl: image,
                        memCacheWidth: 320,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => placeholder,
                        errorWidget: (_, __, ___) => placeholder,
                      ),
                    if (section == 'videos' || section == 'live_news')
                      const Center(
                        child: Icon(Icons.play_circle_fill_rounded,
                            color: Colors.white, size: 34),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: ArticleTypography.heading(
                fontSize: 13,
                height: 1.3,
                color: isDark ? AppColors.textLight : AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoDirectResults extends StatelessWidget {
  const _NoDirectResults(
      {required this.suggestions, required this.onSearchTerm});

  final List<String> suggestions;
  final void Function(String term) onSearchTerm;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.textSecondaryDark : AppColors.textMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded,
              size: 48, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 8),
          Text(
            _telugu ? 'నేరుగా సరిపోలే ఫలితాలు లేవు' : 'No direct matches',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: isDark ? AppColors.textLight : AppColors.textDark),
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_telugu ? 'ఇవి ప్రయత్నించండి' : 'Try these',
                style: TextStyle(color: muted, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in suggestions)
                  ActionChip(
                    key: ValueKey('search_suggestion_$s'),
                    avatar: const Icon(Icons.search_rounded, size: 16),
                    label: Text(s),
                    onPressed: () => onSearchTerm(s),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One article row in search results.
class SearchArticleTile extends StatelessWidget {
  const SearchArticleTile({super.key, required this.article});

  final NewsArticle article;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final box = Container(
      width: 60,
      height: 60,
      color: isDark ? AppColors.surfaceElevatedDark : Colors.black12,
      child: Icon(Icons.newspaper_rounded,
          size: 20, color: isDark ? Colors.white38 : Colors.black26),
    );
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
                placeholder: (_, __) => box,
                errorWidget: (_, __, ___) => box,
              )
            : box,
      ),
      title: Text(
        article.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: ArticleTypography.heading(
          fontSize: 14.5,
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
        MaterialPageRoute(builder: (_) => NewsDetailScreen(article: article)),
      ),
    );
  }
}

/// The screen a full section's "See all" opens: that content's own feed.
/// Null where the app has none (the row then has no "See all").
Widget? seeAllScreenFor(String section) {
  switch (section) {
    case 'ugc':
      return const UgcFeedScreen();
    case 'live_news':
      return const LiveNewsScreen();
    case 'epapers':
      return const MagazinesScreen();
  }
  return null;
}

/// "See all" for articles: every article the search returned, in one list.
/// The search API has no pagination, so nothing more is requested.
class SearchAllArticlesScreen extends StatelessWidget {
  const SearchAllArticlesScreen(
      {super.key, required this.query, required this.articles});

  final String query;
  final List<NewsArticle> articles;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: Text('${sectionTitle('articles')}: $query')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: articles.length,
        separatorBuilder: (_, __) => Divider(
            height: 16,
            color: isDark ? AppColors.borderDark : AppColors.borderLight),
        itemBuilder: (context, i) => SearchArticleTile(article: articles[i]),
      ),
    );
  }
}

/// The message for a failed search (search handover wording).
String searchErrorMessage(SearchErrorKind kind) {
  switch (kind) {
    case SearchErrorKind.invalidQuery:
      return _telugu
          ? 'దయచేసి సరైన శోధన పదాన్ని నమోదు చేయండి.'
          : 'Please enter a valid search term.';
    case SearchErrorKind.forbidden:
      return _telugu
          ? 'ఈ కంటెంట్‌ను చూడటానికి మీకు అనుమతి లేదు.'
          : "You don't have permission to access this content.";
    case SearchErrorKind.rateLimited:
      return _telugu
          ? 'చాలా ఎక్కువ శోధనలు. కాసేపు ఆగి మళ్లీ ప్రయత్నించండి.'
          : 'Too many searches. Please wait and try again.';
    case SearchErrorKind.unavailable:
      return _telugu
          ? 'శోధన తాత్కాలికంగా అందుబాటులో లేదు. దయచేసి మళ్లీ ప్రయత్నించండి.'
          : 'Search is temporarily unavailable. Please try again.';
  }
}
