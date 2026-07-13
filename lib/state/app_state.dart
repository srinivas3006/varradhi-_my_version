import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/news_article.dart';
import '../models/redeem_request.dart';
import '../models/reporter_post.dart';
import '../data/mock_news.dart';
import '../services/api_service.dart';

/// Simple app-wide state singleton. Backed by shared_preferences so key
/// scalar fields (onboarding completion, language, location, coins, login,
/// reporter status) survive app restarts. Lists (posts, redeem requests)
/// are kept in-memory only for this demo — a real backend would own them.
class AppState extends ChangeNotifier {
  // Local persistence for likes/comments until backend supports it
  Set<String> likedItemIds = {};
  Map<String, List<String>> localComments = {};

  AppState._internal();
  static final AppState instance = AppState._internal();

  String language = 'English';
  String stateName = 'Telangana';
  String district = 'Hyderabad';
  bool isLoggedIn = false;
  String? authToken;
  bool isAdmin = false;
  String userName = 'Guest User';
  String userPhone = '';
  ThemeMode themeMode = ThemeMode.system;
  
  List<String> preferredCategories = [];
  bool hasPromptedPreferences = false;

  /// True once the user has completed language + location selection at
  /// least once. When true, the splash screen skips straight to Home.
  bool hasOnboarded = false;

  // ---- Comments state ----
  final Map<String, List<Comment>> articleComments = {};

  // ---- Reporter Program state ----

  /// True once the user has registered for the Reporter Program. This is
  /// instant (no approval needed) — only individual posts need admin review.
  bool isReporter = false;

  /// True once the user has completed the ONE-TIME OTP check that's
  /// required before their very first post submission. Never asked again
  /// after that.
  bool uploadVerified = false;

  /// 1 token = ₹5. Reporters can request a redeem once this reaches 100.
  int reporterTokens = 0;

  final List<ReporterPost> reporterPosts = [];
  final List<RedeemRequest> redeemRequests = [];

  static const int rupeesPerToken = 5;
  static const int tokensNeededToRedeem = 100;

  /// Loads persisted state. Call once, before runApp, so the very first
  /// frame already knows whether to show onboarding or go straight home.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    hasOnboarded = prefs.getBool('hasOnboarded') ?? false;
    language = prefs.getString('language') ?? language;
    stateName = prefs.getString('stateName') ?? stateName;
    district = prefs.getString('district') ?? district;
    isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    authToken = prefs.getString('authToken');
    isAdmin = prefs.getBool('isAdmin') ?? false;
    userName = prefs.getString('userName') ?? userName;
    userPhone = prefs.getString('userPhone') ?? userPhone;
    isReporter = prefs.getBool('isReporter') ?? false;
    uploadVerified = prefs.getBool('uploadVerified') ?? false;
    reporterTokens = prefs.getInt('reporterTokens') ?? 0;
    
    final themeStr = prefs.getString('themeMode');
    if (themeStr == 'light') {
      themeMode = ThemeMode.light;
    } else if (themeStr == 'dark') {
      themeMode = ThemeMode.dark;
    } else {
      themeMode = ThemeMode.system;
    }

    preferredCategories = prefs.getStringList('preferredCategories') ?? [];
    hasPromptedPreferences = prefs.getBool('hasPromptedPreferences') ?? false;

    likedItemIds = (prefs.getStringList('likedItemIds') ?? []).toSet();
    
    // Initialize mock comments for demo purposes for the first article
    if (mockArticles.isNotEmpty) {
      final demoArticleId = mockArticles.first.id;
      final initialComments = mockComments.map((c) => Comment(
        id: c.id,
        username: c.username,
        avatarUrl: c.avatarUrl,
        text: c.text,
        postedAt: c.postedAt,
        likes: c.likes,
        isLikedByUser: c.isLikedByUser,
      )).toList();
      articleComments[demoArticleId] = initialComments;
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasOnboarded', hasOnboarded);
    await prefs.setString('language', language);
    await prefs.setString('stateName', stateName);
    await prefs.setString('district', district);
    await prefs.setBool('isLoggedIn', isLoggedIn);
    if (authToken != null) {
      await prefs.setString('authToken', authToken!);
    } else {
      await prefs.remove('authToken');
    }
    await prefs.setBool('isAdmin', isAdmin);
    await prefs.setString('userName', userName);
    await prefs.setString('userPhone', userPhone);
    await prefs.setString('themeMode', themeMode.name);
    await prefs.setStringList('preferredCategories', preferredCategories);
    await prefs.setBool('hasPromptedPreferences', hasPromptedPreferences);
    await prefs.setBool('isReporter', isReporter);
    await prefs.setBool('uploadVerified', uploadVerified);
    await prefs.setInt('reporterTokens', reporterTokens);
    await prefs.setStringList('likedItemIds', likedItemIds.toList());
  }

