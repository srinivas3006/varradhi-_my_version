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
  final Set<int> _activatedTabs = {0};

  bool _searchVisible = false;
  bool _bulkSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _queueController.dispose();
    _reportsController.dispose();
    _logsController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    final index = _tabController.index;
    _activatedTabs.add(index);
    if (mounted) {
      setState(() {});
    }
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('బల్క్ చర్య విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి.')));
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
              const Text('యూజీసీ అడ్మిన్ పర్యవేక్షణ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              Text(
                'క్యూలో ${_queueController.totalCount} అంశాలు ఉన్నాయి',
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
                tooltip: 'ఎంపిక చేసుకోండి',
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
            Tab(text: 'క్యూ'),
            Tab(text: 'ఫిర్యాదులు'),
            Tab(text: 'లాగ్‌లు'),
            Tab(text: 'ఓటీపీ లాగ్‌లు'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          AdminQueueTab(controller: _queueController, showSearch: _searchVisible),
          _lazyTab(1, AdminReportsTab(controller: _reportsController)),
          _lazyTab(2, AdminLogsTab(controller: _logsController, showSearch: _searchVisible)),
          _lazyTab(3, AdminOtpDeliveriesTab(controller: _otpController, showSearch: _searchVisible)),
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

  Widget _lazyTab(int index, Widget child) {
    if (_activatedTabs.contains(index)) return child;
    return const SizedBox.shrink();
  }
}
