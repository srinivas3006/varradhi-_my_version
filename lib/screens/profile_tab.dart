import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../core/navigation/auth_guard.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../core/utils/indian_mobile.dart';
import 'account_login_screen.dart';
import 'reporter_intro_screen.dart';
import '../features/admin/presentation/screens/admin_ugc_screen.dart';
import 'bookmarks_screen.dart';
import 'preferences_screen.dart';
import 'about_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';
import 'account_deletion_screen.dart';
import 'cms_page_screen.dart';
import '../services/cms_service.dart';
import 'notifications_screen.dart';
import '../widgets/spotlight/news_language_sheet.dart';
import 'my_posts_screen.dart';
import 'reporter_wallet_screen.dart';
import 'ad_booking_screen.dart';
import 'device_sessions_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import '../localization/app_translations.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key, this.showBackButton = false});

  /// True when opened as its own screen (from the Home header's profile
  /// button) rather than as a tab: adds a top bar with a back arrow.
  final bool showBackButton;

  /// Opens Profile over the current screen — the Home header's top-left
  /// button. Profile is no longer a bottom-bar tab.
  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/profile'),
          builder: (_) => const ProfileTab(showBackButton: true),
        ),
      );

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab>
    with SingleTickerProviderStateMixin {
  /// True while the avatar is uploading, so the save button cannot be
  /// tapped twice into two multipart requests.
  bool _savingProfile = false;

  late AnimationController _themeAnimController;

  @override
  void initState() {
    super.initState();
    _themeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    // Initial value for theme animation
    if (AppState.instance.themeMode == ThemeMode.dark) {
      _themeAnimController.value = 1.0;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && AppState.instance.isLoggedIn) {
        AppState.instance.refreshReporterDashboard();
      }
    });
  }

  @override
  void dispose() {
    _themeAnimController.dispose();
    super.dispose();
  }

  void _toggleTheme(AppState state) {
    HapticFeedback.lightImpact();

    // Determine what it currently is
    final isCurrentlyDark = state.themeMode == ThemeMode.dark ||
        (state.themeMode == ThemeMode.system &&
            Theme.of(context).brightness == Brightness.dark);

    final newMode = isCurrentlyDark ? ThemeMode.light : ThemeMode.dark;
    state.setThemeMode(newMode);

    if (newMode == ThemeMode.dark) {
      _themeAnimController.forward();
    } else {
      _themeAnimController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final state = AppState.instance;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = Theme.of(context).scaffoldBackgroundColor;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: widget.showBackButton
              ? AppBar(
                  backgroundColor: bgColor,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    key: const Key('profile_back_btn'),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  title: Text(
                    tr('nav_profile'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                )
              : null,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await AppState.instance.refreshReporterDashboard();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.only(
                    left: 16, right: 16, top: 16, bottom: 40),
                children: [
                  // 1. Identity Header Card
                  _buildIdentityCard(state, isDark),
                  const SizedBox(height: 12),

                  // Contact Us, on the first screen without scrolling —
                  // Play's News policy wants it easy to find (version 12
                  // was rejected for an in-app contact page reviewers did
                  // not find). Same CMS page as the item under About.
                  _buildContactUsButton(isDark),
                  const SizedBox(height: 16),

                  // 2. Dynamic Reporter Section (Guest vs Reader vs Reporter)
                  if (!state.hasJoinedAsReporter && !state.isAdmin) ...[
                    _buildBecomeReporterCard(),
                    const SizedBox(height: 16),
                  ] else if (state.isLoggedIn && state.hasJoinedAsReporter) ...[
                    _buildReporterDashboardCard(state, isDark),
                    const SizedBox(height: 16),
                    _buildRewardsCard(state, isDark),
                    const SizedBox(height: 16),
                  ],

                  // 3. Admin Access Badge (Conditional)
                  if (state.isAdmin || state.isContributor) ...[
                    _buildAdminCard(isDark),
                    const SizedBox(height: 16),
                  ],

                  // 4. Explore & Settings Group
                  _buildSectionTitle(tr('explore_saved'), isDark),
                  _buildSettingsGroup(isDark, [
                    _buildListTile(
                      isDark: isDark,
                      icon: Icons.bookmark_border_rounded,
                      title: tr('saved_articles'),
                      trailing: Icon(Icons.arrow_forward_ios_rounded,
                          color: isDark ? Colors.white38 : Colors.black26,
                          size: 16),
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const BookmarksScreen()));
                      },
                    ),
                    _buildListTile(
                      isDark: isDark,
                      icon: Icons.campaign_outlined,
                      title: tr('advertise_with_us'),
                      trailing: Icon(Icons.arrow_forward_ios_rounded,
                          color: isDark ? Colors.white38 : Colors.black26,
                          size: 16),
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AdBookingScreen()));
                      },
                    ),
                    _buildListTile(
                      isDark: isDark,
                      icon: Icons.devices_rounded,
                      title: 'యాక్టివ్ పరికర సెషన్‌లు',
                      trailing: Icon(Icons.arrow_forward_ios_rounded,
                          color: isDark ? Colors.white38 : Colors.black26,
                          size: 16),
                      onTap: () {
                        requireAuth(context, () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const DeviceSessionsScreen()));
                        });
                      },
                    ),
                  ]),

                  const SizedBox(height: 20),

                  _buildSectionTitle(tr('preferences'), isDark),
                  _buildSettingsGroup(isDark, [
                    _buildListTile(
                      isDark: isDark,
                      icon: Icons.tune,
                      title: tr('news_preferences'),
                      trailing: Icon(Icons.arrow_forward_ios_rounded,
                          color: isDark ? Colors.white38 : Colors.black26,
                          size: 16),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PreferencesScreen())),
                    ),
                    // News language: which news every feed shows (lang=te /
                    // en / all). Same sheet as the first-launch prompt.
                    _buildListTile(
                      key: const Key('profile_news_language'),
                      isDark: isDark,
                      icon: Icons.translate_rounded,
                      title: tr('content_language'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            switch (state.contentLanguage) {
                              'te' => 'తెలుగు',
                              'en' => 'English',
                              _ => state.language == 'Telugu'
                                  ? 'అన్ని భాషలు'
                                  : 'All',
                            },
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.arrow_forward_ios_rounded,
                              color: isDark ? Colors.white38 : Colors.black26,
                              size: 16),
                        ],
                      ),
                      onTap: () => NewsLanguageSheet.show(context),
                    ),
                    // Push Notifications Toggle
                    // Premium Notifications Tile
                    _buildListTile(
                      isDark: isDark,
                      icon: Icons.notifications_none_rounded,
                      title: tr('notifications'),
                      badgeCount: state.unreadNotificationsCount,
                      trailing: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          state.togglePushNotifications(
                              !state.pushNotificationsEnabled);
                        },
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, anim) =>
                              ScaleTransition(scale: anim, child: child),
                          child: Icon(
                            state.pushNotificationsEnabled
                                ? Icons.notifications_active_rounded
                                : Icons.notifications_off_rounded,
                            key: ValueKey(state.pushNotificationsEnabled),
                            color: state.pushNotificationsEnabled
                                ? Colors.redAccent
                                : (isDark ? Colors.white38 : Colors.black38),
                            size: 24,
                          ),
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const NotificationsScreen()));
                      },
                    ),
                    // Animated Theme Switch Tile
                    _buildListTile(
                      isDark: isDark,
                      icon: Icons.palette_outlined,
                      title: tr('dark_mode'),
                      trailing: GestureDetector(
                        onTap: () => _toggleTheme(state),
                        child: RotationTransition(
                          turns: _themeAnimController,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.amber.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              isDark ? '🌙' : '☀️',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      ),
                      onTap: () => _toggleTheme(state),
                    ),
                  ]),

                  const SizedBox(height: 20),

                  _buildSectionTitle(tr('about_legal'), isDark),
                  _buildSettingsGroup(isDark, [
                    _buildListTile(
                      isDark: isDark,
                      icon: Icons.info_outline_rounded,
                      title: tr('about'),
                      trailing: Icon(Icons.arrow_forward_ios_rounded,
                          color: isDark ? Colors.white38 : Colors.black26,
                          size: 16),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AboutScreen())),
                    ),
                    _buildListTile(
                      isDark: isDark,
                      icon: Icons.lock_outline_rounded,
                      title: tr('privacy_policy'),
                      trailing: Icon(Icons.arrow_forward_ios_rounded,
                          color: isDark ? Colors.white38 : Colors.black26,
                          size: 16),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PrivacyPolicyScreen())),
                    ),
                    _buildListTile(
                      isDark: isDark,
                      icon: Icons.description_outlined,
                      title: tr('terms_of_service'),
                      trailing: Icon(Icons.arrow_forward_ios_rounded,
                          color: isDark ? Colors.white38 : Colors.black26,
                          size: 16),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const TermsScreen())),
                    ),
                    _buildListTile(
                      key: const Key('profile_contact_us'),
                      isDark: isDark,
                      icon: Icons.support_agent_rounded,
                      title: tr('contact_us'),
                      trailing: Icon(Icons.arrow_forward_ios_rounded,
                          color: isDark ? Colors.white38 : Colors.black26,
                          size: 16),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => CMSPageScreen(
                                  slug: CmsSlugs.contact,
                                  initialTitle: tr('contact_us')))),
                    ),
                    // Account deletion request (Play policy: an in-app path
                    // to delete the account). Logged-in readers only.
                    if (state.isLoggedIn)
                      _buildListTile(
                        key: const Key('profile_delete_account'),
                        isDark: isDark,
                        icon: Icons.person_remove_outlined,
                        title: state.language == 'Telugu'
                            ? 'ఖాతా తొలగింపు అభ్యర్థన'
                            : 'Request account deletion',
                        trailing: Icon(Icons.arrow_forward_ios_rounded,
                            color: isDark ? Colors.white38 : Colors.black26,
                            size: 16),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AccountDeletionScreen())),
                      ),
                  ]),

                  const SizedBox(height: 24),

                  // 5. Account Management / Logout or Login Button
                  if (state.isLoggedIn)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.logout_rounded,
                            color: Colors.redAccent, size: 20),
                        label: Text(tr('log_out').toUpperCase(),
                            style: const TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold)),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          state.logout();
                        },
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF3D3D),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.login_rounded,
                            color: Colors.white, size: 20),
                        label: const Text(
                          'లాగిన్ / రిజిస్టర్',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AccountLoginScreen()));
                        },
                      ),
                    ),

                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'వారధి న్యూస్ v1.0.0',
                      style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Identity Header Card (Guest vs Logged-In)
  Widget _buildIdentityCard(AppState state, bool isDark) {
    if (!state.isLoggedIn) {
      // Premium Guest User Card (Symmetric with Logged-In Card)
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AccountLoginScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.04),
              ),
            ),
            child: Row(
              children: [
                // Avatar (Diameter 56, matching Logged-In avatar)
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6A6A), Color(0xFFFF3D3D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF3D3D).withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'G',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Text Block (Name + Action Cue)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'గెస్ట్ యూజర్',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'లాగిన్ చేయడానికి ఇక్కడ నొక్కండి',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),

                // Trailing Arrow
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: isDark ? Colors.white38 : Colors.black26,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Logged-In User Card
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showEditProfilePopup(state, isDark);
                },
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFFF3D3D),
                  backgroundImage: state.profileAvatar,
                  child: state.profileAvatar == null
                      ? Text(
                          state.userName.isNotEmpty
                              ? state.userName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showEditProfilePopup(state, isDark);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade800 : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? Colors.grey.shade700
                            : Colors.grey.shade200,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.edit_rounded,
                      size: 12,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        state.userName == 'Guest User'
                            ? 'గెస్ట్ యూజర్'
                            : state.userName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (state.isAdmin) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8)),
                        child: const Text(
                          'అడ్మిన్',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ],
                ),
                // Verified mobile from /auth/me/ — shown only when the
                // backend says mobile_verified; no bare "+91" otherwise.
                if (state.profileVerifiedMobile.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '+91 ${IndianMobile.format(state.profileVerifiedMobile)}',
                    key: const Key('profile_verified_mobile'),
                    style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "Become a Reporter" CTA Card
  Widget _buildBecomeReporterCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.redAccent.shade700, Colors.deepOrange.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.campaign_rounded, color: Colors.white, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('become_reporter'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  tr('become_reporter_sub'),
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ReporterIntroScreen()));
            },
            child: Text(tr('join').toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Reporter Dashboard Card (Wallet + Submissions)
  Widget _buildReporterDashboardCard(AppState state, bool isDark) {
    final pendingCount = state.pendingCount;
    final approvedCount = state.approvedCount;
    final publishedCount = state.publishedCount;
    final rejectedCount = state.rejectedCount;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const MyPostsScreen()));
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_rounded,
                        color: Colors.green, size: 20),
                    const SizedBox(width: 6),
                    Text(tr('reporter_dashboard').toUpperCase(),
                        style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    color: isDark ? Colors.white38 : Colors.black26, size: 16),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatusStat(tr('pending'), pendingCount.toString(),
                    Colors.amber, isDark),
                _buildStatusStat(tr('approved'), approvedCount.toString(),
                    Colors.blueAccent, isDark),
                _buildStatusStat(tr('published'), publishedCount.toString(),
                    Colors.green, isDark),
                _buildStatusStat(tr('rejected'), rejectedCount.toString(),
                    Colors.redAccent, isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardsCard(AppState state, bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        requireAuth(
          context,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReporterWalletScreen()),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFF5A623)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFF5A623).withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  tr('rewards_earnings'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusStat(
      String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54, fontSize: 11)),
      ],
    );
  }

  /// Admin Queue Quick Card
  Widget _buildAdminCard(bool isDark) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const AdminUgcScreen()));
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.purple.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.purple.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.admin_panel_settings_rounded,
                color: Colors.purple, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('admin_desk_review'),
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold)),
                  Text(tr('review_reporter_posts'),
                      style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.purple, size: 16),
          ],
        ),
      ),
    );
  }

  /// A labelled "Contact Us" button near the top of Profile.
  Widget _buildContactUsButton(bool isDark) {
    final telugu = AppState.instance.language == 'Telugu';
    return Material(
      color: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: const Key('profile_contact_us_top'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CMSPageScreen(
              slug: CmsSlugs.contact,
              initialTitle: tr('contact_us'),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.support_agent_rounded,
                  color: AppColors.primary, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      telugu
                          ? 'మమ్మల్ని సంప్రదించండి (Contact Us)'
                          : 'Contact Us',
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      telugu
                          ? 'ఇమెయిల్, ఫోన్ ద్వారా మమ్మల్ని సంప్రదించండి'
                          : 'Reach us by email or phone',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.notoSansTelugu(
          color: isDark ? Colors.white38 : Colors.black45,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(bool isDark, List<Widget> tiles) {
    return Material(
      color: isDark
          ? Colors.white.withValues(alpha: 0.04)
          : Colors.black.withValues(alpha: 0.02),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: tiles,
      ),
    );
  }

  Widget _buildListTile({
    Key? key,
    required bool isDark,
    required IconData icon,
    required String title,
    required Widget trailing,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return ListTile(
      key: key,
      onTap: onTap,
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: isDark ? Colors.white70 : Colors.black87, size: 22),
          if (badgeCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
      title: Text(
        title,
        style: GoogleFonts.notoSansTelugu(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: trailing,
    );
  }

  void _showEditProfilePopup(AppState state, bool isDark) {
    final TextEditingController nameController =
        TextEditingController(text: state.userName);
    String? tempImagePath = state.profileImagePath;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20)
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Text(
                        'ప్రొఫైల్ సవరణ',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          // Phone photos are often 5-10 MB; an avatar never
                          // needs that, and big uploads fail on slow networks.
                          final pickedFile = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 1024,
                            maxHeight: 1024,
                            imageQuality: 85,
                          );
                          if (pickedFile != null) {
                            setModalState(() {
                              tempImagePath = pickedFile.path;
                            });
                          }
                        },
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 46,
                              backgroundColor: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200,
                              // A new pick previews from disk; otherwise the
                              // current photo (often only on the server).
                              backgroundImage: tempImagePath != null &&
                                      tempImagePath!.isNotEmpty
                                  ? FileImage(File(tempImagePath!))
                                  : state.profileAvatar,
                              child: (tempImagePath == null ||
                                          tempImagePath!.isEmpty) &&
                                      state.profileAvatar == null
                                  ? Icon(Icons.person,
                                      size: 40,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.black54)
                                  : null,
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF1E1E1E)
                                        : Colors.white,
                                    width: 2),
                              ),
                              child: const Icon(Icons.camera_alt_rounded,
                                  size: 16, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: nameController,
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          labelText: 'పూర్తి పేరు',
                          labelStyle: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black54),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.03),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          onPressed: _savingProfile
                              ? null
                              : () async {
                                  final messenger =
                                      ScaffoldMessenger.of(context);
                                  setModalState(() => _savingProfile = true);

                                  // Awaited so the avatar upload can report
                                  // failure — firing and forgetting left a
                                  // rejected upload looking like a save.
                                  final ok = await state.updateProfile(
                                    name: nameController.text.trim(),
                                    imagePath: tempImagePath,
                                  );
                                  if (!context.mounted) return;
                                  setModalState(() => _savingProfile = false);

                                  if (ok) {
                                    Navigator.pop(context);
                                    return;
                                  }
                                  messenger
                                    ..removeCurrentSnackBar()
                                    ..showSnackBar(SnackBar(
                                      content: Text(
                                        state.language == 'Telugu'
                                            ? 'ప్రొఫైల్ సేవ్ చేయడం విఫలమైంది.'
                                            : 'Could not save your profile.',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ));
                                },
                          child: _savingProfile
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.2, color: Colors.white),
                                )
                              : const Text('మార్పులను సేవ్ చేయండి',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() => nameController.dispose());
  }
}
