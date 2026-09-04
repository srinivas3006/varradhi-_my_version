import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

/// Signup for the Reporter Program's account system. Deliberately has NO
/// OTP step — per the feature plan, OTP verification only happens later,
/// the first time this account tries to submit a reporter post.
class AccountSignupScreen extends StatefulWidget {
  const AccountSignupScreen({super.key});

  @override
  State<AccountSignupScreen> createState() => _AccountSignupScreenState();
}

class _AccountSignupScreenState extends State<AccountSignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _error;

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

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

    try {
      String langCode = 'en';
      switch (AppState.instance.language) {
        case 'Telugu': langCode = 'te'; break;
        case 'Tamil': langCode = 'ta'; break;
        case 'Kannada': langCode = 'kn'; break;
        case 'Marathi': langCode = 'mr'; break;
        case 'Bengali': langCode = 'bn'; break;
        case 'Malayalam': langCode = 'ml'; break;
      }

      final data = await ApiService.instance.register({
        'email': email,
        'password': password,
        'password_confirm': password,
        'full_name': name,
        'preferred_language': langCode,
        'device_id': 'flutter-app', // In production, grab via device_info_plus
        'device_name': 'Mobile Device',
        'device_type': 'android',
        'fcm_token': AppState.instance.fcmToken ?? 'dummy-token'
      });
      
      // Auto-login since register returns the auth tokens and user data
      final token = data['access'] ?? data['token'];
      if (token != null) {
        await AppState.instance.setAuthToken(token);
        final user = data['user'] as Map<String, dynamic>?;
        AppState.instance.accountLogin(username: user?['full_name'] ?? user?['email'] ?? name);
        await AppState.instance.refreshRolesFromServer();
        await ApiService.instance.syncUserLocation();
      } else {
        AppState.instance.signup(fullName: name, phone: email, password: password);
      }
      
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      setState(() => _error = 'Registration failed. Email might be in use.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Join as a reader',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: Theme.of(context).textTheme.bodyLarge?.color),
              ),
              const SizedBox(height: 4),
              const Text(
                'You can register as a Reporter afterwards from your profile.',
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
                  labelText: 'Password',
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
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: const TextStyle(color: AppColors.primary, fontSize: 12.5)),
              ],
              const SizedBox(height: 20),
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
                  onPressed: _submit,
                  child: const Text('Submit',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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
    super.dispose();
  }
}
