import 'package:flutter/material.dart';
import '../core/navigation/app_navigator.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'account_login_screen.dart';
import 'preferences_screen.dart';
import 'notification_settings_screen.dart';
import 'cms_page_screen.dart';
import 'language_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  double _fontSize = 16.0;

  @override
  void initState() {
    super.initState();
    _nameController.text = AppState.instance.userName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile({String? name, String? theme, double? fontSize}) async {
    if (!AppState.instance.isLoggedIn) return;

    final Map<String, dynamic> payload = {};

    if (name != null) payload['full_name'] = name;
    if (theme != null) payload['theme'] = theme;
    if (fontSize != null) payload['font_size'] = fontSize.round();

    try {
      await ApiService.instance.updateProfile(payload);
    } catch (_) {
      // Backend error fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final state = AppState.instance;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: bgColor,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Settings',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // 1. Account Section
              _buildSectionTitle('ACCOUNT', isDark),
              if (state.isLoggedIn) ...[
                _buildCard(
                  isDark,
                  child: Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          child: const Icon(Icons.person_rounded, color: AppColors.primary),
                        ),
                        title: Text(
                          state.userName.isNotEmpty ? state.userName : 'Subscriber',
                          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                        ),
                        subtitle: Text(
                          state.userEmail ?? (state.userPhone.isNotEmpty ? state.userPhone : 'Logged In'),
                          style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _showEditNameDialog(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                _buildCard(
                  isDark,
                  child: ListTile(
                    leading: const Icon(Icons.account_circle_outlined, color: AppColors.primary, size: 36),
                    title: Text('Sign In or Register', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    subtitle: Text('Sync bookmarks, preferences, and notifications', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountLoginScreen()));
                    },
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // 2. Preferences Section
              _buildSectionTitle('CONTENT & DISPLAY', isDark),
              _buildCard(
                isDark,
                child: Column(
                  children: [
                    // Theme Selector
                    ListTile(
                      leading: const Icon(Icons.brightness_6_rounded, color: AppColors.primary),
                      title: Text('Theme', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      trailing: DropdownButton<ThemeMode>(
                        value: state.themeMode,
                        underline: const SizedBox.shrink(),
                        dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                        items: const [
                          DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                          DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                          DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                        ],
                        onChanged: (newMode) {
                          if (newMode != null) {
                            state.setThemeMode(newMode);
                            final themeStr = newMode == ThemeMode.light ? 'light' : (newMode == ThemeMode.dark ? 'dark' : 'system');
                            _updateProfile(theme: themeStr);
                          }
                        },
                      ),
                    ),
                    const Divider(height: 1),

                    // App Language
                    ListTile(
                      leading: const Icon(Icons.language_rounded, color: AppColors.primary),
                      title: Text('App Language', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      subtitle: Text(AppState.instance.language, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: () {
                        AppNavigator.pushSafe(context, MaterialPageRoute(builder: (_) => const LanguageScreen()));
                      },
                    ),
                    const Divider(height: 1),

                    // News Category Preferences
                    ListTile(
                      leading: const Icon(Icons.tune_rounded, color: AppColors.primary),
                      title: Text('Category Preferences', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      subtitle: Text('Personalize topics in your feed', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const PreferencesScreen()));
                      },
                    ),
                    const Divider(height: 1),

                    // Notification Settings
                    ListTile(
                      leading: const Icon(Icons.notifications_none_rounded, color: AppColors.primary),
                      title: Text('Push Notifications', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      subtitle: Text('Manage alert frequency & categories', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()));
                      },
                    ),
                    const Divider(height: 1),

                    // Font Size Slider
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Reading Font Size', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                              Text('${_fontSize.round()} pt', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ],
                          ),
                          Slider(
                            value: _fontSize,
                            min: 12,
                            max: 24,
                            divisions: 12,
                            activeColor: AppColors.primary,
                            onChanged: (val) {
                              setState(() => _fontSize = val);
                            },
                            onChangeEnd: (val) {
                              _updateProfile(fontSize: val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 3. About & Policies (CMS Pages)
              _buildSectionTitle('ABOUT & POLICIES', isDark),
              _buildCard(
                isDark,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info_outline_rounded, color: AppColors.primary),
                      title: Text('About Varadhi', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const CMSPageScreen(slug: 'about', initialTitle: 'About Varadhi')));
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.primary),
                      title: Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const CMSPageScreen(slug: 'privacy-policy', initialTitle: 'Privacy Policy')));
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.description_outlined, color: AppColors.primary),
                      title: Text('Terms of Service', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const CMSPageScreen(slug: 'terms', initialTitle: 'Terms of Service')));
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.support_agent_rounded, color: AppColors.primary),
                      title: Text('Contact Us', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const CMSPageScreen(slug: 'contact', initialTitle: 'Contact Us')));
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 4. Session & Logout
              if (state.isLoggedIn) ...[
                _buildCard(
                  isDark,
                  child: ListTile(
                    leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                    title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                    onTap: () {
                      _showLogoutDialog(context, state, isDark);
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Version info footer
              Center(
                child: Text(
                  'Varadhi News v1.0.0 (Build 2026.09)',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: isDark ? Colors.white38 : Colors.black38,
        ),
      ),
    );
  }

  Widget _buildCard(bool isDark, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }

  void _showEditNameDialog(bool isDark) {
    _nameController.text = AppState.instance.userName;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Profile Name'),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            hintText: 'Enter your full name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () {
              final newName = _nameController.text.trim();
              if (newName.isNotEmpty) {
                AppState.instance.setUserName(newName);
                _updateProfile(name: newName);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AppState state, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              state.logout();
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}
