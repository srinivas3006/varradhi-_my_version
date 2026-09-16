import 'package:flutter/material.dart';
import '../../../data/models/admin_ugc_status.dart';
import '../../../data/models/admin_ugc_submission_model.dart';
import '../../controllers/admin_load_status.dart';
import '../../controllers/admin_reporter_profile_controller.dart';
import '../../theme/admin_colors.dart';
import '../admin_status_badge.dart';

void showAdminReporterDetailSheet(BuildContext context, {String? userId, AdminUgcSubmissionModel? fallbackFrom}) {
  final controller = AdminReporterProfileController();
  controller.load(userId: userId, fallbackFrom: fallbackFrom);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AdminReporterDetailSheetBody(controller: controller),
  );
}

class _AdminReporterDetailSheetBody extends StatelessWidget {
  final AdminReporterProfileController controller;
  const _AdminReporterDetailSheetBody({required this.controller});

  Color _trustColor(int score) {
    if (score < 34) return AdminColors.error;
    if (score < 67) return AdminColors.warning;
    return AdminColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          decoration: BoxDecoration(
            color: AdminColors.card(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: controller.status == AdminLoadStatus.loading
                  ? const Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: CircularProgressIndicator()))
                  : controller.profile == null
                      ? const Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: Text('Reporter profile unavailable')))
                      : _buildBody(context, isDark),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, bool isDark) {
    final profile = controller.profile!;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_pin_circle_outlined, color: AdminColors.primary, size: 24),
              const SizedBox(width: 10),
              Text('Reporter Profile & Trust', style: TextStyle(color: AdminColors.textPrimary(isDark), fontWeight: FontWeight.w800, fontSize: 17)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AdminColors.surface(isDark), borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AdminColors.primary,
                      child: Text(
                        profile.email.isNotEmpty ? profile.email[0].toUpperCase() : '📱',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.email.isNotEmpty ? profile.email : 'Reporter (${profile.mobile})',
                            style: TextStyle(color: AdminColors.textPrimary(isDark), fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: AdminColors.accentSecondary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                            child: Text(profile.trustLevel.label, style: const TextStyle(color: AdminColors.accentSecondary, fontSize: 10.5, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: profile.trustScore / 100,
                    minHeight: 8,
                    backgroundColor: AdminColors.cardBorder(isDark),
                    valueColor: AlwaysStoppedAnimation(_trustColor(profile.trustScore)),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('${profile.trustScore}/100', style: TextStyle(color: AdminColors.textSecondaryColor(isDark), fontSize: 11)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _statMiniCard('మొత్తం పోస్టులు', profile.submissionsCount.toString(), isDark),
                    const SizedBox(width: 8),
                    _statMiniCard('నేటి అప్‌లోడ్‌లు', profile.dailyUploadsCount.toString(), isDark),
                    const SizedBox(width: 8),
                    _statMiniCard('ఖాతా స్థితి', profile.isBlocked ? 'బ్లాక్ అయింది' : 'క్రియాశీలకం', isDark, valueColor: profile.isBlocked ? AdminColors.error : AdminColors.success),
                  ],
                ),
              ],
            ),
          ),
          if (controller.submissionId != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => controller.increaseTrust(),
                    style: OutlinedButton.styleFrom(foregroundColor: AdminColors.success, side: const BorderSide(color: AdminColors.success)),
                    child: const Text('విశ్వసనీయత పెంచు (+10)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => controller.decreaseTrust(),
                    style: OutlinedButton.styleFrom(foregroundColor: AdminColors.warning, side: const BorderSide(color: AdminColors.warning)),
                    child: const Text('విశ్వసనీయత తగ్గించు (-10)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => controller.toggleBlock(),
                style: ElevatedButton.styleFrom(backgroundColor: profile.isBlocked ? AdminColors.success : AdminColors.error, foregroundColor: Colors.white),
                child: Text(profile.isBlocked ? 'యూజర్‌ను అన్‌బ్లాక్ చేయి' : 'యూజర్‌ను బ్లాక్ చేయి'),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text('ఇటీవలి సమర్పణలు', style: TextStyle(color: AdminColors.textSecondaryColor(isDark), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
          const SizedBox(height: 8),
          ...profile.recentSubmissions.map((s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AdminColors.textPrimary(isDark), fontSize: 13.5))),
                    const SizedBox(width: 8),
                    AdminStatusBadge(status: s.status),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _statMiniCard(String label, String value, bool isDark, {Color? valueColor}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: AdminColors.card(isDark), borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: valueColor ?? AdminColors.textPrimary(isDark), fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: AdminColors.textSecondaryColor(isDark), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
