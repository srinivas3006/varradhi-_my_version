import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

/// Screen 17: LocationSelectionScreen
/// - APIs: locations/search, states, districts, subdistricts, villages, location profile
/// - Destination: previous screen / HomeScreen
class LocationSelectionScreen extends StatefulWidget {
  const LocationSelectionScreen({super.key});

  @override
  State<LocationSelectionScreen> createState() => _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;
  List<dynamic> _searchResults = [];

  bool _isLoadingGps = false;
  List<dynamic> _districts = [];
  List<dynamic> _subdistricts = [];

  String? _selectedState;
  String? _selectedDistrict;

  @override
  void initState() {
    super.initState();
    _loadInitialDistricts();
  }

  Future<void> _loadInitialDistricts() async {
    _selectedState = AppState.instance.stateName;
    final dists = await ApiService.instance.getDistricts((_selectedState ?? 'telangana').toLowerCase());
    if (mounted) {
      setState(() {
        _districts = dists.isNotEmpty ? dists : [
          {'name_en': 'Hyderabad', 'slug': 'hyderabad'},
          {'name_en': 'Warangal', 'slug': 'warangal'},
          {'name_en': 'Karimnagar', 'slug': 'karimnagar'},
          {'name_en': 'Nizamabad', 'slug': 'nizamabad'},
          {'name_en': 'Khammam', 'slug': 'khammam'},
          {'name_en': 'Suryapet', 'slug': 'suryapet'},
        ];
      });
    }
  }

