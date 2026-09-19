import 'package:flutter/material.dart';

import '../../../data/models/admin_ugc_options.dart';
import '../../controllers/admin_load_status.dart';
import '../../controllers/admin_otp_deliveries_controller.dart';
import '../../widgets/admin_filter_chip_row.dart';
import '../../widgets/admin_otp_delivery_row.dart';
import '../../widgets/admin_search_bar.dart';
import '../../widgets/admin_status_state.dart';

class AdminOtpDeliveriesTab extends StatefulWidget {
  final AdminOtpDeliveriesController controller;
  final bool showSearch;
  const AdminOtpDeliveriesTab({super.key, required this.controller, required this.showSearch});

  @override
  State<AdminOtpDeliveriesTab> createState() => _AdminOtpDeliveriesTabState();
}

class _AdminOtpDeliveriesTabState extends State<AdminOtpDeliveriesTab> {
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
            if (widget.showSearch) AdminSearchBar(hintText: 'మొబైల్ నంబర్ వెతకండి...', onChanged: c.setMobileQuery),
            const SizedBox(height: 4),
            AdminFilterChipRow<String>(
              options: AdminUgcOptions.otpStatuses.map((s) => AdminFilterChipOption(s, _otpStatusLabel(s))).toList(),
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

  Widget _buildList(AdminOtpDeliveriesController c) {
    if (c.status == AdminLoadStatus.loading) {
      return const AdminStatusState(
        icon: Icons.sms_outlined,
        title: 'OTP లాగ్‌లు లోడ్ అవుతున్నాయి',
        message: 'డెలివరీ స్థితి వివరాలు తెస్తున్నాం.',
        isLoading: true,
      );
    }
    // Only take over the screen when there is nothing loaded. A failure
    // while paginating must not discard the rows already on screen.
    if (c.status == AdminLoadStatus.error && c.items.isEmpty) {
      return AdminStatusState(
        icon: Icons.wifi_off_rounded,
        title: 'OTP లాగ్‌లు రాలేదు',
        message: c.errorMessage ?? 'కనెక్షన్ చూసి మళ్లీ ప్రయత్నించండి.',
        actionLabel: 'మళ్లీ ప్రయత్నించండి',
        onAction: c.refresh,
      );
    }
    final items = c.items;
    if (items.isEmpty) {
      return const AdminStatusState(
        icon: Icons.mark_email_read_outlined,
        title: 'OTP డెలివరీలు లేవు',
        message: 'ఈ ఫిల్టర్‌కు సరిపోయే OTP రికార్డులు లేవు.',
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
          return AdminOtpDeliveryRow(delivery: items[index]);
        },
      ),
    );
  }

  String _otpStatusLabel(String status) {
    switch (status) {
      case 'ALL':
        return 'అన్నీ';
      case 'SENT':
        return 'పంపినవి';
      case 'DELIVERED':
        return 'చేరినవి';
      case 'FAILED':
        return 'విఫలమైనవి';
      case 'EXPIRED':
        return 'గడువు ముగిసినవి';
      case 'PENDING':
        return 'పెండింగ్';
      default:
        return status;
    }
  }
}
