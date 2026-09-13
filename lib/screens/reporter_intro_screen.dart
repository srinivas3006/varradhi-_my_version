import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class ReporterIntroScreen extends StatelessWidget {
  const ReporterIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('రిపోర్టర్‌గా చేరండి')),
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
                'వార్తలు అందించండి. సంపాదించండి.',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark),
              ),
              const SizedBox(height: 6),
              const Text(
                'మీ ప్రాంతం నుండి ఫోటో లేదా వీడియో వార్తలను పంపండి. సంపాదించడానికి ముందు ప్రతి వార్తను మా సంపాదకీయ బృందం సమీక్షిస్తుంది.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13.5, height: 1.4),
              ),
              const SizedBox(height: 24),
              _ruleRow(
                icon: Icons.upload_rounded,
                title: 'వార్తను సమర్పించండి',
                subtitle: 'వివరణతో పాటు ఫోటో లేదా వీడియో వార్తను పంచుకోండి.',
              ),
              _ruleRow(
                icon: Icons.fact_check_outlined,
                title: 'సంపాదకీయ సమీక్ష',
                subtitle: 'క్రెడిట్ చేయడానికి ముందు అడ్మిన్ స్వయంగా పరిశీలిస్తారు.',
              ),
              _ruleRow(
                icon: Icons.monetization_on_outlined,
                title: '1 ఆమోదిత వార్త = 1 టోకెన్',
                subtitle: '1 టోకెన్ = ₹5, నేరుగా మీ వాలెట్‌కు చేరుతుంది.',
              ),
              _ruleRow(
                icon: Icons.account_balance_wallet_outlined,
                title: '100 టోకెన్లు చేరినప్పుడు విత్‌డ్రా',
                subtitle: 'మీ వాలెట్‌లో 100 టోకెన్లు (₹500) పూర్తయిన వెంటనే నగదు బదిలీకి దరఖాస్తు చేసుకోండి.',
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
                        content: Text('మీరు ఇప్పుడు రిపోర్టర్‌గా నమోదయ్యారు! వార్తలు పంపడానికి డ్యాష్‌బోర్డ్‌కు వెళ్లండి.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text('రిపోర్టర్‌గా నమోదు చేసుకోండి',
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
