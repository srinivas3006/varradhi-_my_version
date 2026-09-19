import 'package:flutter/material.dart';

import '../../../data/models/admin_ugc_options.dart';
import '../../controllers/admin_load_status.dart';
import '../../controllers/admin_logs_controller.dart';
import '../../widgets/admin_filter_chip_row.dart';
import '../../widgets/admin_log_card.dart';
import '../../widgets/admin_search_bar.dart';
import '../../widgets/admin_status_state.dart';

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
            if (widget.showSearch) AdminSearchBar(hintText: 'శీర్షిక లేదా అడ్మిన్ ఇమెయిల్ వెతకండి...', onChanged: c.setSearchQuery),
            const SizedBox(height: 4),
            AdminFilterChipRow<String>(
              options: AdminUgcOptions.logActionTypes.map((a) => AdminFilterChipOption(a, _logActionLabel(a))).toList(),
              selected: c.actionFilter,
              onSelect: c.setActionFilter,
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildList(c)),
          ],
        );
      },
    );
  }

  Widget _buildList(AdminLogsController c) {
    if (c.status == AdminLoadStatus.loading) {
      return const AdminStatusState(
        icon: Icons.history_rounded,
        title: 'లాగ్‌లు లోడ్ అవుతున్నాయి',
        message: 'మోడరేషన్ చర్యల వివరాలు తెస్తున్నాం.',
        isLoading: true,
      );
    }
    // Only take over the screen when there is nothing loaded. A failure
    // while paginating must not discard the rows already on screen.
    if (c.status == AdminLoadStatus.error && c.items.isEmpty) {
      return AdminStatusState(
        icon: Icons.wifi_off_rounded,
        title: 'లాగ్‌లు రాలేదు',
        message: c.errorMessage ?? 'కనెక్షన్ చూసి మళ్లీ ప్రయత్నించండి.',
        actionLabel: 'మళ్లీ ప్రయత్నించండి',
        onAction: c.refresh,
      );
    }
    final items = c.items;
    if (items.isEmpty) {
      return const AdminStatusState(
        icon: Icons.rule_folder_outlined,
        title: 'మోడరేషన్ లాగ్‌లు లేవు',
        message: 'ఈ ఫిల్టర్‌కు సరిపోయే చర్యలు లేవు.',
      );
    }
    return RefreshIndicator(
      onRefresh: c.refresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: items.length + (c.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            if (c.status == AdminLoadStatus.error) {
              // Auto-retry is off after a failure, so this is the moderator's
              // way to ask for the next page again.
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'మరిన్ని లోడ్ చేయడం విఫలమైంది',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: c.retryLoadMore,
                        child: const Text('మళ్లీ ప్రయత్నించండి'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return AdminLogCard(log: items[index]);
        },
      ),
    );
  }

  String _logActionLabel(String action) {
    switch (action) {
      case 'ALL':
        return 'అన్నీ';
      case 'APPROVE':
        return 'అంగీకారం';
      case 'REJECT':
        return 'తిరస్కారం';
      case 'FLAG':
        return 'ఫ్లాగ్';
      default:
        return action;
    }
  }
}
