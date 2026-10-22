import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Content preferences: the reader picks categories, sent to the backend as
/// category weights (`PATCH /api/v1/users/me/preferences/`).
///
/// The chips are the backend's own active categories. The old fixed list
/// offered names such as "Videos", "Technology" or "Andhra Pradesh" that
/// are not categories there, so most chips did nothing when saved.
class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final Set<String> _selected = {};
  List<Category> _categories = const [];
  bool _loading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _loading = true);
    final all = await ApiService.instance.getCategories();
    if (!mounted) return;
    final active = all.where((c) => c.isActive && c.slug.isNotEmpty).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    setState(() {
      _categories = active;
      _loading = false;
      _selected
        ..clear()
        ..addAll(AppState.resolvePreferenceSlugs(
            AppState.instance.preferredCategories,
            active.map((c) => c.slug).toSet()));
    });
  }

  /// Names for backend categories the shared label table does not cover
  /// (it is also used by other screens, so it is left as is). The API sends
  /// English names only.
  static const _teluguLabels = {
    'national-news': 'జాతీయ వార్తలు',
    'state-news': 'రాష్ట్ర వార్తలు',
    'local-news': 'స్థానిక వార్తలు',
    'district-news': 'జిల్లా వార్తలు',
    'weather': 'వాతావరణం',
    'education': 'విద్య',
    'jobs-careers': 'ఉద్యోగాలు & కెరీర్',
    'cinema': 'సినిమా',
    'cinima': 'సినిమా',
  };

  static String _label(Category cat) {
    if (AppState.instance.language == 'Telugu') {
      return _teluguLabels[cat.slug] ?? cat.localizedName;
    }
    // The backend spells this slug's name "CINIMA".
    return cat.slug == 'cinima' ? 'Cinema' : cat.localizedName;
  }

  void _toggleCategory(String slug) {
    setState(() {
      if (!_selected.remove(slug)) _selected.add(slug);
    });
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ));
  }

  Future<void> _savePreferences() async {
    if (_isSaving || _loading || _categories.isEmpty) return;
    setState(() => _isSaving = true);

    final app = AppState.instance;
    await app.setPreferredCategories(_selected.toList());

    if (app.isLoggedIn) {
      try {
        await app.syncPreferredCategories();
      } catch (e) {
        debugPrint('[Preferences] save failed: $e');
        if (!mounted) return;
        setState(() => _isSaving = false);
        // Kept on screen so the reader can retry; the choice is already
        // stored on the device and goes up again on the next login.
        _showMessage('సేవ్ కాలేదు. మీ కనెక్షన్‌ను తనిఖీ చేసి మళ్లీ ప్రయత్నించండి.');
        return;
      }
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(app.isLoggedIn
            ? 'అభిరుచులు సేవ్ చేయబడ్డాయి'
            : 'అభిరుచులు సేవ్ చేయబడ్డాయి. లాగిన్ అయిన తర్వాత మీ ఖాతాకు వర్తిస్తాయి.'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'కంటెంట్ అభిరుచులు',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'మీకు ఆసక్తి ఉన్న అంశాలను ఎంచుకోండి. మేము మీ ఫీడ్‌ను అనుకూలీకరిస్తాము.',
              style: TextStyle(
                fontSize: 15,
                color: isDark
                    ? AppColors.textMuted
                    : Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ),
          Expanded(child: _buildBody(isDark)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading || _categories.isEmpty
                      ? null
                      : _savePreferences,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'సేవ్ చేయండి',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_categories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 40, color: AppColors.textMuted),
              const SizedBox(height: 12),
              const Text(
                'అంశాలు లోడ్ కాలేదు. మీ కనెక్షన్‌ను తనిఖీ చేయండి.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _loadCategories,
                child: const Text('మళ్లీ ప్రయత్నించండి'),
              ),
            ],
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Wrap(
        spacing: 12.0,
        runSpacing: 12.0,
        children: _categories.map((cat) {
          final selected = _selected.contains(cat.slug);
          return FilterChip(
            key: ValueKey('pref_${cat.slug}'),
            label: Text(_label(cat)),
            selected: selected,
            onSelected: (_) => _toggleCategory(cat.slug),
            selectedColor: AppColors.primary.withAlpha(50),
            checkmarkColor: AppColors.primary,
            labelStyle: TextStyle(
              color: selected
                  ? AppColors.primary
                  : (isDark ? AppColors.textLight : AppColors.textDark),
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
            backgroundColor: isDark ? AppColors.chipBgDark : AppColors.chipBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: selected ? AppColors.primary : Colors.transparent,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
