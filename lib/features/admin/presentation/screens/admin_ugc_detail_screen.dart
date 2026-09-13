import 'package:flutter/material.dart';
import '../../data/models/admin_ugc_status.dart';
import '../../data/models/admin_ugc_submission_model.dart';
import '../controllers/admin_ugc_detail_controller.dart';
import '../theme/admin_colors.dart';
import '../widgets/admin_media_viewer.dart';
import '../widgets/admin_section_label.dart';
import '../widgets/admin_trust_badge.dart';
import '../widgets/dialogs/admin_approval_dialog.dart';
import '../widgets/dialogs/admin_reject_dialog.dart';
import '../widgets/sheets/admin_branded_media_sheet.dart';
import '../widgets/sheets/admin_edit_metadata_sheet.dart';
import '../widgets/sheets/admin_reporter_detail_sheet.dart';

class AdminUgcDetailScreen extends StatefulWidget {
  final AdminUgcSubmissionModel initial;
  const AdminUgcDetailScreen({super.key, required this.initial});

  @override
  State<AdminUgcDetailScreen> createState() => _AdminUgcDetailScreenState();
}

class _AdminUgcDetailScreenState extends State<AdminUgcDetailScreen> {
  late final AdminUgcDetailController _controller = AdminUgcDetailController(submission: widget.initial);

  @override
  void initState() {
    super.initState();
    _controller.loadDetail();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    await showAdminApprovalDialog(
      context,
      submission: _controller.submission,
      onApprove: (notes, level, push) => _controller.approve(notes: notes, publicationLevel: level, push: push),
    );
  }

