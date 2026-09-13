import 'news_article.dart';
import 'poll.dart';

enum FeedType { article, video, ad, jyothisham, poll }

enum FeedItemType {
  article,
  ad,
  poll,
  trendingRail,
  preferencesPrompt,
  poster,
  infoCard
}

/// Wraps a heterogeneous feed entry (article, ad slot, or poll) so a single
/// PageView/ListView can render a mixed vertical feed, matching Way2News's
/// pattern of interleaving native ads and polls between story cards.
class FeedItem {
  final FeedItemType type;
  final NewsArticle? article;
  final Poll? poll;
  final List<NewsArticle>? trendingArticles;
  final String? mediaUrl; // For poster
  final String? title; // For infoCard

  const FeedItem.article(this.article)
      : type = FeedItemType.article,
        poll = null,
        trendingArticles = null,
        mediaUrl = null,
        title = null;

  const FeedItem.ad()
      : type = FeedItemType.ad,
        article = null,
        poll = null,
        trendingArticles = null,
        mediaUrl = null,
        title = null;

  const FeedItem.poll(this.poll)
      : type = FeedItemType.poll,
        article = null,
        trendingArticles = null,
        mediaUrl = null,
        title = null;

  const FeedItem.trendingRail(this.trendingArticles)
      : type = FeedItemType.trendingRail,
        article = null,
        poll = null,
        mediaUrl = null,
        title = null;

  const FeedItem.preferencesPrompt()
      : type = FeedItemType.preferencesPrompt,
        article = null,
        poll = null,
        trendingArticles = null,
        mediaUrl = null,
        title = null;

  const FeedItem.poster(this.mediaUrl)
      : type = FeedItemType.poster,
        article = null,
        poll = null,
        trendingArticles = null,
        title = null;

  const FeedItem.infoCard(this.title)
      : type = FeedItemType.infoCard,
        article = null,
        poll = null,
        trendingArticles = null,
        mediaUrl = null;
}
