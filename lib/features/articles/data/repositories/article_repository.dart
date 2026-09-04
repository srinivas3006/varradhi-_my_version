import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_response.dart';
import '../models/article_model.dart';
import '../services/article_api_service.dart';

class ArticleRepository {
  final ArticleApiService _apiService = ArticleApiService();

  Future<ApiResponse<List<ArticleModel>>> fetchFeed({
    required String scope,
    String? cursor,
    String? category,
    String? state,
    String? district,
  }) async {
    try {
      return await _apiService.getFeed(
        scope: scope,
        cursor: cursor,
        category: category,
        state: state,
        district: district,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw NetworkException('Unable to reach server');
    }
  }

  Future<ArticleModel?> fetchArticleDetail(String slug) async {
    try {
      final response = await _apiService.getArticleDetail(slug);
      return response.data;
    } catch (e) {
      if (e is AppException) rethrow;
      throw NetworkException('Failed to load article detail');
    }
  }
}
