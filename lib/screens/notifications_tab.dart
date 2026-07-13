import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class _NotificationItem {
  final IconData icon;
  final String title;
  final String body;
  final String time;
  final Color color;

  const _NotificationItem({
    required this.icon,
    required this.title,
    required this.body,
    required this.time,
    required this.color,
  });
}

class NotificationsTab extends StatelessWidget {
  const NotificationsTab({super.key});

  static const List<_NotificationItem> _items = [
    _NotificationItem(
      icon: Icons.monetization_on,
      title: 'You earned 2 coins!',
      body: 'Thanks for reading "ISRO Successfully Launches..."',
      time: '5m ago',
      color: Color(0xFFE8A312),
    ),
    _NotificationItem(
      icon: Icons.local_fire_department,
      title: 'Trending now',
      body: 'India clinches series win with stunning last-over finish',
      time: '1h ago',
      color: Color(0xFFE8412B),
    ),
    _NotificationItem(
      icon: Icons.location_on,
      title: 'Local alert',
      body: 'Heavy rain expected in Hyderabad this week',
      time: '3h ago',
      color: Color(0xFF3B82F6),
    ),
    _NotificationItem(
      icon: Icons.card_giftcard,
      title: 'Redeem your coins',
      body: 'You have enough coins for a ₹10 recharge. Tap to redeem.',
      time: '1d ago',
      color: Color(0xFF10B981),
    ),
    _NotificationItem(
      icon: Icons.newspaper,
      title: 'Daily digest ready',
      body: 'Your personalized morning brief is ready to read.',
      time: '1d ago',
      color: Color(0xFF8B5CF6),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Notifications',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const Divider(height: 24),
              itemBuilder: (context, index) {
                final item = _items[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(item.icon, color: item.color, size: 19),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13.5),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.body,
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.time,
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
