import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/ads/banner_ad_slot.dart';

class JobListingItem {
  final String title;
  final String organization;
  final String location;
  final String type;
  final int vacancies;
  final String lastDate;

  JobListingItem({
    required this.title,
    required this.organization,
    required this.location,
    required this.type,
    required this.vacancies,
    required this.lastDate,
  });
}

class JobsServicesScreen extends StatefulWidget {
  const JobsServicesScreen({super.key});

  @override
  State<JobsServicesScreen> createState() => _JobsServicesScreenState();
}

class _JobsServicesScreenState extends State<JobsServicesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final List<JobListingItem> _jobs = [];
  final List<Map<String, String>> _services = [];
  final bool _isLoading = false;

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
        title: const Text('స్థానిక ఉద్యోగాలు & సేవలు'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          tabs: const [Tab(text: 'ఉద్యోగాలు'), Tab(text: 'సేవలు')],
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_jobs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.work_outline_rounded, size: 48, color: AppColors.textMuted),
              SizedBox(height: 12),
              Text(
                'ప్రస్తుతానికి ఉద్యోగ ప్రకటనలు లేవు',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 6),
              Text(
                'మీ జిల్లాలోని తాజా స్థానిక అవకాశాల కోసం కాసేపటి తర్వాత మళ్లీ చూడండి.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _jobs.length,
      itemBuilder: (context, index) {
        final job = _jobs[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      job.type,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'ఖాళీలు: ${job.vacancies}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(job.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
              const SizedBox(height: 4),
              Text(job.organization, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(job.location, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                  const Spacer(),
                  Text(
                    'చివరి తేదీ: ${job.lastDate}',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFFE8412B), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildServicesList() {
    if (_services.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.handyman_outlined, size: 48, color: AppColors.textMuted),
              SizedBox(height: 12),
              Text(
                'ప్రస్తుతానికి సేవల జాబితా అందుబాటులో లేదు',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 6),
              Text(
                'స్థానిక సేవా ప్రదాతల వివరాలు త్వరలోనే నవీకరించబడతాయి.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _services.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final service = _services[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
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
                child: const Icon(Icons.handyman_outlined, color: AppColors.textMuted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service['name']!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 3),
                    Text('${service['category']} · ${service['area']}', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Color(0xFFE8A312), size: 18),
                  const SizedBox(width: 2),
                  Text(service['rating']!, style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
