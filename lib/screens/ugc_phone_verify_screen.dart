import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/ugc_phone_verification_controller.dart';
import '../core/errors/ugc_error.dart';
import '../core/navigation/auth_guard.dart';
import '../core/utils/indian_mobile.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// One-time phone verification required before posting UGC/news.
///
/// Pops with the backend-verified 10-digit mobile on success, or null if the
/// user backs out. Login is unaffected — the user is already logged in.
class UgcPhoneVerifyScreen extends StatefulWidget {
  const UgcPhoneVerifyScreen({super.key, this.controller, this.notice});

  /// Injected in tests; created internally otherwise.
  final UgcPhoneVerificationController? controller;

  /// Optional line explaining why verification is being asked for again
  /// (e.g. the backend said the mobile is not verified).
  final String? notice;

  /// Opens the screen and returns the verified mobile, or null.
  static Future<String?> open(BuildContext context, {String? notice}) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => UgcPhoneVerifyScreen(notice: notice),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<UgcPhoneVerifyScreen> createState() => _UgcPhoneVerifyScreenState();
}

class _UgcPhoneVerifyScreenState extends State<UgcPhoneVerifyScreen> {
  late final UgcPhoneVerificationController _c;
  late final bool _ownsController;
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _phoneFocus = FocusNode();
  final _codeFocus = FocusNode();
  UgcVerifyStep _lastStep = UgcVerifyStep.enterPhone;
  bool _popped = false;

