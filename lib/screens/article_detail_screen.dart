import 'package:flutter/material.dart';
import '../models/news_article.dart';
import 'news_detail_screen.dart';

/// Screen 09: ArticleDetailScreen (Alias for NewsDetailScreen)
/// - APIs: article detail, comments, reactions, bookmarks, TTS optional
/// - Destinations: CommentsSheet, VideoPlayerScreen
class ArticleDetailScreen extends StatelessWidget {
  final NewsArticle article;
  final String? slug;

  const ArticleDetailScreen({super.key, required this.article, this.slug});

  @override
  Widget build(BuildContext context) {
    return NewsDetailScreen(article: article, slug: slug);
  }
}
