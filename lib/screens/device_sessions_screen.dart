import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class DeviceSessionsScreen extends StatefulWidget {
  const DeviceSessionsScreen({super.key});

  @override
  State<DeviceSessionsScreen> createState() => _DeviceSessionsScreenState();
}

class _DeviceSessionsScreenState extends State<DeviceSessionsScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
    _fetchSessions();
  }

  String _firstString(Map<String, dynamic> json, List<String> keys, [String fallback = '']) {
    for (final key in keys) {
      final value = json[key];
      if (value != null && value.toString().trim().isNotEmpty) return value.toString();
    }
    return fallback;
  }

  Future<void> _fetchSessions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final raw = await ApiService.instance.getDeviceSessions();
      final currentDeviceId = AppState.instance.deviceId;

      final sessions = raw.map((item) {
        final json = item as Map<String, dynamic>;
        final deviceId = _firstString(json, ['device_id']);
        return {
          'id': _firstString(json, ['id', 'session_id']),
          'device': _firstString(json, ['device_name', 'device'], 'Unknown Device'),
          'deviceType': _firstString(json, ['device_type']).toLowerCase(),
          'lastActive': _firstString(json, ['last_active_at', 'last_used_at', 'updated_at', 'created_at']),
          'isCurrent': deviceId.isNotEmpty && deviceId == currentDeviceId,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _sessions = sessions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load device sessions.';
          _isLoading = false;
        });
      }
    }
  }

  String _formatLastActive(String raw) {
    if (raw.isEmpty) return 'Last active unknown';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 5) return 'Active now';
    if (diff.inHours < 1) return 'Last active ${diff.inMinutes}m ago';
    if (diff.inDays < 1) return 'Last active ${diff.inHours}h ago';
    return 'Last active ${diff.inDays}d ago';
  }

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
            onPressed: () async {
              Navigator.pop(context);
              final previousSessions = _sessions;
              setState(() {
                _sessions = _sessions.where((s) => s['id'] != id).toList();
              });
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ApiService.instance.revokeDeviceSession(id);
                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Device session revoked.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _sessions = previousSessions);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Failed to revoke session. Please try again.')),
                  );
                }
              }
            },
            child: const Text('Revoke', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Device Sessions'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0.5,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchSessions, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_sessions.isEmpty) {
      return const Center(child: Text('No active sessions found.', style: TextStyle(color: AppColors.textMuted)));
    }

    return RefreshIndicator(
      onRefresh: _fetchSessions,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: _sessions.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final session = _sessions[index];
          final isCurrent = session['isCurrent'] == true;
          return Container(
            color: Theme.of(context).cardColor,
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
                    (session['deviceType'] as String? ?? '').contains('web')
                        ? Icons.laptop_mac
                        : Icons.phone_iphone,
                    color: isCurrent ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              session['device'] as String? ?? 'Unknown Device',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Current',
                                style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ]
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatLastActive(session['lastActive'] as String? ?? ''),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isCurrent)
                  IconButton(
                    icon: const Icon(Icons.exit_to_app, color: AppColors.primary),
                    onPressed: () => _revokeSession(session['id'] as String),
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
