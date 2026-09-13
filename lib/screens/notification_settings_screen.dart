import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'account_login_screen.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  // Preferences state
  bool _enabled = true;
  String _contentLanguage = 'te';
  bool _articles = true;
  bool _posters = true;
  bool _quotes = true;
  bool _ugc = true;
  bool _breakingNews = true;
  bool _liveNews = true;
  bool _localNews = true;
  bool _sports = true;
  bool _politics = true;
  bool _entertainment = true;
  bool _business = true;
  String _quietHoursStart = '22:00:00';
  String _quietHoursEnd = '06:00:00';
  int _maxPerHour = 5;
  int _maxPerDay = 25;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    if (!AppState.instance.isLoggedIn) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await ApiService.instance.getNotificationPreferences();
      if (prefs != null && mounted) {
        setState(() {
          _enabled = prefs['enabled'] ?? true;
          _contentLanguage = prefs['content_language']?.toString() ?? 'te';
          _articles = prefs['articles'] ?? true;
          _posters = prefs['posters'] ?? true;
          _quotes = prefs['quotes'] ?? true;
          _ugc = prefs['ugc'] ?? true;
          _breakingNews = prefs['breaking_news'] ?? true;
          _liveNews = prefs['live_news'] ?? true;
          _localNews = prefs['local_news'] ?? true;
          _sports = prefs['sports'] ?? true;
          _politics = prefs['politics'] ?? true;
          _entertainment = prefs['entertainment'] ?? true;
          _business = prefs['business'] ?? true;
          _quietHoursStart = prefs['quiet_hours_start']?.toString() ?? '22:00:00';
          _quietHoursEnd = prefs['quiet_hours_end']?.toString() ?? '06:00:00';
          _maxPerHour = prefs['max_per_hour'] is int ? prefs['max_per_hour'] : 5;
          _maxPerDay = prefs['max_per_day'] is int ? prefs['max_per_day'] : 25;
        });
      }
    } catch (e) {
      debugPrint('Failed to load notification preferences: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePreferences() async {
    if (!AppState.instance.isLoggedIn || _isSaving) return;

    setState(() => _isSaving = true);
    HapticFeedback.lightImpact();

    final payload = {
      'enabled': _enabled,
      'content_language': _contentLanguage,
      'articles': _articles,
      'posters': _posters,
      'quotes': _quotes,
      'ugc': _ugc,
      'breaking_news': _breakingNews,
      'live_news': _liveNews,
      'local_news': _localNews,
      'sports': _sports,
      'politics': _politics,
      'entertainment': _entertainment,
      'business': _business,
      'quiet_hours_start': _quietHoursStart,
      'quiet_hours_end': _quietHoursEnd,
      'timezone': 'Asia/Kolkata',
      'max_per_hour': _maxPerHour,
      'max_per_day': _maxPerDay,
      'snoozed_until': null,
    };

    final success = await ApiService.instance.updateNotificationPreferences(payload);
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'నోటిఫికేషన్ సెట్టింగ్‌లు నవీకరించబడ్డాయి' : 'సెట్టింగ్‌లు సేవ్ అయ్యాయి'),
          backgroundColor: success ? Colors.green.shade700 : AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

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
          'నోటిఫికేషన్ సెట్టింగ్‌లు',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: _buildContent(isDark),
    );
  }

  Widget _buildContent(bool isDark) {
    if (!AppState.instance.isLoggedIn) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded, size: 64, color: isDark ? Colors.white24 : Colors.black26),
              const SizedBox(height: 16),
              Text(
                'లాగిన్ అవసరం',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'మీ పుష్ నోటిఫికేషన్ ప్రాధాన్యతలను మార్చుకోవడానికి దయచేసి సైన్ ఇన్ చేయండి.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AccountLoginScreen()),
                  );
                  _loadPreferences();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('సైన్ ఇన్', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Master switch card
          _buildCard(
            isDark,
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              title: Text(
                'అన్ని నోటిఫికేషన్‌లను ప్రారంభించండి',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              subtitle: Text(
                'బ్రేకింగ్ న్యూస్, కథనాలు మరియు హెచ్చరికల ప్రధాన స్విచ్',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
              ),
              value: _enabled,
              activeTrackColor: AppColors.primary,
              onChanged: (val) {
                setState(() => _enabled = val);
                _savePreferences();
              },
            ),
          ),
          const SizedBox(height: 20),

          // Alerts & Updates
          _buildSectionHeader('హెచ్చరికలు & ప్రసారాలు', isDark),
          _buildCard(
            isDark,
            child: Column(
              children: [
                _buildSwitchTile(
                  'బ్రేకింగ్ న్యూస్',
                  'ముఖ్యమైన అత్యవసర మరియు ప్రధాన వార్తల నోటిఫికేషన్‌లు',
                  _breakingNews,
                  _enabled,
                  (val) {
                    setState(() => _breakingNews = val);
                    _savePreferences();
                  },
                  isDark,
                ),
                const Divider(height: 1),
                _buildSwitchTile(
                  'లైవ్ న్యూస్ ప్రసారాలు',
                  'ప్రత్యక్ష కవరేజ్ లేదా ముఖ్య సంఘటనలు ప్రారంభమైనప్పుడు హెచ్చరికలు',
                  _liveNews,
                  _enabled,
                  (val) {
                    setState(() => _liveNews = val);
                    _savePreferences();
                  },
                  isDark,
                ),
                const Divider(height: 1),
                _buildSwitchTile(
                  'స్థానిక వార్తలు & ప్రాంతీయ హెచ్చరికలు',
                  'మీ జిల్లా, మండలం మరియు గ్రామం నుంచి తాజా వార్తలు',
                  _localNews,
                  _enabled,
                  (val) {
                    setState(() => _localNews = val);
                    _savePreferences();
                  },
                  isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Category Channels
          _buildSectionHeader('విభాగాల ప్రాధాన్యతలు', isDark),
          _buildCard(
            isDark,
            child: Column(
              children: [
                _buildSwitchTile('రాజకీయాలు', 'రాజకీయ వార్తలు, ప్రభుత్వ విధానాలు మరియు ఎన్నికల సమాచారం', _politics, _enabled, (val) {
                  setState(() => _politics = val);
                  _savePreferences();
                }, isDark),
                const Divider(height: 1),
                _buildSwitchTile('క్రీడలు', 'క్రికెట్ మ్యాచ్‌లు, స్కోర్లు మరియు టోర్నమెంట్ వార్తలు', _sports, _enabled, (val) {
                  setState(() => _sports = val);
                  _savePreferences();
                }, isDark),
                const Divider(height: 1),
                _buildSwitchTile('వినోదం', 'సినిమా వార్తలు, రివ్యూలు మరియు సెలబ్రిటీ అప్‌డేట్స్', _entertainment, _enabled, (val) {
                  setState(() => _entertainment = val);
                  _savePreferences();
                }, isDark),
                const Divider(height: 1),
                _buildSwitchTile('వ్యాపారం & ఫైనాన్స్', 'స్టాక్ మార్కెట్, ఆర్థిక వ్యవస్థ మరియు వ్యాపార వార్తలు', _business, _enabled, (val) {
                  setState(() => _business = val);
                  _savePreferences();
                }, isDark),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Quiet Hours and Frequency
          _buildSectionHeader('సమయాలు & పరిమితులు', isDark),
          _buildCard(
            isDark,
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: const Icon(Icons.bedtime_outlined, color: AppColors.primary),
                  title: Text(
                    'సైలెంట్ గంటలు',
                    style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                  ),
                  subtitle: Text(
                    '$_quietHoursStart నుండి $_quietHoursEnd మధ్య అత్యవసరం కాని నోటిఫికేషన్‌లను నిలిపివేయండి',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: const Icon(Icons.speed_rounded, color: AppColors.primary),
                  title: Text(
                    'నోటిఫికేషన్ పరిమితులు',
                    style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                  ),
                  subtitle: Text(
                    'గంటకు గరిష్టంగా $_maxPerHour (రోజుకు గరిష్టంగా $_maxPerDay)',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
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

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    bool parentEnabled,
    ValueChanged<bool> onChanged,
    bool isDark,
  ) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: parentEnabled ? (isDark ? Colors.white : Colors.black87) : Colors.grey,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: parentEnabled ? (isDark ? Colors.white54 : Colors.black54) : Colors.grey.shade600,
        ),
      ),
      value: value && parentEnabled,
      activeTrackColor: AppColors.primary,
      onChanged: parentEnabled ? onChanged : null,
    );
  }
}
