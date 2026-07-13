import 'dart:async';
import 'package:dio/dio.dart';
import '../models/api_response.dart';
import '../models/news_article.dart';
import '../models/video_item.dart';
import 'dio_client.dart';

class ApiService {
  ApiService._internal();
  static final ApiService instance = ApiService._internal();

  final Dio _dio = DioClient().dio;

  // --- Auth ---
  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await _dio.post('/api/v1/auth/login/', data: {
      'username': username,
      'password': password,
    });
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    final response = await _dio.post('/api/v1/auth/register/', data: data);
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await _dio.get('/api/v1/auth/me/');
    return response.data['data'] as Map<String, dynamic>;
  }

  // --- Feeds ---
  Future<ApiResponse<List<NewsArticle>>> getNewsFeed({String? cursor, String? category}) async {
    try {
      final response = await _dio.get('/api/v1/articles/feed/', queryParameters: {
        if (cursor != null) 'cursor': cursor,
        if (category != null && category != 'For You' && category != 'Trending') 'category': category.toLowerCase(),
      });
      return ApiResponse<List<NewsArticle>>.fromJson(response.data, (json) {
        return (json as List).map((i) => NewsArticle.fromJson(i)).toList();
      });
    } catch (e) {
      // Fallback to empty if error occurs during integration testing
      return ApiResponse(data: []);
    }
  }

  Future<ApiResponse<List<NewsArticle>>> getUgcFeed({String? cursor}) async {
    try {
      final response = await _dio.get('/api/v1/ugc/feed/', queryParameters: {
        if (cursor != null) 'cursor': cursor,
      });
      return ApiResponse<List<NewsArticle>>.fromJson(response.data, (json) {
        return (json as List).map((i) => NewsArticle.fromJson(i)).toList();
      });
    } catch (e) {
      return ApiResponse(data: []);
    }
  }

  Future<ApiResponse<List<NewsArticle>>> getBlogsFeed({String? cursor}) async {
    try {
      final response = await _dio.get('/api/v1/articles/blogs/', queryParameters: {
        if (cursor != null) 'cursor': cursor,
      });
      return ApiResponse<List<NewsArticle>>.fromJson(response.data, (json) {
        return (json as List).map((i) => NewsArticle.fromJson(i)).toList();
      });
    } catch (e) {
      return ApiResponse(data: []);
    }
  }

  Future<ApiResponse<List<VideoItem>>> getVideoFeed({String? cursor}) async {
    try {
      final response = await _dio.get('/api/v1/articles/video-feed/', queryParameters: {
        if (cursor != null) 'cursor': cursor,
      });
      return ApiResponse<List<VideoItem>>.fromJson(response.data, (json) {
        return (json as List).map((i) => VideoItem.fromJson(i)).toList();
      });
    } catch (e) {
      return ApiResponse(data: []);
    }
  }

  Future<ApiResponse<List<String>>> getAds({String? cursor}) async {
    try {
      final response = await _dio.get('/api/v1/ads/', queryParameters: {
        if (cursor != null) 'cursor': cursor,
      });
      // Assuming ads returns a list of ad objects with an imageUrl
      return ApiResponse<List<String>>.fromJson(response.data, (json) {
        return (json as List).map((i) => i['image_url'] as String).toList();
      });
    } catch (e) {
      return ApiResponse(data: []);
    }
  }

  // --- UGC Creation ---
  Future<bool> sendOtp(String phone) async {
    final response = await _dio.post('/api/v1/ugc/send-otp/', data: {'phone': phone});
    return response.statusCode == 200;
  }

  Future<bool> verifyOtp(String phone, String otp) async {
    final response = await _dio.post('/api/v1/ugc/verify-otp/', data: {
      'phone': phone,
      'otp': otp,
    });
    return response.statusCode == 200;
  }

  Future<Map<String, dynamic>> submitUgc(Map<String, dynamic> data) async {
    final response = await _dio.post('/api/v1/ugc/submit/', data: data);
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadMedia(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await _dio.post('/api/v1/ugc/upload-media/', data: formData);
    return response.data['data'] as Map<String, dynamic>;
  }

  // --- Ad Booking ---
  Future<List<dynamic>> getAdAreas() async {
    final response = await _dio.get('/api/v1/ads/areas/');
    return response.data['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> getAdPricing({
    required String adType,
    String? areaId,
    required int durationDays,
  }) async {
    final response = await _dio.get('/api/v1/ads/pricing/', queryParameters: {
      'ad_type': adType,
      if (areaId != null && areaId.isNotEmpty) 'area_id': areaId,
      'duration_days': durationDays,
    });
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitAdBooking(Map<String, dynamic> data) async {
    final response = await _dio.post('/api/v1/ads/bookings/', data: data);
    return response.data['data'] as Map<String, dynamic>;
  }
}
