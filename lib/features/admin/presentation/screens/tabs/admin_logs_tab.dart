import 'package:flutter/material.dart';
import '../../../data/models/admin_ugc_options.dart';
import '../../controllers/admin_load_status.dart';
import '../../controllers/admin_logs_controller.dart';
import '../../theme/admin_colors.dart';
import '../../widgets/admin_filter_chip_row.dart';
import '../../widgets/admin_log_card.dart';
import '../../widgets/admin_search_bar.dart';

class AdminLogsTab extends StatefulWidget {
  final AdminLogsController controller;
  final bool showSearch;
  const AdminLogsTab({super.key, required this.controller, required this.showSearch});

  @override
  State<AdminLogsTab> createState() => _AdminLogsTabState();
}

class _AdminLogsTabState extends State<AdminLogsTab> {
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
            if (widget.showSearch) AdminSearchBar(hintText: 'Search title or admin email...', onChanged: c.setSearchQuery),
            const SizedBox(height: 4),
            AdminFilterChipRow<String>(
              options: AdminUgcOptions.logActionTypes.map((a) => AdminFilterChipOption(a, a)).toList(),
              selected: c.actionFilter,
              onSelect: c.setActionFilter,
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildList(c, isDark)),
          ],
        );
      },
    );
  }

  Widget _buildList(AdminLogsController c, bool isDark) {
    if (c.status == AdminLoadStatus.loading) return const Center(child: CircularProgressIndicator());
    if (c.status == AdminLoadStatus.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(c.errorMessage ?? 'Failed to load logs', style: TextStyle(color: AdminColors.textSecondaryColor(isDark))),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: c.refresh, child: const Text('Retry')),
          ],
        ),
      );
    }
    final items = c.items;
    if (items.isEmpty) {
      return Center(child: Text('No moderation logs.', style: TextStyle(color: AdminColors.textSecondaryColor(isDark))));
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
          return AdminLogCard(log: items[index]);
        },
      ),
    );
  }
}
