import 'package:dio/dio.dart';
import '../../../../core/config/api_endpoints.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/dio_client.dart';
import '../models/article_model.dart';

class ArticleApiService {
  final Dio _dio = CoreDioClient().dio;

  Future<ApiResponse<List<ArticleModel>>> getFeed({
    required String scope,
    String? cursor,
    int pageSize = 20,
    String? category,
    String? state,
    String? district,
    String? subdistrict,
    String? village,
  }) async {
    final query = <String, dynamic>{
      'scope': scope,
      'page_size': pageSize,
      if (cursor != null) 'cursor': cursor,
      if (category != null) 'category': category,
      if (state != null) 'state': state,
      if (district != null) 'district': district,
      if (subdistrict != null) 'subdistrict': subdistrict,
      if (village != null) 'village': village,
    };

    final response = await _dio.get(ApiEndpoints.articlesFeed, queryParameters: query);
    return ApiResponse<List<ArticleModel>>.fromJson(
      response.data,
      (json) => (json as List).map((item) => ArticleModel.fromJson(item)).toList(),
    );
  }

  Future<ApiResponse<ArticleModel>> getArticleDetail(String slug) async {
    final response = await _dio.get(ApiEndpoints.articleDetail(slug));
    return ApiResponse<ArticleModel>.fromJson(
      response.data,
      (json) => ArticleModel.fromJson(json),
    );
  }
}
