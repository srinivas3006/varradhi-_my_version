import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';

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

  /// Terms of Service + Privacy Policy agreement. Required before an
  /// account is created (Play's user-generated content policy expects users
  /// to accept the terms before they can post).
  bool _acceptedTerms = false;

  /// Turns the box red after a submit without agreeing.
  bool _termsHighlighted = false;

  late final TapGestureRecognizer _termsTap = TapGestureRecognizer()
    ..onTap = () => _openPage(const TermsScreen());
  late final TapGestureRecognizer _privacyTap = TapGestureRecognizer()
    ..onTap = () => _openPage(const PrivacyPolicyScreen());

  void _openPage(Widget page) {
    FocusScope.of(context).unfocus();
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    if (_submitting) return;
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty) {
      setState(() => _error = 'మీ పూర్తి పేరు నమోదు చేయండి.');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      setState(
          () => _error = 'చెల్లుబాటు అయ్యే ఇమెయిల్ చిరునామా నమోదు చేయండి.');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'పాస్‌వర్డ్ కనీసం 8 అక్షరాలు ఉండాలి.');
      return;
    }
    if (RegExp(r'^\d+$').hasMatch(password)) {
      setState(() => _error =
          'పాస్‌వర్డ్ కేవలం అంకెలు మాత్రమే ఉండకూడదు. అక్షరాలు మరియు సంఖ్యలతో కూడిన బలమైన పాస్‌వర్డ్‌ను ఎంచుకోండి.');
      return;
    }
    if (password != confirmPassword) {
      setState(() => _error = 'పాస్‌వర్డ్‌లు సరిపోలడం లేదు.');
      return;
    }
    if (!_acceptedTerms) {
      setState(() {
        _termsHighlighted = true;
        _error = 'కొనసాగడానికి నిబంధనలు మరియు గోప్యతా విధానాన్ని అంగీకరించండి.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      String langCode = 'te';

      final data = await ApiService.instance.register({
        'email': email,
        'password': password,
        'password_confirm': confirmPassword,
        'full_name': name,
        'preferred_language': langCode,
        'theme': AppState.instance.themeMode.name,
        'device_id': AppState.instance.deviceId,
        'device_name': 'Mobile Device',
        'device_type': ApiService.deviceType,
        if (AppState.instance.fcmToken != null)
          'fcm_token': AppState.instance.fcmToken,
        if (AppState.instance.installationSecret != null &&
            AppState.instance.installationSecret!.isNotEmpty)
          'installation_secret': AppState.instance.installationSecret,
      });

      // Auto-login from returned access & refresh tokens
      final token = data['access'] ?? data['token'];
      if (token == null) throw Exception('No access token returned');
      {
        await AppState.instance.setAuthToken(
          token,
          refresh: data['refresh'] as String?,
        );
        final sessionId = data['session_id']?.toString() ??
            data['session']?['id']?.toString();
        if (sessionId != null && sessionId.isNotEmpty) {
          await AppState.instance.setSessionId(sessionId);
        }
        final secret = data['installation_secret']?.toString();
        if (secret != null && secret.isNotEmpty) {
          await AppState.instance.setInstallationSecret(secret);
        }

        final user = data['user'] as Map<String, dynamic>?;
        AppState.instance.accountLogin(
          username: user?['full_name'] ?? user?['email'] ?? name,
        );
        await AppState.instance.refreshRolesFromServer();

        try {
          // Handoff device token to registered user (Backend Flow 2)
          if (AppState.instance.fcmToken != null) {
            await ApiService.instance.handoffDeviceToken(
              sessionId: sessionId,
              fcmToken: AppState.instance.fcmToken,
              installationSecret: AppState.instance.installationSecret,
            );
          }

          await ApiService.instance.syncUserLocation();
        } catch (_) {
          // Account creation has succeeded; optional device sync must not
          // invite the reader to submit the registration a second time.
        }
      }

      if (!mounted) return;

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMsg =
            'రిజిస్ట్రేషన్ విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి.';
        if (e is DioException) {
          if (e.response?.statusCode == 429) {
            errorMsg =
                'చాలా ఎక్కువ ప్రయత్నాలు జరిగాయి. దయచేసి కాసేపు ఆగి మళ్లీ ప్రయత్నించండి.';
          } else if (e.response?.data is Map) {
            final resp = e.response!.data as Map;

            // Extract nested field errors from various backend formats
            Map? fieldErrors;
            if (resp['errors'] is Map) {
              fieldErrors = resp['errors'] as Map;
              if (fieldErrors['details'] is Map) {
                fieldErrors = fieldErrors['details'] as Map;
              }
            } else if (resp['details'] is Map) {
              fieldErrors = resp['details'] as Map;
            } else if (resp['data'] is Map &&
                (resp['data'] as Map)['errors'] is Map) {
              fieldErrors = (resp['data'] as Map)['errors'] as Map;
            } else {
              fieldErrors = resp;
            }

            final passwordErr = fieldErrors['password'];
            final emailErr = fieldErrors['email'];
            final nonFieldErr = fieldErrors['non_field_errors'] ??
                fieldErrors['detail'] ??
                fieldErrors['error'];

            if (passwordErr != null) {
              final str = (passwordErr is List && passwordErr.isNotEmpty)
                  ? passwordErr.first.toString()
                  : passwordErr.toString();
              if (str.toLowerCase().contains('common') ||
                  str.toLowerCase().contains('numeric') ||
                  str.toLowerCase().contains('entirely') ||
                  str.toLowerCase().contains('short')) {
                errorMsg =
                    'పాస్‌వర్డ్ చాలా సాధారణమైనది (12345678 వంటివి అనుమతించబడవు). దయచేసి అక్షరాలు, సంఖ్యలతో బలమైన పాస్‌వర్డ్‌ను ఎంచుకోండి.\n($str)';
              } else {
                errorMsg = 'పాస్‌వర్డ్ లోపం: $str';
              }
            } else if (emailErr != null) {
              final str = (emailErr is List && emailErr.isNotEmpty)
                  ? emailErr.first.toString()
                  : emailErr.toString();
              if (str.toLowerCase().contains('already exists') ||
                  str.toLowerCase().contains('unique')) {
                errorMsg =
                    'ఈ ఇమెయిల్ చిరునామాతో ఇప్పటికే ఖాతా ఉంది. దయచేసి లాగిన్ అవ్వండి.\n($str)';
              } else {
                errorMsg = 'ఇమెయిల్ లోపం: $str';
              }
            } else if (nonFieldErr != null) {
              final str = (nonFieldErr is List && nonFieldErr.isNotEmpty)
                  ? nonFieldErr.first.toString()
                  : nonFieldErr.toString();
              errorMsg = str;
            } else if (resp['errors'] is Map &&
                (resp['errors'] as Map)['message'] != null &&
                (resp['errors'] as Map)['message'].toString().trim() !=
                    'An error occurred.') {
              errorMsg = (resp['errors'] as Map)['message'].toString();
            } else if (resp['message'] != null &&
                resp['message'].toString().trim() != 'An error occurred.') {
              errorMsg = resp['message'].toString();
            } else {
              String? fallbackKeyMsg;
              for (final entry in fieldErrors.entries) {
                final k = entry.key.toString();
                if (['status', 'message', 'code', 'errors', 'details', 'data']
                    .contains(k)) {
                  continue;
                }
                final v = entry.value;
                if (v is List && v.isNotEmpty) {
                  fallbackKeyMsg = '$k: ${v.first}';
                  break;
                } else if (v is String && v.isNotEmpty) {
                  fallbackKeyMsg = '$k: $v';
                  break;
                }
              }
              errorMsg = fallbackKeyMsg ??
                  (resp['message']?.toString() ??
                      'రిజిస్ట్రేషన్ విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి.');
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

  void _clearError() {
    // Also rebuilds the password checklist as the reader types.
    setState(() => _error = null);
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

  Widget _eye(bool obscured, Color color, VoidCallback onTap) => IconButton(
        icon: Icon(obscured
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined),
        color: color,
        onPressed: onTap,
      );

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
            Transform.translate(
              offset: const Offset(0, -40),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Container(
                  key: const Key('signup_form_card'),
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
                          'మీ ఖాతాను సృష్టించండి',
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'వార్తలను అనుకూలీకరించడానికి, కథనాలను సేవ్ చేసుకోవడానికి సైన్ అప్ చేయండి.',
                          style: TextStyle(
                              color: mutedColor, fontSize: 13.5, height: 1.5),
                        ),
                        const SizedBox(height: 22),
                        TextField(
                          key: const Key('signup_name_field'),
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          onChanged: (_) => _clearError(),
                          decoration: _fieldDecoration(
                            isDark: isDark,
                            label: 'పూర్తి పేరు',
                            icon: Icons.person_outline_rounded,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          key: const Key('signup_email_field'),
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          autofillHints: const [AutofillHints.email],
                          onChanged: (_) => _clearError(),
                          decoration: _fieldDecoration(
                            isDark: isDark,
                            label: 'ఇమెయిల్ చిరునామా',
                            icon: Icons.mail_outline_rounded,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          key: const Key('signup_password_field'),
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newPassword],
                          onChanged: (_) => _clearError(),
                          decoration: _fieldDecoration(
                            isDark: isDark,
                            label: 'పాస్‌వర్డ్ (కనీసం 8 అక్షరాలు)',
                            icon: Icons.lock_outline_rounded,
                            suffix: _eye(
                                _obscurePassword,
                                mutedColor,
                                () => setState(() =>
                                    _obscurePassword = !_obscurePassword)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          key: const Key('signup_confirm_field'),
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          onChanged: (_) => _clearError(),
                          decoration: _fieldDecoration(
                            isDark: isDark,
                            label: 'పాస్‌వర్డ్ నిర్ధారించండి',
                            icon: Icons.lock_reset_rounded,
                            suffix: _eye(
                                _obscureConfirmPassword,
                                mutedColor,
                                () => setState(() => _obscureConfirmPassword =
                                    !_obscureConfirmPassword)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildPasswordChecklist(mutedColor),
                        const SizedBox(height: 10),
                        _buildTermsAgreement(isDark, mutedColor),
                        const SizedBox(height: 16),
                        if (_error != null) _buildError(),
                        _buildSubmitButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -22),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: Divider(color: lineColor)),
                        Flexible(
                          flex: 3,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('ఇప్పటికే ఖాతా ఉందా?',
                                textAlign: TextAlign.center,
                                style:
                                    TextStyle(color: mutedColor, fontSize: 13)),
                          ),
                        ),
                        Expanded(child: Divider(color: lineColor)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        key: const Key('signup_login_button'),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.login_rounded, size: 20),
                        label: const Text(
                          'లాగిన్',
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
                            style: TextStyle(color: mutedColor, fontSize: 12.5),
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
      key: const Key('signup_brand_header'),
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          24, MediaQuery.of(context).padding.top + 48, 24, 64),
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
            width: 72,
            height: 72,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'వారధిలో చేరండి',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'మీ ప్రాంత వార్తలు, మీ చేతుల్లో',
            textAlign: TextAlign.center,
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

  /// Live hints for the same rules [_submit] enforces, so the reader sees
  /// what is missing before tapping the button.
  Widget _buildPasswordChecklist(Color mutedColor) {
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    Widget rule(String key, String label, bool ok) {
      return Padding(
        key: Key('signup_rule_$key'),
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Icon(
                ok ? Icons.check_circle_rounded : Icons.circle_outlined,
                key: ValueKey(ok),
                size: 17,
                color: ok ? const Color(0xFF16A34A) : mutedColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  color: ok ? const Color(0xFF16A34A) : mutedColor,
                  fontWeight: ok ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        rule('length', 'కనీసం 8 అక్షరాలు', password.length >= 8),
        rule('not_numeric', 'కేవలం అంకెలు కాకూడదు',
            password.isNotEmpty && !RegExp(r'^\d+$').hasMatch(password)),
        rule('match', 'పాస్‌వర్డ్‌లు సరిపోలాయి',
            confirm.isNotEmpty && password == confirm),
      ],
    );
  }

  /// "I agree to the Terms and Privacy Policy" — both open in-app.
  Widget _buildTermsAgreement(bool isDark, Color mutedColor) {
    final alert = _termsHighlighted && !_acceptedTerms;
    const link = TextStyle(
      color: AppColors.primary,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.primary,
    );
    return AnimatedContainer(
      key: const Key('signup_terms'),
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
      decoration: BoxDecoration(
        color: alert
            ? AppColors.error.withValues(alpha: 0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alert
              ? AppColors.error.withValues(alpha: 0.5)
              : Colors.transparent,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            key: const Key('signup_terms_checkbox'),
            value: _acceptedTerms,
            activeColor: AppColors.primary,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            side: BorderSide(
              color: alert
                  ? AppColors.error
                  : (isDark ? AppColors.iconMutedDark : AppColors.textMuted),
              width: 1.6,
            ),
            onChanged: (v) => setState(() {
              _acceptedTerms = v ?? false;
              if (_acceptedTerms) {
                _termsHighlighted = false;
                _error = null;
              }
            }),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              // Tapping the sentence (outside the links) ticks the box too.
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() {
                _acceptedTerms = !_acceptedTerms;
                if (_acceptedTerms) {
                  _termsHighlighted = false;
                  _error = null;
                }
              }),
              child: Padding(
                padding: const EdgeInsets.only(top: 9),
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textDark),
                    children: [
                      const TextSpan(text: 'నేను వారధి '),
                      TextSpan(
                        text: 'నిబంధనలు మరియు షరతులు',
                        style: link,
                        recognizer: _termsTap,
                      ),
                      const TextSpan(text: ' మరియు '),
                      TextSpan(
                        text: 'గోప్యతా విధానం',
                        style: link,
                        recognizer: _privacyTap,
                      ),
                      const TextSpan(text: 'ను చదివి అంగీకరిస్తున్నాను.'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      key: const Key('signup_error'),
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
        key: const Key('signup_submit'),
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
                    child: Text('ఖాతాను సృష్టించండి',
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
    _termsTap.dispose();
    _privacyTap.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
