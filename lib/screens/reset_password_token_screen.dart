import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'reset_password_confirm_screen.dart';

class ResetPasswordTokenScreen extends StatefulWidget {
  final String email;
  const ResetPasswordTokenScreen({super.key, required this.email});

  @override
  State<ResetPasswordTokenScreen> createState() => _ResetPasswordTokenScreenState();
}

class _ResetPasswordTokenScreenState extends State<ResetPasswordTokenScreen> {
  final _tokenController = TextEditingController();
  bool _submitting = false;
  String? _error;

  Future<void> _verifyToken() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() => _error = 'దయచేసి మీ ఇమెయిల్‌కు పంపిన రీసెట్ కోడ్‌ను నమోదు చేయండి.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ApiService.instance.verifyPasswordReset(widget.email, token);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordConfirmScreen(
            email: widget.email,
            token: token,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        String errorMsg = 'చెల్లని లేదా గడువు ముగిసిన ధృవీకరణ కోడ్.';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('కోడ్ ధృవీకరించండి')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ధృవీకరణ కోడ్‌ను నమోదు చేయండి',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'మేము ${widget.email} కి రీసెట్ కోడ్‌ను పంపాము. కొనసాగడానికి దాన్ని కింద నమోదు చేయండి.',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13.5),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _tokenController,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  labelText: 'ధృవీకరణ కోడ్',
                  filled: true,
                  fillColor: isDark ? AppColors.chipBgDark : AppColors.chipBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: const TextStyle(color: AppColors.primary, fontSize: 12.5)),
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
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: _submitting ? null : _verifyToken,
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text('కోడ్‌ను ధృవీకరించండి',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
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
    _tokenController.dispose();
    super.dispose();
  }
}