  Future<void> _loadSubdistricts(String district) async {
    final subs = await ApiService.instance.getSubdistricts(district.toLowerCase());
    if (mounted) {
      setState(() {
        _subdistricts = subs;
      });
    }
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final results = await ApiService.instance.searchLocations(q.trim());
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _detectGps() async {
    setState(() => _isLoadingGps = true);
    try {
      final loc = await LocationService.detectLocation();
      await ApiService.instance.resolveAndSyncCanonicalLocation(loc);
      if (mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingGps = false);
    }
  }

  Future<void> _saveAndExit({
    required String state,
    required String district,
    String? subdistrict,
    String? village,
    double? lat,
    double? lon,
    String? stateId,
    String? districtId,
    String? subdistrictId,
    String? villageId,
  }) async {
    // If districtId is not provided, look it up from _districts
    if (districtId == null) {
      for (var d in _districts) {
        final dName = (d['name_en'] ?? d['name'] ?? '').toString().toLowerCase();
        if (dName == district.toLowerCase()) {
          districtId = d['id']?.toString();
          stateId ??= d['state']?.toString();
          break;
        }
      }
    }

    final app = AppState.instance;
    app.setLocation(
      state,
      district,
      city: district,
      subdistrict: subdistrict ?? district,
      village: village ?? '',
      latitude: lat,
      longitude: lon,
      stateId: stateId,
      districtId: districtId,
      subdistrictId: subdistrictId,
      villageId: villageId,
    );

    // Prepare canonical patch payload as required by appcode.md
    final patchData = <String, dynamic>{};
    if (villageId != null && villageId.isNotEmpty) patchData['village_id'] = villageId;
    if (subdistrictId != null && subdistrictId.isNotEmpty) patchData['subdistrict_id'] = subdistrictId;
    if (districtId != null && districtId.isNotEmpty) patchData['district_id'] = districtId;
    if (stateId != null && stateId.isNotEmpty) patchData['state_id'] = stateId;

    if (patchData.isNotEmpty) {
      await ApiService.instance.updateLocationProfile(patchData);
    }

    if (app.isLoggedIn && lat != null && lon != null) {
      await ApiService.instance.updateUserLocation({
        'lat': lat,
        'lon': lon,
        'city': district,
        'district': district,
        'state': state,
        'subdistrict': subdistrict ?? district,
        'village': village ?? '',
        'country': 'India',
        'location_source': 'manual',
      });
    }

    if (!mounted) return;

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('మీ ప్రాంతాన్ని ఎంచుకోండి', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        elevation: 0,
        actions: [
          if (!Navigator.of(context).canPop())
            TextButton(
              onPressed: () {
                AppState.instance.completeOnboarding('Telugu');
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                );
              },
              child: const Text(
                'దాటవేయి',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Box
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'నగరం, మండలం లేదా గ్రామం కోసం వెతకండి...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                  filled: true,
                  fillColor: isDark ? AppColors.chipBgDark : AppColors.chipBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // GPS Auto-detect Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: InkWell(
                onTap: _isLoadingGps ? null : _detectGps,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      _isLoadingGps
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            )
                          : const Icon(Icons.my_location_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'నా ప్రస్తుత ప్రాంతాన్ని గుర్తించండి (GPS)',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Search Results or Hierarchical Picker
            Expanded(
              child: _searchController.text.trim().length >= 2
                  ? _buildSearchResults()
                  : _buildHierarchicalPicker(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchResults.isEmpty) {
      return const Center(child: Text('No locations found matching your search.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final loc = _searchResults[index] as Map<String, dynamic>;
        final title = loc['name_en'] ?? loc['name'] ?? 'Location';
        final sub = loc['district'] ?? loc['state'] ?? '';

        return ListTile(
          leading: const Icon(Icons.location_on_outlined, color: AppColors.primary),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: sub.isNotEmpty ? Text(sub) : null,
          onTap: () {
            final type = loc['type']?.toString().toLowerCase();
            final id = loc['id']?.toString();
            String? stateId;
            String? districtId;
            String? subdistrictId;
            String? villageId;

            if (type == 'village') {
              villageId = id;
            } else if (type == 'subdistrict') {
              subdistrictId = id;
            } else if (type == 'district') {
              districtId = id;
            } else if (type == 'state') {
              stateId = id;
            }

            _saveAndExit(
              state: loc['state'] ?? 'Telangana',
              district: loc['district'] ?? title,
              subdistrict: loc['subdistrict'] ?? (type == 'subdistrict' ? title : null),
              village: loc['village'] ?? (type == 'village' ? title : null),
              stateId: stateId,
              districtId: districtId,
              subdistrictId: subdistrictId,
              villageId: villageId,
            );
          },
        );
      },
    );
  }

  Widget _buildHierarchicalPicker(bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // District Section Header
        const Text(
          'ప్రముఖ జిల్లాలు (POPULAR DISTRICTS)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 10),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _districts.map((d) {
            final name = d['name_en'] ?? d['name'] ?? 'District';
            final isSelected = _selectedDistrict == name;

              return FilterChip(
                selected: isSelected,
                label: Text(name),
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
                onSelected: (_) {
                  setState(() => _selectedDistrict = name);
                  _loadSubdistricts(name);
                  _saveAndExit(
                    state: _selectedState ?? 'Telangana',
                    district: name,
                    districtId: d['id']?.toString(),
                    stateId: d['state']?.toString(),
                  );
                },
              );
            }).toList(),
          ),

          if (_subdistricts.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'మండలాలు / నియోజకవర్గాలు (MANDALS)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _subdistricts.map((s) {
                final name = s['name_en'] ?? s['name'] ?? 'Mandal';
                return ActionChip(
                  label: Text(name),
                  onPressed: () {
                    String? distId;
                    for (var d in _districts) {
                      final dName = (d['name_en'] ?? d['name'] ?? '').toString().toLowerCase();
                      if (dName == (_selectedDistrict ?? '').toLowerCase()) {
                        distId = d['id']?.toString();
                        break;
                      }
                    }
                    _saveAndExit(
                      state: _selectedState ?? 'Telangana',
                      district: _selectedDistrict ?? 'Hyderabad',
                      subdistrict: name,
                      subdistrictId: s['id']?.toString(),
                      districtId: distId,
                    );
                  },
                );
              }).toList(),
            ),
          ],
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }
}
