import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

import '../core/widgets/section_header.dart';
import '../core/widgets/state_views.dart';
import '../models/location_model.dart';
import '../core/utils/location_detector.dart';
import '../providers/location_provider.dart';
import '../repositories/location_repository.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class LocationSelectionScreen extends StatelessWidget {
  final LocationRepository? repository;
  const LocationSelectionScreen({super.key, this.repository});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          LocationProvider(repository: repository ?? LocationRepository()),
      child: const _LocationSelectionScreen(),
    );
  }
}

class _LocationSelectionScreen extends StatefulWidget {
  const _LocationSelectionScreen();

  @override
  State<_LocationSelectionScreen> createState() =>
      _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<_LocationSelectionScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocationProvider>().load();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _apply(Future<bool> Function() action) async {
    final ok = await action();
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ప్రాంతం విజయవంతంగా నవీకరించబడింది',
            style: GoogleFonts.notoSansTelugu(),
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      } else {
        Navigator.pushReplacementNamed(context, '/main');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ప్రాంతం నవీకరించడం విఫలమైంది. దయచేసి మళ్ళీ ప్రయత్నించండి.',
            style: GoogleFonts.notoSansTelugu(),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _detect(LocationProvider provider) async {
    await provider.detectLocation();
    if (!mounted) return;

    if (provider.detectFailure != null) {
      _showDetectFailure(provider.detectFailure!);
      return;
    }
    final place = provider.detectedPlace;
    if (place == null || provider.detectMatches.isEmpty) return;

    final chosen = await showModalBottomSheet<LocationSearchResult>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ConfirmDetected(
        place: place,
        matches: provider.detectMatches,
      ),
    );
    if (!mounted || chosen == null) return;
    await _apply(() => provider.apply(chosen));
  }

  void _showDetectFailure(LocationDetectFailure failure) {
    String message = 'లొకేషన్ గుర్తించలేకపోయాము. దయచేసి దిగువన ఎంచుకోండి.';
    String? actionLabel;

    switch (failure) {
      case LocationDetectFailure.serviceDisabled:
        message = 'లొకేషన్ సేవలు నిలిపివేయబడ్డాయి. దయచేసి ఆన్ చేయండి.';
        break;
      case LocationDetectFailure.permissionDeniedForever:
        message = 'లొకేషన్ అనుమతి నిరాకరించబడింది. సెట్టింగ్స్‌లో అనుమతించండి.';
        actionLabel = 'సెట్టింగ్స్ తెరవండి';
        break;
      case LocationDetectFailure.permissionDenied:
      case LocationDetectFailure.noPlaceFound:
      case LocationDetectFailure.timeout:
      case LocationDetectFailure.unknown:
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.notoSansTelugu()),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: actionLabel == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: Geolocator.openAppSettings,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocationProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? AppColors.textLight : AppColors.readingTitleLight,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'జిల్లాను ఎంచుకోండి',
              style: GoogleFonts.notoSansTelugu(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.readingTitleDark
                    : AppColors.readingTitleLight,
              ),
            ),
            Text(
              'మీ ప్రాంత వార్తల కోసం ఎంచుకోండి',
              style: GoogleFonts.notoSansTelugu(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: isDark
                    ? AppColors.readingMetaDark
                    : AppColors.readingMetaLight,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // GPS Location Action Button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed:
                      provider.isDetecting ? null : () => _detect(provider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.6),
                    disabledForegroundColor: Colors.white70,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: provider.isDetecting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.my_location_rounded,
                          size: 20, color: Colors.white),
                  label: Text(
                    provider.isDetecting
                        ? 'లొకేషన్ గుర్తిస్తోంది...'
                        : 'నా ప్రస్తుత ప్రాంతాన్ని ఉపయోగించండి',
                    style: GoogleFonts.notoSansTelugu(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: TextField(
                controller: _controller,
                onChanged: provider.onQueryChanged,
                style: GoogleFonts.notoSansTelugu(
                  fontSize: 14.5,
                  color:
                      isDark ? AppColors.textLight : AppColors.readingTitleLight,
                ),
                decoration: InputDecoration(
                  hintText: 'గ్రామం లేదా మండలం పేరుతో వెతకండి...',
                  hintStyle: GoogleFonts.notoSansTelugu(
                    fontSize: 14,
                    color: isDark
                        ? AppColors.readingMetaDark
                        : const Color(0xFF9CA3AF),
                  ),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 20, color: AppColors.primary),
                  suffixIcon: provider.isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : (_controller.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _controller.clear();
                                provider.onQueryChanged('');
                              },
                              icon: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: isDark
                                    ? AppColors.readingMetaDark
                                    : const Color(0xFF9CA3AF),
                              ),
                            )),
                  filled: true,
                  fillColor: isDark
                      ? AppColors.surfaceElevatedDark
                      : const Color(0xFFF3F4F6),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark
                          ? AppColors.borderDark
                          : const Color(0xFFE5E7EB),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark
                          ? AppColors.borderDark
                          : const Color(0xFFE5E7EB),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),

