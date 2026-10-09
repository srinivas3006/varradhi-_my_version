import 'package:flutter/material.dart';
import '../core/navigation/auth_guard.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/auth/auth_ui.dart'
    show AuthPrimaryButton, authMuted, authTitle;
import '../widgets/branded_page.dart';

class ReporterIntroScreen extends StatelessWidget {
  const ReporterIntroScreen({super.key});

  static const _steps = [
    (
      Icons.upload_rounded,
      'వార్తను సమర్పించండి',
      'వివరణతో పాటు ఫోటో లేదా వీడియో వార్తను పంచుకోండి.',
    ),
    (
      Icons.fact_check_outlined,
      'సంపాదకీయ సమీక్ష',
      'క్రెడిట్ చేయడానికి ముందు అడ్మిన్ స్వయంగా పరిశీలిస్తారు.',
    ),
    (
      Icons.monetization_on_outlined,
      '1 ఆమోదిత వార్త = 1 టోకెన్',
      '1 టోకెన్ = ₹5, నేరుగా మీ వాలెట్‌కు చేరుతుంది.',
    ),
    (
      Icons.account_balance_wallet_outlined,
      '100 టోకెన్లు చేరినప్పుడు విత్‌డ్రా',
      'మీ వాలెట్‌లో 100 టోకెన్లు (₹500) పూర్తయిన వెంటనే నగదు బదిలీకి దరఖాస్తు చేసుకోండి.',
    ),
  ];

  void _register(BuildContext context) {
    requireAuth(context, () {
      AppState.instance.registerAsReporter();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'మీరు ఇప్పుడు రిపోర్టర్‌గా నమోదయ్యారు! వార్తలు పంపడానికి డ్యాష్‌బోర్డ్‌కు వెళ్లండి.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return BrandedPage(
      barTitle: 'రిపోర్టర్‌గా చేరండి',
      icon: Icons.campaign_rounded,
      title: 'వార్తలు అందించండి. సంపాదించండి.',
      subtitle:
          'మీ ప్రాంతం నుండి ఫోటో లేదా వీడియో వార్తలను పంపండి. సంపాదించడానికి ముందు ప్రతి వార్తను మా సంపాదకీయ బృందం సమీక్షిస్తుంది.',
      bottom: AuthPrimaryButton(
        key: const Key('reporter_register_button'),
        label: 'రిపోర్టర్‌గా నమోదు చేసుకోండి',
        onPressed: () => _register(context),
      ),
      children: [
        const Row(
          children: [
            Expanded(
              child: _StatTile(
                key: Key('reporter_stat_per_story'),
                value: '₹5',
                label: 'ప్రతి ఆమోదిత వార్తకు',
                icon: Icons.monetization_on_rounded,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                key: Key('reporter_stat_withdraw'),
                value: '₹500',
                label: 'చేరగానే విత్‌డ్రా',
                icon: Icons.account_balance_wallet_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SectionCard(
          icon: Icons.route_rounded,
          title: 'ఎలా పనిచేస్తుంది',
          child: Column(
            children: [
              for (var i = 0; i < _steps.length; i++)
                _StepRow(
                  number: i + 1,
                  icon: _steps[i].$1,
                  title: _steps[i].$2,
                  subtitle: _steps[i].$3,
                  isLast: i == _steps.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDarkNavy : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: isDark ? 0.4 : 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 12.5, color: authMuted(context)),
          ),
        ],
      ),
    );
  }
}

/// One step of the timeline: numbered badge, connector line, text.
class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isLast,
  });

  final int number;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, Color(0xFFC81B00)],
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18, top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'దశ $number',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: authTitle(context),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: authMuted(context),
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
