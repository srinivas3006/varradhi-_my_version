import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Withdrawal request (POST /api/v1/rewards/payouts/).
///
/// The user picks how many coins (minimum … available) and where to send
/// them: a UPI ID, or a PhonePe mobile number. BANK is not offered — the
/// backend has no account-number / IFSC fields yet.
class RedeemRequestScreen extends StatefulWidget {
  final int minimumCoins;
  final int availableCoins;
  final double coinValue;

  const RedeemRequestScreen({
    super.key,
    this.minimumCoins = 100,
    this.availableCoins = 100,
    this.coinValue = 1.0,
  });

  @override
  State<RedeemRequestScreen> createState() => _RedeemRequestScreenState();
}

enum PayoutMethod { upi, phonepe }

/// The message to show for a failed payout request, from the backend's
/// error envelope: `errors.details` first (field messages such as
/// "Insufficient available coins."), then a message for the status code.
/// Returns the per-field messages in [fieldErrors].
String payoutErrorMessage(Object error, Map<String, String> fieldErrors) {
  const fallback = 'నగదు బదిలీ అభ్యర్థన విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి.';
  if (error is! DioException) return fallback;
  final code = error.response?.statusCode;
  final data = error.response?.data;
  final errors = data is Map ? data['errors'] : null;
  final details = errors is Map ? errors['details'] : null;

  if (details is Map && details.isNotEmpty) {
    final all = <String>[];
    details.forEach((field, v) {
      final msgs = v is List ? v.map((e) => e.toString()) : [v.toString()];
      final text = msgs.where((m) => m.trim().isNotEmpty).join(' ');
      if (text.isEmpty) return;
      fieldErrors[field.toString()] = text;
      all.add(text);
    });
    if (all.isNotEmpty) return all.join('\n');
  }
  if (details is String && details.trim().isNotEmpty) return details;

  switch (code) {
    case 401:
      return 'సెషన్ ముగిసింది. దయచేసి మళ్లీ లాగిన్ అవ్వండి.';
    case 403:
      return 'ఈ పనికి మీకు అనుమతి లేదు.';
    case 429:
      return 'చాలా ఎక్కువ ప్రయత్నాలు. కొద్దిసేపు ఆగి మళ్లీ ప్రయత్నించండి.';
  }
  if (code != null && code >= 500) {
    return 'సర్వర్ సమస్య. మీ వివరాలు అలాగే ఉన్నాయి — మళ్లీ ప్రయత్నించండి.';
  }
  if (code == null) {
    return 'ఇంటర్నెట్ కనెక్షన్ లేదు. మళ్లీ ప్రయత్నించండి.';
  }
  final msg = errors is Map ? errors['message']?.toString() : null;
  if (msg != null && msg.isNotEmpty && msg != 'An error occurred.') return msg;
  return fallback;
}

