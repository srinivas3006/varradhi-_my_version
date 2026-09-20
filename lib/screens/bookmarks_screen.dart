import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/news_article.dart';
import '../localization/app_translations.dart';
import '../services/api_service.dart';
import '../widgets/news_feed_card.dart';
import 'news_detail_screen.dart';
import 'comments_screen.dart';
import 'account_login_screen.dart';
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
  List<NewsArticle> _bookmarks = [];
  String? _error;
  int _generation = 0;
  final Set<String> _removing = {};

  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_onAppStateChanged);
    if (AppState.instance.isLoggedIn) {
      _fetchBookmarks();
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() {
    if (!mounted) return;
    if (AppState.instance.isLoggedIn) {
      if (_bookmarks.isEmpty && !_isLoading) {
        _fetchBookmarks();
      } else {
        setState(() {});
      }
    } else {
      if (_bookmarks.isNotEmpty) {
        setState(() {
          _bookmarks = [];
          _isLoading = false;
        });
      } else {
        setState(() {});
      }
    }
  }

  Future<void> _fetchBookmarks() async {
    if (!mounted || !AppState.instance.isLoggedIn) return;
    final generation = ++_generation;

    setState(() {
      _isLoading = _bookmarks.isEmpty;
      _error = null;
    });

    try {
      final bookmarks = await ApiService.instance.getBookmarks();
      if (mounted && generation == _generation) {
        for (final article in bookmarks) {
          if (!_removing.contains(article.id)) {
            AppState.instance.setBookmarked(article.id, true);
          }
        }
        setState(() {
          _bookmarks = bookmarks.where((a) => !_removing.contains(a.id)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = tr('saved_load_failed');
          _isLoading = false;
        });
      }
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
    if (!AppState.instance.isLoggedIn) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bookmark_border_rounded, size: 72, color: isDark ? Colors.white24 : Colors.black26),
              const SizedBox(height: 16),
              Text(
                tr('sign_in_saved'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr('sign_in_saved_sub'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AccountLoginScreen()),
                  );
                  if (AppState.instance.isLoggedIn) {
                    _fetchBookmarks();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(tr('sign_in_register'), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

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
          final article = _bookmarks[index];
          return NewsFeedCard(
            article: article,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NewsDetailScreen(article: article, slug: article.slug),
                ),
              ).then((_) { if (mounted) _fetchBookmarks(); });
            },
            onLike: () {},
            onBookmark: () async {
              if (!_removing.add(article.id)) return;
              HapticFeedback.lightImpact();
              final oldIndex = _bookmarks.indexWhere((a) => a.id == article.id);
              final wasSaved = AppState.instance.isBookmarked(article.id);
              if (wasSaved) AppState.instance.toggleBookmark(article.id);
              setState(() => _bookmarks.removeWhere((a) => a.id == article.id));
              try {
                final success = await ApiService.instance.toggleBookmark(article.id);
                if (!success) throw Exception('Bookmark update failed');
              } catch (_) {
                if (wasSaved && !AppState.instance.isBookmarked(article.id)) {
                  AppState.instance.toggleBookmark(article.id);
                }
                if (!mounted) return;
                setState(() {
                  if (!_bookmarks.any((a) => a.id == article.id)) {
                    _bookmarks.insert(oldIndex.clamp(0, _bookmarks.length), article);
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr('bookmark_update_failed'))),
                );
              } finally {
                _removing.remove(article.id);
              }
            },
            onShare: () => ShareService.shareArticle(article),
            onComment: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CommentsScreen(article: article)),
              );
            },
          );
        },
      ),
    );
  }
}
