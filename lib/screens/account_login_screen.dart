import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'account_signup_screen.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';

/// Full account login screen.
/// - API: POST /api/v1/auth/login/
/// - Rate limiting: 429 error mapping
/// - Destination: Returns to original protected action or navigates to HomeScreen
class AccountLoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  const AccountLoginScreen({super.key, this.onLoginSuccess});

  @override
  State<AccountLoginScreen> createState() => _AccountLoginScreenState();
}

class _AccountLoginScreenState extends State<AccountLoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    if (_submitting) return;
    final email = _usernameController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'మీ ఇమెయిల్ చిరునామా మరియు పాస్‌వర్డ్ నమోదు చేయండి.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final data = await ApiService.instance.login(
        email,
        password,
        fcmToken: AppState.instance.fcmToken,
      );
      final token = data['access'] ?? data['token'];
      if (token == null) {
        throw Exception('No access token returned');
      }

      // Persist tokens securely
      await AppState.instance.setAuthToken(token, refresh: data['refresh'] as String?);
      final sessionId = data['session_id']?.toString() ?? data['session']?['id']?.toString();
      if (sessionId != null && sessionId.isNotEmpty) {
        await AppState.instance.setSessionId(sessionId);
      }
      if (data['installation_secret'] != null) {
        await AppState.instance
            .setInstallationSecret(data['installation_secret'].toString());
      }

      final user = data['user'] as Map<String, dynamic>?;
      AppState.instance.accountLogin(
        username: user?['full_name'] ?? user?['username'] ?? 'User',
      );

      // Refresh server-side roles (admin/contributor/tokens)
      await AppState.instance.refreshRolesFromServer();

      // Handoff guest device token to logged-in user (Backend Flow 2)
      if (AppState.instance.fcmToken != null) {
        try {
          await ApiService.instance.handoffDeviceToken(
            sessionId: sessionId,
            fcmToken: AppState.instance.fcmToken,
            installationSecret: AppState.instance.installationSecret,
          );
        } catch (_) {}
      }

      // Sync user location
      try {
        await ApiService.instance.syncUserLocation();
      } catch (_) {}

      if (!mounted) return;

      // Invoke custom callback if provided
      if (widget.onLoginSuccess != null) {
        widget.onLoginSuccess!();
      }

      // Navigate back to original protected action, or HomeScreen
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'చెల్లని ఇమెయిల్ లేదా పాస్‌వర్డ్.';
        if (e is DioException) {
          if (e.response?.statusCode == 429) {
            errorMsg = 'చాలా ఎక్కువ ప్రయత్నాలు జరిగాయి. దయచేసి కాసేపు ఆగి మళ్లీ ప్రయత్నించండి.';
          } else if (e.response?.data is Map) {
            final resp = e.response!.data as Map;
            if (resp['errors'] is Map) {
              final errMap = resp['errors'] as Map;
              if (errMap['message'] != null) {
                errorMsg = errMap['message'].toString();
              } else if (errMap['details'] is Map && errMap['details']['detail'] != null) {
                errorMsg = errMap['details']['detail'].toString();
              }
            } else if (resp['message'] != null) {
              errorMsg = resp['message'].toString();
            } else if (resp['detail'] != null) {
              errorMsg = resp['detail'].toString();
            }
          }
        }
        setState(() => _error = errorMsg);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('లాగిన్')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.badge_outlined,
                    color: AppColors.primary, size: 28),
              ),
              const SizedBox(height: 18),
              Text(
                'స్వాగతం',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).textTheme.bodyLarge?.color),
              ),
              const SizedBox(height: 4),
              const Text(
                'మీ ఖాతా, ప్రాధాన్యతలు మరియు కథనాలను యాక్సెస్ చేయడానికి లాగిన్ అవ్వండి.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13.5),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _usernameController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  labelText: 'ఇమెయిల్ చిరునామా',
                  filled: true,
                  fillColor: isDark ? AppColors.chipBgDark : AppColors.chipBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'పాస్‌వర్డ్',
                  filled: true,
                  fillColor: isDark ? AppColors.chipBgDark : AppColors.chipBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                    );
                  },
                  child: const Text(
                    'పాస్‌వర్డ్ మర్చిపోయారా?',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style:
                        const TextStyle(color: AppColors.primary, fontSize: 12.5)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text('లాగిన్',
                          style:
                              TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () async {
                    final registered = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => const AccountSignupScreen()),
                    );
                    if (!mounted || registered != true) return;
                    widget.onLoginSuccess?.call();
                    if (mounted) Navigator.of(context).pop(true);
                  },
                  child: const Text.rich(
                    TextSpan(
                      text: 'కొత్త వారా? ',
                      style: TextStyle(color: AppColors.textMuted),
                      children: [
                        TextSpan(
                          text: 'ఖాతాను సృష్టించండి',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
