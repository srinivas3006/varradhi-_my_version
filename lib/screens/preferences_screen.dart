import 'package:flutter/material.dart';
import '../localization/app_translations.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final List<String> _selected = [];
  final List<String> _selectableCategories = [
    'Latest News',
    'Andhra Pradesh',
    'Telangana',
    'National',
    'International',
    'Politics',
    'Business',
    'Sports',
    'Cinema',
    'Technology',
    'Education & Jobs',
    'Health',
    'Agriculture',
    'Spiritual',
    'Videos',
    'Photos',
  ];

  @override
  void initState() {
    super.initState();
    _selected.addAll(AppState.instance.preferredCategories);
  }

  void _toggleCategory(String category) {
    setState(() {
      if (_selected.contains(category)) {
        _selected.remove(category);
      } else {
        _selected.add(category);
      }
    });
  }

  bool _isSaving = false;

  Future<void> _savePreferences() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    await AppState.instance.setPreferredCategories(_selected);
    if (!mounted) return;

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('అభిరుచులు సేవ్ చేయబడ్డాయి'),
        duration: Duration(seconds: 2),
      ),
    );
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
                color: isDark ? AppColors.textMuted : Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Wrap(
                spacing: 12.0,
                runSpacing: 12.0,
                children: _selectableCategories.map((cat) {
                  final selected = _selected.contains(cat);
                  return FilterChip(
                    label: Text(categoryLabel(cat)),
                    selected: selected,
                    onSelected: (_) => _toggleCategory(cat),
                    selectedColor: AppColors.primary.withAlpha(50), // Replaced withOpacity
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
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _savePreferences,
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
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'సేవ్ చేయండి',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
