import 'package:flutter/material.dart';
import '../screens/horoscope_screen.dart';
import '../screens/jobs_services_screen.dart';
import '../screens/live_cricket_screen.dart';
import '../screens/magazines_screen.dart';
import '../theme/app_theme.dart';

class QuickLinksRow extends StatelessWidget {
  const QuickLinksRow({super.key});

  @override
  Widget build(BuildContext context) {
    final links = [
      (
        icon: Icons.work_outline_rounded,
        label: 'Jobs',
        color: const Color(0xFF3B82F6),
        builder: () => const JobsServicesScreen(),
      ),
      (
        icon: Icons.handyman_outlined,
        label: 'Services',
        color: const Color(0xFF10B981),
        builder: () => const JobsServicesScreen(),
      ),
      (
        icon: Icons.sports_cricket_rounded,
        label: 'Cricket',
        color: const Color(0xFFE8412B),
        builder: () => const LiveCricketScreen(),
      ),
      (
        icon: Icons.menu_book_rounded,
        label: 'Magazines',
        color: const Color(0xFF8B5CF6),
        builder: () => const MagazinesScreen(),
      ),
      (
        icon: Icons.auto_awesome_rounded,
        label: 'Horoscope',
        color: const Color(0xFFE8A312),
        builder: () => const HoroscopeScreen(),
      ),
    ];

    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: links.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final link = links[index];
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => link.builder()),
            ),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: link.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(link.icon, color: link.color, size: 24),
                ),
                const SizedBox(height: 6),
                Text(
                  link.label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
