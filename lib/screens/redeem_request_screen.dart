import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

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

class _RedeemRequestScreenState extends State<RedeemRequestScreen> {
  final _upiController = TextEditingController();
  final _accountNameController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  Future<void> _submit() async {
    final upi = _upiController.text.trim();
    final accountName = _accountNameController.text.trim();

    if (upi.isEmpty || !upi.contains('@')) {
      setState(() => _error = 'Please enter a valid UPI ID (e.g. name@bank or 9876543210@upi).');
      return;
    }

    if (widget.availableCoins < widget.minimumCoins) {
      setState(() => _error = 'You need at least ${widget.minimumCoins} coins to request a payout.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await ApiService.instance.createRewardPayout({
        'coins_requested': widget.minimumCoins,
        'payout_method': 'UPI',
        'payout_upi_id': upi,
        if (accountName.isNotEmpty) 'payout_account_name': accountName,
        'user_notes': 'Payout request from Android App',
      });

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payout request for ₹${(widget.minimumCoins * widget.coinValue).toStringAsFixed(0)} submitted successfully!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Failed to submit payout request. Please try again.';
        if (e is DioException) {
          final data = e.response?.data;
          if (data is Map) {
            msg = data['errors']?['message'] ??
                data['errors']?['details']?['non_field_errors']?.first ??
                data['errors']?['details']?['coins_requested']?.first ??
                msg;
          }
        }
        setState(() {
          _isSubmitting = false;
          _error = msg;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final coins = widget.minimumCoins;
    final amount = (coins * widget.coinValue).toStringAsFixed(coins * widget.coinValue == (coins * widget.coinValue).roundToDouble() ? 0 : 2);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Request Payout'),
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
                  color: isDark ? const Color(0xFF2C2412) : const Color(0xFFFFF4E0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFD98E).withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.monetization_on, color: Color(0xFFE8A312), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Redeeming $coins Coins',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Payout Amount: ₹$amount directly to your UPI account',
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

              const Text(
                'UPI ID *',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _upiController,
                enabled: !_isSubmitting,
                decoration: InputDecoration(
                  hintText: 'e.g. yourname@oksbi or mobile@upi',
                  prefixIcon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
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
              const SizedBox(height: 16),

              const Text(
                'Account Holder Name (Optional)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _accountNameController,
                enabled: !_isSubmitting,
                decoration: InputDecoration(
                  hintText: 'As per bank / UPI records',
                  prefixIcon: const Icon(Icons.person_outline, size: 20),
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
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12.5)),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Confirm Payout Request',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Payout requests are verified and transferred directly to your bank account via UPI within 24 to 48 business hours.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4),
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
    _accountNameController.dispose();
    super.dispose();
  }
}
