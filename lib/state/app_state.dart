import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/news_article.dart';
import '../models/redeem_request.dart';
import '../models/reporter_post.dart';

/// Simple app-wide state singleton. Scalar fields (onboarding completion,
/// language, location, coins, login, reporter status) survive app restarts
/// via shared_preferences. The auth token is the one exception: it's kept
/// out of shared_preferences (which is plaintext, unencrypted disk storage
/// on both Android and iOS) and instead lives in flutter_secure_storage,
/// which is backed by Keychain on iOS and EncryptedSharedPreferences /
/// Keystore on Android.
/// Lists (posts, redeem requests) are kept in-memory only for this demo —
/// a real backend would own them.
class AppState extends ChangeNotifier {
  static const _secureStorage = FlutterSecureStorage();
  static const _authTokenKey = 'authToken';

  // Local persistence for likes/comments until backend supports it
  Set<String> likedItemIds = {};
  Set<String> bookmarkedItemIds = {};
  Map<String, List<String>> localComments = {};

  AppState._internal();
  static final AppState instance = AppState._internal();

  String language = 'English';
  String stateName = 'Telangana';
  String district = 'Hyderabad';
  bool isLoggedIn = false;

  /// Never persisted via SharedPreferences. See init()/setAuthToken()/
  /// _clearAuthToken() — this is loaded from and written to secure storage.
  String? authToken;

  /// NOTE: this is a UI convenience flag only. It must never be trusted for
  /// authorization decisions — any admin-only API call must be re-checked
  /// server-side against the token, since a locally-stored bool can always
  /// be flipped on a rooted/jailbroken device.
  bool isAdmin = false;
  String userName = 'Guest User';
  String userPhone = '';
  String? fcmToken;
  ThemeMode themeMode = ThemeMode.system;

  List<String> preferredCategories = [];
  bool hasPromptedPreferences = false;

  /// True once the user has completed language + location selection at
  /// least once. When true, the splash screen skips straight to Home.
  bool hasOnboarded = false;

  /// True if the user has already been prompted for location permission
  /// in the feed. Ensures we only ask once.
  bool locationPrompted = false;
  
  /// True if the user successfully granted location permissions and we fetched real GPS data
  bool hasValidLocation = false;

  /// True if the user has push notifications enabled globally in their profile
  bool pushNotificationsEnabled = true;

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
    isAdmin = prefs.getBool('isAdmin') ?? false;
    userName = prefs.getString('userName') ?? userName;
    userPhone = prefs.getString('userPhone') ?? userPhone;
    isReporter = prefs.getBool('isReporter') ?? false;
    uploadVerified = prefs.getBool('uploadVerified') ?? false;
    reporterTokens = prefs.getInt('reporterTokens') ?? 0;

    // Auth token comes from secure storage, not shared_preferences.
    authToken = await _secureStorage.read(key: _authTokenKey);
    // If we don't actually have a token, don't trust a stale isLoggedIn flag.
    if (authToken == null) {
      isLoggedIn = false;
    }

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
    locationPrompted = prefs.getBool('locationPrompted') ?? false;
    hasValidLocation = prefs.getBool('hasValidLocation') ?? false;
    pushNotificationsEnabled = prefs.getBool('pushNotificationsEnabled') ?? true;

