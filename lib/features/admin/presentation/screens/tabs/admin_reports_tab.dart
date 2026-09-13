import 'package:flutter/material.dart';

import '../../../data/models/admin_ugc_options.dart';
import '../../controllers/admin_load_status.dart';
import '../../controllers/admin_reports_controller.dart';
import '../../widgets/admin_filter_chip_row.dart';
import '../../widgets/admin_report_card.dart';
import '../../widgets/admin_status_state.dart';

class AdminReportsTab extends StatefulWidget {
  final AdminReportsController controller;
  const AdminReportsTab({super.key, required this.controller});

  @override
  State<AdminReportsTab> createState() => _AdminReportsTabState();
}

class _AdminReportsTabState extends State<AdminReportsTab> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.controller.loadInitial();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.maxScrollExtent - _scrollController.position.pixels < 250) {
      widget.controller.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        return Column(
          children: [
            const SizedBox(height: 8),
            AdminFilterChipRow<String>(
              options: AdminUgcOptions.reportStatuses.map((s) => AdminFilterChipOption(s, _reportStatusLabel(s))).toList(),
              selected: c.statusFilter,
              onSelect: c.setStatusFilter,
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildList(c)),
          ],
        );
      },
    );
  }

  Widget _buildList(AdminReportsController c) {
    if (c.status == AdminLoadStatus.loading) {
      return const AdminStatusState(
        icon: Icons.report_gmailerrorred_rounded,
        title: 'నివేదికలు లోడ్ అవుతున్నాయి',
        message: 'రిపోర్ట్ చేసిన యూజీసీ వివరాలు తెస్తున్నాం.',
        isLoading: true,
      );
    }
    if (c.status == AdminLoadStatus.error) {
      return AdminStatusState(
        icon: Icons.wifi_off_rounded,
        title: 'నివేదికలు రాలేదు',
        message: c.errorMessage ?? 'కనెక్షన్ చూసి మళ్లీ ప్రయత్నించండి.',
        actionLabel: 'మళ్లీ ప్రయత్నించండి',
        onAction: c.refresh,
      );
    }
    if (c.items.isEmpty) {
      return const AdminStatusState(
        icon: Icons.verified_user_outlined,
        title: 'నివేదికలు లేవు',
        message: 'ఈ ఫిల్టర్‌కు సరిపోయే రిపోర్టులు లేవు.',
      );
    }
    return RefreshIndicator(
      onRefresh: c.refresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: c.items.length + (c.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= c.items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final report = c.items[index];
          return AdminReportCard(
            report: report,
            onDismiss: () => c.dismissReport(report.id),
            onMarkReviewed: () => c.reviewReport(report.id),
          );
        },
      ),
    );
  }

  String _reportStatusLabel(String status) {
    switch (status) {
      case 'ALL':
        return 'అన్నీ';
      case 'PENDING':
        return 'పెండింగ్';
      case 'REVIEWED':
        return 'సమీక్షించాయి';
      case 'DISMISSED':
        return 'తొలగించాయి';
      default:
        return status;
    }
  }
}
