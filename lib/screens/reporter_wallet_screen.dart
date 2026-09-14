import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/redeem_request.dart';
import '../state/app_state.dart';
import '../services/api_service.dart';
import '../core/navigation/auth_guard.dart';
import 'redeem_request_screen.dart';

class ReporterWalletScreen extends StatefulWidget {
  const ReporterWalletScreen({super.key});

  @override
  State<ReporterWalletScreen> createState() => _ReporterWalletScreenState();
}

class _ReporterWalletScreenState extends State<ReporterWalletScreen> {
  RewardWallet? _wallet;
  List<RewardPayout> _payouts = [];
  bool _loading = false;
  bool _openingPayout = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadWallet();
    });
  }

  Future<void> _loadWallet() async {
    if (_loading || !AppState.instance.isLoggedIn) return;
    _loading = true;
    try {
      final wallet = RewardWallet.fromJson(await ApiService.instance.getRewardWallet());
      if (!mounted) return;
      setState(() => _wallet = wallet);
      final payouts = await ApiService.instance.getRewardPayouts();
      if (!mounted) return;
      setState(() {
        _payouts = payouts.map((json) =>
          RewardPayout.fromJson(Map<String, dynamic>.from(json as Map)),
        ).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          action: SnackBarAction(label: 'Retry', onPressed: _loadWallet),
        ));
      }
    } finally {
      _loading = false;
    }
  }

  Future<void> _openPayout() async {
    if (_openingPayout) return;
    _openingPayout = true;
    try {
    if (!await ensureAuth(context) || !mounted) return;
    if (_loading) return;
    _wallet = null;
    await _loadWallet();
    if (!mounted || _loading || _wallet == null) return;
    final wallet = _wallet!;
    if (wallet.availableCoins < wallet.minimumWithdrawalCoins) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        'విత్‌డ్రా కోసం ఇంకా ${wallet.minimumWithdrawalCoins - wallet.availableCoins} కాయిన్లు కావాలి',
      )));
      return;
    }
    final submitted = await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => RedeemRequestScreen(
        availableCoins: wallet.availableCoins,
        minimumCoins: wallet.minimumWithdrawalCoins,
        coinValue: wallet.coinValueRupees,
      ),
    ));
    if (mounted && submitted == true) await _loadWallet();
    } finally {
      _openingPayout = false;
    }
  }


  String _redeemStatusLabel(RedeemStatus status) {
    switch (status) {
      case RedeemStatus.requested:
        return 'పెండింగ్';
      case RedeemStatus.processing:
        return 'ప్రాసెసింగ్';
      case RedeemStatus.paid:
        return 'చెల్లించబడింది';
      case RedeemStatus.rejected:
        return 'తిరస్కరించబడింది';
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
      case RedeemStatus.rejected:
        return const Color(0xFFEF4444);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final available = _wallet?.availableCoins ?? 0;
        final minimum = _wallet?.minimumWithdrawalCoins ?? AppState.tokensNeededToRedeem;
        final progress = minimum > 0 ? (available / minimum).clamp(0.0, 1.0) : 0.0;
        final canRedeem = _wallet != null && available >= minimum;

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
                    'రివార్డ్‌లు & ఆదాయాలు',
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
                              const Color(0xFFFFD700).withValues(alpha: 0.15),
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
                            color: const Color(0xFFFFD700).withValues(alpha: 0.1),
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
                            color: const Color(0xFFF5A623).withValues(alpha: 0.1),
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
                      // Modern Red Rewards Balance Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFE0001B),
                              Color(0xFFBA0014),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFBA0014).withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // "AVAILABLE COINS" Row
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFBBF24),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.attach_money_rounded,
                                    size: 14,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'అందుబాటులో ఉన్న కాయిన్లు',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.1,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            // Balance + Rupee estimate
                            Builder(
                              builder: (context) {
                                final coins = _wallet?.availableCoins;
                                final rupees = _wallet?.availableValueRupees;
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      coins?.toString() ?? '—',
                                      style: const TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: -1.0,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      rupees == null ? '—' : '≈ ₹${rupees.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white.withValues(alpha: 0.9),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),

                            const SizedBox(height: 14),

                            // Yellow Progress Bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 5,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFBBF24)),
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Subtext
                            Text(
                              canRedeem
                                  ? 'మీరు ఇప్పుడు విత్‌డ్రా చేసుకోవచ్చు.'
                                  : 'విత్‌డ్రా కోసం ఇంకా ${minimum - available} కాయిన్లు కావాలి',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),

                            const SizedBox(height: 18),

                            // CTA: "Withdraw over UPI"
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _openPayout();
                              },
                              child: Container(
                                width: double.infinity,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.account_balance_wallet_outlined,
                                      color: Color(0xFFBA0014),
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'UPI ద్వారా విత్‌డ్రా చేయండి',
                                      style: TextStyle(
                                        color: Color(0xFFBA0014),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Metrics Grid (3 Columns)
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF1F5F9)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _wallet?.lifetimeEarnedCoins.toString() ?? '—',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: isDark ? Colors.white : const Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  const Text(
                                    'మొత్తం ఆదాయం',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF1F5F9)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _wallet?.lockedCoins.toString() ?? '—',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: isDark ? Colors.white : const Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  const Text(
                                    'లాక్ అయినవి',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF1F5F9)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _wallet?.redeemedCoins.toString() ?? '—',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: isDark ? Colors.white : const Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  const Text(
                                    'విత్‌డ్రా చేసినవి',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // History Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'లావాదేవీల చరిత్ర',
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
                      
                      if (_payouts.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40.0),
                            child: Column(
                              children: [
                                Icon(Icons.receipt_long_rounded, size: 48, color: isDark ? Colors.white24 : Colors.black12),
                                const SizedBox(height: 16),
                                Text(
                                  'ఇంకా లావాదేవీలు లేవు.',
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
                        ..._payouts.map((r) => Container(
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
                                color: Colors.black.withValues(alpha: 0.02),
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
                                      '₹${r.valueRupees.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: isDark ? Colors.white : Colors.black87,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'UPI: ${r.payoutUpiId ?? ''}',
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
                                    '-${r.coinsRequested} టోకెన్లు',
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
                                      color: _redeemStatusColor(r.parsedStatus).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _redeemStatusLabel(r.parsedStatus),
                                      style: TextStyle(
                                        color: _redeemStatusColor(r.parsedStatus),
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
