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
      setState(
          () => _error = 'మీ ఇమెయిల్ చిరునామా మరియు పాస్‌వర్డ్ నమోదు చేయండి.');
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
      await AppState.instance
          .setAuthToken(token, refresh: data['refresh'] as String?);
      final sessionId =
          data['session_id']?.toString() ?? data['session']?['id']?.toString();
      if (sessionId != null && sessionId.isNotEmpty) {
        await AppState.instance.setSessionId(sessionId);
      }
      final secret = data['installation_secret']?.toString() ??
          (data['data'] is Map
              ? data['data']['installation_secret']?.toString()
              : null);
      if (secret != null && secret.isNotEmpty) {
        await AppState.instance.setInstallationSecret(secret);
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
            errorMsg =
                'చాలా ఎక్కువ ప్రయత్నాలు జరిగాయి. దయచేసి కాసేపు ఆగి మళ్లీ ప్రయత్నించండి.';
          } else if (e.response?.data is Map) {
            final resp = e.response!.data as Map;
            Map? fieldErrors;
            if (resp['errors'] is Map) {
              fieldErrors = resp['errors'] as Map;
              if (fieldErrors['details'] is Map) {
                fieldErrors = fieldErrors['details'] as Map;
              }
            } else if (resp['details'] is Map) {
              fieldErrors = resp['details'] as Map;
            } else {
              fieldErrors = resp;
            }

            final nonField = fieldErrors['non_field_errors'] ??
                fieldErrors['detail'] ??
                fieldErrors['error'];
            if (nonField != null) {
              errorMsg = (nonField is List && nonField.isNotEmpty)
                  ? nonField.first.toString()
                  : nonField.toString();
            } else if (fieldErrors['password'] != null) {
              final p = fieldErrors['password'];
              errorMsg = (p is List && p.isNotEmpty)
                  ? p.first.toString()
                  : p.toString();
            } else if (fieldErrors['email'] != null) {
              final em = fieldErrors['email'];
              errorMsg = (em is List && em.isNotEmpty)
                  ? em.first.toString()
                  : em.toString();
            } else if (resp['message'] != null &&
                resp['message'].toString().trim() != 'An error occurred.') {
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

  void _openForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  Future<void> _openSignup() async {
    final registered = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AccountSignupScreen()),
    );
    if (!mounted || registered != true) return;
    widget.onLoginSuccess?.call();
    if (mounted) Navigator.of(context).pop(true);
  }

  InputDecoration _fieldDecoration({
    required bool isDark,
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );
    final idle = isDark ? AppColors.borderDark : AppColors.borderLight;
    return InputDecoration(
      labelText: label,
      floatingLabelStyle: const TextStyle(
          color: AppColors.primary, fontWeight: FontWeight.w600),
      prefixIcon: Icon(icon, size: 22),
      prefixIconColor: WidgetStateColor.resolveWith((states) =>
          states.contains(WidgetState.focused)
              ? AppColors.primary
              : (isDark ? AppColors.iconMutedDark : AppColors.textMuted)),
      suffixIcon: suffix,
      filled: true,
      fillColor:
          isDark ? AppColors.surfaceElevatedDark : const Color(0xFFF7F7F9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: border(idle),
      enabledBorder: border(idle),
      focusedBorder: border(AppColors.primary, 1.6),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.cardDarkNavy : Colors.white;
    final titleColor = isDark ? AppColors.textLight : AppColors.textDark;
    final mutedColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textMuted;
    final lineColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : const Color(0xFFF6F6F8),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          children: [
            _buildBrandHeader(context),
            // Form card, lifted over the header.
            Transform.translate(
              offset: const Offset(0, -44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Container(
                  key: const Key('login_form_card'),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(26),
                    border: isDark ? Border.all(color: lineColor) : null,
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'స్వాగతం',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'మీ ఖాతా, ప్రాధాన్యతలు మరియు కథనాలను యాక్సెస్ చేయడానికి లాగిన్ అవ్వండి.',
                          style: TextStyle(
                              color: mutedColor, fontSize: 13.5, height: 1.5),
                        ),
                        const SizedBox(height: 22),
                        TextField(
                          key: const Key('login_email_field'),
                          controller: _usernameController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          autofillHints: const [AutofillHints.email],
                          onChanged: (_) {
                            if (_error != null) setState(() => _error = null);
                          },
                          decoration: _fieldDecoration(
                            isDark: isDark,
                            label: 'ఇమెయిల్ చిరునామా',
                            icon: Icons.mail_outline_rounded,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          key: const Key('login_password_field'),
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onSubmitted: (_) => _submit(),
                          onChanged: (_) {
                            if (_error != null) setState(() => _error = null);
                          },
                          decoration: _fieldDecoration(
                            isDark: isDark,
                            label: 'పాస్‌వర్డ్',
                            icon: Icons.lock_outline_rounded,
                            suffix: IconButton(
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined),
                              color: mutedColor,
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _openForgotPassword,
                            child: const Text(
                              'పాస్‌వర్డ్ మర్చిపోయారా?',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        if (_error != null) _buildError(),
                        _buildSubmitButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Sign-up, below the card.
            Transform.translate(
              offset: const Offset(0, -24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: Divider(color: lineColor)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('కొత్త వారా?',
                              style:
                                  TextStyle(color: mutedColor, fontSize: 13)),
                        ),
                        Expanded(child: Divider(color: lineColor)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        key: const Key('login_signup_button'),
                        onPressed: _openSignup,
                        icon: const Icon(Icons.person_add_alt_1_rounded,
                            size: 20),
                        label: const Text(
                          'ఖాతాను సృష్టించండి',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(
                              color: AppColors.primary, width: 1.4),
                          backgroundColor: cardColor,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified_user_outlined,
                            size: 16, color: mutedColor),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'మీ సమాచారం సురక్షితంగా ఉంటుంది',
                            textAlign: TextAlign.center,
                            style:
                                TextStyle(color: mutedColor, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandHeader(BuildContext context) {
    return Container(
      key: const Key('login_brand_header'),
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          24, MediaQuery.of(context).padding.top + 52, 24, 72),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, Color(0xFFC81B00)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'వారధి',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'మీ ప్రాంత వార్తలు, మీ చేతుల్లో',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      key: const Key('login_error'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        key: const Key('login_submit'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.7),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: AppColors.primary.withValues(alpha: 0.4),
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
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text('లాగిన్',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
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
