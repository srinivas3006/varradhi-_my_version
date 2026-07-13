import 'package:flutter/material.dart';
import '../localization/app_translations.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'location_screen.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  final List<Map<String, String>> _languages = const [
    {'name': 'English', 'native': 'English'},
    {'name': 'Hindi', 'native': 'हिन्दी'},
    {'name': 'Telugu', 'native': 'తెలుగు'},
    {'name': 'Tamil', 'native': 'தமிழ்'},
    {'name': 'Kannada', 'native': 'ಕನ್ನಡ'},
    {'name': 'Marathi', 'native': 'मराठी'},
    {'name': 'Bengali', 'native': 'বাংলা'},
    {'name': 'Malayalam', 'native': 'മലയാളം'},
  ];

  String _selected = 'English';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('choose_language'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tr('choose_language_sub'),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13.5),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.builder(
                  itemCount: _languages.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.4,
                  ),
                  itemBuilder: (context, index) {
                    final lang = _languages[index];
                    final isSelected = lang['name'] == _selected;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selected = lang['name']!);
                        // Live preview: update the app-wide language
                        // immediately so this screen's own text (and the
                        // font used for its script) updates as you tap,
                        // not just after pressing Continue.
                        AppState.instance.setLanguage(lang['name']!);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.08)
                              : AppColors.chipBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              lang['native']!,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              lang['name']!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    AppState.instance.setLanguage(_selected);
                    if (AppState.instance.hasOnboarded) {
                      Navigator.of(context).pop();
                    } else {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LocationScreen()),
                      );
                    }
                  },
                  child: Text(
                    tr('continue'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
