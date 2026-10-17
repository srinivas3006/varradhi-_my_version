import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../widgets/auth/auth_ui.dart';
import 'reset_password_token_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(
          () => _error = 'దయచేసి మీ నమోదిత ఇమెయిల్ చిరునామా నమోదు చేయండి.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ApiService.instance.requestPasswordReset(email);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordTokenScreen(email: email),
        ),
      );
    } catch (e) {
      if (mounted) {
        String errorMsg =
            'పాస్‌వర్డ్ రీసెట్ అభ్యర్థన విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి.';
        if (e is DioException && e.response?.data is Map) {
          final resp = e.response!.data as Map;
          if (resp['errors'] is Map && resp['errors']['message'] != null) {
            errorMsg = resp['errors']['message'].toString();
          }
        }
        setState(() => _error = errorMsg);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: authBackground(context),
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
            const AuthBrandHeader(
              key: Key('forgot_brand_header'),
              icon: Icons.lock_reset_rounded,
              title: 'పాస్‌వర్డ్ మర్చిపోయారా?',
              subtitle: 'చింతించకండి, కొన్ని క్షణాల్లో రీసెట్ చేయవచ్చు',
            ),
            AuthCard(
              key: const Key('forgot_form_card'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AuthCardHeading(
                    title: 'పాస్‌వర్డ్ రీసెట్ చేయండి',
                    note:
                        'మీ ఇమెయిల్ చిరునామా నమోదు చేయండి, పాస్‌వర్డ్ రీసెట్ చేయడానికి మేము మీకు ధృవీకరణ కోడ్‌ను పంపుతాము.',
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    key: const Key('forgot_email_field'),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.send,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    onSubmitted: (_) => _submit(),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    decoration: authFieldDecoration(
                      context,
                      label: 'ఇమెయిల్ చిరునామా',
                      icon: Icons.mail_outline_rounded,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const AuthInfoLine(
                    icon: Icons.mark_email_unread_outlined,
                    text:
                        'కోడ్ రాకపోతే మీ ఇమెయిల్ స్పామ్ ఫోల్డర్‌ను కూడా చూడండి.',
                  ),
                  const SizedBox(height: 8),
                  if (_error != null)
                    AuthErrorBox(_error!, key: const Key('forgot_error')),
                  AuthPrimaryButton(
                    key: const Key('forgot_submit'),
                    label: 'రీసెట్ కోడ్ పంపండి',
                    icon: Icons.send_rounded,
                    busy: _submitting,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -22),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: AuthSecondaryAction(
                  buttonKey: const Key('forgot_back_to_login'),
                  prompt: 'పాస్‌వర్డ్ గుర్తొచ్చిందా?',
                  label: 'లాగిన్‌కు తిరిగి వెళ్ళండి',
                  icon: Icons.login_rounded,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}
