import 'dart:async';
import 'package:dio/dio.dart';
import '../models/api_response.dart';
import '../models/news_article.dart';
import '../models/live_news.dart';
import '../models/feed_item.dart';
import '../models/video_item.dart';
import '../models/category.dart';
import '../models/unified_feed_item.dart';
import '../models/ad_banner.dart';
import '../models/reporter_post.dart';
import '../models/poll.dart';
import 'dio_client.dart';

class ApiService {
  ApiService._internal();
  static final ApiService instance = ApiService._internal();

  final Dio _dio = DioClient().dio;

  // --- Auth ---
  Future<Map<String, dynamic>> login(String email, String password, {String? fcmToken}) async {
    final response = await _dio.post('/api/v1/auth/login/', data: {
      'email': email,
      'password': password,
      'device_id': 'flutter-app',
      'device_name': 'Mobile Device',
      'device_type': 'android',
      'fcm_token': fcmToken ?? 'dummy-token'
    });
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<void> updateFcmToken(String token) async {
    try {
      await _dio.post('/api/v1/users/fcm-token/', data: {'fcm_token': token});
    } catch (e) {
      // Silently fail if not logged in or backend unavailable
    }
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    final response = await _dio.post('/api/v1/auth/register/', data: data);
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    final response = await _dio.post('/api/v1/auth/token/refresh/', data: {
      'refresh': refreshToken,
      'device_id': 'flutter-app',
    });
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<void> logout(String refreshToken, {bool logoutAllDevices = false}) async {
    try {
      await _dio.post('/api/v1/auth/logout/', data: {
        'refresh': refreshToken,
        'logout_all_devices': logoutAllDevices,
      });
    } catch (e) {
      // Silently fail logout if network is unreachable
    }
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await _dio.get('/api/v1/auth/me/');
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final response = await _dio.patch('/api/v1/auth/me/', data: data);
    return response.data['data'] as Map<String, dynamic>;
  }

  // --- Passwords ---
  Future<void> changePassword(String currentPassword, String newPassword) async {
    await _dio.post('/api/v1/auth/password/change/', data: {
      'current_password': currentPassword,
      'new_password': newPassword,
      'new_password_confirm': newPassword,
    });
  }

  Future<void> requestPasswordReset(String email) async {
    await _dio.post('/api/v1/auth/password/reset/request/', data: {'email': email});
  }

  Future<void> verifyPasswordReset(String email, String token) async {
    await _dio.post('/api/v1/auth/password/reset/verify/', data: {
      'email': email,
      'token': token,
    });
  }

  Future<void> confirmPasswordReset(String email, String token, String newPassword) async {
    await _dio.post('/api/v1/auth/password/reset/confirm/', data: {
      'email': email,
      'token': token,
      'new_password': newPassword,
      'new_password_confirm': newPassword,
    });
  }

  // --- Device Sessions ---
  /* 
  // TODO: Uncomment and wire up when building the 'Active Sessions' UI in settings
  Future<List<dynamic>> getDeviceSessions() async {
    final response = await _dio.get('/api/v1/auth/sessions/');
    return response.data['data'] as List<dynamic>;
  }

  Future<void> revokeDeviceSession(String sessionId) async {
    await _dio.delete('/api/v1/auth/sessions/$sessionId/');
  }
  */

  // --- Location & Preferences ---
  Future<void> updateUserLocation(Map<String, dynamic> locationData) async {
    await _dio.post('/api/v1/user/location/', data: locationData);
  }

  Future<Map<String, dynamic>> updateCategoryPreferences(Map<String, double> categoryWeights) async {
    final response = await _dio.patch('/api/v1/users/me/preferences/', data: {
      'category_weights': categoryWeights
    });
    return response.data['data'] as Map<String, dynamic>;
  }

  // --- Feeds ---
  Future<NewsArticle> getArticleDetail(String slug) async {
    final response = await _dio.get('/api/v1/articles/$slug/');
    return NewsArticle.fromJson(response.data['data']);
  }

  Future<List<NewsArticle>> getFeaturedArticles({String? lang}) async {
    final response = await _dio.get('/api/v1/articles/featured/', queryParameters: {
      if (lang != null) 'lang': lang,
    });
    return (response.data['data'] as List).map((i) => NewsArticle.fromJson(i)).toList();
  }

  Future<List<NewsArticle>> getRecommendations({
    int? limit,
    String? lang,
    String? state,
    String? district,
    String? city,
    String? village,
    String? subdistrict,
    String? category,
  }) async {
    final response = await _dio.get('/api/v1/articles/recommendations/', queryParameters: {
      if (limit != null) 'limit': limit,
      if (lang != null) 'lang': lang,
      if (state != null) 'state': state,
      if (district != null) 'district': district,
      if (city != null) 'city': city,
      if (village != null) 'village': village,
      if (subdistrict != null) 'subdistrict': subdistrict,
      if (category != null) 'category': category,
    });
    return (response.data['data'] as List).map((i) => NewsArticle.fromJson(i)).toList();
  }

  // --- Recommendation Tracking ---
  Future<void> trackArticleImpression(String articleId, String sessionId) async {
    try {
      await _dio.post('/api/v1/articles/recommendation/impression/', data: {
        'article_id': articleId,
        'session_id': sessionId,
      });
    } catch (_) {
      // Fail silently to avoid interrupting user experience
    }
  }

  Future<void> trackArticleClick(String articleId, String sessionId) async {
    try {
      await _dio.post('/api/v1/articles/recommendation/click/', data: {
        'article_id': articleId,
        'session_id': sessionId,
      });
    } catch (_) {
      // Fail silently
    }
  }

  Future<void> trackArticleDwell(String articleId, String sessionId, int seconds) async {
    try {
      await _dio.post('/api/v1/articles/recommendation/dwell/', data: {
        'article_id': articleId,
        'session_id': sessionId,
        'seconds': seconds,
      });
    } catch (_) {
      // Fail silently
    }
  }

  // --- Feeds ---
  Future<ApiResponse<List<UnifiedFeedItem>>> getUnifiedFeed({
    String? cursor,
    int? pageSize,
    String? include,
    String? lang,
    String? category,
    String? state,
    String? district,
    String? city,
    String? subdistrict,
    String? village,
  }) async {
    final response = await _dio.get('/api/v1/feed/', queryParameters: {
      if (cursor != null) 'cursor': cursor,
      if (pageSize != null) 'page_size': pageSize,
      if (include != null) 'include': include,
      if (lang != null) 'lang': lang,
      if (category != null) 'category': category,
      if (state != null) 'state': state,
      if (district != null) 'district': district,
      if (city != null) 'city': city,
      if (subdistrict != null) 'subdistrict': subdistrict,
      if (village != null) 'village': village,
    });
    return ApiResponse<List<UnifiedFeedItem>>.fromJson(response.data, (json) {
      return (json as List).map((i) => UnifiedFeedItem.fromJson(i)).toList();
    });
  }

  Future<List<LiveNews>> getLiveNews() async {
    final response = await _dio.get('/api/v1/articles/live/');
    return (response.data['data'] as List).map((i) => LiveNews.fromJson(i)).toList();
  }

  Future<ApiResponse<List<NewsArticle>>> getNewsFeed({
    String? cursor,
    int? pageSize,
    String? lang,
    String? category,
    bool? breaking,
    String? state,
    String? district,
    String? city,
    String? subdistrict,
    String? village,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _dio.get('/api/v1/articles/feed/', queryParameters: {
      if (cursor != null) 'cursor': cursor,
      if (pageSize != null) 'page_size': pageSize,
      if (lang != null) 'lang': lang,
      if (category != null && category != 'For You' && category != 'Trending') 'category': category.toLowerCase(),
      if (breaking != null) 'breaking': breaking,
      if (state != null) 'state': state,
      if (district != null) 'district': district,
      if (city != null) 'city': city,
      if (subdistrict != null) 'subdistrict': subdistrict,
      if (village != null) 'village': village,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
    return ApiResponse<List<NewsArticle>>.fromJson(response.data, (json) {
      return (json as List).map((i) => NewsArticle.fromJson(i)).toList();
    });
  }



  Future<ApiResponse<List<NewsArticle>>> getBlogsFeed({String? cursor}) async {
    final response = await _dio.get('/api/v1/articles/blogs/', queryParameters: {
      if (cursor != null) 'cursor': cursor,
    });
    return ApiResponse<List<NewsArticle>>.fromJson(response.data, (json) {
      return (json as List).map((i) => NewsArticle.fromJson(i)).toList();
    });
  }

  // --- TTS (Text to Speech) ---
  Future<Map<String, dynamic>> generateTTS({
    required String content,
    required String language,
    required String objectType,
    required String objectId,
    bool forceRegenerate = false,
  }) async {
    final response = await _dio.post('/api/v1/articles/tts/', data: {
      'content': content,
      'language': language,
      'object_type': objectType,
      'object_id': objectId,
      'force_regenerate': forceRegenerate,
    });
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTTSStatus(String taskId) async {
    final response = await _dio.get('/api/v1/articles/tts/status/$taskId/');
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<ApiResponse<List<VideoItem>>> getVideoFeed({
    String? cursor,
    int? pageSize,
    String? lang,
    String? scope,
    String? state,
    String? district,
    String? city,
    String? subdistrict,
    String? village,
  }) async {
    final response = await _dio.get('/api/v1/articles/video-feed/', queryParameters: {
      if (cursor != null) 'cursor': cursor,
      if (pageSize != null) 'page_size': pageSize,
      if (lang != null) 'lang': lang,
      if (scope != null) 'scope': scope,
      if (state != null) 'state': state,
      if (district != null) 'district': district,
      if (city != null) 'city': city,
      if (subdistrict != null) 'subdistrict': subdistrict,
      if (village != null) 'village': village,
    });
    return ApiResponse<List<VideoItem>>.fromJson(response.data, (json) {
      return (json as List).map((i) => VideoItem.fromJson(i)).toList();
    });
  }

  Future<ApiResponse<List<VideoItem>>> getShortsFeed({
    String? cursor,
    int? pageSize,
    String? lang,
    String? scope,
    String? state,
    String? district,
    String? city,
    String? subdistrict,
    String? village,
  }) async {
    final response = await _dio.get('/api/v1/articles/shorts-feed/', queryParameters: {
      if (cursor != null) 'cursor': cursor,
      if (pageSize != null) 'page_size': pageSize,
      if (lang != null) 'lang': lang,
      if (scope != null) 'scope': scope,
      if (state != null) 'state': state,
      if (district != null) 'district': district,
      if (city != null) 'city': city,
      if (subdistrict != null) 'subdistrict': subdistrict,
      if (village != null) 'village': village,
    });
    return ApiResponse<List<VideoItem>>.fromJson(response.data, (json) {
      return (json as List).map((i) => VideoItem.fromJson(i)).toList();
    });
  }

  Future<ApiResponse<List<AdBanner>>> getAds({
    String? zone,
    String? scope,
    String? state,
    String? district,
    String? areaId,
  }) async {
    try {
      final response = await _dio.get('/api/v1/ads/', queryParameters: {
        if (zone != null) 'zone': zone,
        if (scope != null) 'scope': scope,
        if (state != null) 'state': state,
        if (district != null) 'district': district,
        if (areaId != null) 'area_id': areaId,
      });
      return ApiResponse<List<AdBanner>>.fromJson(response.data, (json) {
        return (json as List).map((i) => AdBanner.fromJson(i)).toList();
      });
    } catch (e) {
      return ApiResponse(data: []);
    }
  }

  Future<void> trackAdEvent(String adId, String eventType) async {
    try {
      await _dio.post('/api/v1/ads/event/', data: {
        'ad_id': adId,
        'event_type': eventType,
      });
    } catch (e) {
      // Silently fail for analytics tracking
    }
  }

  Future<ApiResponse<List<NewsArticle>>> searchArticles(
    String query, {
    String? lang,
    String? category,
  }) async {
    try {
      final response = await _dio.get('/api/v1/search/', queryParameters: {
        'q': query,
        if (lang != null) 'lang': lang,
        if (category != null) 'category': category,
      });
      // Search API wraps items in data['results'] instead of directly in data.
      return ApiResponse<List<NewsArticle>>.fromJson(response.data, (json) {
        final results = (json as Map<String, dynamic>)['results'] as List;
        return results.map((i) => NewsArticle.fromJson(i)).toList();
      });
    } catch (e) {
      return ApiResponse(data: []);
    }
  }

  Future<List<String>> getTrendingSearches() async {
    try {
      final response = await _dio.get('/api/v1/search/trending/');
      return (response.data['data'] as List).map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> getZeroResultsSearches() async {
    try {
      final response = await _dio.get('/api/v1/search/zero-results/');
      return (response.data['data'] as List).map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  // --- Categories ---
  Future<List<Category>> getCategories() async {
    try {
      final response = await _dio.get('/api/v1/categories/');
      return (response.data['data'] as List).map((i) => Category.fromJson(i)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Category> createCategory(Map<String, dynamic> data) async {
    final response = await _dio.post('/api/v1/categories/admin/', data: data);
    return Category.fromJson(response.data['data']);
  }

  Future<Category> updateCategory(String slug, Map<String, dynamic> data) async {
    final response = await _dio.patch('/api/v1/categories/admin/$slug/', data: data);
    return Category.fromJson(response.data['data']);
  }

  Future<void> deleteCategory(String slug) async {
    await _dio.delete('/api/v1/categories/admin/$slug/');
  }

  // --- Bookmarks ---
  Future<List<NewsArticle>> getBookmarks() async {
    try {
      final response = await _dio.get('/api/v1/bookmarks/');
      return (response.data['data'] as List).map((i) => NewsArticle.fromJson(i)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addBookmark(String articleId) async {
    await _dio.post('/api/v1/bookmarks/', data: {'article': articleId});
  }

  Future<bool> toggleBookmark(String articleId) async {
    final response = await _dio.post('/api/v1/bookmarks/toggle/', data: {'article': articleId});
    return response.statusCode == 200 || response.statusCode == 201;
  }

  Future<void> removeBookmark(String bookmarkId) async {
    await _dio.delete('/api/v1/bookmarks/$bookmarkId/');
  }

  // --- Contributor / Reporter ---
  Future<Map<String, dynamic>> createArticle(Map<String, dynamic> data, {String? thumbnailPath}) async {
    dynamic requestData;
    
    if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
      // Use Multipart FormData if there's a file upload
      final formDataMap = Map<String, dynamic>.from(data);
      formDataMap['thumbnail_upload'] = await MultipartFile.fromFile(thumbnailPath);
      requestData = FormData.fromMap(formDataMap);
    } else {
      // Standard JSON
      requestData = data;
    }

    final response = await _dio.post('/api/v1/articles/', data: requestData);
    return response.data['data'] as Map<String, dynamic>;
  }

  // --- UGC Creation ---
  Future<bool> sendOtp(String phone) async {
    final response = await _dio.post('/api/v1/ugc/send-otp/', data: {'mobile': phone});
    return response.statusCode == 200;
  }

  Future<bool> verifyOtp(String phone, String otp) async {
    final response = await _dio.post('/api/v1/ugc/verify-otp/', data: {
      'mobile': phone,
      'otp': otp,
    });
    return response.statusCode == 200;
  }

  Future<List<UnifiedFeedItem>> getUgcFeed({
    String? state,
    String? district,
    String? scope,
    int pageSize = 20,
    int page = 1,
  }) async {
    final Map<String, dynamic> params = {
      'page_size': pageSize,
      'page': page,
    };
    if (state != null) params['state'] = state;
    if (district != null) params['district'] = district;
    if (scope != null) params['scope'] = scope;

    try {
      final response = await _dio.get('/api/v1/ugc/feed/', queryParameters: params);
      final List data = response.data['data'] ?? [];
      return data.map((json) => UnifiedFeedItem(
        id: json['id'] ?? '',
        type: json['type'] ?? 'ugc',
        title: json['title'] ?? '',
        summary: json['description'] ?? '',
        thumbnailUrl: json['thumbnail_url'] ?? '',
        mediaUrl: json['media_url'] ?? '',
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
        district: json['district'] ?? '',
        subdistrict: json['subdistrict'] ?? '',
        village: json['village'] ?? '',
        state: json['state'] ?? '',
        priorityScore: json['priority_score'] ?? 0,
        source: json['source'] ?? json['uploader'] ?? 'UGC',
        trustScore: json['trust_score'] ?? 50,
        metadata: {
          'media_type': json['media_type'],
          'trust_level': json['trust_level'],
        },
      )).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> submitUgc(Map<String, dynamic> data) async {
    final response = await _dio.post('/api/v1/ugc/submit/', data: data);
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadMedia({
    required String submissionId,
    required String mobile,
    required String mediaType,
    required String filePath,
  }) async {
    final formData = FormData.fromMap({
      'submission_id': submissionId,
      'mobile': mobile,
      'media_type': mediaType,
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await _dio.post('/api/v1/ugc/upload-media/', data: formData);
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getReporterDashboard() async {
    final response = await _dio.get('/api/v1/ugc/reporter/dashboard/');
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<List<ReporterPost>> getReporterSubmissions({
    String status = 'pending',
    int pageSize = 20,
    int page = 1,
  }) async {
    try {
      final response = await _dio.get('/api/v1/ugc/reporter/submissions/', queryParameters: {
        'status': status,
        'page_size': pageSize,
        'page': page,
      });
      final List data = response.data['data'] ?? [];
      return data.map((json) {
        PostStatus postStatus = PostStatus.pending;
        if (json['status'] == 'approved' || json['status'] == 'published') postStatus = PostStatus.approved;
        if (json['status'] == 'rejected') postStatus = PostStatus.rejected;
        
        return ReporterPost(
          id: json['id'] ?? '',
          reporterName: json['uploader'] ?? 'Me',
          type: json['content_type'] == 'video' ? PostType.video : PostType.image,
          caption: json['title'] ?? '',
          category: json['category'] ?? 'local',
          mediaUrl: json['thumbnail_url'] ?? json['media_url'] ?? '',
          status: postStatus,
          submittedAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
          rejectionReason: json['rejection_reason'],
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> reportUgcSubmission({
    required String submissionId,
    required String reason,
    String? notes,
  }) async {
    final response = await _dio.post('/api/v1/ugc/report/', data: {
      'submission_id': submissionId,
      'reason': reason,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return response.statusCode == 200 || response.statusCode == 201;
  }

  // --- Rewards ---
  Future<Map<String, dynamic>> getRewardWallet() async {
    final response = await _dio.get('/api/v1/rewards/wallet/');
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<List<dynamic>> getRewardTransactions({int pageSize = 20}) async {
    final response = await _dio.get('/api/v1/rewards/transactions/', queryParameters: {'page_size': pageSize});
    return response.data['data'] as List<dynamic>? ?? [];
  }

  Future<List<dynamic>> getRewardPayouts({int pageSize = 20}) async {
    final response = await _dio.get('/api/v1/rewards/payouts/', queryParameters: {'page_size': pageSize});
    return response.data['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> createRewardPayout(Map<String, dynamic> data) async {
    final response = await _dio.post('/api/v1/rewards/payouts/', data: data);
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getRewardPayoutDetails(String payoutId) async {
    final response = await _dio.get('/api/v1/rewards/payouts/$payoutId/');
    return response.data['data'] as Map<String, dynamic>;
  }

  // --- Admin Moderation ---
  Future<List<ReporterPost>> getModerationQueue() async {
    try {
      final response = await _dio.get('/api/v1/ugc/moderation/queue/');
      final List data = response.data['data'] ?? [];
      return data.map((json) => ReporterPost(
        id: json['id'] ?? '',
        reporterName: json['uploader'] ?? 'Reporter',
        type: json['content_type'] == 'video' ? PostType.video : PostType.image,
        caption: json['title'] ?? '',
        category: json['category'] ?? 'local',
        mediaUrl: json['thumbnail_url'] ?? json['media_url'] ?? '',
        status: PostStatus.pending,
        submittedAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      )).toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> approveUgcSubmission(String submissionId) async {
    final response = await _dio.post('/admin/api/ugc/submissions/$submissionId/approve/');
    return response.statusCode == 200 || response.statusCode == 201;
  }

  Future<bool> rejectUgcSubmission(String submissionId, String? reason) async {
    final data = reason != null && reason.isNotEmpty ? {'reason': reason} : {};
    final response = await _dio.post('/admin/api/ugc/submissions/$submissionId/reject/', data: data);
    return response.statusCode == 200 || response.statusCode == 201;
  }

  // --- Posters ---
  Future<List<dynamic>> getPosters({
    String? category,
    String? lang,
    String? cursor,
    int pageSize = 20,
  }) async {
    final Map<String, dynamic> params = {'page_size': pageSize};
    if (category != null) params['category'] = category;
    if (lang != null) params['lang'] = lang;
    if (cursor != null) params['cursor'] = cursor;

    try {
      final response = await _dio.get('/api/v1/posters/', queryParameters: params);
      return response.data['data'] as List<dynamic>? ?? [];
    } catch (_) {
      return [];
    }
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



  // --- Notifications ---
  Future<List<dynamic>> getNotifications({bool? unread}) async {
    final Map<String, dynamic> params = {};
    if (unread != null) params['unread'] = unread;
    try {
      final response = await _dio.get('/api/v1/notifications/inbox/', queryParameters: params);
      return response.data['data'] as List<dynamic>? ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<int> getUnreadNotificationCount() async {
    try {
      final response = await _dio.get('/api/v1/notifications/inbox/unread-count/');
      return response.data['data']['count'] ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<Map<String, dynamic>?> getNotificationDetails(String notificationId) async {
    try {
      final response = await _dio.get('/api/v1/notifications/inbox/$notificationId/');
      return response.data['data'] as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<bool> markNotificationRead(String notificationId) async {
    try {
      final response = await _dio.post('/api/v1/notifications/inbox/$notificationId/read/');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  // --- Polls ---
  Future<List<Poll>> getPolls() async {
    try {
      final response = await _dio.get('/api/v1/polls/');
      final List data = response.data['data'] ?? [];
      return data.map((json) => _parsePoll(json)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Poll?> getPollDetails(String pollId) async {
    try {
      final response = await _dio.get('/api/v1/polls/$pollId/');
      return _parsePoll(response.data['data']);
    } catch (_) {
      return null;
    }
  }

  Poll _parsePoll(Map<String, dynamic> json) {
    List<String> labels = [];
    List<int> counts = [];
    
    final opts = json['options'] as List?;
    if (opts != null && opts.isNotEmpty) {
      for (var o in opts) {
        labels.add(o['label'] ?? '');
        counts.add(o['vote_count'] ?? 0);
      }
    } else {
       labels.add(json['option_a'] ?? 'A');
       labels.add(json['option_b'] ?? 'B');
       counts.add(json['vote_a_count'] ?? 0);
       counts.add(json['vote_b_count'] ?? 0);
    }
    
    int? selectedIdx;
    if (json['user_vote'] == 'a') selectedIdx = 0;
    if (json['user_vote'] == 'b') selectedIdx = 1;

    return Poll(
      id: json['id'] ?? '',
      question: json['question'] ?? '',
      options: labels,
      votes: counts,
      selectedOption: selectedIdx,
    );
  }

  Future<bool> submitPollVote(String pollId, int optionIndex) async {
    try {
      String choice = optionIndex == 0 ? 'a' : 'b'; 
      final response = await _dio.post('/api/v1/polls/$pollId/vote/', data: {
        'choice': choice
      });
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  // --- CMS ---
  Future<Map<String, dynamic>?> getCmsPage(String slug) async {
    try {
      final response = await _dio.get('/api/v1/cms/$slug/');
      return response.data['data'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  // --- Quotes / Daily Cards ---
  Future<Map<String, dynamic>?> getRandomQuote() async {
    try {
      final response = await _dio.get('/api/v1/quotes/random/');
      return response.data['data'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }
}