  static String _t(String te, String en) =>
      AppState.instance.language == 'Telugu' ? te : en;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _c = widget.controller ??
        UgcPhoneVerificationController(
            initialMobile: AppState.instance.userPhone);
    _phoneController.text = _c.mobile;
    _c.addListener(_onChanged);
  }

  void _onChanged() {
    if (!mounted) return;
    if (_c.step != _lastStep) {
      if (_c.step == UgcVerifyStep.enterCode) {
        _codeController.clear();
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _codeFocus.requestFocus());
      } else if (_c.step == UgcVerifyStep.enterPhone) {
        _codeController.clear();
      }
      _lastStep = _c.step;
    }
    if (_c.step == UgcVerifyStep.verified && !_popped) {
      _popped = true;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text(_t('మొబైల్ ధృవీకరించబడింది', 'Mobile verified')),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.of(context).pop(_c.verifiedMobile);
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _c.removeListener(_onChanged);
    if (_ownsController) _c.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _phoneFocus.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _sendCode() {
    FocusScope.of(context).unfocus();
    _c.setMobile(_phoneController.text);
    _c.sendCode();
  }

  void _submitCode() {
    FocusScope.of(context).unfocus();
    _c.submitCode(_codeController.text);
  }

  Future<void> _relogin() async {
    final ok = await ensureAuth(context);
    if (ok && mounted) _c.editNumber();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      // Don't let a stray back gesture abandon an in-flight verification.
      canPop: !_c.isBusy,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            tooltip: _t('మూసివేయి', 'Close'),
            icon: const Icon(Icons.close_rounded),
            onPressed: _c.isBusy ? null : () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(),
                if (widget.notice != null) ...[
                  const SizedBox(height: 16),
                  _banner(widget.notice!, Icons.info_outline_rounded,
                      Colors.amber.shade800),
                ],
                const SizedBox(height: 28),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _c.step == UgcVerifyStep.enterCode
                      ? _codeStep(isDark)
                      : _phoneStep(isDark),
                ),
                if (_c.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  _banner(_c.errorMessage!, Icons.error_outline_rounded,
                      theme.colorScheme.error),
                ],
                ..._recoveryActions(),
                const SizedBox(height: 28),
                _privacyNote(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.verified_user_rounded,
              size: 40, color: AppColors.primary),
        ),
        const SizedBox(height: 18),
        Text(
          _t('మీ మొబైల్ నంబర్ ధృవీకరించండి', 'Verify your mobile number'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          _t('వార్తలు పంపడానికి ఒక్కసారి మాత్రమే ధృవీకరణ అవసరం. మీ లాగిన్‌పై దీని ప్రభావం ఉండదు.',
              'News uploads need a one-time phone check. Your login is not affected.'),
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 13.5, color: AppColors.textMuted, height: 1.5),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(bool isDark,
      {String? hint, Widget? prefix}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
          color: isDark ? Colors.white24 : const Color(0xFFE1E3E9), width: 1.5),
    );
    return InputDecoration(
      counterText: '',
      hintText: hint,
      prefixIcon: prefix,
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.02),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.primary, width: 1.8)),
    );
  }

  Widget _phoneStep(bool isDark) {
    final sending = _c.busy == UgcVerifyBusy.sendingCode;
    return Column(
      key: const ValueKey('phone-step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_t('మొబైల్ నంబర్', 'Mobile number'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(
          key: const Key('ugc-verify-phone'),
          controller: _phoneController,
          focusNode: _phoneFocus,
          enabled: !_c.isBusy,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.telephoneNumberNational],
          maxLength: 10,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1.5),
          onChanged: _c.setMobile,
          onSubmitted: (_) => _sendCode(),
          decoration: _fieldDecoration(
            isDark,
            hint: '98765 43210',
            prefix: const Padding(
              padding: EdgeInsets.only(left: 16, right: 10),
              child: Center(
                widthFactor: 1,
                child: Text('+91',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted)),
              ),
            ),
          ),
        ),
        if (_c.mode == UgcVerifyMode.backendSms) ...[
          const SizedBox(height: 8),
          Text(_t('OTP SMS ద్వారా పంపబడుతుంది.', 'The OTP will be sent by SMS.'),
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ],
        const SizedBox(height: 20),
        _primaryButton(
          key: const Key('ugc-verify-send'),
          label: _t('OTP పంపండి', 'Send OTP'),
          busy: sending,
          busyLabel: _t('OTP పంపుతోంది…', 'Sending OTP…'),
          onPressed: IndianMobile.isValid(_c.mobile) && !_c.isBusy
              ? _sendCode
              : null,
        ),
      ],
    );
  }

  Widget _codeStep(bool isDark) {
    final verifying = _c.busy == UgcVerifyBusy.verifyingCode ||
        _c.busy == UgcVerifyBusy.linkingAccount;
    return Column(
      key: const ValueKey('code-step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: _t('OTP పంపబడిన నంబర్ ', 'OTP sent to '),
                  children: [
                    TextSpan(
                      text: '+91 ${IndianMobile.format(_c.mobile)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                style: const TextStyle(fontSize: 13.5),
              ),
            ),
            TextButton(
              onPressed: _c.isBusy ? null : _c.editNumber,
              child: Text(_t('మార్చండి', 'Change')),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          key: const Key('ugc-verify-code'),
          controller: _codeController,
          focusNode: _codeFocus,
          enabled: !_c.isBusy,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.oneTimeCode],
          maxLength: UgcPhoneVerificationController.codeLength,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 24, letterSpacing: 14, fontWeight: FontWeight.w800),
          onChanged: (v) {
            if (v.length == UgcPhoneVerificationController.codeLength) {
              _submitCode();
            }
          },
          onSubmitted: (_) => _submitCode(),
          decoration: _fieldDecoration(isDark, hint: '••••••'),
        ),
        const SizedBox(height: 12),
        Center(child: _resendRow()),
        const SizedBox(height: 18),
        _primaryButton(
          key: const Key('ugc-verify-submit'),
          label: _t('ధృవీకరించండి', 'Verify'),
          busy: verifying,
          busyLabel: _c.busy == UgcVerifyBusy.linkingAccount
              ? _t('ఖాతాకు అనుసంధానిస్తోంది…', 'Linking to your account…')
              : _t('ధృవీకరిస్తోంది…', 'Verifying…'),
          onPressed: _c.isBusy ? null : _submitCode,
        ),
      ],
    );
  }

  Widget _resendRow() {
    if (_c.resendSecondsLeft > 0) {
      final s = _c.resendSecondsLeft;
      return Text(
        '${_t('మళ్లీ పంపడానికి ', 'Resend in ')}0:${s.toString().padLeft(2, '0')}',
        style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
      );
    }
    return TextButton(
      onPressed: _c.canResend ? _c.resendCode : null,
      child: Text(_t('OTP మళ్లీ పంపండి', 'Resend OTP'),
          style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  List<Widget> _recoveryActions() {
    final actions = <Widget>[];
    if (_c.canRetryLink) {
      actions.add(OutlinedButton.icon(
        onPressed: _c.isBusy ? null : _c.retryLink,
        icon: const Icon(Icons.refresh_rounded),
        label: Text(_t('మళ్లీ ప్రయత్నించండి', 'Try again')),
      ));
    }
    if (_c.canUseFallback && _c.mode == UgcVerifyMode.firebase) {
      actions.add(OutlinedButton.icon(
        key: const Key('ugc-verify-fallback'),
        onPressed: _c.isBusy ? null : _c.useFallback,
        icon: const Icon(Icons.sms_outlined),
        label: Text(_t('SMS ద్వారా OTP పొందండి', 'Get OTP by SMS')),
      ));
    }
    if (_c.errorKind == UgcErrorKind.sessionExpired) {
      actions.add(OutlinedButton.icon(
        onPressed: _relogin,
        icon: const Icon(Icons.login_rounded),
        label: Text(_t('మళ్లీ లాగిన్ అవ్వండి', 'Log in again')),
      ));
    }
    if (actions.isEmpty) return const [];
    return [
      const SizedBox(height: 12),
      for (final a in actions)
        Padding(padding: const EdgeInsets.only(top: 8), child: a),
    ];
  }

  Widget _primaryButton({
    required Key key,
    required String label,
    required bool busy,
    required String busyLabel,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        key: key,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: busy ? null : onPressed,
        child: busy
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white)),
                  const SizedBox(width: 12),
                  Text(busyLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              )
            : Text(label,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _banner(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13, height: 1.4, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _privacyNote() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lock_outline_rounded,
            size: 16, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _t('ఈ నంబర్ మీ వార్తల ధృవీకరణ కోసం మాత్రమే. ఒకసారి ధృవీకరించిన తర్వాత మార్చడం సాధ్యం కాదు.',
                'This number is used only to verify your news posts. It cannot be changed once verified.'),
            style: const TextStyle(
                fontSize: 11.5, color: AppColors.textMuted, height: 1.45),
          ),
        ),
      ],
    );
  }
}
