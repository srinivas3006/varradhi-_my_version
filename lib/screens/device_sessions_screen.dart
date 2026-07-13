import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DeviceSessionsScreen extends StatefulWidget {
  const DeviceSessionsScreen({super.key});

  @override
  State<DeviceSessionsScreen> createState() => _DeviceSessionsScreenState();
}

class _DeviceSessionsScreenState extends State<DeviceSessionsScreen> {
  // Mock sessions
  final List<Map<String, dynamic>> _sessions = [
    {
      'id': '1',
      'device': 'iPhone 14 Pro Max',
      'location': 'Hyderabad, India',
      'lastActive': 'Active now',
      'isCurrent': true,
    },
    {
      'id': '2',
      'device': 'MacBook Pro 16"',
      'location': 'Hyderabad, India',
      'lastActive': 'Last active 2 days ago',
      'isCurrent': false,
    },
    {
      'id': '3',
      'device': 'Samsung Galaxy S22',
      'location': 'Mumbai, India',
      'lastActive': 'Last active 1 week ago',
      'isCurrent': false,
    },
  ];

  void _revokeSession(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Session?'),
        content: const Text('Are you sure you want to log out from this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _sessions.removeWhere((s) => s['id'] == id);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Device session revoked.')),
              );
            },
            child: const Text('Revoke', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Device Sessions'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0.5,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: _sessions.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final session = _sessions[index];
          return Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.chipBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    session['device'].toString().contains('MacBook')
                        ? Icons.laptop_mac
                        : Icons.phone_iphone,
                    color: session['isCurrent'] ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            session['device'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          if (session['isCurrent']) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Current',
                                style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ]
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${session['location']} • ${session['lastActive']}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!session['isCurrent'])
                  IconButton(
                    icon: const Icon(Icons.exit_to_app, color: Colors.red),
                    onPressed: () => _revokeSession(session['id']),
                    tooltip: 'Revoke Session',
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
