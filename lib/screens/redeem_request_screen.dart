import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class RedeemRequestScreen extends StatefulWidget {
  const RedeemRequestScreen({super.key});

  @override
  State<RedeemRequestScreen> createState() => _RedeemRequestScreenState();
}

class _RedeemRequestScreenState extends State<RedeemRequestScreen> {
  final _upiController = TextEditingController();
  String? _error;

  void _submit() {
    final upi = _upiController.text.trim();
    if (upi.isEmpty || !upi.contains('@')) {
      setState(() => _error = 'Enter a valid UPI ID (e.g. name@bank).');
      return;
    }
    final request = AppState.instance.requestRedeem(upi);
    if (request == null) {
      setState(() => _error = 'You need at least 100 tokens to redeem.');
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Redeem request for ₹${request.amountRupees} submitted.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const tokens = AppState.tokensNeededToRedeem;
    const amount = tokens * AppState.rupeesPerToken;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Request Redeem')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFD98E)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.monetization_on, color: Color(0xFFE8A312)),
                    SizedBox(width: 10),
                    Text('Redeeming $tokens tokens for ₹$amount',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('UPI ID',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              const SizedBox(height: 8),
              TextField(
                controller: _upiController,
                decoration: InputDecoration(
                  hintText: 'yourname@bank',
                  filled: true,
                  fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFE7E9EE), width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFE7E9EE), width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: _submit,
                  child: const Text('Confirm Request',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Payouts are processed manually by our team after verification. '
                'This is a demo — no real payment is sent.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _upiController.dispose();
    super.dispose();
  }
}
