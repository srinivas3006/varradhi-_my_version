import 'package:flutter/material.dart';
import '../models/redeem_request.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'redeem_request_screen.dart';

class ReporterWalletScreen extends StatelessWidget {
  const ReporterWalletScreen({super.key});

  String _redeemStatusLabel(RedeemStatus status) {
    switch (status) {
      case RedeemStatus.requested:
        return 'Requested';
      case RedeemStatus.processing:
        return 'Processing';
      case RedeemStatus.paid:
        return 'Paid';
    }
  }

  Color _redeemStatusColor(RedeemStatus status) {
    switch (status) {
      case RedeemStatus.requested:
        return const Color(0xFFE8A312);
      case RedeemStatus.processing:
        return const Color(0xFF3B82F6);
      case RedeemStatus.paid:
        return const Color(0xFF10B981);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final state = AppState.instance;
        final progress =
            (state.reporterTokens / AppState.tokensNeededToRedeem).clamp(0.0, 1.0);
        final canRedeem = state.reporterTokens >= AppState.tokensNeededToRedeem;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(title: const Text('Reporter Wallet')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFC94A), Color(0xFFE8A312)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Wallet balance',
                          style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                      const SizedBox(height: 6),
                      Text('${state.reporterTokens} tokens',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                      Text('≈ ₹${state.reporterTokens * AppState.rupeesPerToken}',
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Progress to redeem',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                          Text(
                              '${state.reporterTokens} / ${AppState.tokensNeededToRedeem} tokens',
                              style: const TextStyle(
                                  fontSize: 12.5, color: AppColors.textMuted)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 10,
                          backgroundColor: AppColors.chipBg,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                canRedeem ? AppColors.primary : AppColors.chipBg,
                            foregroundColor: canRedeem ? Colors.white : AppColors.textMuted,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: canRedeem
                              ? () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const RedeemRequestScreen()),
                                  )
                              : null,
                          child: Text(
                            canRedeem
                                ? 'Request Redeem'
                                : 'Reach ${AppState.tokensNeededToRedeem} tokens to redeem',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Redemption history',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 10),
                if (state.redeemRequests.isEmpty)
                  const Text('No redeem requests yet.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12.5))
                else
                  ...state.redeemRequests.map((r) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('₹${r.amountRupees} · ${r.tokensRedeemed} tokens',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700, fontSize: 13.5)),
                                  const SizedBox(height: 2),
                                  Text('UPI: ${r.upiId}',
                                      style: const TextStyle(
                                          fontSize: 11.5, color: AppColors.textMuted)),
                                ],
                              ),
                            ),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _redeemStatusColor(r.status).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _redeemStatusLabel(r.status),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _redeemStatusColor(r.status),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
              ],
            ),
          ),
        );
      },
    );
  }
}
