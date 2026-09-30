import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/saved_item.dart';
import '../localization/app_translations.dart';
import '../services/api_service.dart';
import '../services/content_engagement_service.dart';
import '../widgets/news_feed_card.dart';
import 'news_detail_screen.dart';
import 'comments_screen.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/share_service.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  bool _isLoading = true;

  /// The combined saved list — articles and citizen posts — straight from
  /// `GET /api/v1/bookmarks/`.
  List<SavedItem> _bookmarks = [];
  String? _error;
  int _generation = 0;

  /// Bookmark ids with a DELETE in flight; their button is disabled.
  final Set<String> _removing = {};

  late bool _wasLoggedIn;

  @override
  void initState() {
    super.initState();
    _wasLoggedIn = AppState.instance.isLoggedIn;
    AppState.instance.addListener(_onAppStateChanged);
    _fetchBookmarks();
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() {
    if (!mounted) return;
    final loggedIn = AppState.instance.isLoggedIn;
    if (loggedIn != _wasLoggedIn) {
      // Logged in or out: reload for the new owner of the bookmarks.
      _wasLoggedIn = loggedIn;
      _bookmarks = [];
      _fetchBookmarks();
    } else if (!loggedIn) {
      // A guest's list is on the phone; keep it current.
      setState(() => _bookmarks = _guestItems());
    }
  }

  /// A guest's bookmarks, kept on this phone, newest first.
  static List<SavedItem> _guestItems() => AppState.instance.deviceSavedStories
      .map(SavedItem.onDevice)
      .toList();

  Future<void> _fetchBookmarks() async {
    if (!mounted) return;
    if (!AppState.instance.isLoggedIn) {
      setState(() {
        _bookmarks = _guestItems();
        _error = null;
        _isLoading = false;
      });
      return;
    }
    final generation = ++_generation;

    setState(() {
      _isLoading = _bookmarks.isEmpty;
      _error = null;
    });

    try {
      // Anything saved as a guest joins the account before the list loads.
      await ContentEngagementService.instance.syncGuestBookmarks();
      final bookmarks = await ApiService.instance.getBookmarks();
      if (mounted && generation == _generation) {
        // The server list is the truth: every screen shows these as saved.
        for (final item in bookmarks) {
          AppState.instance
              .setBookmarked(AppState.bookmarkKey(item.story), true);
        }
        // Guest bookmarks that could not be copied yet still show.
        final onServer = bookmarks.map((b) => b.contentId).toSet();
        setState(() {
          _bookmarks = [
            ..._guestItems().where((g) => !onServer.contains(g.contentId)),
            ...bookmarks,
          ];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          if (_bookmarks.isEmpty) _error = tr('saved_load_failed');
          _isLoading = false;
        });
      }
    }
  }

  /// A server bookmark: DELETE /api/v1/bookmarks/{bookmark id}/, and the row
  /// stays until the server answers 204 (or 404, already gone), per the
  /// bookmark handover. A guest bookmark is simply removed from the phone.
  Future<void> _remove(SavedItem item) async {
    if (!_removing.add(item.id)) return;
    HapticFeedback.lightImpact();
    setState(() {});
    try {
      if (!item.onDevice) {
        await ApiService.instance.deleteBookmark(item.id);
      }
      final key = AppState.bookmarkKey(item.story);
      AppState.instance.setBookmarked(key, false);
      item.story.isBookmarked = false;
      await AppState.instance.removeDeviceSavedStory(key);
      if (!mounted) return;
      setState(() => _bookmarks.removeWhere((b) => b.id == item.id));
    } catch (e) {
      debugPrint('[Bookmark] remove ${item.id} failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('bookmark_update_failed'))),
      );
    } finally {
      _removing.remove(item.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          tr('saved_articles'),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_error != null && _bookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: isDark ? Colors.white38 : Colors.black38),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchBookmarks,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(tr('retry')),
            ),
          ],
        ),
      );
    }

    if (_bookmarks.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchBookmarks,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmarks_outlined, size: 64, color: isDark ? Colors.white24 : Colors.black26),
                  const SizedBox(height: 16),
                  Text(
                    tr('no_saved_articles'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('no_saved_articles_sub'),
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchBookmarks,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _bookmarks.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final item = _bookmarks[index];
          final article = item.story;
          // NewsFeedCard splits its height between image and text, so it
          // needs a bounded height. Inside this ListView it had none, the
          // layout failed, and a release build drew a blank white page even
          // though the saved items had loaded.
          return SizedBox(
            height: _cardHeight(context),
            child: NewsFeedCard(
            article: article,
            onTap: () {
              // content_id drives navigation: an article opens by slug, a
              // citizen post by its id (the detail screen fetches either).
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NewsDetailScreen(
                    article: article,
                    slug: item.isUgc ? null : article.slug,
                  ),
                ),
              ).then((_) { if (mounted) _fetchBookmarks(); });
            },
            onLike: () {},
            onBookmark: () => _remove(item),
            onShare: () => ShareService.shareArticle(article),
            onComment: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CommentsScreen(article: article)),
              );
            },
            ),
          );
        },
      ),
    );
  }

  /// One card per story: image on top, headline and summary below. Sized
  /// from the width so the photo keeps its shape on every phone.
  static double _cardHeight(BuildContext context) =>
      (MediaQuery.sizeOf(context).width * 1.25).clamp(420.0, 620.0);
}
