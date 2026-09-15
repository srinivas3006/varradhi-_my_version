import 'package:flutter/material.dart';
import '../../data/models/admin_bulk_action_model.dart';
import '../controllers/admin_logs_controller.dart';
import '../controllers/admin_otp_deliveries_controller.dart';
import '../controllers/admin_reports_controller.dart';
import '../controllers/admin_ugc_queue_controller.dart';
import '../theme/admin_colors.dart';
import '../widgets/admin_access_guard.dart';
import '../widgets/admin_bulk_action_bar.dart';
import '../widgets/dialogs/admin_bulk_notes_dialog.dart';
import 'tabs/admin_logs_tab.dart';
import 'tabs/admin_otp_tab.dart';
import 'tabs/admin_queue_tab.dart';
import 'tabs/admin_reports_tab.dart';

/// Tabs of the moderation console, in the order they appear in the [TabBar].
/// Named so deep links can address one without hardcoding an index.
class AdminConsoleTab {
  AdminConsoleTab._();

  static const int queue = 0;
  static const int reports = 1;
  static const int logs = 2;
  static const int otp = 3;
  static const int count = 4;
}

class AdminUgcScreen extends StatefulWidget {
  /// Tab to open on, as an [AdminConsoleTab] constant.
  final int initialTab;

  const AdminUgcScreen({super.key, this.initialTab = AdminConsoleTab.queue});

  @override
  State<AdminUgcScreen> createState() => _AdminUgcScreenState();
}

class _AdminUgcScreenState extends State<AdminUgcScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _queueController = AdminUgcQueueController();
  final _reportsController = AdminReportsController();
  final _logsController = AdminLogsController();
  final _otpController = AdminOtpDeliveriesController();
  final Set<int> _activatedTabs = {};

  bool _searchVisible = false;
  bool _bulkSubmitting = false;

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.initialTab.clamp(0, AdminConsoleTab.count - 1);
    _activatedTabs.add(initialIndex);
    _tabController = TabController(
      length: AdminConsoleTab.count,
      vsync: this,
      initialIndex: initialIndex,
    );
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
      case AdminConsoleTab.queue:
        _queueController.refresh();
        break;
      case AdminConsoleTab.reports:
        _reportsController.refresh();
        break;
      case AdminConsoleTab.logs:
        _logsController.refresh();
        break;
      case AdminConsoleTab.otp:
        _otpController.refresh();
        break;
    }
  }

  Future<void> _runBulkAction(String action) async {
    final selectedCount = _queueController.selectedIds.length;
    if (selectedCount == 0) return;

    // Confirm and collect the moderation note before touching a whole
    // selection — the backend records it against every affected row.
    final notes = await showAdminBulkNotesDialog(context, action: action, count: selectedCount);
    if (notes == null || !mounted) return;

    setState(() => _bulkSubmitting = true);
    try {
      final result = await _queueController.applyBulkAction(action, notes: notes);
      if (mounted) _showBulkResult(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('బల్క్ చర్య విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి.')));
      }
    } finally {
      if (mounted) setState(() => _bulkSubmitting = false);
    }
  }

  /// A bulk call can partly succeed — the backend answers HTTP 207 with
  /// per-row errors. Reporting a flat "done" there would quietly leave rows
  /// unmoderated, so name the failures instead of claiming success.
  void _showBulkResult(AdminBulkActionResult result) {
    final messenger = ScaffoldMessenger.of(context)..removeCurrentSnackBar();

    if (result.failedCount == 0 && result.errors.isEmpty) {
      messenger.showSnackBar(SnackBar(
        content: Text('${result.successCount} అంశాలు నవీకరించబడ్డాయి'),
        backgroundColor: AdminColors.success,
      ));
      return;
    }

    final detail = result.errors.isEmpty ? '' : ': ${result.errors.first}';
    messenger.showSnackBar(SnackBar(
      content: Text('${result.successCount} నవీకరించబడ్డాయి, ${result.failedCount} విఫలమయ్యాయి$detail'),
      backgroundColor: AdminColors.error,
      duration: const Duration(seconds: 5),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isQueueTab = _tabController.index == AdminConsoleTab.queue;

    return AdminAccessGuard(
      child: Scaffold(
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
            _lazyTab(AdminConsoleTab.queue, AdminQueueTab(controller: _queueController, showSearch: _searchVisible)),
            _lazyTab(AdminConsoleTab.reports, AdminReportsTab(controller: _reportsController)),
            _lazyTab(AdminConsoleTab.logs, AdminLogsTab(controller: _logsController, showSearch: _searchVisible)),
            _lazyTab(AdminConsoleTab.otp, AdminOtpDeliveriesTab(controller: _otpController, showSearch: _searchVisible)),
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
      ),
    );
  }

  Widget _lazyTab(int index, Widget child) {
    if (_activatedTabs.contains(index)) return child;
    return const SizedBox.shrink();
  }
}