            // Results or Drilldown Hierarchy
            Expanded(
              child: provider.isSearchMode
                  ? _SearchResults(
                      provider: provider,
                      onSelect: (result) =>
                          _apply(() => provider.apply(result)),
                    )
                  : _Drilldown(
                      provider: provider,
                      onApplyNode: (node, level) =>
                          _apply(() => provider.applyNode(node, level)),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.provider, required this.onSelect});

  final LocationProvider provider;
  final ValueChanged<LocationSearchResult> onSelect;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (provider.results.isEmpty && !provider.isSearching) {
      return EmptyStateView(
        icon: Icons.travel_explore_outlined,
        title: 'ఫలితాలు లేవు',
        message: 'దయచేసి సరైన పేరుతో వెతకండి',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: provider.results.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        thickness: 0.6,
        color: isDark ? AppColors.borderDark : const Color(0xFFF1F5F9),
      ),
      itemBuilder: (context, index) {
        final result = provider.results[index];
        final teluguName = result.nameTe.trim();
        final englishName = result.nameEn.trim();
        final primaryName = teluguName.isNotEmpty ? teluguName : englishName;
        final secondaryName =
            teluguName.isNotEmpty && englishName.isNotEmpty ? englishName : '';

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _iconFor(result.type),
              size: 20,
              color: AppColors.primary,
            ),
          ),
          title: Text(
            primaryName,
            style: GoogleFonts.notoSansTelugu(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.readingTitleDark
                  : AppColors.readingTitleLight,
            ),
          ),
          subtitle: Text(
            [
              _levelLabelTe(result.type),
              if (secondaryName.isNotEmpty) secondaryName,
              if (result.breadcrumb.isNotEmpty) result.breadcrumb,
            ].where((value) => value.isNotEmpty).join(' • '),
            style: TextStyle(
              fontSize: 12.5,
              color: isDark
                  ? AppColors.readingMetaDark
                  : const Color(0xFF6B7280),
            ),
          ),
          trailing: const Icon(Icons.chevron_right_rounded,
              size: 20, color: AppColors.primary),
          onTap: () => onSelect(result),
        );
      },
    );
  }

  String _levelLabelTe(LocationLevel level) {
    switch (level) {
      case LocationLevel.state:
        return 'రాష్ట్రం';
      case LocationLevel.district:
        return 'జిల్లా';
      case LocationLevel.subdistrict:
        return 'మండలం';
      case LocationLevel.village:
        return 'గ్రామం';
      case LocationLevel.unknown:
        return 'ప్రాంతం';
    }
  }

  IconData _iconFor(LocationLevel level) {
    switch (level) {
      case LocationLevel.state:
        return Icons.map_outlined;
      case LocationLevel.district:
        return Icons.location_city_outlined;
      case LocationLevel.subdistrict:
        return Icons.hub_outlined;
      case LocationLevel.village:
        return Icons.holiday_village_outlined;
      case LocationLevel.unknown:
        return Icons.place_outlined;
    }
  }
}

class _Drilldown extends StatelessWidget {
  const _Drilldown({required this.provider, required this.onApplyNode});