    likedItemIds = (prefs.getStringList('likedItemIds') ?? []).toSet();
    bookmarkedItemIds = (prefs.getStringList('bookmarkedItemIds') ?? []).toSet();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasOnboarded', hasOnboarded);
    await prefs.setString('language', language);
    await prefs.setString('stateName', stateName);
    await prefs.setString('district', district);
    await prefs.setBool('isLoggedIn', isLoggedIn);
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
    await prefs.setStringList('bookmarkedItemIds', bookmarkedItemIds.toList());
    await prefs.setBool('locationPrompted', locationPrompted);
    await prefs.setBool('hasValidLocation', hasValidLocation);
    await prefs.setBool('pushNotificationsEnabled', pushNotificationsEnabled);
    // Deliberately no authToken here — see setAuthToken/_clearAuthToken.
  }

  /// Stores a freshly-issued auth token in secure storage and marks the
  /// user logged in. This is the only path that should ever set authToken.
  Future<void> setAuthToken(String token) async {
    authToken = token;
    isLoggedIn = true;
    await _secureStorage.write(key: _authTokenKey, value: token);
    notifyListeners();
    await _persist();
  }

  Future<void> _clearAuthToken() async {
    authToken = null;
    await _secureStorage.delete(key: _authTokenKey);
  }

  /// Marks onboarding (language + location) as done. Login stays optional/
  /// skippable on every future launch, matching Way2News's "no login
  /// required" behavior — only language+location gate the splash skip.
  void completeOnboarding([String? defaultLang]) {
    hasOnboarded = true;
    if (defaultLang != null) {
      language = defaultLang;
    }
    notifyListeners();
    _persist();
  }

  void markLocationPrompted() {
    locationPrompted = true;
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

  void togglePushNotifications(bool value) {
    pushNotificationsEnabled = value;
    notifyListeners();
    _persist();
  }

  void setLocation(String state, String district) {
    stateName = state;
    this.district = district;
    hasOnboarded = true;
    hasValidLocation = true;
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

  void toggleBookmark(String itemId) {
    if (bookmarkedItemIds.contains(itemId)) {
      bookmarkedItemIds.remove(itemId);
    } else {
      bookmarkedItemIds.add(itemId);
    }
    notifyListeners();
    _persist();
  }

  bool isLiked(String itemId) {
    return likedItemIds.contains(itemId);
  }

  bool isBookmarked(String itemId) {
    return bookmarkedItemIds.contains(itemId);
  }

  /// Onboarding's quick phone+OTP login (skippable, used at first launch).
  /// TODO(backend): this still issues a client-side mock token. Once the
  /// OTP-verify endpoint exists, this should call it and use setAuthToken
  /// with the real token it returns, same as accountLogin below.
  void login(String phone) {
    userPhone = phone;
    userName = 'Vasu';
    setAuthToken('mock_token_${DateTime.now().millisecondsSinceEpoch}');
  }

  /// Full account signup — used by the Reporter Program's own auth flow.
  /// TODO(backend): this is still a frontend-only mock. The real signup
  /// endpoint must hash the password server-side; the app must never store
  /// or transmit it except over TLS directly to that endpoint, and must
  /// never persist it locally in any form.
  void signup({
    required String fullName,
    required String phone,
    required String password,
  }) {
    userName = fullName;
    userPhone = phone;
    setAuthToken('mock_token_${DateTime.now().millisecondsSinceEpoch}');
  }

  /// Records a full account login. Expects the caller (e.g. the login
  /// screen) to have already exchanged credentials for a token via
  /// ApiService and called setAuthToken with the real token — this method
  /// only updates the display name. It never accepts a password and never
  /// falls back to a mock-logged-in state on failure.
  void accountLogin({required String username}) {
    userName = username;
    notifyListeners();
    _persist();
  }

  Future<void> logout() async {
    /*
    // TODO: Uncomment when ready to integrate backend session revocation
    try {
      // In production, fetch the actual refresh token from secure storage
      final String refreshToken = "stored-refresh-token"; 
      await ApiService.instance.logout(refreshToken, logoutAllDevices: false);
    } catch (e) {}
    */

    isLoggedIn = false;
    isAdmin = false;
    userName = 'Guest User';
    userPhone = '';
    await _clearAuthToken();
    notifyListeners();
    await _persist();
  }

  /*
  // TODO: Uncomment this method when adding the "Logout of all devices" UI button
  Future<void> logoutAllDevices() async {
    try {
      final String refreshToken = "stored-refresh-token"; 
      await ApiService.instance.logout(refreshToken, logoutAllDevices: true);
      await logout(); // Clear local state after backend invalidates all sessions
    } catch (e) {}
  }
  */


  // ---- Comments Program methods ----

  final Map<String, int> userAddedComments = {};

  List<Comment> getComments(String articleId) {
    if (!articleComments.containsKey(articleId)) {
      _seedMockComments(articleId);
    }
    return articleComments[articleId]!;
  }

  void _seedMockComments(String articleId) {
    final mockTexts = [
      "Very informative article, thanks for sharing!",
      "I totally agree with this.",
      "This is a big issue in our area right now.",
      "Can we get more coverage on this topic?",
      "Excellent reporting.",
      "Hope the authorities take action soon.",
      "Superb! Great work by the team.",
      "This needs more attention from the government.",
      "Informative piece. Please keep us updated.",
      "Very sad to see this happen."
    ];
    final mockNames = [
      "Ravi Kumar", "Srinivas", "Priya", "Krishna", "Venkatesh", 
      "Suresh", "Ramesh", "Anitha", "Lakshmi", "Karthik"
    ];
    
    mockTexts.shuffle();
    mockNames.shuffle();
    
    final commentsList = <Comment>[];
    // Generate 4 to 8 mock comments based on articleId hash
    final count = 4 + (articleId.hashCode.abs() % 5); 
    for (int i = 0; i < count; i++) {
      final name = mockNames[i % mockNames.length];
      commentsList.add(
        Comment(
          id: 'mock_c_${articleId}_$i',
          username: name,
          avatarUrl: 'https://i.pravatar.cc/150?u=${name.hashCode}',
          text: mockTexts[i % mockTexts.length],
          postedAt: DateTime.now().subtract(Duration(minutes: (i + 1) * 15)),
          likes: (i * 7) % 25,
        ),
      );
    }
    articleComments[articleId] = commentsList;
  }

  int getDisplayCommentCount(String articleId, int baseCount) {
    return baseCount + (userAddedComments[articleId] ?? 0);
  }

  int getCommentCount(String articleId) {
    // Kept for backward compatibility if needed, but getDisplayCommentCount is preferred
    return getDisplayCommentCount(articleId, 0);
  }

  void addComment(String articleId, String text) {
    if (!articleComments.containsKey(articleId)) {
      _seedMockComments(articleId);
    }
    
    final newComment = Comment(
      id: 'c_${DateTime.now().millisecondsSinceEpoch}',
      username: isLoggedIn ? userName : 'Guest User',
      avatarUrl: 'https://i.pravatar.cc/150?u=${(isLoggedIn ? userName : 'Guest User').hashCode}',
      text: text,
      postedAt: DateTime.now(),
      likes: 0,
    );
    
    articleComments[articleId]!.insert(0, newComment);
    userAddedComments[articleId] = (userAddedComments[articleId] ?? 0) + 1;
    notifyListeners();
  }

  void setComments(String articleId, List<Comment> comments) {
    articleComments[articleId] = comments;
    notifyListeners();
  }



  void addReply(String articleId, String parentCommentId, String text) {
    if (!articleComments.containsKey(articleId)) {
      _seedMockComments(articleId);
    }
    final comments = articleComments[articleId]!;

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
        userAddedComments[articleId] = (userAddedComments[articleId] ?? 0) + 1;
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
