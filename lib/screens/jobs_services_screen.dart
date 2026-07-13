import 'package:flutter/material.dart';
import '../data/mock_jobs.dart';
import '../theme/app_theme.dart';
import '../widgets/ads/banner_ad_slot.dart';
import '../widgets/ads/native_ad_card.dart';

class JobsServicesScreen extends StatefulWidget {
  const JobsServicesScreen({super.key});

  @override
  State<JobsServicesScreen> createState() => _JobsServicesScreenState();
}

class _JobsServicesScreenState extends State<JobsServicesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Local Jobs & Services'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          tabs: const [Tab(text: 'Jobs'), Tab(text: 'Services')],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildJobsList(), _buildServicesList()],
            ),
          ),
          const BannerAdSlot(),
        ],
      ),
    );
  }

  Widget _buildJobsList() {
    // Interleave a native ad card every 4 job listings.
    final items = <Widget>[];
    for (var i = 0; i < mockJobs.length; i++) {
      final job = mockJobs[i];
      items.add(Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(job.type,
                      style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
                ),
                const Spacer(),
                Text('Vacancies: ${job.vacancies}',
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textMuted)),
              ],
            ),
            const SizedBox(height: 8),
            Text(job.title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14.5)),
            const SizedBox(height: 4),
            Text(job.organization,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.textMuted)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on,
                    size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(job.location,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textMuted)),
                const Spacer(),
                Text('Last date: ${job.lastDate}',
                    style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFFE8412B),
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ));
      if ((i + 1) % 4 == 0) {
        items.add(const NativeAdCard());
      }
    }
    return ListView(padding: const EdgeInsets.all(16), children: items);
  }

  Widget _buildServicesList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: mockLocalServices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final service = mockLocalServices[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.chipBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.handyman_outlined,
                    color: AppColors.textMuted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service['name']!,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 3),
                    Text('${service['category']} · ${service['area']}',
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.star_rounded,
                      color: Color(0xFFE8A312), size: 18),
                  const SizedBox(width: 2),
                  Text(service['rating']!,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
