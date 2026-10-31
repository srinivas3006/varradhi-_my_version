import 'package:flutter/material.dart';
import '../models/news_article.dart';
import '../spotlight/spotlight_screen.dart';

class SpotlightScreen extends StatelessWidget {
  final String? initialStoryId;
  final int? initialStoryIndex;
  final String? initialCategory;
  final bool isLocal;

  /// A story opened from a notification, shown as the first card.
  final NewsArticle? pinnedArticle;

  const SpotlightScreen({
    super.key,
    this.initialStoryId,
    this.initialStoryIndex,
    this.initialCategory,
    this.isLocal = false,
    this.pinnedArticle,
  });

  @override
  Widget build(BuildContext context) {
    return SpotlightScreenView(
      initialStoryId: initialStoryId,
      initialStoryIndex: initialStoryIndex,
      initialCategory: initialCategory,
      isLocal: isLocal,
      pinnedArticle: pinnedArticle,
    );
  }
}
