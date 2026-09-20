import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../core/navigation/auth_guard.dart';
import '../state/app_state.dart';
import '../models/reporter_post.dart';
import 'account_login_screen.dart';
import 'reporter_intro_screen.dart';
import '../features/admin/presentation/screens/admin_ugc_screen.dart';
import 'bookmarks_screen.dart';
import 'preferences_screen.dart';
import 'about_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';
import 'notifications_screen.dart';
import 'my_posts_screen.dart';
import 'reporter_wallet_screen.dart';
import 'ad_booking_screen.dart';
import 'device_sessions_screen.dart';
import '../localization/app_translations.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> with SingleTickerProviderStateMixin {
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
                            (state.themeMode == ThemeMode.system && Theme.of(context).brightness == Brightness.dark);
    
    final newMode = isCurrentlyDark ? ThemeMode.light : ThemeMode.dark;
    state.setThemeMode(newMode);
    
    if (newMode == ThemeMode.dark) {
      _themeAnimController.forward();
    } else {
      _themeAnimController.reverse();
    }
  }

  void _handleGatedAction(AppState state, VoidCallback onAuthorized) {
    if (!state.isLoggedIn) {
      HapticFeedback.warningNotification();
      _showLoginRequiredDialog();
    } else {
      onAuthorized();
    }
  }

  void _showLoginRequiredDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(tr('account_required'), style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: Text(
          tr('account_required_sub'),
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('cancel'), style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountLoginScreen()));
            },
            child: Text(tr('log_in'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
          body: SafeArea(
            child: ListView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 40),
              children: [
                // 1. Identity Header Card
                _buildIdentityCard(state, isDark),
                const SizedBox(height: 16),

                // 2. Dynamic Reporter Section (Guest vs Reader vs Reporter)
                if (state.isLoggedIn && !state.isReporter && !state.isAdmin) ...[
                  _buildBecomeReporterCard(),
                  const SizedBox(height: 16),
                ] else if (state.isLoggedIn && state.isReporter && !state.isAdmin) ...[
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
                    trailing: Icon(Icons.arrow_forward_ios_rounded, color: isDark ? Colors.white38 : Colors.black26, size: 16),
                    onTap: () => _handleGatedAction(state, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const BookmarksScreen()));
                    }),
                  ),
                  _buildListTile(
                    isDark: isDark,
                    icon: Icons.campaign_outlined,
                    title: tr('advertise_with_us'),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, color: isDark ? Colors.white38 : Colors.black26, size: 16),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdBookingScreen()));
                    },
                  ),
                  if (state.isLoggedIn)
                    _buildListTile(
                      isDark: isDark,
                      icon: Icons.devices_rounded,
                      title: 'యాక్టివ్ పరికర సెషన్‌లు',
                      trailing: Icon(Icons.arrow_forward_ios_rounded, color: isDark ? Colors.white38 : Colors.black26, size: 16),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const DeviceSessionsScreen()));
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
                    trailing: Icon(Icons.arrow_forward_ios_rounded, color: isDark ? Colors.white38 : Colors.black26, size: 16),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PreferencesScreen())),
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
                        state.togglePushNotifications(!state.pushNotificationsEnabled);
                      },
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                        child: Icon(
                          state.pushNotificationsEnabled ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
                          key: ValueKey(state.pushNotificationsEnabled),
                          color: state.pushNotificationsEnabled ? Colors.redAccent : (isDark ? Colors.white38 : Colors.black38),
                          size: 24,
                        ),
                      ),
                    ),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
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
                            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.2),
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
                    trailing: Icon(Icons.arrow_forward_ios_rounded, color: isDark ? Colors.white38 : Colors.black26, size: 16),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen())),
                  ),
                  _buildListTile(
                    isDark: isDark,
                    icon: Icons.lock_outline_rounded,
                    title: tr('privacy_policy'),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, color: isDark ? Colors.white38 : Colors.black26, size: 16),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
                  ),
                  _buildListTile(
                    isDark: isDark,
                    icon: Icons.description_outlined,
                    title: tr('terms_of_service'),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, color: isDark ? Colors.white38 : Colors.black26, size: 16),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen())),
                  ),
                ]),

                const SizedBox(height: 24),

                // 5. Account Management / Logout Button
                if (state.isLoggedIn)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                      label: Text(tr('log_out').toUpperCase(), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        state.logout();
                      },
                    ),
                  ),
                  
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'Vaaradhi v1.0.0',
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38, 
                      fontSize: 12,
                      fontWeight: FontWeight.w600
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Identity Header Card (Guest vs Logged-In)
  Widget _buildIdentityCard(AppState state, bool isDark) {
    if (!state.isLoggedIn) {
      // Premium Guest User Card
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
          ),
        ),
        child: Row(
          children: [
            // Avatar (Size 58, vibrant red gradient, clean centered G)
            Container(
              width: 58,
              height: 58,
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
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Text Block (Greeting + User State)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'స్వాగతం',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'గెస్ట్ యూజర్',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
            ),

            // Login Button (Primary CTA)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3D3D),
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: const Color(0xFFFF3D3D).withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.login_rounded, size: 16, color: Colors.white),
              label: const Text(
                'లాగిన్ అవ్వండి',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AccountLoginScreen()),
                );
              },
            ),
          ],
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
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
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
                  backgroundImage: state.profileImagePath != null && state.profileImagePath!.isNotEmpty
                      ? FileImage(File(state.profileImagePath!))
                      : null,
                  child: state.profileImagePath == null || state.profileImagePath!.isEmpty
                      ? Text(
                          state.userName.isNotEmpty ? state.userName[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
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
                        color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
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
                        state.userName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (state.isAdmin) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                        child: const Text(
                          'అడ్మిన్',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '+91 ${state.userPhone}',
                  style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13),
                ),
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
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  tr('become_reporter_sub'),
                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ReporterIntroScreen()));
            },
            child: Text(tr('join').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Reporter Dashboard Card (Wallet + Submissions)
  Widget _buildReporterDashboardCard(AppState state, bool isDark) {
    final pendingCount = state.reporterPosts.where((p) => p.status == PostStatus.pending).length;
    final approvedCount = state.reporterPosts.where((p) => p.status == PostStatus.approved).length;
    final publishedCount = state.reporterPosts.where((p) => p.status == PostStatus.published).length;
    final rejectedCount = state.reporterPosts.where((p) => p.status == PostStatus.rejected).length;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(context, MaterialPageRoute(builder: (_) => const MyPostsScreen()));
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
          boxShadow: isDark ? [] : [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
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
                    const Icon(Icons.verified_rounded, color: Colors.green, size: 20),
                    const SizedBox(width: 6),
                    Text(tr('reporter_dashboard').toUpperCase(), style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: isDark ? Colors.white38 : Colors.black26, size: 16),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatusStat(tr('pending'), pendingCount.toString(), Colors.amber, isDark),
                _buildStatusStat(tr('approved'), approvedCount.toString(), Colors.blueAccent, isDark),
                _buildStatusStat(tr('published'), publishedCount.toString(), Colors.green, isDark),
                _buildStatusStat(tr('rejected'), rejectedCount.toString(), Colors.redAccent, isDark),
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
            BoxShadow(color: const Color(0xFFF5A623).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))
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
                  child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  tr('rewards_earnings'),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusStat(String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 11)),
      ],
    );
  }

  /// Admin Queue Quick Card
  Widget _buildAdminCard(bool isDark) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUgcScreen()));
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
            const Icon(Icons.admin_panel_settings_rounded, color: Colors.purple, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('admin_desk_review'), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                  Text(tr('review_reporter_posts'), style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.purple, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
      ),
    );
  }

  Widget _buildSettingsGroup(bool isDark, List<Widget> tiles) {
    return Material(
      color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: tiles,
      ),
    );
  }

  Widget _buildListTile({
    required bool isDark,
    required IconData icon,
    required String title,
    required Widget trailing,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return ListTile(
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
      title: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: trailing,
    );
  }

    void _showEditProfilePopup(AppState state, bool isDark) {
      final TextEditingController nameController = TextEditingController(text: state.userName);
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
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20)
                  ],
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
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
                            final pickedFile = await picker.pickImage(source: ImageSource.gallery);
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
                                backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                                backgroundImage: tempImagePath != null && tempImagePath!.isNotEmpty
                                    ? FileImage(File(tempImagePath!))
                                    : null,
                                child: tempImagePath == null || tempImagePath!.isEmpty
                                    ? Icon(Icons.person, size: 40, color: isDark ? Colors.white54 : Colors.black54)
                                    : null,
                              ),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: nameController,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            labelText: 'పూర్తి పేరు',
                            labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                            filled: true,
                            fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            onPressed: _savingProfile
                                ? null
                                : () async {
                                    final messenger =
                                        ScaffoldMessenger.of(context);
                                    setModalState(
                                        () => _savingProfile = true);

                                    // Awaited so the avatar upload can report
                                    // failure — firing and forgetting left a
                                    // rejected upload looking like a save.
                                    final ok = await state.updateProfile(
                                      name: nameController.text.trim(),
                                      imagePath: tempImagePath,
                                    );
                                    if (!context.mounted) return;
                                    setModalState(
                                        () => _savingProfile = false);

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
                                        strokeWidth: 2.2,
                                        color: Colors.white),
                                  )
                                : const Text('మార్పులను సేవ్ చేయండి', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
