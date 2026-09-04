import 'package:flutter/material.dart';
import '../models/news_article.dart';
import '../services/api_service.dart';
import '../widgets/news_feed_card.dart';
import 'news_detail_screen.dart';
import 'comments_screen.dart';
import '../state/app_state.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  bool _isLoading = true;
  List<NewsArticle> _bookmarks = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchBookmarks();
  }

  Future<void> _fetchBookmarks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final bookmarks = await ApiService.instance.getBookmarks();
      setState(() {
        _bookmarks = bookmarks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load saved articles.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Articles'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchBookmarks,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_bookmarks.isEmpty) {
      return const Center(
        child: Text('No saved articles yet.'),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchBookmarks,
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
              ).then((_) => _fetchBookmarks());
            },
            onLike: () {},
            onBookmark: () async {
              AppState.instance.toggleBookmark(article.id);
              final success = await ApiService.instance.toggleBookmark(article.id);
              if (!success) {
                if (mounted) {
                  AppState.instance.toggleBookmark(article.id); // revert
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to update bookmark')),
                  );
                }
              } else if (!AppState.instance.isBookmarked(article.id)) {
                 // remove it from the list if unbookmarked
                 setState(() {
                    _bookmarks.removeWhere((a) => a.id == article.id);
                 });
              }
            },
            onShare: () {},
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
