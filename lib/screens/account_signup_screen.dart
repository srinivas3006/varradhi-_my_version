import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

/// Signup / Registration screen.
/// - API: POST /api/v1/auth/register/
/// - Fields: email, password, password_confirm, full_name, preferred_language, device_id, device_name, device_type, fcm_token
/// - Destination: HomeScreen / SpotlightScreen
class AccountSignupScreen extends StatefulWidget {
  const AccountSignupScreen({super.key});

  @override
  State<AccountSignupScreen> createState() => _AccountSignupScreenState();
}

class _AccountSignupScreenState extends State<AccountSignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty) {
      setState(() => _error = 'Enter your full name.');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }
    if (password != confirmPassword) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      String langCode = 'en';
      switch (AppState.instance.language) {
        case 'Telugu':
          langCode = 'te';
          break;
        case 'Hindi':
          langCode = 'hi';
          break;
        case 'Tamil':
          langCode = 'ta';
          break;
        default:
          langCode = 'en';
      }

      final data = await ApiService.instance.register({
        'email': email,
        'password': password,
        'password_confirm': confirmPassword,
        'full_name': name,
        'preferred_language': langCode,
        'device_id': AppState.instance.deviceId,
        'device_name': 'Mobile Device',
        'device_type': 'android',
        'fcm_token': AppState.instance.fcmToken ?? 'device-fcm-token',
      });

      // Auto-login from returned access & refresh tokens
      final token = data['access'] ?? data['token'];
      if (token != null) {
        await AppState.instance.setAuthToken(
          token,
          refresh: data['refresh'] as String?,
        );
        final sessionId = data['session_id']?.toString() ?? data['session']?['id']?.toString();
        if (sessionId != null && sessionId.isNotEmpty) {
          await AppState.instance.setSessionId(sessionId);
        }

        final user = data['user'] as Map<String, dynamic>?;
        AppState.instance.accountLogin(
          username: user?['full_name'] ?? user?['email'] ?? name,
        );
        await AppState.instance.refreshRolesFromServer();

        // Handoff device token to registered user (Backend Flow 2)
        if (AppState.instance.fcmToken != null) {
          await ApiService.instance.handoffDeviceToken(
            sessionId: sessionId,
            fcmToken: AppState.instance.fcmToken,
            installationSecret: AppState.instance.installationSecret,
          );
        }

        await ApiService.instance.syncUserLocation();
      }

      if (!mounted) return;

      // Navigate to HomeScreen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Registration failed. Please try again.';
        if (e is DioException) {
          if (e.response?.statusCode == 429) {
            errorMsg = 'Too many attempts. Please wait and try again.';
          } else if (e.response?.data is Map) {
            final resp = e.response!.data as Map;
            if (resp['errors'] is Map) {
              final errMap = resp['errors'] as Map;
              if (errMap['message'] != null) {
                errorMsg = errMap['message'].toString();
              } else if (errMap['details'] is Map) {
                final details = errMap['details'] as Map;
                if (details['email'] != null) {
                  errorMsg = (details['email'] is List)
                      ? (details['email'] as List).first.toString()
                      : details['email'].toString();
                } else if (details['password'] != null) {
                  errorMsg = (details['password'] is List)
                      ? (details['password'] as List).first.toString()
                      : details['password'].toString();
                }
              }
            } else if (resp['message'] != null) {
              errorMsg = resp['message'].toString();
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
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create your account',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sign up to customize news topics, save stories, and engage.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13.5),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                autofillHints: const [AutofillHints.name],
                decoration: InputDecoration(
                  labelText: 'Full name',
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
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  labelText: 'Email address',
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
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Password (min 8 characters)',
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
              const SizedBox(height: 14),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  filled: true,
                  fillColor: isDark ? AppColors.chipBgDark : AppColors.chipBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () => setState(
                        () => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style:
                      const TextStyle(color: AppColors.primary, fontSize: 12.5),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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
                      : const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text.rich(
                    TextSpan(
                      text: 'Already have an account? ',
                      style: TextStyle(color: AppColors.textMuted),
                      children: [
                        TextSpan(
                          text: 'Log In',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
