import 'package:flutter/material.dart';
import '../../../data/models/admin_ugc_options.dart';
import '../../controllers/admin_load_status.dart';
import '../../controllers/admin_reports_controller.dart';
import '../../theme/admin_colors.dart';
import '../../widgets/admin_filter_chip_row.dart';
import '../../widgets/admin_report_card.dart';

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
    if (_scrollController.position.maxScrollExtent - _scrollController.position.pixels < 250) {
      widget.controller.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        return Column(
          children: [
            const SizedBox(height: 8),
            AdminFilterChipRow<String>(
              options: AdminUgcOptions.reportStatuses.map((s) => AdminFilterChipOption(s, s)).toList(),
              selected: c.statusFilter,
              onSelect: c.setStatusFilter,
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildList(c, isDark)),
          ],
        );
      },
    );
  }

  Widget _buildList(AdminReportsController c, bool isDark) {
    if (c.status == AdminLoadStatus.loading) return const Center(child: CircularProgressIndicator());
    if (c.status == AdminLoadStatus.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(c.errorMessage ?? 'Failed to load reports', style: TextStyle(color: AdminColors.textSecondaryColor(isDark))),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: c.refresh, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (c.items.isEmpty) {
      return Center(child: Text('No reports.', style: TextStyle(color: AdminColors.textSecondaryColor(isDark))));
    }
    return RefreshIndicator(
      onRefresh: c.refresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: c.items.length + (c.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= c.items.length) {
            return const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator()));
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
}
