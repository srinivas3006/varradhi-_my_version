import 'dart:ui';
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
        return 'Pending';
      case RedeemStatus.processing:
        return 'Processing';
      case RedeemStatus.paid:
        return 'Paid';
    }
  }

  Color _redeemStatusColor(RedeemStatus status) {
    switch (status) {
      case RedeemStatus.requested:
        return const Color(0xFFFFD700);
      case RedeemStatus.processing:
        return const Color(0xFF3B82F6);
      case RedeemStatus.paid:
        return const Color(0xFF10B981);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final state = AppState.instance;
        final progress =
            (state.reporterTokens / AppState.tokensNeededToRedeem).clamp(0.0, 1.0);
        final canRedeem = state.reporterTokens >= AppState.tokensNeededToRedeem;

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
          body: CustomScrollView(
            slivers: [
              // Premium App Bar
              SliverAppBar(
                expandedHeight: 240.0,
                floating: false,
                pinned: true,
                backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                elevation: 0,
                iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                  title: Text(
                    'Rewards & Earnings',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Premium Background Gradient
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFFFFD700).withOpacity(0.15),
                              isDark ? const Color(0xFF1A1A1A) : Colors.white,
                            ],
                          ),
                        ),
                      ),
                      // Decorative circles
                      Positioned(
                        top: -50,
                        right: -50,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFFD700).withOpacity(0.1),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 50,
                        left: -30,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFF5A623).withOpacity(0.1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Balance Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2C2C2C), Color(0xFF1A1A1A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD700).withOpacity(0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            )
                          ],
                          border: Border.all(
                            color: const Color(0xFFFFD700).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total Balance',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 14,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFD700).withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet_rounded,
                                    color: Color(0xFFFFD700),
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '₹${state.reporterTokens * AppState.rupeesPerToken}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${state.reporterTokens} Tokens Earned',
                                style: const TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Progress Section
                      Text(
                        'Redemption Progress',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: isDark ? [] : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${(progress * 100).toInt()}% towards goal',
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : Colors.black54,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${state.reporterTokens} / ${AppState.tokensNeededToRedeem}',
                                  style: TextStyle(
                                    color: isDark ? Colors.white54 : Colors.black45,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  canRedeem ? const Color(0xFF10B981) : const Color(0xFFFFD700),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: canRedeem 
                                      ? const Color(0xFFFFD700) 
                                      : (isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade300),
                                  foregroundColor: canRedeem 
                                      ? Colors.black87 
                                      : (isDark ? Colors.white54 : Colors.black38),
                                  elevation: canRedeem ? 4 : 0,
                                  shadowColor: const Color(0xFFFFD700).withOpacity(0.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
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
                                      ? 'Request Payout'
                                      : 'Need ${AppState.tokensNeededToRedeem - state.reporterTokens} more to redeem',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // History Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Transaction History',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Icon(Icons.history_rounded, color: isDark ? Colors.white54 : Colors.black45, size: 20),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      if (state.redeemRequests.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40.0),
                            child: Column(
                              children: [
                                Icon(Icons.receipt_long_rounded, size: 48, color: isDark ? Colors.white24 : Colors.black12),
                                const SizedBox(height: 16),
                                Text(
                                  'No transactions yet.',
                                  style: TextStyle(
                                    color: isDark ? Colors.white54 : Colors.black45,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...state.redeemRequests.map((r) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade200,
                            ),
                            boxShadow: isDark ? [] : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.currency_rupee_rounded,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '₹${r.amountRupees}',
                                      style: TextStyle(
                                        color: isDark ? Colors.white : Colors.black87,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'UPI: ${r.upiId}',
                                      style: TextStyle(
                                        color: isDark ? Colors.white54 : Colors.black45,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '-${r.tokensRedeemed} Tokens',
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _redeemStatusColor(r.status).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _redeemStatusLabel(r.status),
                                      style: TextStyle(
                                        color: _redeemStatusColor(r.status),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
