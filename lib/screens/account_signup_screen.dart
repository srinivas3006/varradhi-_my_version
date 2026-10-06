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
      setState(() => _error = 'చెల్లుబాటు అయ్యే ఇమెయిల్ చిరునామా నమోదు చేయండి.');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'పాస్‌వర్డ్ కనీసం 8 అక్షరాలు ఉండాలి.');
      return;
    }
    if (RegExp(r'^\d+$').hasMatch(password)) {
      setState(() => _error = 'పాస్‌వర్డ్ కేవలం అంకెలు మాత్రమే ఉండకూడదు. అక్షరాలు మరియు సంఖ్యలతో కూడిన బలమైన పాస్‌వర్డ్‌ను ఎంచుకోండి.');
      return;
    }
    if (password != confirmPassword) {
      setState(() => _error = 'పాస్‌వర్డ్‌లు సరిపోలడం లేదు.');
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
        final sessionId = data['session_id']?.toString() ?? data['session']?['id']?.toString();
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
        String errorMsg = 'రిజిస్ట్రేషన్ విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి.';
        if (e is DioException) {
          if (e.response?.statusCode == 429) {
            errorMsg = 'చాలా ఎక్కువ ప్రయత్నాలు జరిగాయి. దయచేసి కాసేపు ఆగి మళ్లీ ప్రయత్నించండి.';
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
            } else if (resp['data'] is Map && (resp['data'] as Map)['errors'] is Map) {
              fieldErrors = (resp['data'] as Map)['errors'] as Map;
            } else {
              fieldErrors = resp;
            }

            final passwordErr = fieldErrors['password'];
            final emailErr = fieldErrors['email'];
            final nonFieldErr = fieldErrors['non_field_errors'] ?? fieldErrors['detail'] ?? fieldErrors['error'];

            if (passwordErr != null) {
              final str = (passwordErr is List && passwordErr.isNotEmpty)
                  ? passwordErr.first.toString()
                  : passwordErr.toString();
              if (str.toLowerCase().contains('common') ||
                  str.toLowerCase().contains('numeric') ||
                  str.toLowerCase().contains('entirely') ||
                  str.toLowerCase().contains('short')) {
                errorMsg = 'పాస్‌వర్డ్ చాలా సాధారణమైనది (12345678 వంటివి అనుమతించబడవు). దయచేసి అక్షరాలు, సంఖ్యలతో బలమైన పాస్‌వర్డ్‌ను ఎంచుకోండి.\n($str)';
              } else {
                errorMsg = 'పాస్‌వర్డ్ లోపం: $str';
              }
            } else if (emailErr != null) {
              final str = (emailErr is List && emailErr.isNotEmpty)
                  ? emailErr.first.toString()
                  : emailErr.toString();
              if (str.toLowerCase().contains('already exists') || str.toLowerCase().contains('unique')) {
                errorMsg = 'ఈ ఇమెయిల్ చిరునామాతో ఇప్పటికే ఖాతా ఉంది. దయచేసి లాగిన్ అవ్వండి.\n($str)';
              } else {
                errorMsg = 'ఇమెయిల్ లోపం: $str';
              }
            } else if (nonFieldErr != null) {
              final str = (nonFieldErr is List && nonFieldErr.isNotEmpty)
                  ? nonFieldErr.first.toString()
                  : nonFieldErr.toString();
              errorMsg = str;
            } else if (resp['errors'] is Map && (resp['errors'] as Map)['message'] != null && (resp['errors'] as Map)['message'].toString().trim() != 'An error occurred.') {
              errorMsg = (resp['errors'] as Map)['message'].toString();
            } else if (resp['message'] != null && resp['message'].toString().trim() != 'An error occurred.') {
              errorMsg = resp['message'].toString();
            } else {
              String? fallbackKeyMsg;
              for (final entry in fieldErrors.entries) {
                final k = entry.key.toString();
                if (['status', 'message', 'code', 'errors', 'details', 'data'].contains(k)) continue;
                final v = entry.value;
                if (v is List && v.isNotEmpty) {
                  fallbackKeyMsg = '$k: ${v.first}';
                  break;
                } else if (v is String && v.isNotEmpty) {
                  fallbackKeyMsg = '$k: $v';
                  break;
                }
              }
              errorMsg = fallbackKeyMsg ?? (resp['message']?.toString() ?? 'రిజిస్ట్రేషన్ విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి.');
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
      appBar: AppBar(title: const Text('ఖాతాను సృష్టించండి')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'మీ ఖాతాను సృష్టించండి',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'వార్తలను అనుకూలీకరించడానికి, కథనాలను సేవ్ చేసుకోవడానికి సైన్ అప్ చేయండి.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13.5),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                autofillHints: const [AutofillHints.name],
                decoration: InputDecoration(
                  labelText: 'పూర్తి పేరు',
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
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'పాస్‌వర్డ్ (కనీసం 8 అక్షరాలు)',
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
                  labelText: 'పాస్‌వర్డ్ నిర్ధారించండి',
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
                          'ఖాతాను సృష్టించండి',
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
                      text: 'ఇప్పటికే ఖాతా ఉందా? ',
                      style: TextStyle(color: AppColors.textMuted),
                      children: [
                        TextSpan(
                          text: 'లాగిన్',
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
