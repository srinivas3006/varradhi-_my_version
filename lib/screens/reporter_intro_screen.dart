import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class ReporterIntroScreen extends StatelessWidget {
  const ReporterIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Become a Reporter')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.campaign_rounded,
                    color: AppColors.primary, size: 36),
              ),
              const SizedBox(height: 16),
              const Text(
                'Report news. Get paid.',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark),
              ),
              const SizedBox(height: 6),
              const Text(
                'Submit image or video news from your area. Every post is '
                'reviewed by our editorial team before it earns a reward.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13.5, height: 1.4),
              ),
              const SizedBox(height: 24),
              _ruleRow(
                icon: Icons.upload_rounded,
                title: 'Submit a post',
                subtitle: 'Share an image or video news story with a caption.',
              ),
              _ruleRow(
                icon: Icons.fact_check_outlined,
                title: 'Editorial review',
                subtitle: 'An admin manually checks it before anything is credited.',
              ),
              _ruleRow(
                icon: Icons.monetization_on_outlined,
                title: '1 approved post = 1 token',
                subtitle: '1 token = ₹5, credited straight to your wallet.',
              ),
              _ruleRow(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Redeem at 100 tokens',
                subtitle: 'Once your wallet hits 100 tokens (₹500), request a payout.',
              ),
              const Spacer(),
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
                  onPressed: () {
                    AppState.instance.registerAsReporter();
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('You\'re now a Reporter! Head to your dashboard to post.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text('Register as Reporter',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ruleRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