  Future<void> _reject() async {
    await showAdminRejectDialog(context, onReject: (notes) => _controller.reject(notes: notes));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final s = _controller.submission;
        return Scaffold(
          backgroundColor: AdminColors.scaffold(isDark),
          appBar: AppBar(
            backgroundColor: AdminColors.scaffold(isDark),
            foregroundColor: AdminColors.textPrimary(isDark),
            elevation: 0,
            title: const Text('యూజర్ కథనం సమగ్ర వివరాలు', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            actions: [
              IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => showAdminEditMetadataSheet(context, controller: _controller)),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _controller.loadDetail),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _buildStatusBanner(s, isDark),
              const SizedBox(height: 14),
              AdminMediaViewer(submission: s, onUploadBranded: () => showAdminBrandedMediaSheet(context, controller: _controller)),
              const SizedBox(height: 14),
              _buildContentDetailsCard(s, isDark),
              const SizedBox(height: 14),
              _buildLocationCard(s, isDark),
              const SizedBox(height: 14),
              _buildReporterCard(s, isDark),
            ],
          ),
          bottomNavigationBar: _buildBottomBar(s, isDark),
        );
      },
    );
  }

  Widget _buildStatusBanner(AdminUgcSubmissionModel s, bool isDark) {
    final color = s.status.color(isDark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text('స్థితి: ${s.status.teluguLabel}', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13.5)),
          ),
          if (s.moderationLevel.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AdminColors.card(isDark), borderRadius: BorderRadius.circular(10)),
              child: Text('స్థాయి: ${s.moderationLevel}', style: TextStyle(color: AdminColors.textPrimary(isDark), fontSize: 11, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  Widget _card(bool isDark, {required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.card(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.cardBorder(isDark)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildContentDetailsCard(AdminUgcSubmissionModel s, bool isDark) {
    return _card(isDark, children: [
      AdminSectionLabel(
        'కథన వివరాలు',
        trailing: s.category.isNotEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AdminColors.surface(isDark), borderRadius: BorderRadius.circular(8)),
                child: Text(s.category.toUpperCase(), style: TextStyle(color: AdminColors.textSecondaryColor(isDark), fontSize: 10, fontWeight: FontWeight.w700)),
              )
            : null,
      ),
      const SizedBox(height: 10),
      Text(s.title, style: TextStyle(color: AdminColors.textPrimary(isDark), fontWeight: FontWeight.w800, fontSize: 16)),
      if (s.description.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(s.description, style: TextStyle(color: AdminColors.textSecondaryColor(isDark), fontSize: 13.5, height: 1.4)),
      ],
      if (s.editorNotes.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text('ఎడిటర్ నోట్స్: "${s.editorNotes}"', style: TextStyle(color: AdminColors.textSecondaryColor(isDark), fontSize: 12.5, fontStyle: FontStyle.italic)),
      ],
    ]);
  }

  Widget _buildLocationCard(AdminUgcSubmissionModel s, bool isDark) {
    final parts = [s.village, s.mandal, s.district, s.stateName].where((e) => e.isNotEmpty).join(' · ');
    return _card(isDark, children: [
      const AdminSectionLabel('ప్రాంత వివరాలు'),
      const SizedBox(height: 10),
      Text(parts.isEmpty ? 'లొకేషన్ వివరాలు లేవు' : parts, style: TextStyle(color: AdminColors.textPrimary(isDark), fontSize: 13.5)),
      if (s.latitude != null && s.longitude != null) ...[
        const SizedBox(height: 6),
        Text('GPS: ${s.latitude!.toStringAsFixed(4)}, ${s.longitude!.toStringAsFixed(4)}',
            style: TextStyle(color: AdminColors.textSecondaryColor(isDark), fontSize: 12)),
      ],
    ]);
  }

  Widget _buildReporterCard(AdminUgcSubmissionModel s, bool isDark) {
    return _card(isDark, children: [
      AdminSectionLabel(
        'రిపోర్టర్ & ఆడిట్ ధృవీకరణ',
        trailing: TextButton(
          onPressed: () => showAdminReporterDetailSheet(context, userId: s.reporterUserId, fallbackFrom: s),
          child: const Text('ప్రొఫైల్ చూడండి'),
        ),
      ),
      const SizedBox(height: 6),
      _kv('పేరు', s.reporterName, isDark),
      if (s.reporterEmail.isNotEmpty) _kv('ఇమెయిల్', s.reporterEmail, isDark),
      if (s.reporterMobile.isNotEmpty) _kv('మొబైల్', s.reporterMobile, isDark),
      Row(
        children: [
          Expanded(child: _kv('విశ్వసనీయత స్థాయి', '', isDark, trailing: AdminTrustBadge(level: s.trustLevel))),
        ],
      ),
      _kv('అప్‌లోడర్ హోదా', s.uploaderStatus, isDark),
      if (s.duplicateFlagged) _kv('డూప్లికేట్ స్కోర్', '${s.duplicateScore?.toStringAsFixed(0) ?? '?'}%', isDark),
      _kv('నివేదికల సంఖ్య', s.reportCount.toString(), isDark),
      _kv('సమర్పించిన సమయం', s.submittedAt.toLocal().toString(), isDark),
    ]);
  }

  Widget _kv(String label, String value, bool isDark, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: TextStyle(color: AdminColors.textSecondaryColor(isDark), fontSize: 12))),
          Expanded(child: trailing ?? Text(value, style: TextStyle(color: AdminColors.textPrimary(isDark), fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildBottomBar(AdminUgcSubmissionModel s, bool isDark) {
    Widget content;
    if (s.status.isPendingLike) {
      content = Row(
        children: [
          IconButton(onPressed: _controller.flag, icon: const Icon(Icons.flag_outlined, color: AdminColors.warning)),
          const Spacer(),
          OutlinedButton(
            onPressed: _reject,
            style: OutlinedButton.styleFrom(foregroundColor: AdminColors.error, side: const BorderSide(color: AdminColors.error)),
            child: const Text('తిరస్కరించు'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _approve,
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.success, foregroundColor: Colors.white),
            child: const Text('ఆమోదించు'),
          ),
        ],
      );
    } else if (s.status == AdminUgcStatus.flagged) {
      content = Row(
        children: [
          TextButton(onPressed: () => showAdminReporterDetailSheet(context, userId: s.reporterUserId, fallbackFrom: s), child: const Text('రిపోర్టర్ ప్రొఫైల్')),
          const Spacer(),
          OutlinedButton(
            onPressed: _reject,
            style: OutlinedButton.styleFrom(foregroundColor: AdminColors.error, side: const BorderSide(color: AdminColors.error)),
            child: const Text('తిరస్కరించు'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _approve,
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.success, foregroundColor: Colors.white),
            child: const Text('ఆమోదించు'),
          ),
        ],
      );
    } else {
      content = Row(
        children: [
          TextButton(onPressed: () => showAdminReporterDetailSheet(context, userId: s.reporterUserId, fallbackFrom: s), child: const Text('రిపోర్టర్ ప్రొఫైల్')),
          const Spacer(),
          OutlinedButton(
            onPressed: _controller.decreaseTrust,
            style: OutlinedButton.styleFrom(foregroundColor: AdminColors.warning, side: const BorderSide(color: AdminColors.warning)),
            child: const Text('ట్రస్ట్ -10'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _controller.increaseTrust,
            style: OutlinedButton.styleFrom(foregroundColor: AdminColors.success, side: const BorderSide(color: AdminColors.success)),
            child: const Text('ట్రస్ట్ +10'),
          ),
        ],
      );
    }

    return Material(
      color: AdminColors.card(isDark),
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: content),
      ),
    );
  }
}
