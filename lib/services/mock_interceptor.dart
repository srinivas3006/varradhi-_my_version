import 'package:dio/dio.dart';
import '../data/mock_videos.dart';
import '../data/mock_news.dart';
import '../state/app_state.dart';

/// Shared fake submission shape for the Admin UGC Moderation mocks below —
/// matches AdminUgcSubmissionModel.fromJson's expected fields.
/// The `{id}` segment in a `.../submissions/{id}/<action>/` path.
String _submissionIdFromPath(String path) {
  final segments = path.split('/').where((e) => e.isNotEmpty).toList();
  return segments[segments.length - 2];
}

Map<String, dynamic> _mockAdminUgcSubmission(String id, {String status = 'PENDING', String title = 'Mock UGC submission'}) {
  return {
    "id": id,
    "title": title,
    "description": "Mock description for $title.",
    "category": "local",
    "publication_level": "district",
    "level": "district",
    "status": status,
    "village": "Madhapur",
    "subdistrict": "Serilingampally",
    "district": "Hyderabad",
    "state": "Telangana",
    "latitude": 17.385,
    "longitude": 78.4867,
    "media_url": "https://images.unsplash.com/photo-1596727289524-77e77b69ab8d",
    "media_type": "image",
    "thumbnail_url": "https://images.unsplash.com/photo-1596727289524-77e77b69ab8d",
    "branded_media_url": "",
    "upload_status": "READY",
    "validation_status": "VALID",
    "reporter": {
      "id": "mock-reporter-1",
      "name": "Jane Doe",
      "email": "jane@example.com",
      "mobile": "9876543210",
      "trust_level": "NEW_USER",
      "trust_score": 40,
      "is_blocked": false,
    },
    "duplicate_flagged": false,
    "duplicate_score": 0,
    "report_count": 0,
    "admin_notes": "",
    "created_at": DateTime.now().toIso8601String(),
    "updated_at": DateTime.now().toIso8601String(),
  };
}

class MockInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Handle Login
    if (options.path.contains('/api/v1/auth/login/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": {
              "access": "mock-jwt-access-token",
              "refresh": "mock-jwt-refresh-token",
              "user": {
                "id": "user-uuid-123",
                "email": options.data['email'] ?? "ravi@example.com",
                "full_name": "Ravi",
                "is_admin": false,
              }
            },
            "meta": {},
            "errors": null
          },
        ),
      );
    }

    // Handle Register
    if (options.path.contains('/api/v1/auth/register/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 201,
          data: {
            "data": {
              "access": "jwt-access-token",
              "refresh": "jwt-refresh-token",
              "session_id": "1d0d9b0e-88ec-45ca-924b-5d9ba0615f10",
              "user": {
                "id": "c52f9153-d3b6-45e8-99dd-ffbf6a44bb16",
                "email": options.data['email'] ?? "ravi@example.com",
                "full_name": options.data['full_name'] ?? "Ravi Kumar",
                "profile_image": null,
                "preferred_language": options.data['preferred_language'] ?? "te",
                "theme": "system",
                "font_size": 16,
                "is_contributor": false,
                "is_admin": false,
                "created_at": "2026-06-22T10:00:00+05:30"
              }
            },
            "meta": {},
            "errors": null
          },
        ),
      );
    }

    // Handle Token Refresh
    if (options.path.contains('/api/v1/auth/token/refresh/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": {
              "access": "new-mock-access-token",
              "refresh": "new-mock-refresh-token"
            },
            "meta": {},
            "errors": null
          },
        ),
      );
    }

    // Handle Logout
    if (options.path.contains('/api/v1/auth/logout/') || options.path.contains('/api/v1/auth/revoke/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {"data": {"message": "Logged out successfully"}, "meta": {}, "errors": null},
        ),
      );
    }

    // Handle Profile (GET / PATCH)
    if (options.path.contains('/api/v1/auth/me/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": {
              "id": "c52f9153-d3b6-45e8-99dd-ffbf6a44bb16",
              "email": "ravi@example.com",
              "full_name": options.data?['full_name'] ?? "Ravi Kumar",
              "profile_image": null,
              "preferred_language": options.data?['preferred_language'] ?? "te",
              "theme": options.data?['theme'] ?? "system",
              "font_size": options.data?['font_size'] ?? 16,
              "is_contributor": false,
              "is_admin": false,
              "created_at": "2026-06-22T10:00:00+05:30"
            },
            "meta": {},
            "errors": null
          },
        ),
      );
    }

    // Handle Passwords (Change, Request, Verify, Confirm)
    if (options.path.contains('/api/v1/auth/password/')) {
      // Simulate slight delay for security endpoints
      await Future.delayed(const Duration(milliseconds: 600));
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {"data": {"message": "Success"}, "meta": {}, "errors": null},
        ),
      );
    }

    // Handle Device Sessions
    if (options.path.contains('/api/v1/auth/sessions/')) {
      if (options.method.toUpperCase() == 'DELETE') {
        return handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 204, // No Content
            data: null,
          ),
        );
      }
      
      // GET sessions
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": [
              {
                "id": "mock-session-1234",
                "device_name": "Pixel 8",
                "device_type": "android",
                "last_used_at": DateTime.now().toIso8601String(),
                "ip_address": "192.168.1.5",
                "is_active": true,
                "created_at": "2026-06-22T10:00:00+05:30"
              },
              {
                "id": "mock-session-5678",
                "device_name": "iPhone 13",
                "device_type": "ios",
                "last_used_at": DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
                "ip_address": "10.0.0.12",
                "is_active": false,
                "created_at": "2026-06-01T10:00:00+05:30"
              }
            ],
            "meta": {},
            "errors": null
          },
        ),
      );
    }

    // Handle User Location POST
    if (options.path.contains('/api/v1/user/location/')) {
      final authHeader = options.headers['Authorization'];
      if (authHeader == null || !authHeader.toString().startsWith('Bearer ')) {
        return handler.reject(
          DioException(
            requestOptions: options,
            response: Response(
              requestOptions: options,
              statusCode: 401,
              data: {
                "errors": [
                  {
                    "code": "unauthorized",
                    "message": "Authentication credentials were not provided."
                  }
                ]
              },
            ),
            type: DioExceptionType.badResponse,
          ),
        );
      }
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": {
              "lat": options.data['lat'] ?? 17.385,
              "lon": options.data['lon'] ?? 78.4867,
              "village": options.data['village'] ?? "Local Village",
              "city": options.data['city'] ?? "Hyderabad",
              "subdistrict": options.data['subdistrict'] ?? "Local Subdistrict",
              "district": options.data['district'] ?? "Hyderabad District",
              "state": options.data['state'] ?? "Telangana",
              "country": options.data['country'] ?? "India",
              "location_source": "gps",
              "location_updated_at": DateTime.now().toIso8601String()
            },
            "meta": {},
            "errors": null
          },
        ),
      );
    }

    // Handle User Preferences PATCH
    if (options.path.contains('/api/v1/users/me/preferences/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": {
              "user": "c52f9153-d3b6-45e8-99dd-ffbf6a44bb16",
              "category_weights": options.data['category_weights'] ?? {
                "local": 1.0,
                "politics": 0.7,
                "sports": 0.5
              },
              "top_categories": ["local", "politics"],
              "updated_at": DateTime.now().toIso8601String()
            },
            "meta": {},
            "errors": null
          },
        ),
      );
    }

    // Handle Article Feed
    if (options.path.contains('/api/v1/articles/feed/')) {
      final reqDistrict = options.queryParameters['district'] ?? options.queryParameters['city'] ?? AppState.instance.district;
      final reqState = options.queryParameters['state'] ?? AppState.instance.stateName;
      final lat = options.queryParameters['latitude'] ?? options.queryParameters['lat'] ?? AppState.instance.latitude;
      final lon = options.queryParameters['longitude'] ?? options.queryParameters['lng'] ?? options.queryParameters['lon'] ?? AppState.instance.longitude;

      final articles = mockArticles.map((a) {
        final json = a.toJson();
        // Dynamically personalize top article for real-time location feedback
        if (json['id'] == '1' || json['id'] == 't1') {
          json['title'] = '$reqDistrict Local News & Real-Time Regional Updates';
          json['summary'] = 'Latest developments and breaking stories in $reqDistrict, $reqState${lat != null ? " (GPS: ${double.parse(lat.toString()).toStringAsFixed(3)}, ${double.parse(lon.toString()).toStringAsFixed(3)})" : ""}.';
          json['category'] = reqDistrict;
          json['location_tags'] = [reqDistrict, reqState];
        }
        return json;
      }).toList();

      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": articles,
            "meta": {
              "count": articles.length,
              "next": null,
              "previous": null
            },
            "errors": null
          },
        ),
      );
    }

    // Handle Featured Articles
    if (options.path.contains('/api/v1/articles/featured/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": mockArticles.take(5).map((a) => a.toJson()).toList(),
            "meta": {},
            "errors": null
          },
        ),
      );
    }

    // Handle Recommendations
    if (options.path.contains('/api/v1/articles/recommendations/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": mockArticles.skip(5).take(15).map((a) => a.toJson()).toList(),
            "meta": {},
            "errors": null
          },
        ),
      );
    }

    // Handle Recommendation Tracking
    if (options.path.contains('/api/v1/articles/recommendation/')) {
      // Catch impression, click, dwell
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {"data": {"status": "tracked"}, "meta": {}, "errors": null},
        ),
      );
    }

    // Handle Live News
    if (options.path.contains('/api/v1/articles/live/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": [
              {
                "id": "live-uuid-5555",
                "title": "LIVE: Telangana Assembly Session",
                "youtube_url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                "youtube_video_id": "dQw4w9WgXcQ",
                "thumbnail_url": "https://images.unsplash.com/photo-1596727289524-77e77b69ab8d",
                "description": "Watch the live monsoon session of the assembly.",
                "channel_name": "VARADHI TV",
                "is_active": true,
                "autoplay": true,
                "sort_order": 1
              }
            ],
            "meta": {},
            "errors": null
          }
        )
      );
    }

    // Handle Video Feed
    if (options.path.contains('/api/v1/articles/video-feed/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": mockVideos.map((v) => v.toJson()).toList(),
            "meta": {
              "count": mockVideos.length,
              "next": null,
              "previous": null
            },
            "errors": null
          }
        )
      );
    }

    // Handle Unified Feed
    if (options.path.contains('/api/v1/feed/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": mockArticles.map((a) => {
              ...a.toJson(),
              "type": "article",
            }).toList(),
            "meta": {
              "count": mockArticles.length,
              "next": null,
              "previous": null
            },
            "errors": null
          },
        ),
      );
    }

    // Handle Shorts Feed
    if (options.path.contains('/api/v1/articles/shorts-feed/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": mockVideos.map((v) => v.toJson()).toList(),
            "meta": {
              "count": mockVideos.length,
              "next": null,
              "previous": null
            },
            "errors": null
          }
        )
      );
    }

    // Handle TTS Request
    if (options.path.contains('/api/v1/articles/tts/') && !options.path.contains('status')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": {
              "task_id": "tts-task-12345",
              "state": "PENDING",
              "tts_id": null,
              "file_url": null,
              "error": null
            },
            "meta": {},
            "errors": null
          },
        ),
      );
    }

    // Handle TTS Status Poll
    if (options.path.contains('/api/v1/articles/tts/status/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": {
              "task_id": options.path.split('/').where((e) => e.isNotEmpty).last,
              "state": "COMPLETED",
              "tts_id": "tts-uuid-9876",
              "file_url": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3", // Demo audio file
              "error": null
            },
            "meta": {},
            "errors": null
          },
        ),
      );
    }

    // Handle Contributor Article Create
    if (options.path.endsWith('/api/v1/articles/') && options.method.toUpperCase() == 'POST') {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 201, // Created
          data: {
            "data": {
              "id": "new-article-uuid-1010",
              "title": "Article Successfully Submitted",
              "slug": "article-successfully-submitted",
              "summary": "Your article has been received and is pending review.",
              "status": "pending",
              "created_at": DateTime.now().toIso8601String()
            },
            "meta": {},
            "errors": null
          },
        ),
      );
    }

    // Handle Categories
    if (options.path.endsWith('/api/v1/categories/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": [
              {
                "id": "cat-uuid-1",
                "name": "Local",
                "slug": "local",
                "icon": "https://example.com/icons/local.png",
                "order": 1,
                "is_active": true
              },
              {
                "id": "cat-uuid-2",
                "name": "State",
                "slug": "state",
                "icon": "https://example.com/icons/state.png",
                "order": 2,
                "is_active": true
              },
              {
                "id": "cat-uuid-3",
                "name": "Sports",
                "slug": "sports",
                "icon": "https://example.com/icons/sports.png",
                "order": 3,
                "is_active": true
              }
            ],
            "meta": {},
            "errors": null
          },
        ),
      );
    }

    // Handle Search Trending
    if (options.path.contains('/api/v1/search/trending/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": ["KCR", "Revanth Reddy", "Hyderabad Metro", "Weather", "Elections"],
            "meta": {},
            "errors": null
          },
        ),
      );
    }

    // Handle Search Zero Results
    if (options.path.contains('/api/v1/search/zero-results/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": ["asdfghjkl", "unknown city festival"],
            "meta": {},
            "errors": null
          },
        ),
      );
    }

    // Handle Search
    if (options.path.contains('/api/v1/search/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": {
              "keyword": options.queryParameters['q'] ?? "metro",
              "result_count": 1,
              "results": [
                {
                  "id": "search-uuid-1",
                  "title": "Metro services extended in Hyderabad",
                  "slug": "metro-services-extended-hyderabad",
                  "summary": "Metro timings have been extended.",
                  "thumbnail_url": "https://images.unsplash.com/photo-1540910419892-4a36d2c3266c",
                  "category": {
                    "id": "cat-uuid-1",
                    "name": "Local",
                    "slug": "local",
                    "icon": "",
                    "order": 1,
                    "is_active": true
                  },
                  "author_name": "VARADHI News",
                  "source_name": "Reporter",
                  "language": "te",
                  "is_featured": false,
                  "is_breaking": false,
                  "is_bookmarked": false,
                  "share_url": null,
                  "read_time_minutes": 2,
                  "view_count": 125,
                  "published_at": "2026-06-22T08:30:00+05:30",
                  "state": "Telangana",
                  "district": "Hyderabad",
                  "village": "",
                  "subdistrict": "",
                  "is_regional": true,
                  "priority_score": 90,
                  "location_tags": ["Hyderabad"]
                }
              ]
            },
            "meta": {},
            "errors": null
          },
        ),
      );
    }

    // Handle Article Detail
    // Must be after feed/featured to not intercept them if path matching is broad, 
    // but contains matches exactly. To be safe, we'll check regex or strict match.
    if (RegExp(r'^/api/v1/articles/[a-zA-Z0-9-]+/$').hasMatch(options.path) 
        && !options.path.contains('feed') 
        && !options.path.contains('featured')
        && !options.path.contains('blogs')
        && !options.path.contains('video')) {
      final slug = options.path.split('/').where((s) => s.isNotEmpty).last;
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": {
              "id": "5f90fd61-6bbf-43d5-9d92-d4269c1052d3",
              "title": "Mock Article: $slug",
              "slug": slug,
              "summary": "This is a detailed summary for the mock article.",
              "content": "<p>This is the full rich-text HTML content of the article.</p><p>It includes multiple paragraphs and detailed information fetched from the server.</p>",
              "thumbnail_url": "https://images.unsplash.com/photo-1596727289524-77e77b69ab8d",
              "category": {
                "id": "2d35a2f8-0e71-45c0-a2d1-fec74ec1b7ff",
                "name": "Local",
                "slug": "local",
                "icon": "",
                "order": 1,
                "is_active": true
              },
              "author_name": "VARADHI News",
              "source_url": "https://example.com/source",
              "source_name": "Reporter",
              "source_logo_url": "",
              "language": "te",
              "is_featured": false,
              "is_breaking": true,
              "seo_title": "SEO Title",
              "seo_description": "SEO Description",
              "seo_tags": ["News", "Local"],
              "read_time_minutes": 4,
              "view_count": 850,
              "published_at": DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
              "is_bookmarked": false,
              "share_url": null,
              "village": "",
              "subdistrict": "",
              "tts_url": ""
            },
            "meta": {},
            "errors": null
          },
        ),
      );
    }
    if (options.path.contains('/api/v1/ugc/send-otp/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {"data": {"message": "OTP sent successfully"}, "meta": {}, "errors": null},
        ),
      );
    }

    // Handle UGC Verify OTP
    if (options.path.contains('/api/v1/ugc/verify-otp/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {"data": {"verified": true}, "meta": {}, "errors": null},
        ),
      );
    }

    // Handle UGC Submit
    if (options.path.contains('/api/v1/ugc/submit/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 201, // Created
          data: {
            "data": {
              "submission_id": "mock-uuid-1234-5678",
              "status": "pending_review",
              "message": "Submission received and pending review."
            },
            "meta": {},
            "errors": null
          },
        ),
      );
    }

    // Handle UGC Upload Media
    if (options.path.contains('/api/v1/ugc/upload-media/')) {
      // simulate longer network delay for file upload
      await Future.delayed(const Duration(milliseconds: 1500));
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": {
              "status": "success",
              "media_url": "https://example.com/mock-video.mp4",
              "message": "Media uploaded successfully"
            },
            "meta": {},
            "errors": null
          },
        ),
      );
    }

    // Handle Ad Areas
    if (options.path.contains('/api/v1/ads/areas/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": [
              {"id": "08c5c4f8-7334-4135-a6c8-b16c12a7c4de", "name": "Suryapet Local Area"},
              {"id": "c92a95c4-722a-43d9-95e2-38e5d0e3b624", "name": "Khammam Local Area"}
            ],
            "meta": {},
            "errors": null
          },
        ),
      );
    }

    // Handle Ad Pricing
    if (options.path.contains('/api/v1/ads/pricing/')) {
      final adType = options.queryParameters['ad_type'] as String?;
      final durationStr = options.queryParameters['duration_days']?.toString();
      final duration = durationStr != null ? int.tryParse(durationStr) ?? 7 : 7;
      String price;
      if (adType == 'main') {
        price = duration == 30 ? "9999.00" : duration == 14 ? "5499.00" : "2999.00";
      } else {
        price = duration == 30 ? "3499.00" : duration == 14 ? "1899.00" : "999.00";
      }
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": {
              "price": price,
              "currency": "₹"
            },
            "meta": {},
            "errors": null
          },
        ),
      );
    }

    // Handle Ad Booking
    if (options.path.contains('/api/v1/ads/bookings/')) {
      final payload = options.data as Map<String, dynamic>? ?? {};
      final bName = payload['business_name'] ?? 'My Business';
      final adType = payload['ad_type'] == 'main' ? 'State-wide (Main News)' : 'Local News Only';
      final duration = payload['duration_days'] ?? 7;
      final msg = Uri.encodeComponent("Hi Varadhi Team,\nI would like to advertise my business.\n\n*Business Name:* $bName\n*Visibility:* $adType\n*Duration:* $duration days\n\nPlease let me know the process.");
      
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 201,
          data: {
            "data": {
              "status": "pending",
              "whatsapp_url": "https://wa.me/919876543210?text=$msg"
            },
            "meta": {},
            "errors": null
          },
        ),
      );
    }

    // Handle Ad Event Tracking
    if (options.path.contains('/api/v1/ads/event/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {"data": {"status": "success"}, "meta": {}, "errors": null},
        ),
      );
    }

    // Handle Bookmarks
    if (options.path.endsWith('/api/v1/bookmarks/')) {
      if (options.method == 'GET') {
        final allArticles = mockArticles;
        final saved = allArticles
            .where((a) => AppState.instance.isBookmarked(a.id))
            .map((a) => a.toJson())
            .toList();
        return handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              "data": saved,
              "meta": {},
              "errors": null
            },
          ),
        );
      } else if (options.method == 'POST') {
        return handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 201,
            data: {"data": {"status": "success"}, "meta": {}, "errors": null},
          ),
        );
      }
    }

    if (options.path.endsWith('/api/v1/bookmarks/toggle/')) {
      final articleId = options.data['article'];
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {"data": {"status": "success", "is_bookmarked": AppState.instance.isBookmarked(articleId)}, "meta": {}, "errors": null},
        ),
      );
    }

    if (options.path.contains('/api/v1/bookmarks/') && options.method == 'DELETE') {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {"data": {"status": "success"}, "meta": {}, "errors": null},
        ),
      );
    }

    // Handle UGC
    if (options.path.endsWith('/api/v1/ugc/send-otp/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {"data": {"status": "success", "message": "OTP sent successfully"}, "meta": {}, "errors": null},
        ),
      );
    }
    if (options.path.endsWith('/api/v1/ugc/verify-otp/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {"data": {"status": "success", "token": "mock-ugc-token"}, "meta": {}, "errors": null},
        ),
      );
    }
    if (options.path.endsWith('/api/v1/ugc/submit/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": {
              "id": "mock-ugc-submission-id",
              "title": "Mock Road repair work",
              "status": "pending",
              "upload_status": "pending",
              "created_at": DateTime.now().toIso8601String()
            },
            "meta": {},
            "errors": null
          },
        ),
      );
    }
    if (options.path.endsWith('/api/v1/ugc/upload-media/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": {
              "status": "success",
              "message": "Media uploaded successfully",
              "media_url": "https://example.com/mock-ugc-media.mp4"
            },
            "meta": {},
            "errors": null
          },
        ),
      );
    }
    if (options.path.contains('/api/v1/ugc/feed/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": [
              {
                "id": "mock-ugc-1",
                "type": "video",
                "title": "Local event coverage",
                "description": "Footage from the local event.",
                "thumbnail_url": "https://example.com/thumb.jpg",
                "media_url": "https://example.com/video.mp4",
                "media_type": "video/mp4",
                "district": options.queryParameters['district'] ?? "Hyderabad",
                "state": options.queryParameters['state'] ?? "Telangana",
                "village": "Madhapur",
                "subdistrict": "Serilingampally",
                "created_at": DateTime.now().toIso8601String(),
                "priority_score": 85,
                "source": "UGC",
                "trust_level": "verified",
                "trust_score": 90,
                "uploader": "John Doe"
              }
            ],
            "meta": {
              "pagination": {
                "page": options.queryParameters['page'] ?? 1,
                "page_size": options.queryParameters['page_size'] ?? 20,
                "total_pages": 1,
                "total_count": 1
              }
            },
            "errors": null
          },
        ),
      );
    }

    if (options.path.endsWith('/api/v1/ugc/reporter/dashboard/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": {
              "total_submissions": 4,
              "pending_count": 1,
              "approved_count": 2,
              "published_count": 2,
              "rejected_count": 1,
              "trust_score": 65,
              "reporter_level": "TRUSTED",
              "recent_submissions": []
            },
            "meta": {},
            "errors": null
          },
        ),
      );
    }

    if (options.path.endsWith('/api/v1/ugc/reporter/submissions/')) {
      final status = options.queryParameters['status'] ?? 'pending';
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": [
              {
                "id": "mock-sub-1",
                "title": "Mock submission for $status",
                "status": status,
                "content_type": "video",
                "category": "local",
                "thumbnail_url": "https://example.com/thumb.jpg",
                "created_at": DateTime.now().toIso8601String(),
                "rejection_reason": status == "rejected" ? "Low quality media" : null
              }
            ],
            "meta": {
              "pagination": {
                "page": options.queryParameters['page'] ?? 1,
                "page_size": options.queryParameters['page_size'] ?? 20,
                "total_pages": 1,
                "total_count": 1
              }
            },
            "errors": null
          },
        ),
      );
    }

    if (options.path.endsWith('/api/v1/ugc/report/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": {
              "status": "success",
              "message": "Report submitted successfully"
            },
            "meta": {},
            "errors": null
          },
        ),
      );
    }
    
    // --- Admin UGC Moderation (lib/features/admin/) ---
    if (options.path.endsWith('/admin/api/ugc/queue/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "items": [
              _mockAdminUgcSubmission('mock-ugc-1', status: 'PENDING', title: 'Mock pending video report'),
              _mockAdminUgcSubmission('mock-ugc-2', status: 'FLAGGED', title: 'Mock flagged image report'),
              _mockAdminUgcSubmission('mock-ugc-3', status: 'APPROVED', title: 'Mock approved report'),
            ],
            "count": 3,
            "next": null,
            "previous": null,
          },
        ),
      );
    }
    if (RegExp(r'/admin/api/ugc/submissions/[^/]+/$').hasMatch(options.path) &&
        (options.method == 'GET' || options.method == 'PATCH')) {
      final id = options.path.split('/').where((e) => e.isNotEmpty).last;
      final base = _mockAdminUgcSubmission(id, title: 'Mock submission detail $id');
      final merged = options.method == 'PATCH' && options.data is Map ? {...base, ...options.data as Map} : base;
      return handler.resolve(
        Response(requestOptions: options, statusCode: 200, data: {"data": merged}),
      );
    }
    if (options.path.contains('/api/v1/ugc/admin/submissions/') && options.path.endsWith('/branded-media/')) {
      final submission = _mockAdminUgcSubmission(_submissionIdFromPath(options.path))
        ..['branded_media_url'] = 'https://example.com/mock-branded.jpg';
      return handler.resolve(
        Response(requestOptions: options, statusCode: 200, data: {"data": submission}),
      );
    }
    if (options.path.contains('/admin/api/ugc/submissions/') && options.path.endsWith('/approve/')) {
      return handler.resolve(
        Response(requestOptions: options, statusCode: 200, data: {"data": _mockAdminUgcSubmission(_submissionIdFromPath(options.path), status: 'APPROVED')}),
      );
    }
    if (options.path.contains('/admin/api/ugc/submissions/') && options.path.endsWith('/reject/')) {
      return handler.resolve(
        Response(requestOptions: options, statusCode: 200, data: {"data": _mockAdminUgcSubmission(_submissionIdFromPath(options.path), status: 'REJECTED')}),
      );
    }
    if (options.path.contains('/admin/api/ugc/submissions/') && options.path.endsWith('/flag/')) {
      return handler.resolve(
        Response(requestOptions: options, statusCode: 200, data: {"data": _mockAdminUgcSubmission(_submissionIdFromPath(options.path), status: 'FLAGGED')}),
      );
    }
    if (options.path.endsWith('/admin/api/ugc/submissions/bulk-action/')) {
      final ids = (options.data is Map ? options.data['ids'] : null) as List? ?? [];
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {"data": {"success_count": ids.length, "failed_count": 0, "errors": []}},
        ),
      );
    }
    if (options.path.contains('/admin/api/ugc/submissions/') &&
        (options.path.endsWith('/block-uploader/') ||
            options.path.endsWith('/unblock-uploader/') ||
            options.path.endsWith('/increase-trust/') ||
            options.path.endsWith('/decrease-trust/'))) {
      return handler.resolve(
        Response(requestOptions: options, statusCode: 200, data: {"data": {"status": "success"}}),
      );
    }
    if (options.path.endsWith('/admin/api/ugc/moderation-logs/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "items": [
              {
                "id": "mock-log-1",
                "action": "APPROVE",
                "submission_id": "mock-ugc-3",
                "submission_title": "Mock approved report",
                "old_status": "PENDING",
                "new_status": "APPROVED",
                "notes": "Verified by editor.",
                "admin_email": "editor@varadhi.example.com",
                "created_at": DateTime.now().toIso8601String(),
              },
            ],
            "count": 1,
            "next": null,
            "previous": null,
          },
        ),
      );
    }
    if (options.path.endsWith('/admin/api/ugc/reports/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "items": [
              {
                "id": "mock-report-1",
                "status": "PENDING",
                "reason": "spam",
                "target": {"id": "mock-ugc-2", "title": "Mock flagged image report"},
                "reporter_note": "This looks fake.",
                "reporter_email": "user@example.com",
                "created_at": DateTime.now().toIso8601String(),
              },
            ],
            "count": 1,
            "next": null,
            "previous": null,
          },
        ),
      );
    }
    if (options.path.contains('/admin/api/ugc/reports/') && (options.path.endsWith('/review/') || options.path.endsWith('/dismiss/'))) {
      return handler.resolve(
        Response(requestOptions: options, statusCode: 200, data: {"data": {"status": "success"}}),
      );
    }
    if (options.path.contains('/admin/api/ugc/reporters/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": {
              "id": "mock-reporter-1",
              "name": "Jane Doe",
              "email": "jane@example.com",
              "mobile": "9876543210",
              "trust_level": "TRUSTED_REPORTER",
              "trust_score": 70,
              "submissions_count": 12,
              "daily_uploads_count": 1,
              "is_blocked": false,
              "recent_submissions": [
                {"id": "mock-ugc-1", "title": "Mock pending video report", "status": "PENDING"},
              ],
            },
          },
        ),
      );
    }
    if (options.path.endsWith('/admin/api/ugc/otp-deliveries/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "items": [
              {
                "id": "mock-otp-1",
                "mobile": "9876543210",
                "provider": "MSG91",
                "status": "DELIVERED",
                "failure_reason": "",
                "created_at": DateTime.now().toIso8601String(),
              },
            ],
            "count": 1,
            "next": null,
            "previous": null,
          },
        ),
      );
    }

    // --- Rewards ---
    if (options.path.endsWith('/api/v1/rewards/wallet/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": {
              "available_coins": 1500,
              "locked_coins": 200,
              "redeemed_coins": 5000,
              "lifetime_earned_coins": 6700,
              "coin_value_rupees": "1.00",
              "available_value_rupees": "1500.00",
              "minimum_withdrawal_coins": 1000
            },
            "meta": {},
            "errors": null
          },
        ),
      );
    }
    if (options.path.contains('/api/v1/rewards/transactions/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": [
              {
                "id": "mock-tx-1",
                "transaction_type": "EARN",
                "coins": 50,
                "value_rupees": "50.00",
                "status": "COMPLETED",
                "source_app": "REPORTER",
                "source_model": "UGC_SUBMISSION",
                "source_object_id": "mock-sub-1",
                "metadata": {},
                "created_at": DateTime.now().toIso8601String()
              }
            ],
            "meta": {},
            "errors": null
          },
        ),
      );
    }
    if (options.path.contains('/api/v1/rewards/payouts/') && options.method == 'GET') {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": [
              {
                "id": "mock-payout-1",
                "coins_requested": 1000,
                "coin_value_rupees": "1.00",
                "amount_rupees": "1000.00",
                "payout_method": "PHONEPE",
                "payout_mobile": "9876543210",
                "payout_upi_id": "user@upi",
                "payout_account_name": "John Doe",
                "status": "PENDING",
                "user_notes": "Please send to PhonePe",
                "payment_reference": null,
                "requested_at": DateTime.now().toIso8601String(),
                "approved_at": null,
                "paid_at": null,
                "rejected_at": null,
                "created_at": DateTime.now().toIso8601String(),
                "updated_at": DateTime.now().toIso8601String()
              }
            ],
            "meta": {},
            "errors": null
          },
        ),
      );
    }
    if (options.path.contains('/api/v1/rewards/payouts/') && options.method == 'POST') {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 201,
          data: {
            "data": {
              "id": "mock-payout-2",
              "coins_requested": options.data['coins_requested'] ?? 1000,
              "coin_value_rupees": "1.00",
              "amount_rupees": "${options.data['coins_requested'] ?? 1000}.00",
              "payout_method": options.data['payout_method'] ?? "PHONEPE",
              "payout_mobile": options.data['payout_mobile'] ?? "9876543210",
              "payout_upi_id": options.data['payout_upi_id'] ?? "user@upi",
              "payout_account_name": null,
              "status": "PENDING",
              "user_notes": options.data['user_notes'] ?? "",
              "payment_reference": null,
              "requested_at": DateTime.now().toIso8601String(),
              "approved_at": null,
              "paid_at": null,
              "rejected_at": null,
              "created_at": DateTime.now().toIso8601String(),
              "updated_at": DateTime.now().toIso8601String()
            },
            "meta": {},
            "errors": null
          },
        ),
      );
    }

    // --- Posters ---
    if (options.path.endsWith('/api/v1/posters/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": [
              {
                "id": "mock-poster-1",
                "title": "Good Morning",
                "category": options.queryParameters['category'] ?? "good_morning",
                "image_url": "https://cdn.varadhi.example.com/posters/good-morning.jpg",
                "thumbnail_url": "",
                "images": [
                  {
                    "id": "mock-poster-1",
                    "image_url": "https://cdn.varadhi.example.com/posters/good-morning.jpg",
                    "caption": "",
                    "sort_order": 0
                  }
                ],
                "language": options.queryParameters['lang'] ?? "te",
                "festival_name": "",
                "event_date": null,
                "share_url": null,
                "created_at": DateTime.now().toIso8601String()
              }
            ],
            "meta": {
              "count": 1,
              "next": null,
              "previous": null
            },
            "errors": null
          },
        ),
      );
    }

    if (options.path.endsWith('/api/v1/ads/event/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": {
              "status": "success",
              "message": "Event recorded"
            },
            "meta": {},
            "errors": null
          },
        ),
      );
    }

    // --- Ad Booking ---
    if (options.path.endsWith('/api/v1/ads/areas/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": [
              {
                "id": "area-1",
                "name": "Hyderabad Main",
                "state": "Telangana",
                "district": "Hyderabad",
                "city": "Hyderabad",
                "village": "",
                "subdistrict": "",
                "sort_order": 1
              },
              {
                "id": "area-2",
                "name": "Warangal Local",
                "state": "Telangana",
                "district": "Warangal",
                "city": "Warangal",
                "village": "",
                "subdistrict": "",
                "sort_order": 2
              }
            ],
            "meta": {},
            "errors": null
          },
        ),
      );
    }
    if (options.path.contains('/api/v1/ads/pricing/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": {
              "ad_type": options.queryParameters['ad_type'] ?? "local",
              "duration_days": int.tryParse(options.queryParameters['duration_days']?.toString() ?? "7") ?? 7,
              "price": "500.00",
              "currency": "INR",
              "area": options.queryParameters['area_id']
            },
            "meta": {},
            "errors": null
          },
        ),
      );
    }
    if (options.path.endsWith('/api/v1/ads/bookings/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 201,
          data: {
            "data": {
              "id": "ce154de3-59d6-41c6-a587-7be2483fdc2f",
              "status": "pending",
              "quoted_price": "1500.00",
              "currency": "INR",
              "whatsapp_url": "https://wa.me/919876543210?text=Hello+Varadhi"
            },
            "meta": {},
            "errors": null
          },
        ),
      );
    }

    // --- Notifications ---
    if (options.path.endsWith('/api/v1/notifications/inbox/unread-count/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": {"count": 2},
            "meta": {},
            "errors": null
          },
        ),
      );
    }
    if (options.path.endsWith('/api/v1/notifications/inbox/') || options.path.contains('/api/v1/notifications/inbox/?')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": [
              {
                "id": "notif-uuid-1",
                "notification_id": "notif-core-1",
                "title": "Welcome to Varadhi!",
                "body": "Stay updated with local news.",
                "image_url": "https://example.com/notif.png",
                "deep_link": "varadhi://home",
                "is_read": false,
                "read_at": null,
                "notification_created_at": DateTime.now().toIso8601String(),
                "created_at": DateTime.now().toIso8601String()
              }
            ],
            "meta": {},
            "errors": null
          },
        ),
      );
    }
    if (options.path.contains('/api/v1/notifications/inbox/') && options.path.endsWith('/read/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": {"status": "success"},
            "meta": {},
            "errors": null
          },
        ),
      );
    }
    if (options.path.contains('/api/v1/notifications/inbox/') && !options.path.endsWith('/read/') && !options.path.endsWith('/unread-count/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": {
              "id": "notif-uuid-1",
              "notification_id": "notif-core-1",
              "title": "Welcome to Varadhi!",
              "body": "Stay updated with local news.",
              "image_url": "https://example.com/notif.png",
              "deep_link": "varadhi://home",
              "is_read": false,
              "read_at": null,
              "notification_created_at": DateTime.now().toIso8601String(),
              "created_at": DateTime.now().toIso8601String()
            },
            "meta": {},
            "errors": null
          },
        ),
      );
    }

    // --- Polls ---
    if (options.path.endsWith('/api/v1/polls/') || (options.path.contains('/api/v1/polls/') && !options.path.endsWith('/vote/') && !options.path.contains('/admin/'))) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": [
              {
                "id": "mock-poll-1",
                "question": "Best local issue to fix?",
                "option_a": "Roads",
                "option_b": "Water",
                "vote_a_count": 120,
                "vote_b_count": 80,
                "total_votes": 200,
                "options": [
                  {
                    "id": "f6d0c8b7-8e0e-47d7-8b82-49e504cf7301",
                    "label": "Roads",
                    "sort_order": 0,
                    "vote_count": 120,
                    "percentage": 60.0
                  },
                  {
                    "id": "f6d0c8b7-8e0e-47d7-8b82-49e504cf7302",
                    "label": "Water",
                    "sort_order": 1,
                    "vote_count": 80,
                    "percentage": 40.0
                  }
                ],
                "user_vote": null,
                "user_vote_option_id": null,
                "is_active": true,
                "is_expired": false,
                "ends_at": null,
                "created_at": DateTime.now().toIso8601String()
              }
            ],
            "meta": {},
            "errors": null
          },
        ),
      );
    }
    if (options.path.contains('/api/v1/polls/') && options.path.endsWith('/vote/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": {"status": "success", "message": "Vote recorded"},
            "meta": {},
            "errors": null
          },
        ),
      );
    }

    // --- CMS ---
    if (options.path.contains('/api/v1/cms/')) {
      final slug = options.path.split('/').where((e) => e.isNotEmpty).last;
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": {
              "id": "cms-123",
              "slug": slug,
              "title": slug == 'terms' ? 'Terms & Conditions' : 'Privacy Policy',
              "content": "<p>This is the mock content for $slug.</p>",
              "updated_at": DateTime.now().toIso8601String()
            },
            "meta": {},
            "errors": null
          },
        ),
      );
    }

    // --- Quotes / Daily Cards ---
    if (options.path.endsWith('/api/v1/quotes/random/')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            "data": {
              "id": "quote-uuid-1",
              "text": "Your future is created by what you do today, not tomorrow.",
              "author": "Robert Kiyosaki",
              "background_image_url": "https://images.unsplash.com/photo-1499209974431-9dddcece7f88?w=800",
              "created_at": DateTime.now().toIso8601String()
            },
            "meta": {},
            "errors": null
          },
        ),
      );
    }



    // Pass through unmocked requests
    handler.next(options);
  }
}