  /// Marks onboarding (language + location) as done. Login stays optional/
  /// skippable on every future launch, matching Way2News's "no login
  /// required" behavior — only language+location gate the splash skip.
  void completeOnboarding() {
    hasOnboarded = true;
    notifyListeners();
    _persist();
  }

  void setLanguage(String lang) {
    language = lang;
    notifyListeners();
    _persist();
  }

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    notifyListeners();
    _persist();
  }

  void setLocation(String state, String district) {
    stateName = state;
    this.district = district;
    hasOnboarded = true;
    notifyListeners();
    _persist();
  }

  void setPreferredCategories(List<String> categories) {
    preferredCategories = categories;
    hasPromptedPreferences = true;
    notifyListeners();
    _persist();
  }

  void markPreferencesPrompted() {
    hasPromptedPreferences = true;
    notifyListeners();
    _persist();
  }

  void toggleLike(String itemId) {
    if (likedItemIds.contains(itemId)) {
      likedItemIds.remove(itemId);
    } else {
      likedItemIds.add(itemId);
    }
    notifyListeners();
    _persist();
  }

  bool isLiked(String itemId) {
    return likedItemIds.contains(itemId);
  }

  /// Onboarding's quick phone+OTP login (skippable, used at first launch).
  void login(String phone) {
    isLoggedIn = true;
    authToken = 'mock_token_${DateTime.now().millisecondsSinceEpoch}';
    userPhone = phone;
    userName = 'Vasu';
    notifyListeners();
    _persist();
  }

  /// Full account signup — used by the Reporter Program's own auth flow.
  /// Note: this is a frontend-only mock. Nothing is hashed or sent to a
  /// real server; a production build must never store passwords like this.
  void signup({
    required String fullName,
    required String phone,
    required String password,
  }) {
    isLoggedIn = true;
    authToken = 'mock_token_${DateTime.now().millisecondsSinceEpoch}';
    userName = fullName;
    userPhone = phone;
    notifyListeners();
    _persist();
  }

  /// Full account login (username/full name + password). Mocked: accepts
  /// any non-empty credentials since there's no real backend to check
  /// against — a production build would verify against a real user store.
  Future<void> accountLogin({required String username, required String password}) async {
    try {
      final data = await ApiService.instance.login(username, password);
      isLoggedIn = true;
      authToken = data['access'] ?? data['token'] ?? 'mock_token_${DateTime.now().millisecondsSinceEpoch}';
      userName = data['user']?['username'] ?? data['user']?['first_name'] ?? username;
      notifyListeners();
      _persist();
    } catch (e) {
      // Fallback for demo/testing without real backend connection
      isLoggedIn = true;
      authToken = 'mock_token_${DateTime.now().millisecondsSinceEpoch}';
      userName = username;
      notifyListeners();
      _persist();
      throw Exception('Login failed: $e'); // Optionally bubble up
    }
  }

  void logout() {
    isLoggedIn = false;
    authToken = null;
    isAdmin = false;
    userName = 'Guest User';
    userPhone = '';
    notifyListeners();
    _persist();
  }


  // ---- Comments Program methods ----

  List<Comment> getComments(String articleId) {
    return articleComments[articleId] ?? [];
  }

  int getCommentCount(String articleId) {
    final comments = articleComments[articleId] ?? [];
    int count = comments.length;
    for (var c in comments) {
      count += c.replies.length;
    }
    return count;
  }

  void setComments(String articleId, List<Comment> comments) {
    articleComments[articleId] = comments;
    notifyListeners();
  }

  void addComment(String articleId, String text) {
    final newComment = Comment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      username: userName.isNotEmpty ? userName : 'Guest User',
      avatarUrl: 'https://i.pravatar.cc/150?u=${userName.hashCode}',
      text: text,
      postedAt: DateTime.now(),
    );
    
    if (!articleComments.containsKey(articleId)) {
      articleComments[articleId] = [];
    }
    articleComments[articleId]!.insert(0, newComment);
    notifyListeners();
  }

  void addReply(String articleId, String parentCommentId, String text) {
    final comments = articleComments[articleId] ?? [];
    
    // Find parent comment
    for (var comment in comments) {
      if (comment.id == parentCommentId) {
        comment.replies.add(Comment(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          username: userName.isNotEmpty ? userName : 'Guest User',
          avatarUrl: 'https://i.pravatar.cc/150?u=${userName.hashCode}',
          text: text,
          postedAt: DateTime.now(),
        ));
        break;
      }
    }
    notifyListeners();
  }

  void toggleCommentLike(String articleId, String commentId) {
    final comments = articleComments[articleId] ?? [];
    
    // Simple deep search for the comment (including replies)
    bool found = false;
    for (var comment in comments) {
      if (comment.id == commentId) {
        comment.isLikedByUser = !comment.isLikedByUser;
        comment.likes += comment.isLikedByUser ? 1 : -1;
        found = true;
        break;
      }
      for (var reply in comment.replies) {
        if (reply.id == commentId) {
          reply.isLikedByUser = !reply.isLikedByUser;
          reply.likes += reply.isLikedByUser ? 1 : -1;
          found = true;
          break;
        }
      }
      if (found) break;
    }
    notifyListeners();
  }

  void reportComment(String articleId, String commentId) {
    final comments = articleComments[articleId] ?? [];
    
    bool found = false;
    for (var comment in comments) {
      if (comment.id == commentId) {
        comment.isReported = true;
        found = true;
        break;
      }
      for (var reply in comment.replies) {
        if (reply.id == commentId) {
          reply.isReported = true;
          found = true;
          break;
        }
      }
      if (found) break;
    }
    notifyListeners();
  }

  // ---- Reporter Program methods ----

  /// Instantly registers the current account as a Reporter. No approval
  /// needed for the role itself — only individual posts need review.
  void registerAsReporter() {
    isReporter = true;
    notifyListeners();
    _persist();
  }

  /// Checks the one-time upload OTP. Mock code is always '1234'. Returns
  /// true on success and permanently marks the account as upload-verified,
  /// so this is never asked again for any future post.
  bool verifyUploadOtp(String code) {
    if (code.trim() == '1234') {
      uploadVerified = true;
      notifyListeners();
      _persist();
      return true;
    }
    return false;
  }

  /// Creates a new post in "pending review" state. Call only after
  /// confirming `uploadVerified` is true (verify via OTP first if not).
  ReporterPost submitReporterPost({
    required PostType type,
    required String caption,
    required String category,
    required String mediaUrl,
  }) {
    final post = ReporterPost(
      id: 'post_${DateTime.now().millisecondsSinceEpoch}',
      reporterName: userName,
      type: type,
      caption: caption,
      category: category,
      mediaUrl: mediaUrl,
      submittedAt: DateTime.now(),
    );
    reporterPosts.insert(0, post);
    notifyListeners();
    return post;
  }

  /// Demo admin action: approves a pending post and credits 1 token.
  void adminApprovePost(String postId) {
    final post = reporterPosts.firstWhere((p) => p.id == postId);
    post.status = PostStatus.approved;
    reporterTokens += 1;

    // Convert to live news article
    final newArticle = NewsArticle(
      id: 'approved_${post.id}',
      title: post.caption,
      summary: post.caption,
      body: post.caption,
      imageUrl: post.mediaUrl,
      source: post.reporterName,
      category: post.category,
      publishedAt: DateTime.now(),
      likes: 0,
      comments: 0,
      shares: 0,
      readTimeMinutes: 1,
    );
    mockArticles.insert(0, newArticle);

    notifyListeners();
    _persist();
  }

  /// Demo admin action: rejects a pending post — no token awarded.
  void adminRejectPost(String postId, [String? reason]) {
    final post = reporterPosts.firstWhere((p) => p.id == postId);
    post.status = PostStatus.rejected;
    post.rejectionReason = reason;
    notifyListeners();
  }

  /// Requests a payout once the reporter has at least 100 tokens. Deducts
  /// 100 tokens immediately and files the request for (demo) admin payout.
  /// Returns null if the reporter doesn't have enough tokens yet.
  RedeemRequest? requestRedeem(String upiId) {
    if (reporterTokens < tokensNeededToRedeem) return null;
    reporterTokens -= tokensNeededToRedeem;
    final request = RedeemRequest(
      id: 'redeem_${DateTime.now().millisecondsSinceEpoch}',
      tokensRedeemed: tokensNeededToRedeem,
      amountRupees: tokensNeededToRedeem * rupeesPerToken,
      upiId: upiId,
      requestedAt: DateTime.now(),
    );
    redeemRequests.insert(0, request);
    notifyListeners();
    _persist();
    return request;
  }

  /// Demo admin action: advances a redeem request's status.
  void adminUpdateRedeemStatus(String requestId, RedeemStatus status) {
    final request = redeemRequests.firstWhere((r) => r.id == requestId);
    request.status = status;
    notifyListeners();
  }
}