  final LocationProvider provider;
  final void Function(LocationNode node, LocationLevel level) onApplyNode;

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (provider.hasError && provider.states.isEmpty) {
      return ErrorStateView(
        error: provider.error ?? 'Error',
        onRetry: provider.load,
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        if (provider.selectedState != null) _Breadcrumbs(provider: provider),
        if (provider.selectedState == null) ...[
          const SectionHeader(title: 'రాష్ట్రాన్ని ఎంచుకోండి'),
          const SizedBox(height: 8),
          _NodeGrid(
            nodes: provider.states,
            onTap: provider.selectState,
          ),
        ] else if (provider.selectedDistrict == null) ...[
          const SizedBox(height: 12),
          SectionHeader(
            title:
                '${provider.selectedState!.nameTe.isNotEmpty ? provider.selectedState!.nameTe : provider.selectedState!.nameEn} లోని జిల్లాలు',
            trailingText: 'ఈ రాష్ట్రం ఎంచుకోండి',
            onTrailingTap: () =>
                onApplyNode(provider.selectedState!, LocationLevel.state),
          ),
          const SizedBox(height: 8),
          _NodeList(
            nodes: provider.districts,
            onTap: provider.selectDistrict,
            onUse: (node) => onApplyNode(node, LocationLevel.district),
          ),
        ] else if (provider.selectedSubdistrict == null) ...[
          const SizedBox(height: 12),
          SectionHeader(
            title:
                '${provider.selectedDistrict!.nameTe.isNotEmpty ? provider.selectedDistrict!.nameTe : provider.selectedDistrict!.nameEn} లోని మండలాలు',
            trailingText: 'ఈ జిల్లా ఎంచుకోండి',
            onTrailingTap: () =>
                onApplyNode(provider.selectedDistrict!, LocationLevel.district),
          ),
          const SizedBox(height: 8),
          _NodeList(
            nodes: provider.subdistricts,
            onTap: provider.selectSubdistrict,
            onUse: (node) => onApplyNode(node, LocationLevel.subdistrict),
          ),
        ] else ...[
          const SizedBox(height: 12),
          SectionHeader(
            title:
                '${provider.selectedSubdistrict!.nameTe.isNotEmpty ? provider.selectedSubdistrict!.nameTe : provider.selectedSubdistrict!.nameEn} లోని గ్రామాలు',
            trailingText: 'ఈ మండలం ఎంచుకోండి',
            onTrailingTap: () => onApplyNode(
                provider.selectedSubdistrict!, LocationLevel.subdistrict),
          ),
          const SizedBox(height: 8),
          _NodeList(
            nodes: provider.villages,
            onTap: (node) => onApplyNode(node, LocationLevel.village),
            onUse: (node) => onApplyNode(node, LocationLevel.village),
          ),
        ],
      ],
    );
  }
}

class _Breadcrumbs extends StatelessWidget {
  const _Breadcrumbs({required this.provider});

  final LocationProvider provider;

