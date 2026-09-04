import 'package:flutter/material.dart';
import '../controllers/admin_logs_controller.dart';
import '../controllers/admin_otp_deliveries_controller.dart';
import '../controllers/admin_reports_controller.dart';
import '../controllers/admin_ugc_queue_controller.dart';
import '../theme/admin_colors.dart';
import '../widgets/admin_bulk_action_bar.dart';
import 'tabs/admin_logs_tab.dart';
import 'tabs/admin_otp_tab.dart';
import 'tabs/admin_queue_tab.dart';
import 'tabs/admin_reports_tab.dart';

class AdminUgcScreen extends StatefulWidget {
  const AdminUgcScreen({super.key});

  @override
  State<AdminUgcScreen> createState() => _AdminUgcScreenState();
}

class _AdminUgcScreenState extends State<AdminUgcScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _queueController = AdminUgcQueueController();
  final _reportsController = AdminReportsController();
  final _logsController = AdminLogsController();
  final _otpController = AdminOtpDeliveriesController();

  bool _searchVisible = false;
  bool _bulkSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _queueController.dispose();
    _reportsController.dispose();
    _logsController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _refreshActiveTab() {
    switch (_tabController.index) {
      case 0:
        _queueController.refresh();
        break;
      case 1:
        _reportsController.refresh();
        break;
      case 2:
        _logsController.refresh();
        break;
      case 3:
        _otpController.refresh();
        break;
    }
  }

  Future<void> _runBulkAction(String action) async {
    setState(() => _bulkSubmitting = true);
    try {
      await _queueController.applyBulkAction(action);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bulk action failed. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _bulkSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isQueueTab = _tabController.index == 0;

    return Scaffold(
      backgroundColor: AdminColors.scaffold(isDark),
      appBar: AppBar(
        backgroundColor: AdminColors.scaffold(isDark),
        foregroundColor: AdminColors.textPrimary(isDark),
        elevation: 0,
        title: AnimatedBuilder(
          animation: _queueController,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('UGC Admin Moderation', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              Text(
                '${_queueController.totalCount} items in queue',
                style: TextStyle(fontSize: 11.5, color: AdminColors.textSecondaryColor(isDark), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        actions: [
          if (isQueueTab)
            AnimatedBuilder(
              animation: _queueController,
              builder: (context, _) => IconButton(
                icon: Icon(_queueController.isMultiSelectMode ? Icons.checklist_rtl : Icons.checklist_outlined),
                tooltip: 'Multi-select',
                onPressed: _queueController.toggleMultiSelect,
              ),
            ),
          IconButton(
            icon: Icon(_searchVisible ? Icons.search_off : Icons.search),
            onPressed: () => setState(() => _searchVisible = !_searchVisible),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshActiveTab),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AdminColors.primary,
          unselectedLabelColor: AdminColors.textSecondaryColor(isDark),
          indicatorColor: AdminColors.primary,
          tabs: const [
            Tab(text: 'Queue'),
            Tab(text: 'Reports'),
            Tab(text: 'Logs'),
            Tab(text: 'OTP Logs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          AdminQueueTab(controller: _queueController, showSearch: _searchVisible),
          AdminReportsTab(controller: _reportsController),
          AdminLogsTab(controller: _logsController, showSearch: _searchVisible),
          AdminOtpDeliveriesTab(controller: _otpController, showSearch: _searchVisible),
        ],
      ),
      bottomNavigationBar: isQueueTab
          ? AnimatedBuilder(
              animation: _queueController,
              builder: (context, _) {
                if (!_queueController.isMultiSelectMode) return const SizedBox.shrink();
                return AdminBulkActionBar(
                  selectedCount: _queueController.selectedIds.length,
                  totalCount: _queueController.filteredItems.length,
                  isSubmitting: _bulkSubmitting,
                  onSelectAll: _queueController.selectAll,
                  onDeselectAll: _queueController.deselectAll,
                  onAction: _runBulkAction,
                );
              },
            )
          : null,
    );
  }
}
