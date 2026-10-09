import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

/// Slugs of the public CMS pages the app opens. The backend owns their text.
class CmsSlugs {
  CmsSlugs._();
  static const about = 'about-us';
  static const privacy = 'privacy-policy';
  static const terms = 'terms-and-conditions';
  static const contact = 'contact-us';
}

/// A CMS page as the backend sent it; [content] is HTML.
class CmsPage {
  const CmsPage({
    required this.slug,
    required this.title,
    required this.content,
    this.fetchedAt,
  });

  final String slug;
  final String title;
  final String content;

  /// When this copy was downloaded (null if unknown).
  final DateTime? fetchedAt;

  factory CmsPage.fromJson(Map<String, dynamic> json, {String? slug}) =>
      CmsPage(
        slug: (json['slug'] ?? slug ?? '').toString(),
        title: (json['title'] ?? '').toString().trim(),
        content: (json['content'] ?? '').toString(),
        fetchedAt: DateTime.tryParse(json['fetched_at']?.toString() ?? ''),
      );

  Map<String, dynamic> toJson() => {
        'slug': slug,
        'title': title,
        'content': content,
        if (fetchedAt != null) 'fetched_at': fetchedAt!.toIso8601String(),
      };
}

enum CmsStatus {
  /// Fresh from the server.
  fresh,

  /// The server could not be reached (offline, 5xx, still throttled); this
  /// is the copy saved on the last successful load.
  cached,

  /// 404: the page does not exist or is inactive.
  notFound,

  /// Nothing to show: the request failed and there is no saved copy.
  failed,
}

class CmsResult {
  const CmsResult(this.status, {this.page});
  final CmsStatus status;
  final CmsPage? page;
}

/// Loads public CMS pages with an on-device cache per slug.
///
/// Opening a page always asks the server (so edits in the admin portal show
/// up), saves the reply, and falls back to the saved copy when the network
/// or server fails. A throttled request (429) is retried once after a short
/// wait.
class CmsService {
  CmsService({
    Future<Map<String, dynamic>> Function(String slug)? fetcher,
    this.throttleWait = const Duration(seconds: 3),
  }) : _fetch = fetcher ?? ApiService.instance.fetchCmsPage;

  static final CmsService instance = CmsService();

  final Future<Map<String, dynamic>> Function(String slug) _fetch;
  final Duration throttleWait;

  @visibleForTesting
  static String cacheKey(String slug) => 'cms_page_$slug';

  /// The saved copy of [slug], if any.
  Future<CmsPage?> cached(String slug) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cacheKey(slug));
      if (raw == null) return null;
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final page = CmsPage.fromJson(json, slug: slug);
      return page.content.trim().isEmpty ? null : page;
    } catch (_) {
      return null;
    }
  }

  Future<CmsResult> load(String slug) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final data = await _fetch(slug);
        final page = CmsPage(
          slug: slug,
          title: (data['title'] ?? '').toString().trim(),
          content: (data['content'] ?? '').toString(),
          fetchedAt: DateTime.now(),
        );
        await _save(page);
        return CmsResult(CmsStatus.fresh, page: page);
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status == 404) {
          // Removed or switched off in the admin portal: do not keep showing
          // the old text.
          await _forget(slug);
          return const CmsResult(CmsStatus.notFound);
        }
        if (status == 429 && attempt == 0) {
          await Future<void>.delayed(throttleWait);
          continue;
        }
        break;
      } catch (_) {
        break;
      }
    }
    final saved = await cached(slug);
    return saved != null
        ? CmsResult(CmsStatus.cached, page: saved)
        : const CmsResult(CmsStatus.failed);
  }

  Future<void> _save(CmsPage page) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey(page.slug), jsonEncode(page.toJson()));
    } catch (_) {}
  }

  Future<void> _forget(String slug) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(cacheKey(slug));
    } catch (_) {}
  }
}