  @override
  Widget build(BuildContext context) {
    final crumbs = <String>[
      if (provider.selectedState != null)
        (provider.selectedState!.nameTe.isNotEmpty
            ? provider.selectedState!.nameTe
            : provider.selectedState!.nameEn),
      if (provider.selectedDistrict != null)
        (provider.selectedDistrict!.nameTe.isNotEmpty
            ? provider.selectedDistrict!.nameTe
            : provider.selectedDistrict!.nameEn),
      if (provider.selectedSubdistrict != null)
        (provider.selectedSubdistrict!.nameTe.isNotEmpty
            ? provider.selectedSubdistrict!.nameTe
            : provider.selectedSubdistrict!.nameEn),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: provider.clearDrilldown,
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon:
                const Icon(Icons.restart_alt_rounded, color: AppColors.primary),
            tooltip: 'మొదటి నుండి ప్రారంభించండి',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              crumbs.join('  ›  '),
              style: GoogleFonts.notoSansTelugu(
                fontSize: 14.5,
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeGrid extends StatelessWidget {
  const _NodeGrid({required this.nodes, required this.onTap});

  final List<LocationNode> nodes;
  final ValueChanged<LocationNode> onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final node in nodes)
          Material(
            color: isDark
                ? AppColors.surfaceElevatedDark
                : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: () => onTap(node),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color:
                        isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
                    width: 1,
                  ),
                ),
                child: Text(
                  node.nameTe.isNotEmpty ? node.nameTe : node.nameEn,
                  style: GoogleFonts.notoSansTelugu(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textLight
                        : AppColors.readingTitleLight,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NodeList extends StatelessWidget {
  const _NodeList({
    required this.nodes,
    required this.onTap,
    required this.onUse,
  });

  final List<LocationNode> nodes;
  final ValueChanged<LocationNode> onTap;
  final ValueChanged<LocationNode> onUse;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (nodes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'ఏమీ కనుగొనబడలేదు',
            style: GoogleFonts.notoSansTelugu(
              fontSize: 14,
              color:
                  isDark ? AppColors.readingMetaDark : const Color(0xFF9CA3AF),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < nodes.length; i++) ...[
          _buildItem(context, nodes[i], isDark),
          if (i < nodes.length - 1)
            Divider(
              height: 1,
              thickness: 0.6,
              color: isDark ? AppColors.borderDark : const Color(0xFFF1F5F9),
            ),
        ],
      ],
    );
  }

  Widget _buildItem(BuildContext context, LocationNode node, bool isDark) {
    final teluguName = node.nameTe.trim();
    final englishName = node.nameEn.trim();
    final primaryName = teluguName.isNotEmpty ? teluguName : englishName;
    final secondaryName =
        teluguName.isNotEmpty && englishName.isNotEmpty ? englishName : '';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      title: Text(
        primaryName,
        style: GoogleFonts.notoSansTelugu(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color:
              isDark ? AppColors.readingTitleDark : AppColors.readingTitleLight,
        ),
      ),
      subtitle: secondaryName.isNotEmpty
          ? Text(
              secondaryName,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.readingMetaDark
                    : const Color(0xFF6B7280),
                fontWeight: FontWeight.w400,
              ),
            )
          : null,
      trailing: InkWell(
        onTap: () => onUse(node),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.28),
              width: 1,
            ),
          ),
          child: Text(
            'ఎంచుకోండి',
            style: GoogleFonts.notoSansTelugu(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
      onTap: () => onTap(node),
    );
  }
}

class _ConfirmDetected extends StatelessWidget {
  const _ConfirmDetected({required this.place, required this.matches});

  final DetectedPlace place;
  final List<LocationSearchResult> matches;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDarkNavy : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.my_location_rounded,
                    size: 22, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ఇదే మీ ప్రాంతమా?',
                    style: GoogleFonts.notoSansTelugu(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.readingTitleDark
                          : AppColors.readingTitleLight,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              place.fullTrail.isEmpty ? 'లొకేషన్' : place.fullTrail,
              style: TextStyle(
                fontSize: 14.5,
                color: isDark
                    ? AppColors.readingMetaDark
                    : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              matches.length == 1
                  ? 'దిగువ మీ ప్రాంతాన్ని నిర్ధారించండి.'
                  : 'సరిపోయే ప్రాంతాన్ని ఎంచుకోండి.',
              style: GoogleFonts.notoSansTelugu(
                fontSize: 13.5,
                color: isDark
                    ? AppColors.readingMetaDark
                    : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 12),
            for (final match in matches) ...[
              Material(
                color: isDark
                    ? AppColors.surfaceElevatedDark
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  onTap: () => Navigator.of(context).pop(match),
                  leading: const Icon(Icons.place_rounded,
                      size: 22, color: AppColors.primary),
                  title: Text(
                    match.nameTe.isNotEmpty ? match.nameTe : match.nameEn,
                    style: GoogleFonts.notoSansTelugu(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.readingTitleDark
                          : AppColors.readingTitleLight,
                    ),
                  ),
                  subtitle: Text(
                    [match.subdistrict, match.district, match.state]
                        .where((v) => v.isNotEmpty)
                        .join(', '),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark
                          ? AppColors.readingMetaDark
                          : const Color(0xFF6B7280),
                    ),
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _levelLabelTe(match.type),
                      style: GoogleFonts.notoSansTelugu(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: isDark
                    ? AppColors.readingMetaDark
                    : const Color(0xFF6B7280),
              ),
              child: Text(
                'స్వయంగా ఎంచుకుంటాను',
                style: GoogleFonts.notoSansTelugu(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _levelLabelTe(LocationLevel level) {
    switch (level) {
      case LocationLevel.state:
        return 'రాష్ట్రం';
      case LocationLevel.district:
        return 'జిల్లా';
      case LocationLevel.subdistrict:
        return 'మండలం';
      case LocationLevel.village:
        return 'గ్రామం';
      case LocationLevel.unknown:
        return 'ప్రాంతం';
    }
  }
}
