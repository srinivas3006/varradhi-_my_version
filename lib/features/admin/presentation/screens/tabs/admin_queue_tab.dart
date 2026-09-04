import 'package:flutter/material.dart';
import '../../../data/models/admin_ugc_status.dart';
import '../../controllers/admin_load_status.dart';
import '../../controllers/admin_ugc_queue_controller.dart';
import '../../theme/admin_colors.dart';
import '../../widgets/admin_filter_chip_row.dart';
import '../../widgets/admin_search_bar.dart';
import '../../widgets/admin_ugc_card.dart';
import '../../widgets/dialogs/admin_approval_dialog.dart';
import '../../widgets/dialogs/admin_reject_dialog.dart';
import '../../widgets/sheets/admin_reporter_detail_sheet.dart';
import '../admin_ugc_detail_screen.dart';

class AdminQueueTab extends StatefulWidget {
  final AdminUgcQueueController controller;
  final bool showSearch;

  const AdminQueueTab({super.key, required this.controller, required this.showSearch});

  @override
  State<AdminQueueTab> createState() => _AdminQueueTabState();
}

class _AdminQueueTabState extends State<AdminQueueTab> {
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

  Future<void> _approve(String id) async {
    final item = widget.controller.filteredItems.firstWhere((e) => e.id == id);
    await showAdminApprovalDialog(
      context,
      submission: item,
      onApprove: (notes, level, push) => widget.controller.approveItem(id, notes: notes, publicationLevel: level, push: push),
    );
  }

  Future<void> _reject(String id) async {
    await showAdminRejectDialog(context, onReject: (notes) => widget.controller.rejectItem(id, notes: notes));
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
            if (widget.showSearch) AdminSearchBar(hintText: 'Search title, district, mobile...', onChanged: c.setSearchQuery),
            const SizedBox(height: 4),
            AdminFilterChipRow<AdminUgcStatus?>(
              options: const [
                AdminFilterChipOption(null, 'ALL'),
                AdminFilterChipOption(AdminUgcStatus.pending, 'PENDING'),
                AdminFilterChipOption(AdminUgcStatus.flagged, 'FLAGGED'),
                AdminFilterChipOption(AdminUgcStatus.approved, 'APPROVED'),
                AdminFilterChipOption(AdminUgcStatus.rejected, 'REJECTED'),
              ],
              selected: c.statusFilter,
              onSelect: c.setStatusFilter,
            ),
            const SizedBox(height: 8),
            AdminFilterChipRow<AdminQueueRefinement>(
              options: const [
                AdminFilterChipOption(AdminQueueRefinement.all, 'ALL'),
                AdminFilterChipOption(AdminQueueRefinement.duplicatesOnly, 'Duplicates'),
                AdminFilterChipOption(AdminQueueRefinement.reported, 'Reported'),
              ],
              selected: c.refinementFilter,
              onSelect: c.setRefinement,
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildList(c, isDark)),
          ],
        );
      },
    );
  }

  Widget _buildList(AdminUgcQueueController c, bool isDark) {
    if (c.status == AdminLoadStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (c.status == AdminLoadStatus.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(c.errorMessage ?? 'Failed to load queue', style: TextStyle(color: AdminColors.textSecondaryColor(isDark))),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: c.refresh, child: const Text('Retry')),
          ],
        ),
      );
    }
    final items = c.filteredItems;
    if (items.isEmpty) {
      return Center(child: Text('No items in this view.', style: TextStyle(color: AdminColors.textSecondaryColor(isDark))));
    }
    return RefreshIndicator(
      onRefresh: c.refresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: items.length + (c.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator()));
          }
          final item = items[index];
          return AdminUgcCard(
            item: item,
            multiSelectMode: c.isMultiSelectMode,
            selected: c.selectedIds.contains(item.id),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminUgcDetailScreen(initial: item))),
            onToggleSelected: () {
              if (!c.isMultiSelectMode) c.toggleMultiSelect();
              c.toggleSelection(item.id);
            },
            onApprove: () => _approve(item.id),
            onReject: () => _reject(item.id),
            onFlag: () => c.flagItem(item.id),
            onViewProfile: () => showAdminReporterDetailSheet(context, userId: item.reporterUserId, fallbackFrom: item),
            onIncreaseTrust: () => c.increaseTrustFor(item.id),
            onDecreaseTrust: () => c.decreaseTrustFor(item.id),
            onToggleBlock: () => c.toggleBlockFor(item.id),
          );
        },
      ),
    );
  }
}
