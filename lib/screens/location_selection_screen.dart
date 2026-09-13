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
  State<LocationSelectionScreen> createState() =>
      _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  int _searchGeneration = 0;
  int _districtGeneration = 0;
  int _subdistrictGeneration = 0;
  int _villageGeneration = 0;
  bool _isSearching = false;
  List<dynamic> _searchResults = [];

  bool _isLoadingGps = false;
  bool _isLoadingHierarchy = true;
  String? _hierarchyError;
  List<dynamic> _states = [];
  List<dynamic> _districts = [];
  List<dynamic> _subdistricts = [];
  List<dynamic> _villages = [];

  String? _selectedState;
  String? _selectedDistrict;
  String? _selectedSubdistrict;

  @override
  void initState() {
    super.initState();
    _loadInitialLocations();
  }

  String _locationName(dynamic item) {
    if (item is! Map) return '';
    return (item['name_en'] ?? item['name'] ?? '').toString().trim();
  }

  dynamic _findByName(List<dynamic> items, String name) {
    final expected = name.trim().toLowerCase();
    for (final item in items) {
      if (_locationName(item).toLowerCase() == expected) return item;
    }
    return null;
  }

  Future<void> _loadInitialLocations() async {
    if (mounted) {
      setState(() {
        _isLoadingHierarchy = true;
        _hierarchyError = null;
      });
    }
    final states = await ApiService.instance.getStates();
    if (!mounted) return;
    if (states.isEmpty) {
      setState(() {
        _states = [];
        _districts = [];
        _isLoadingHierarchy = false;
        _hierarchyError =
            'ప్రాంతాలను లోడ్ చేయలేకపోయాం. నెట్‌వర్క్‌ను తనిఖీ చేసి మళ్లీ ప్రయత్నించండి.';
      });
      return;
    }

    final savedState = AppState.instance.stateName;
    final selected = _findByName(states, savedState) ?? states.first;
    final stateName = _locationName(selected);
    setState(() {
      _states = states;
      _selectedState = stateName;
    });
    await _loadDistricts(stateName);
  }

  Future<void> _loadDistricts(String state) async {
    final generation = ++_districtGeneration;
    _subdistrictGeneration++;
    _villageGeneration++;
    if (mounted) {
      setState(() {
        _isLoadingHierarchy = true;
        _hierarchyError = null;
        _selectedDistrict = null;
        _selectedSubdistrict = null;
        _districts = [];
        _subdistricts = [];
        _villages = [];
      });
    }
    final districts = await ApiService.instance.getDistricts(state);
    if (!mounted ||
        generation != _districtGeneration ||
        state != _selectedState) {
      return;
    }
    setState(() {
      _districts = districts;
      _isLoadingHierarchy = false;
      if (districts.isEmpty) {
        _hierarchyError = '$stateలో జిల్లాలు అందుబాటులో లేవు.';
      }
    });
  }

  Future<void> _loadSubdistricts(String district) async {
    final generation = ++_subdistrictGeneration;
    _villageGeneration++;
    final subs = await ApiService.instance.getSubdistricts(
      district,
      state: _selectedState ?? 'Telangana',
    );
    if (mounted &&
        generation == _subdistrictGeneration &&
        district == _selectedDistrict) {
      setState(() {
        _subdistricts = subs;
        _villages = [];
        _selectedSubdistrict = null;
      });
    }
  }

  Future<void> _loadVillages(String subdistrict) async {
    final generation = ++_villageGeneration;
    final villages = await ApiService.instance.getVillages(
      subdistrict,
      state: _selectedState ?? 'Telangana',
      district: _selectedDistrict,
    );
    if (mounted &&
        generation == _villageGeneration &&
        subdistrict == _selectedSubdistrict) {
      setState(() {
        _villages = villages;
      });
    }
  }

  String? _selectedDistrictId() {
    for (var d in _districts) {
      final dName = (d['name_en'] ?? d['name'] ?? '').toString().toLowerCase();
      if (dName == (_selectedDistrict ?? '').toLowerCase()) {
        return d['id']?.toString();
      }
    }
    return null;
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    final generation = ++_searchGeneration;
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
      if (mounted && generation == _searchGeneration) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _detectGps() async {
    final consent = await LocationService.showPrivacyDisclosure(context);
    if (!consent) return;

    setState(() => _isLoadingGps = true);
    try {
      final loc = await LocationService.detectLocation();
      final match = await ApiService.instance.resolveCanonicalLocation(loc);
      final confirmed = await LocationService.showCanonicalConfirmation(
        context,
        match,
      );
      if (!confirmed || !mounted) return;
      await ApiService.instance.applyCanonicalLocation(match);
      if (mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    } on LocationException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'మీ ప్రాంతాన్ని గుర్తించలేకపోయాం. దయచేసి మీరే ఎంచుకోండి.'),
          ),
        );
      }
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
    final states =
        _states.isNotEmpty ? _states : await ApiService.instance.getStates();
    final stateItem = _findByName(states, state);
    stateId ??= stateItem is Map ? stateItem['id']?.toString() : null;

    if (district.isNotEmpty && districtId == null) {
      final districts = _selectedState == state && _districts.isNotEmpty
          ? _districts
          : await ApiService.instance.getDistricts(state);
      final districtItem = _findByName(districts, district);
      districtId = districtItem is Map ? districtItem['id']?.toString() : null;
    }

    if (district.isNotEmpty &&
        subdistrict?.isNotEmpty == true &&
        subdistrictId == null) {
      final subdistricts = await ApiService.instance.getSubdistricts(
        district,
        state: state,
      );
      final subdistrictItem = _findByName(subdistricts, subdistrict!);
      subdistrictId =
          subdistrictItem is Map ? subdistrictItem['id']?.toString() : null;
    }

    if (district.isNotEmpty &&
        subdistrict?.isNotEmpty == true &&
        village?.isNotEmpty == true &&
        villageId == null) {
      final villages = await ApiService.instance.getVillages(
        subdistrict!,
        state: state,
        district: district,
      );
      final villageItem = _findByName(villages, village!);
      villageId = villageItem is Map ? villageItem['id']?.toString() : null;
    }

    final app = AppState.instance;
    app.setLocation(
      state,
      district,
      city: village?.isNotEmpty == true
          ? village
          : (subdistrict?.isNotEmpty == true ? subdistrict : district),
      subdistrict: subdistrict ?? '',
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
    if (villageId != null && villageId.isNotEmpty)
      patchData['village_id'] = villageId;
    if (subdistrictId != null && subdistrictId.isNotEmpty)
      patchData['subdistrict_id'] = subdistrictId;
    if (districtId != null && districtId.isNotEmpty)
      patchData['district_id'] = districtId;
    if (stateId != null && stateId.isNotEmpty) patchData['state_id'] = stateId;

    if (patchData.isNotEmpty) {
      try {
        await ApiService.instance.updateLocationProfile(patchData);
      } catch (_) {
        // The local selection remains usable when optional profile sync fails.
      }
    }

    if (app.isLoggedIn && lat != null && lon != null) {
      await ApiService.instance.updateUserLocation({
        'lat': lat,
        'lon': lon,
        'city': village?.isNotEmpty == true
            ? village
            : (subdistrict?.isNotEmpty == true ? subdistrict : district),
        'district': district,
        'state': state,
        'subdistrict': subdistrict ?? '',
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
        title: const Text('మీ ప్రాంతాన్ని ఎంచుకోండి',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
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
                  prefixIcon:
                      const Icon(Icons.search, color: AppColors.primary),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      _isLoadingGps
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.primary),
                            )
                          : const Icon(Icons.my_location_rounded,
                              color: AppColors.primary, size: 20),
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
      return const Center(
          child: Text('మీ వెతుకులాటికి సరిపోలే ప్రాంతాలు కనిపించలేదు.'));
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
          leading:
              const Icon(Icons.location_on_outlined, color: AppColors.primary),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
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

            final stateName =
                (type == 'state' ? title : loc['state'])?.toString() ??
                    'Telangana';
            final districtName =
                (type == 'state' ? '' : loc['district'] ?? title).toString();

            _saveAndExit(
              state: stateName,
              district: districtName,
              subdistrict:
                  loc['subdistrict'] ?? (type == 'subdistrict' ? title : null),
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
        const Text(
          'రాష్ట్రం',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedState,
          isExpanded: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.map_outlined),
            labelText: 'రాష్ట్రాన్ని ఎంచుకోండి',
          ),
          items: _states
              .map(_locationName)
              .where((name) => name.isNotEmpty)
              .map(
                (name) => DropdownMenuItem<String>(
                  value: name,
                  child: Text(name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: _isLoadingHierarchy
              ? null
              : (state) {
                  if (state == null || state == _selectedState) return;
                  setState(() => _selectedState = state);
                  _loadDistricts(state);
                },
        ),
        if (_selectedState?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _isLoadingHierarchy
                ? null
                : () {
                    final selected = _findByName(_states, _selectedState!);
                    _saveAndExit(
                      state: _selectedState!,
                      district: '',
                      stateId:
                          selected is Map ? selected['id']?.toString() : null,
                    );
                  },
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: Text('${_selectedState} ప్రాంతాన్ని ఎంచుకోండి'),
          ),
        ],
        if (_isLoadingHierarchy) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        if (_hierarchyError != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _hierarchyError!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
              TextButton.icon(
                onPressed: _loadInitialLocations,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('మళ్లీ ప్రయత్నించండి'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),

        // District Section Header
        const Text(
          'జిల్లాలు',
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
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              onSelected: (_) {
                setState(() {
                  _selectedDistrict = name;
                  _selectedSubdistrict = null;
                  _villages = [];
                });
                _loadSubdistricts(name);
              },
            );
          }).toList(),
        ),

        if (_selectedDistrict != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              _saveAndExit(
                state: _selectedState ?? 'Telangana',
                district: _selectedDistrict!,
                districtId: _selectedDistrictId(),
              );
            },
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: Text('$_selectedDistrict జిల్లాను ఎంచుకోండి'),
          ),
        ],

        if (_subdistricts.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'మండలాలు',
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
              final isSelected = _selectedSubdistrict == name;
              return FilterChip(
                selected: isSelected,
                label: Text(name),
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black87),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
                onSelected: (_) {
                  setState(() => _selectedSubdistrict = name);
                  _loadVillages(name);
                },
              );
            }).toList(),
          ),
          if (_selectedSubdistrict != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                final selected = _subdistricts.cast<dynamic>().firstWhere(
                      (s) =>
                          ((s['name_en'] ?? s['name'] ?? '').toString()) ==
                          _selectedSubdistrict,
                      orElse: () => <String, dynamic>{},
                    );
                _saveAndExit(
                  state: _selectedState ?? 'Telangana',
                  district: _selectedDistrict ?? 'Hyderabad',
                  subdistrict: _selectedSubdistrict,
                  subdistrictId:
                      selected is Map ? selected['id']?.toString() : null,
                  districtId: _selectedDistrictId(),
                );
              },
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: Text('$_selectedSubdistrict మండలాన్ని ఎంచుకోండి'),
            ),
          ],
        ],

        if (_villages.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'గ్రామాలు',
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
            children: _villages.map((v) {
              final name = v['name_en'] ?? v['name'] ?? 'Village';
              return ActionChip(
                label: Text(name),
                onPressed: () {
                  final selectedSubdistrict = _subdistricts
                      .cast<dynamic>()
                      .firstWhere(
                        (s) =>
                            ((s['name_en'] ?? s['name'] ?? '').toString()) ==
                            _selectedSubdistrict,
                        orElse: () => <String, dynamic>{},
                      );
                  _saveAndExit(
                    state: _selectedState ?? 'Telangana',
                    district: _selectedDistrict ?? 'Hyderabad',
                    subdistrict: _selectedSubdistrict,
                    village: name,
                    villageId: v['id']?.toString(),
                    subdistrictId: selectedSubdistrict is Map
                        ? selectedSubdistrict['id']?.toString()
                        : null,
                    districtId: _selectedDistrictId(),
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
