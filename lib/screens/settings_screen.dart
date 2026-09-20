import 'package:flutter/material.dart';
import '../localization/app_translations.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'account_login_screen.dart';
import 'preferences_screen.dart';
import 'notification_settings_screen.dart';
import 'cms_page_screen.dart';
import 'account_deletion_screen.dart';
import 'package:dio/dio.dart';
import 'bookmarks_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  double _fontSize = 19.0;

  @override
  void initState() {
    super.initState();
    _fontSize = AppState.instance.readingFontSize;
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
    if (fontSize != null) {
      payload['font_size'] = fontSize.round().clamp(12, 24);
    }

    try {
      await ApiService.instance.updateProfile(payload);
    } on DioException catch (e) {
      // The backend reports field errors under errors.details; swallowing
      // them left the reader believing a rejected change had saved.
      final data = e.response?.data;
      String? detail;
      if (data is Map && data['errors'] is Map) {
        final errors = data['errors'] as Map;
        if (errors['details'] is Map) {
          final details = errors['details'] as Map;
          final first = details.values.first;
          detail = first is List && first.isNotEmpty
              ? first.first.toString()
              : first?.toString();
        }
        detail ??= errors['message']?.toString();
      }
      debugPrint('[Settings] profile update failed: ${detail ?? e}');
      if (mounted && detail != null) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(detail),
            behavior: SnackBarBehavior.floating,
          ));
      }
    } catch (e) {
      debugPrint('[Settings] profile update failed: $e');
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
              tr('settings'),
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
              _buildSectionTitle(tr('account'), isDark),
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
                          state.userName.isNotEmpty ? state.userName : tr('subscriber'),
                          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                        ),
                        subtitle: Text(
                          state.userEmail ?? (state.userPhone.isNotEmpty ? state.userPhone : tr('logged_in')),
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
                    title: Text(tr('sign_in_or_register'), style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    subtitle: Text(tr('sign_in_sync_sub'), style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountLoginScreen()));
                    },
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // 2. Preferences Section
              _buildSectionTitle(tr('content_display'), isDark),
              _buildCard(
                isDark,
                child: Column(
                  children: [
                    // Theme Selector
                    ListTile(
                      leading: const Icon(Icons.brightness_6_rounded, color: AppColors.primary),
                      title: Text(tr('theme'), style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      trailing: DropdownButton<ThemeMode>(
                        value: state.themeMode,
                        underline: const SizedBox.shrink(),
                        dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                        items: const [
                          DropdownMenuItem(value: ThemeMode.system, child: Text('సిస్టమ్')),
                          DropdownMenuItem(value: ThemeMode.light, child: Text('లైట్')),
                          DropdownMenuItem(value: ThemeMode.dark, child: Text('డార్క్')),
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

                    // Saved articles. Reachable only from the Profile tab
                    // and a notification deep link before this — there was
                    // no way into it from Settings at all.
                    if (state.isLoggedIn) ...[
                      ListTile(
                        leading: const Icon(Icons.bookmark_rounded,
                            color: AppColors.primary),
                        title: Text(
                          state.language == 'Telugu'
                              ? 'సేవ్ చేసిన వార్తలు'
                              : 'Saved Articles',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87),
                        ),
                        subtitle: Text(
                          state.language == 'Telugu'
                              ? 'మీరు బుక్‌మార్క్ చేసిన వార్తలు'
                              : 'Articles you bookmarked',
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.black54),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded,
                            size: 16),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const BookmarksScreen()),
                        ),
                      ),
                      const Divider(height: 1),
                    ],

                    // App Language
                    ListTile(
                      leading: const Icon(Icons.language_rounded, color: AppColors.primary),
                      title: Text(tr('app_language'), style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      subtitle: Text(state.language, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: () => _showLanguageDialog(context, state, isDark),
                    ),
                    const Divider(height: 1),

                    // Content Language — the language of the news itself,
                    // deliberately separate from the interface language above.
                    ListTile(
                      leading: const Icon(Icons.article_outlined,
                          color: AppColors.primary),
                      title: Text(tr('content_language'),
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87)),
                      subtitle: Text(
                          _contentLanguageLabel(state.contentLanguage),
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.black54)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded,
                          size: 16),
                      onTap: () =>
                          _showContentLanguageDialog(context, state, isDark),
                    ),
                    const Divider(height: 1),

                    // News Category Preferences
                    ListTile(
                      leading: const Icon(Icons.tune_rounded, color: AppColors.primary),
                      title: Text(tr('category_preferences'), style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      subtitle: Text(tr('category_preferences_sub'), style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const PreferencesScreen()));
                      },
                    ),
                    const Divider(height: 1),

                    // Notification Settings
                    ListTile(
                      leading: const Icon(Icons.notifications_none_rounded, color: AppColors.primary),
                      title: Text(tr('push_notifications'), style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      subtitle: Text(tr('notification_preferences_sub'), style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
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
                              Text(tr('reading_font_size'), style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                              Text('${_fontSize.round()} pt', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ],
                          ),
                          Slider(
                            // 12-24 is what PATCH /auth/me/ accepts. The
                            // slider used to reach 26, so the top two stops
                            // were rejected with a 400 the app swallowed —
                            // the size changed locally and never saved.
                            value: _fontSize.clamp(12.0, 24.0),
                            min: 12,
                            max: 24,
                            divisions: 12,
                            activeColor: AppColors.primary,
                            onChanged: (val) {
                              setState(() => _fontSize = val);
                            },
                            onChangeEnd: (val) {
                              AppState.instance.setReadingFontSize(val);
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
              _buildSectionTitle(tr('about_policies'), isDark),
              _buildCard(
                isDark,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info_outline_rounded, color: AppColors.primary),
                      title: Text(tr('about_varadhi'), style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => CMSPageScreen(slug: 'about', initialTitle: tr('about_varadhi'))));
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.primary),
                      title: Text(tr('privacy_policy'), style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => CMSPageScreen(slug: 'privacy-policy', initialTitle: tr('privacy_policy'))));
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.description_outlined, color: AppColors.primary),
                      title: Text(tr('terms_of_service'), style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => CMSPageScreen(slug: 'terms', initialTitle: tr('terms_of_service'))));
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.support_agent_rounded, color: AppColors.primary),
                      title: Text(tr('contact_us'), style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => CMSPageScreen(slug: 'contact', initialTitle: tr('contact_us'))));
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 4. Session & Logout & Delete Account
              if (state.isLoggedIn) ...[
                _buildCard(
                  isDark,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                        title: Text(tr('log_out'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                        onTap: () {
                          _showLogoutDialog(context, state, isDark);
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                        title: Text(
                          state.language == 'Telugu' ? 'ఖాతా తొలగింపు (Delete Account)' : 'Delete Account Permanently',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
                        ),
                        subtitle: Text(
                          state.language == 'Telugu' ? 'ఖాతా మరియు వ్యక్తిగత డేటా తొలగింపు అభ్యర్థన' : 'Request account and personal data deletion',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.red),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AccountDeletionScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Version info footer
              Center(
                child: Text(
                  tr('app_version'),
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
        title: Text(tr('edit_profile_name')),
        content: TextField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: tr('full_name_hint'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('cancel')),
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
            child: Text(tr('save')),
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
        title: Text(tr('log_out')),
        content: Text(tr('logout_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              state.logout();
            },
            child: Text(tr('log_out')),
          ),
        ],
      ),
    );
  }

  /// null is "All Languages" — the feed then omits `lang` entirely.
  static String _contentLanguageLabel(String? code) {
    switch (code) {
      case 'te':
        return 'తెలుగు (Telugu)';
      case 'en':
        return 'English';
      default:
        return 'All Languages';
    }
  }

  void _showContentLanguageDialog(
      BuildContext context, AppState state, bool isDark) {
    Widget option(BuildContext ctx, String label, String? code) => ListTile(
          title: Text(label),
          trailing: state.contentLanguage == code
              ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
              : null,
          onTap: () {
            state.setContentLanguage(code);
            Navigator.pop(ctx);
          },
        );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tr('content_language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            option(ctx, 'All Languages', null),
            const Divider(height: 1),
            option(ctx, 'తెలుగు (Telugu)', 'te'),
            const Divider(height: 1),
            option(ctx, 'English', 'en'),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, AppState state, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tr('app_language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('తెలుగు (Telugu)'),
              trailing: state.language == 'Telugu'
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                  : null,
              onTap: () {
                state.setLanguage('Telugu');
                Navigator.pop(ctx);
              },
            ),
            const Divider(height: 1),
            ListTile(
              title: const Text('English'),
              trailing: state.language == 'English'
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                  : null,
              onTap: () {
                state.setLanguage('English');
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

}
