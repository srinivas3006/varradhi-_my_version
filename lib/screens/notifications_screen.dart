import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../state/app_state.dart';
import '../models/app_notification.dart';
import '../theme/app_theme.dart';

import 'account_login_screen.dart';
import 'notification_settings_screen.dart';
import 'notifications_tab.dart';
import '../services/api_service.dart';
import '../core/navigation/notification_deep_link_resolver.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (AppState.instance.isLoggedIn) {
      _loadNotifications();
    }
  }

  Future<void> _loadNotifications() async {
    if (!AppState.instance.isLoggedIn) return;
    setState(() => _isLoading = true);
    await AppState.instance.fetchNotifications();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'నోటిఫికేషన్లు',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'ఇన్‌బాక్స్'),
              Tab(text: 'యాక్టివిటీ డైజెస్ట్'),
            ],
          ),
          actions: [
            AnimatedBuilder(
              animation: AppState.instance,
              builder: (context, _) {
                if (AppState.instance.unreadNotificationsCount == 0 || !AppState.instance.isLoggedIn) {
                  return const SizedBox.shrink();
                }
                return TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    AppState.instance.markAllNotificationsRead();
                  },
                  child: const Text('అన్నీ చదివినట్లు గుర్తించు', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.tune_rounded, color: isDark ? Colors.white70 : Colors.black87),
              tooltip: 'నోటిఫికేషన్ సెట్టింగ్‌లు',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
                );
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            AnimatedBuilder(
              animation: AppState.instance,
              builder: (context, _) {
                if (!AppState.instance.isLoggedIn) {
                  return _buildLoginRequired(isDark);
                }

                final notifications = AppState.instance.notifications;
                
                if (_isLoading && notifications.isEmpty) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }

                if (notifications.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _loadNotifications,
                    color: AppColors.primary,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.7,
                        child: _buildEmptyState(isDark),
                      ),
                    ),
                  );
                }
                
                return RefreshIndicator(
                  onRefresh: _loadNotifications,
                  color: AppColors.primary,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: notifications.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildNotificationCard(notifications[index], isDark);
                    },
                  ),
                );
              },
            ),
            const NotificationsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginRequired(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mark_email_unread_outlined, size: 64, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 16),
            Text(
              'నోటిఫికేషన్ల కోసం లాగిన్ అవ్వండి',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'తాజా వార్తల అలర్ట్‌లు, సంపాదకీయ సమాచారం మరియు మీ వార్తల స్థితి అప్‌డేట్‌లను పొందడానికి లాగిన్ అవ్వండి.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AccountLoginScreen()),
                );
                if (AppState.instance.isLoggedIn) {
                  _loadNotifications();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('లాగిన్ / రిజిస్టర్', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 64, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 16),
          Text(
            'ఇంకా ఎలాంటి నోటిఫికేషన్లు లేవు',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'కొత్త అప్‌డేట్‌లు వచ్చినప్పుడు మీకు ఇక్కడ తెలియజేస్తాము.',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(AppNotification notification, bool isDark) {
    final bool isUnread = !notification.isRead;
    
    // Determine icon and color based on type
    IconData icon;
    Color iconColor;
    switch (notification.type) {
      case NotificationType.approved:
        icon = Icons.check_circle_outline_rounded;
        iconColor = Colors.green;
        break;
      case NotificationType.rejected:
        icon = Icons.cancel_outlined;
        iconColor = Colors.red;
        break;
      case NotificationType.pending:
        icon = Icons.hourglass_empty_rounded;
        iconColor = Colors.amber;
        break;
      case NotificationType.announcement:
        icon = Icons.celebration_outlined;
        iconColor = AppColors.primary;
        break;
    }

    return GestureDetector(
      onTap: () async {
        if (isUnread) {
          HapticFeedback.lightImpact();
          AppState.instance.markNotificationRead(notification.id);
          ApiService.instance.markNotificationRead(notification.id);
        }

        final target = NotificationDeepLinkResolver.resolveFromAppNotification(notification);
        if (mounted) {
          NotificationService.instance.navigateToTarget(target, context: context);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUnread 
              ? (isDark ? AppColors.primary.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.05))
              : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnread
                ? AppColors.primary.withValues(alpha: 0.3)
                : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
            width: isUnread ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        _formatTimestamp(notification.timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.message,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? (isUnread ? Colors.white70 : Colors.white54) : (isUnread ? Colors.black87 : Colors.black54),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (notification.imageUrl != null && notification.imageUrl!.isNotEmpty) ...[
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  notification.imageUrl!,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
            if (isUnread) ...[
              const SizedBox(width: 12),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} నిమిషాల కిందట';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} గంటల కిందట';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} రోజుల కిందట';
    } else {
      return DateFormat('MMM d').format(time);
    }
  }
}
