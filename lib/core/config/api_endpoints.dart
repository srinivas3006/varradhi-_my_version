class ApiEndpoints {
  static const String articlesFeed = '/api/v1/articles/feed/';
  static const String featuredArticles = '/api/v1/articles/featured/';
  static const String recommendations = '/api/v1/articles/recommendations/';
  static String articleDetail(String slug) => '/api/v1/articles/$slug/';

  // Recommendation Tracking
  static const String trackImpression = '/api/v1/articles/recommendation/impression/';
  static const String trackClick = '/api/v1/articles/recommendation/click/';
  static const String trackDwell = '/api/v1/articles/recommendation/dwell/';
}
