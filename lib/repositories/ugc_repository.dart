import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/errors/app_exception.dart';
import '../core/network/api_response.dart';
import '../core/network/dio_client.dart';
import '../models/news_article.dart';
import '../models/unified_feed_item.dart';
import '../services/api_service.dart';

/// Production UgcRepository managing:
/// - UGC feed data retrieval and cursor pagination
/// - Domain model transformation (UnifiedFeedItem -> NewsArticle)
/// - Submission data retrieval
/// - Safe error handling
class UgcRepository {
  UgcRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient.instance;

  static final UgcRepository instance = UgcRepository();

  // ignore: unused_field
  final ApiClient _api;

  /// Fetches UGC feed items transformed cleanly into NewsArticle domain models.
  Future<ApiResponse<List<NewsArticle>>> getUgcFeed({
    String? cursor,
    int pageSize = 20,
  }) async {
    try {
      final response = await ApiService.instance.getUgcFeed(
        cursor: cursor,
        pageSize: pageSize,
      );

      final unifiedItems = response.data ?? [];
      final articles = unifiedItems.map((u) => _mapUnifiedToArticle(u)).toList();

      return ApiResponse<List<NewsArticle>>(
        data: articles,
        meta: response.meta,
        errors: response.errors,
        apiError: response.apiError,
        nextCursor: response.nextCursor,
        statusCode: response.statusCode,
      );
    } on AppException {
      rethrow;
    } catch (e) {
      debugPrint('[UgcRepository] Error fetching UGC feed: $e');
      throw ApiException('UGC డేటాను లోడ్ చేయడం విఫలమైంది.');
    }
  }

  /// Transforms backend UnifiedFeedItem into domain NewsArticle.
  NewsArticle _mapUnifiedToArticle(UnifiedFeedItem u) {
    final title = u.title.isNotEmpty
        ? u.title
        : (u.summary.isNotEmpty ? u.summary : 'Citizen Report');

    final primaryImage = u.thumbnailUrl.isNotEmpty ? u.thumbnailUrl : u.mediaUrl;
    final images = [
      if (u.thumbnailUrl.isNotEmpty) u.thumbnailUrl,
      if (u.mediaUrl.isNotEmpty) u.mediaUrl,
    ];

    return NewsArticle(
      id: u.id,
      title: title,
      slug: u.id,
      summary: u.summary,
      body: u.summary,
      imageUrl: primaryImage,
      imageUrls: images,
      source: u.district.isNotEmpty ? u.district : 'Citizen Reporter',
      category: 'UGC',
      publishedAt: u.createdAt,
      likes: 0,
      comments: 0,
      shares: 0,
      viewCount: 0,
      readTimeMinutes: 1,
      state: u.state.isNotEmpty ? u.state : null,
      district: u.district.isNotEmpty ? u.district : null,
      subdistrict: u.subdistrict.isNotEmpty ? u.subdistrict : null,
      village: u.village.isNotEmpty ? u.village : null,
    );
  }

  /// Submits citizen post data.
  Future<Map<String, dynamic>> submitPost(Map<String, dynamic> data) async {
    try {
      return await ApiService.instance.submitUgc(data);
    } on AppException {
      rethrow;
    } catch (e) {
      debugPrint('[UgcRepository] Error submitting UGC post: $e');
      throw ApiException('వార్తను సమర్పించడం విఫలమైంది. దయచేసి మళ్ళీ ప్రయత్నించండి.');
    }
  }

  /// Uploads a single media file associated with a submission.
  Future<Map<String, dynamic>> uploadMedia({
    required String submissionId,
    required String mobile,
    required String mediaType,
    required String filePath,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      return await ApiService.instance.uploadMedia(
        submissionId: submissionId,
        mobile: mobile,
        mediaType: mediaType,
        filePath: filePath,
        onSendProgress: onSendProgress,
        cancelToken: cancelToken,
      );
    } on DioException {
      rethrow;
    } on AppException {
      rethrow;
    } catch (e) {
      debugPrint('[UgcRepository] Error uploading media: $e');
      throw ApiException('మీడియాను అప్‌లోడ్ చేయడం విఫలమైంది. దయచేసి మళ్ళీ ప్రయత్నించండి.');
    }
  }

  /// Uploads a batch of media files associated with a submission.
  Future<Map<String, dynamic>> uploadMediaBatch({
    required String submissionId,
    required String mobile,
    required List<String> filePaths,
    required List<String> mediaTypes,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      return await ApiService.instance.uploadMediaBatch(
        submissionId: submissionId,
        mobile: mobile,
        filePaths: filePaths,
        mediaTypes: mediaTypes,
        onSendProgress: onSendProgress,
        cancelToken: cancelToken,
      );
    } on DioException {
      rethrow;
    } on AppException {
      rethrow;
    } catch (e) {
      debugPrint('[UgcRepository] Error uploading media batch: $e');
      throw ApiException('మీడియా ఫైళ్లను అప్‌లోడ్ చేయడం విఫలమైంది. దయచేసి మళ్ళీ ప్రయత్నించండి.');
    }
  }
}
