import 'dart:async';

import 'package:flutter/material.dart';

import '../models/location_model.dart';
import '../repositories/location_repository.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// What the reporter chose in [UgcLocationSheet].
class UgcPlace {
  final String village;
  final String subdistrict;
  final String district;
  final String stateName;

  /// "Use my current location": drop the manual correction.
  final bool useGps;

  const UgcPlace({
    this.village = '',
    this.subdistrict = '',
    this.district = '',
    this.stateName = '',
    this.useGps = false,
  });

  const UgcPlace.gps() : this(useGps: true);

  /// Fills the four levels from a search hit: the hit itself is its own
  /// level, its parents come from the breadcrumb fields.
  factory UgcPlace.fromSearch(LocationSearchResult r) => UgcPlace(
        village: r.type == LocationLevel.village ? r.nameEn : '',
        subdistrict:
            r.type == LocationLevel.subdistrict ? r.nameEn : r.subdistrict,
        district: r.type == LocationLevel.district ? r.nameEn : r.district,
        stateName: r.type == LocationLevel.state ? r.nameEn : r.state,
      );
}

/// Lets the reporter correct where the story happened: search a place,
/// edit village / mandal / district / state by hand, or go back to GPS.
/// Only the post changes — the app's own location is left alone.
class UgcLocationSheet extends StatefulWidget {
  final UgcPlace initial;
  final Future<List<LocationSearchResult>> Function(String query)? search;

  const UgcLocationSheet({super.key, required this.initial, this.search});

  static Future<UgcPlace?> open(BuildContext context, UgcPlace initial,
      {Future<List<LocationSearchResult>> Function(String query)? search}) {
    return showModalBottomSheet<UgcPlace>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => UgcLocationSheet(initial: initial, search: search),
    );
  }

  @override
  State<UgcLocationSheet> createState() => _UgcLocationSheetState();
}

class _UgcLocationSheetState extends State<UgcLocationSheet> {
  late final _village = TextEditingController(text: widget.initial.village);
  late final _mandal = TextEditingController(text: widget.initial.subdistrict);
  late final _district = TextEditingController(text: widget.initial.district);
  late final _state = TextEditingController(text: widget.initial.stateName);
  final _query = TextEditingController();
  Timer? _debounce;
  List<LocationSearchResult> _results = const [];
  bool _searching = false;
  int _searchGen = 0;

  static String _t(String te, String en) =>
      AppState.instance.language == 'Telugu' ? te : en;

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_village, _mandal, _district, _state, _query]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onQuery(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(q.trim()));
  }

  Future<void> _run(String q) async {
    final gen = ++_searchGen;
    setState(() => _searching = true);
    List<LocationSearchResult> hits;
    try {
      hits = await (widget.search ?? LocationRepository().search)(q);
    } catch (_) {
      hits = const [];
    }
    if (!mounted || gen != _searchGen) return;
    setState(() {
      _results = hits;
      _searching = false;
    });
  }

  void _pick(LocationSearchResult r) {
    final p = UgcPlace.fromSearch(r);
    setState(() {
      _village.text = p.village;
      _mandal.text = p.subdistrict;
      _district.text = p.district;
      _state.text = p.stateName;
      _results = const [];
      _query.clear();
    });
    FocusScope.of(context).unfocus();
  }

  bool get _valid =>
      _district.text.trim().isNotEmpty && _state.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? Colors.white24 : const Color(0xFFE7E9EE);
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          key: const Key('ugc_location_sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Text(_t('వార్త జరిగిన ప్రాంతం', 'Where did this happen?'),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              _t('GPS సరిగ్గా లేకపోతే ఇక్కడ సరిచేయండి.',
                  'Correct the place if GPS got it wrong.'),
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              key: const Key('ugc_location_use_gps'),
              onPressed: () => Navigator.pop(context, const UgcPlace.gps()),
              icon: const Icon(Icons.my_location_rounded, size: 18),
              label: Text(_t('నా ప్రస్తుత లొకేషన్ (GPS)',
                  'Use my current location (GPS)')),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('ugc_location_search'),
              controller: _query,
              onChanged: _onQuery,
              textInputAction: TextInputAction.search,
              decoration: _decoration(
                border,
                _t('గ్రామం / మండలం / జిల్లా వెతకండి',
                    'Search village / mandal / district'),
                prefix: const Icon(Icons.search_rounded, size: 20),
                suffix: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : null,
              ),
            ),
            if (_results.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6),
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  border: Border.all(color: border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _results.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: border),
                  itemBuilder: (_, i) {
                    final r = _results[i];
                    final te = r.nameTe.trim();
                    return ListTile(
                      key: Key('ugc_location_result_$i'),
                      dense: true,
                      leading: const Icon(Icons.place_outlined, size: 20),
                      title: Text(te.isNotEmpty ? '$te (${r.nameEn})' : r.nameEn),
                      subtitle:
                          r.breadcrumb.isEmpty ? null : Text(r.breadcrumb),
                      onTap: () => _pick(r),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            _field(_village, _t('గ్రామం / ప్రాంతం', 'Village / area'),
                'ugc_location_village', border),
            _field(_mandal, _t('మండలం', 'Mandal'), 'ugc_location_mandal',
                border),
            _field(_district, _t('జిల్లా *', 'District *'),
                'ugc_location_district', border),
            _field(_state, _t('రాష్ట్రం *', 'State *'), 'ugc_location_state',
                border),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                key: const Key('ugc_location_save'),
                onPressed: _valid
                    ? () => Navigator.pop(
                          context,
                          UgcPlace(
                            village: _village.text,
                            subdistrict: _mandal.text,
                            district: _district.text,
                            stateName: _state.text,
                          ),
                        )
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(_t('ఈ ప్రాంతాన్ని ఉపయోగించు', 'Use this place'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, String key,
      Color border) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        key: Key(key),
        controller: c,
        onChanged: (_) => setState(() {}),
        textCapitalization: TextCapitalization.words,
        decoration: _decoration(border, label),
      ),
    );
  }

  InputDecoration _decoration(Color border, String label,
      {Widget? prefix, Widget? suffix}) {
    OutlineInputBorder outline(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: 1.3),
        );
    return InputDecoration(
      labelText: label,
      isDense: true,
      prefixIcon: prefix,
      suffixIcon: suffix,
      filled: true,
      fillColor: Theme.of(context).cardColor,
      border: outline(border),
      enabledBorder: outline(border),
      focusedBorder: outline(AppColors.primary),
    );
  }
}
