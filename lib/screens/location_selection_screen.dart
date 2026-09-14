import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

import '../core/widgets/section_header.dart';
import '../core/widgets/state_views.dart';
import '../models/location_model.dart';
import '../core/utils/location_detector.dart';
import '../providers/location_provider.dart';
import '../repositories/location_repository.dart';
import '../state/app_state.dart';

class LocationSelectionScreen extends StatelessWidget {
  const LocationSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LocationProvider(repository: LocationRepository()),
      child: const _LocationSelectionScreen(),
    );
  }
}

class _LocationSelectionScreen extends StatefulWidget {
  const _LocationSelectionScreen({super.key});

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
        const SnackBar(content: Text('ప్రాంతం నవీకరించబడింది (Location updated)')),
      );
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacementNamed(context, '/main');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ప్రాంతం నవీకరించబడలేదు (Update failed)')),
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
        message = 'లొకేషన్ సేవలు నిలిపివేయబడ్డాయి (Location disabled). దయచేసి ఆన్ చేయండి.';
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
        content: Text(message),
        duration: const Duration(seconds: 5),
        action: actionLabel == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                onPressed: Geolocator.openAppSettings,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocationProvider>();
    final currentLoc = AppState.instance.district.isNotEmpty
        ? AppState.instance.district
        : 'Unknown';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('జిల్లాను ఎంచుకోండి', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Choose District', style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton.icon(
                  onPressed: provider.isDetecting ? null : () => _detect(provider),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  icon: provider.isDetecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.my_location_rounded, size: 18),
                  label: Text(
                    provider.isDetecting
                        ? 'లొకేషన్ వెతుకుతోంది...'
                        : 'నా ప్రస్తుత ప్రాంతాన్ని ఉపయోగించండి',
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: TextField(
                controller: _controller,
                onChanged: provider.onQueryChanged,
                decoration: InputDecoration(
                  hintText: 'గ్రామం లేదా మండలం పేరుతో వెతకండి...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: provider.isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : (_controller.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _controller.clear();
                                provider.onQueryChanged('');
                              },
                              icon: const Icon(Icons.close_rounded, size: 18),
                            )),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: provider.isSearchMode
                  ? _SearchResults(
                      provider: provider,
                      onSelect: (result) => _apply(() => provider.apply(result)),
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
    if (provider.results.isEmpty && !provider.isSearching) {
      return const EmptyStateView(
        icon: Icons.travel_explore_outlined,
        title: 'ఫలితాలు లేవు',
        message: 'దయచేసి వేరే పేరుతో వెతకండి',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: provider.results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final result = provider.results[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _iconFor(result.type),
              size: 19,
              color: Theme.of(context).primaryColor,
            ),
          ),
          title: Text(result.nameEn, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            [result.type.label, result.breadcrumb]
                .where((value) => value.isNotEmpty)
                .join(' • '),
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => onSelect(result),
        );
      },
    );
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
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.hasError && provider.states.isEmpty) {
      return ErrorStateView(error: provider.error ?? 'Error', onRetry: provider.load);
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
            title: '${provider.selectedState!.nameEn} లో జిల్లాలు',
            trailingText: 'ఈ రాష్ట్రం ఎంచుకోండి',
            onTrailingTap: () => onApplyNode(provider.selectedState!, LocationLevel.state),
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
            title: '${provider.selectedDistrict!.nameEn} లో మండలాలు',
            trailingText: 'ఈ జిల్లా ఎంచుకోండి',
            onTrailingTap: () => onApplyNode(provider.selectedDistrict!, LocationLevel.district),
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
            title: '${provider.selectedSubdistrict!.nameEn} లో గ్రామాలు',
            trailingText: 'ఈ మండలం ఎంచుకోండి',
            onTrailingTap: () => onApplyNode(provider.selectedSubdistrict!, LocationLevel.subdistrict),
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
      if (provider.selectedState != null) provider.selectedState!.nameEn,
      if (provider.selectedDistrict != null) provider.selectedDistrict!.nameEn,
      if (provider.selectedSubdistrict != null) provider.selectedSubdistrict!.nameEn,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: provider.clearDrilldown,
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.restart_alt_rounded),
            tooltip: 'మొదటి నుండి ప్రారంభించండి (Start Over)',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              crumbs.join('  ›  '),
              style: TextStyle(fontSize: 14, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final node in nodes)
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: () => onTap(node),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Text(node.nameEn, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
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
    if (nodes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text('ఏమీ కనుగొనబడలేదు', style: TextStyle(fontSize: 14, color: Colors.grey)),
        ),
      );
    }

    return Column(
      children: [
        for (final node in nodes)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(node.nameEn, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            subtitle: node.nameTe.isNotEmpty
                ? Text(node.nameTe, style: const TextStyle(fontSize: 13, color: Colors.grey))
                : null,
            trailing: TextButton(
              onPressed: () => onUse(node),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Text('ఎంచుకోండి'),
            ),
            onTap: () => onTap(node),
          ),
      ],
    );
  }
}

class _ConfirmDetected extends StatelessWidget {
  const _ConfirmDetected({required this.place, required this.matches});

  final DetectedPlace place;
  final List<LocationSearchResult> matches;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Icon(Icons.my_location_rounded, size: 20, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('ఇదే మీ ప్రాంతమా?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            place.fullTrail.isEmpty ? 'Unknown area' : place.fullTrail,
            style: const TextStyle(fontSize: 15, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Text(
            matches.length == 1
                ? 'దిగువ మీ ప్రాంతాన్ని నిర్ధారించండి.'
                : 'సరిపోయే ప్రాంతాన్ని ఎంచుకోండి.',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          for (final match in matches)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  onTap: () => Navigator.of(context).pop(match),
                  leading: Icon(Icons.place_rounded, size: 20, color: Theme.of(context).primaryColor),
                  title: Text(match.nameEn, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    [match.subdistrict, match.district, match.state]
                        .where((v) => v.isNotEmpty)
                        .join(', '),
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  trailing: Text(
                    match.type.name.toUpperCase(),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('స్వయంగా ఎంచుకుంటాను'),
          ),
        ],
      ),
    );
  }
}
