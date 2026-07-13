import 'package:flutter/material.dart';
import '../localization/app_translations.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'account_login_screen.dart';
import 'admin_panel_screen.dart';

import 'create_post_screen.dart';
import 'language_screen.dart';
import 'my_posts_screen.dart';
import 'reporter_intro_screen.dart';
import 'reporter_wallet_screen.dart';

import 'live_news_screen.dart';
import 'device_sessions_screen.dart';
import 'ad_booking_screen.dart';
import 'preferences_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _pushNotifications = true;

  void _showPasswordChangeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                obscureText: true,
                decoration: InputDecoration(labelText: 'Current Password'),
              ),
              TextField(
                obscureText: true,
                decoration: InputDecoration(labelText: 'New Password'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password changed successfully.')),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final state = AppState.instance;
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      state.userName.isNotEmpty ? state.userName[0] : 'G',
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(state.userName,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          state.isLoggedIn
                              ? '+91 ${state.userPhone}'
                              : tr('not_logged_in'),
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  if (!state.isLoggedIn)
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AccountLoginScreen()),
                      ),
                      child: Text(tr('log_in')),
                    ),
                ],
              ),

              _buildAdminSection(context, state),
              _buildReporterSection(context, state),
              const SizedBox(height: 24),
              const Text('Explore',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 4),
              _settingsTile(
                icon: Icons.campaign_outlined,
                title: 'Advertise with Us',
                color: AppColors.primary,
                onTap: () {
                  if (!AppState.instance.isLoggedIn) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AccountLoginScreen()),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdBookingScreen()),
                    );
                  }
                },
              ),

              _settingsTile(
                icon: Icons.live_tv_outlined,
                title: 'Live News',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LiveNewsScreen()),
                ),
              ),


              const SizedBox(height: 24),
              Text(tr('settings'),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 12),
              _settingsTile(
                icon: Icons.tune,
                title: AppState.instance.language == 'Telugu' ? 'కంటెంట్ అభిరుచులు' : 'News Preferences',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PreferencesScreen()),
                  );
                },
              ),
              _settingsTile(
                icon: Icons.language,
                title: tr('language'),
                trailing: Text(state.language,
                    style: const TextStyle(color: AppColors.textMuted)),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LanguageScreen()),
                ),
              ),
              _settingsSwitch(
                icon: Icons.notifications_none_rounded,
                title: tr('push_notifications'),
                value: _pushNotifications,
                onChanged: (v) => setState(() => _pushNotifications = v),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  state.themeMode == ThemeMode.dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
                title: Text(tr('dark_mode'), style: const TextStyle(fontSize: 14)),
                trailing: _ThemeToggleSwitch(
                  isDark: state.themeMode == ThemeMode.dark || (state.themeMode == ThemeMode.system && Theme.of(context).brightness == Brightness.dark),
                  onChanged: (isDark) {
                    AppState.instance.setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
                  },
                ),
              ),
              _settingsTile(
                icon: Icons.info_outline,
                title: tr('about'),
                onTap: () {},
              ),
              _settingsTile(
                icon: Icons.privacy_tip_outlined,
                title: tr('privacy_policy'),
                onTap: () {},
              ),

              const SizedBox(height: 8),
              if (state.isLoggedIn) ...[
                _settingsTile(
                  icon: Icons.devices,
                  title: 'Device Sessions',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DeviceSessionsScreen()),
                  ),
                ),
                _settingsTile(
                  icon: Icons.lock_outline,
                  title: 'Change Password',
                  onTap: _showPasswordChangeDialog,
                ),
                _settingsTile(
                  icon: Icons.logout,
                  title: tr('log_out'),
                  color: Colors.red,
                  onTap: () {
                    AppState.instance.logout();
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAdminSection(BuildContext context, AppState state) {
    if (!state.isAdmin) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.admin_panel_settings_outlined, color: Colors.red, size: 20),
                SizedBox(width: 8),
                Text('Admin Access',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.fact_check_outlined, size: 18),
                label: const Text('Review Reporter Posts'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReporterSection(BuildContext context, AppState state) {
    // Guests can't become reporters until they have a real account.
    if (!state.isLoggedIn) {
      return const SizedBox.shrink();
    }

    if (!state.isReporter) {
      // CTA card inviting a logged-in (non-reporter) user to join.
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.campaign_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Become a Reporter',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  SizedBox(height: 2),
                  Text('Post news, get it reviewed, earn ₹5 per approved post.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReporterIntroScreen()),
              ),
              child: const Text('Join'),
            ),
          ],
        ),
      );
    }

    // Reporter Dashboard: wallet summary + quick actions.
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.badge_rounded, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              const Text('Reporter Dashboard',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const Spacer(),
              Text('${state.reporterTokens} tokens · ₹${state.reporterTokens * AppState.rupeesPerToken}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: const Text('Post News'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreatePostScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.article_outlined, size: 18),
                  label: const Text('My Posts'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyPostsScreen()),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
              label: const Text('View Wallet'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReporterWalletScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
    Color color = AppColors.textDark,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(fontSize: 14, color: color)),
      trailing: trailing ??
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
      onTap: onTap,
    );
  }

  Widget _settingsSwitch({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.textDark),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      trailing: Switch(
        value: value,
        activeThumbColor: AppColors.primary,
        onChanged: onChanged,
      ),
    );
  }
}

class _ThemeToggleSwitch extends StatelessWidget {
  final bool isDark;
  final ValueChanged<bool> onChanged;

  const _ThemeToggleSwitch({required this.isDark, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!isDark),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        width: 56,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? AppColors.chipBgDark : AppColors.chipBg,
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.black12,
            width: 1.5,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              left: isDark ? 24 : 2,
              right: isDark ? 2 : 24,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, anim) => RotationTransition(
                  turns: child.key == const ValueKey('moon') 
                      ? Tween<double>(begin: -0.5, end: 0.0).animate(anim) 
                      : Tween<double>(begin: 0.5, end: 0.0).animate(anim),
                  child: ScaleTransition(scale: anim, child: child),
                ),
                child: isDark
                    ? const Icon(Icons.nightlight_round, key: ValueKey('moon'), size: 20, color: Colors.amber)
                    : const Icon(Icons.wb_sunny_rounded, key: ValueKey('sun'), size: 20, color: Colors.orange),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