class _RedeemRequestScreenState extends State<RedeemRequestScreen> {
  final _coinsController = TextEditingController();
  final _upiController = TextEditingController();
  final _mobileController = TextEditingController();
  final _accountNameController = TextEditingController();
  PayoutMethod _method = PayoutMethod.upi;
  bool _isSubmitting = false;
  bool _cooldown = false;
  String? _error;
  Map<String, String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    // Default to everything available; the user can lower it.
    _coinsController.text = '${widget.availableCoins}';
    _coinsController.addListener(() => setState(() {}));
  }

  int? get _coins => int.tryParse(_coinsController.text.trim());

  String _rupees(double v) =>
      '₹${v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2)}';

  Future<void> _submit() async {
    if (_isSubmitting || _cooldown) return;
    final coins = _coins;
    final upi = _upiController.text.trim();
    final mobile = _mobileController.text.trim();
    final accountName = _accountNameController.text.trim();
    final fieldErrors = <String, String>{};

    if (coins == null || coins < widget.minimumCoins) {
      fieldErrors['coins_requested'] =
          'కనీసం ${widget.minimumCoins} కాయిన్లు విత్‌డ్రా చేయాలి.';
    } else if (coins > widget.availableCoins) {
      fieldErrors['coins_requested'] =
          'మీ దగ్గర ${widget.availableCoins} కాయిన్లు మాత్రమే ఉన్నాయి.';
    }
    if (_method == PayoutMethod.upi &&
        !RegExp(r'^[a-zA-Z0-9._-]+@[a-zA-Z0-9][a-zA-Z0-9.-]*$').hasMatch(upi)) {
      fieldErrors['payout_upi_id'] =
          'సరైన UPI ID నమోదు చేయండి (ఉదా: name@bank లేదా 9876543210@upi).';
    }
    if (_method == PayoutMethod.phonepe &&
        !RegExp(r'^[6-9]\d{9}$').hasMatch(mobile)) {
      fieldErrors['payout_mobile'] = 'సరైన 10 అంకెల మొబైల్ నంబర్ నమోదు చేయండి.';
    }
    if (fieldErrors.isNotEmpty) {
      setState(() {
        _fieldErrors = fieldErrors;
        _error = null;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
      _fieldErrors = {};
    });

    try {
      await ApiService.instance.createRewardPayout({
        'coins_requested': coins,
        'payout_method': _method == PayoutMethod.upi ? 'UPI' : 'PHONEPE',
        'payout_upi_id': _method == PayoutMethod.upi ? upi : '',
        'payout_mobile': _method == PayoutMethod.phonepe ? mobile : '',
        'payout_account_name': accountName,
        'user_notes': 'Payout request from Android App',
      });

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop(true);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
                '${_rupees(coins! * widget.coinValue)} విత్‌డ్రా అభ్యర్థన పంపబడింది. చెల్లించే వరకు $coins కాయిన్లు హోల్డ్‌లో ఉంటాయి.'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final fields = <String, String>{};
      final msg = payoutErrorMessage(e, fields);
      final code = e is DioException ? e.response?.statusCode : null;
      setState(() {
        _isSubmitting = false;
        _fieldErrors = fields;
        _error = msg;
        // 429: pause submitting for a moment.
        _cooldown = code == 429;
      });
      if (code == 429) {
        Future.delayed(const Duration(seconds: 30), () {
          if (mounted) setState(() => _cooldown = false);
        });
      }
    }
  }

  InputDecoration _decoration(
      bool isDark, String hint, IconData icon, String? errorText) {
    final border = BorderSide(
        color: isDark ? Colors.white24 : const Color(0xFFE7E9EE), width: 1.5);
    return InputDecoration(
      hintText: hint,
      errorText: errorText,
      errorMaxLines: 3,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.02),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: border),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: border),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
      );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coins = _coins ?? 0;
    final amount = _rupees(coins * widget.coinValue);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('విత్‌డ్రా అభ్యర్థన'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2C2412)
                      : const Color(0xFFFFF4E0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFFFFD98E).withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.monetization_on,
                        color: Color(0xFFE8A312), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'మీకు వచ్చేది: $amount',
                            key: const Key('redeem_amount'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 17),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'అందుబాటులో ${widget.availableCoins} కాయిన్లు · 1 కాయిన్ = ${_rupees(widget.coinValue)} · కనీసం ${widget.minimumCoins}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _label('ఎన్ని కాయిన్లు? *'),
              TextField(
                key: const Key('redeem_coins'),
                controller: _coinsController,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _decoration(
                    isDark,
                    '${widget.minimumCoins} – ${widget.availableCoins}',
                    Icons.toll_outlined,
                    _fieldErrors['coins_requested']),
              ),
              const SizedBox(height: 18),
              _label('ఎక్కడికి పంపాలి? *'),
              SegmentedButton<PayoutMethod>(
                key: const Key('redeem_method'),
                segments: const [
                  ButtonSegment(
                      value: PayoutMethod.upi,
                      label: Text('UPI ID'),
                      icon: Icon(Icons.account_balance_wallet_outlined)),
                  ButtonSegment(
                      value: PayoutMethod.phonepe,
                      label: Text('PhonePe నంబర్'),
                      icon: Icon(Icons.phone_android_rounded)),
                ],
                selected: {_method},
                onSelectionChanged: _isSubmitting
                    ? null
                    : (s) => setState(() {
                          _method = s.first;
                          _fieldErrors = {};
                        }),
              ),
              const SizedBox(height: 14),
              if (_method == PayoutMethod.upi)
                TextField(
                  key: const Key('redeem_upi'),
                  controller: _upiController,
                  enabled: !_isSubmitting,
                  decoration: _decoration(
                      isDark,
                      'ఉదా: yourname@oksbi లేదా mobile@upi',
                      Icons.alternate_email_rounded,
                      _fieldErrors['payout_upi_id']),
                )
              else
                TextField(
                  key: const Key('redeem_mobile'),
                  controller: _mobileController,
                  enabled: !_isSubmitting,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _decoration(isDark, 'PhonePe మొబైల్ నంబర్',
                      Icons.phone_rounded, _fieldErrors['payout_mobile']),
                ),
              const SizedBox(height: 16),
              _label('ఖాతాదారుని పేరు (ఐచ్ఛికం)'),
              TextField(
                controller: _accountNameController,
                enabled: !_isSubmitting,
                decoration: _decoration(
                    isDark,
                    'బ్యాంక్ / UPI రికార్డుల ప్రకారం',
                    Icons.person_outline,
                    _fieldErrors['payout_account_name']),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  key: const Key('redeem_error'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 12.5)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  key: const Key('redeem_submit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: _isSubmitting || _cooldown ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text('$amount విత్‌డ్రా చేయండి',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'అభ్యర్థన పంపగానే ఆ కాయిన్లు హోల్డ్‌లోకి వెళ్తాయి. అడ్మిన్ ధృవీకరించి చెల్లించిన తర్వాత "విత్‌డ్రాలు"లో రిఫరెన్స్ నంబర్ కనిపిస్తుంది. తిరస్కరిస్తే కాయిన్లు తిరిగి మీ బ్యాలెన్స్‌కి వస్తాయి.',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textMuted, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _coinsController.dispose();
    _upiController.dispose();
    _mobileController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }
}
