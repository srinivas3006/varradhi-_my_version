import 'package:flutter/material.dart';
import '../localization/app_translations.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'spotlight_screen.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> with SingleTickerProviderStateMixin {
  final List<Map<String, String>> _languages = const [
    {'name': 'English', 'native': 'English'},
    {'name': 'Telugu', 'native': 'తెలుగు'},
  ];

  String _selected = 'English';
  
  late final AnimationController _animController;
  late final Animation<double> _fadeHeaderAnim;
  late final List<Animation<double>> _slideAnims;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeHeaderAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    // Staggered slide animations for the language cards
    _slideAnims = List.generate(2, (index) {
      final start = 0.2 + (index * 0.15);
      final end = start + 0.4;
      return Tween<double>(begin: 50.0, end: 0.0).animate(
        CurvedAnimation(
          parent: _animController,
          curve: Interval(start, end > 1.0 ? 1.0 : end, curve: Curves.easeOutCubic),
        ),
      );
    });

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedBuilder(
                animation: _fadeHeaderAnim,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeHeaderAnim.value,
                    child: child,
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('choose_language'),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr('choose_language_sub'),
                      style: const TextStyle(
                        color: AppColors.textMuted, 
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _languages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final lang = _languages[index];
                    final isSelected = lang['name'] == _selected;
                    
                    return AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        final animValue = _slideAnims[index].value;
                        // Fade in proportionally to the slide
                        final opacity = (1.0 - (animValue / 50.0)).clamp(0.0, 1.0);
                        return Transform.translate(
                          offset: Offset(0, animValue),
                          child: Opacity(
                            opacity: opacity,
                            child: child,
                          ),
                        );
                      },
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selected = lang['name']!);
                          AppState.instance.setLanguage(lang['name']!);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : Colors.grey.shade200,
                              width: isSelected ? 2.0 : 1.5,
                            ),
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                )
                              else
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lang['native']!,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected ? AppColors.primary : AppColors.textDark,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      lang['name']!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AnimatedScale(
                                scale: isSelected ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.elasticOut,
                                child: const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.primary,
                                  size: 28,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              AnimatedBuilder(
                animation: _fadeHeaderAnim,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeHeaderAnim.value,
                    child: child,
                  );
                },
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          AppState.instance.setLanguage(_selected);
                          if (AppState.instance.hasOnboarded) {
                            Navigator.of(context).pop();
                          } else {
                            AppState.instance.completeOnboarding();
                            Navigator.of(context).pushReplacement(
                              PageRouteBuilder(
                                transitionDuration: const Duration(milliseconds: 500),
                                pageBuilder: (_, __, ___) => const SpotlightScreen(),
                                transitionsBuilder: (_, anim, __, child) =>
                                    FadeTransition(opacity: anim, child: child),
                              ),
                            );
                          }
                        },
                        child: Text(
                          tr('continue'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                    if (!AppState.instance.hasOnboarded) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            AppState.instance.completeOnboarding('Telugu');
                            Navigator.of(context).pushReplacement(
                              PageRouteBuilder(
                                transitionDuration: const Duration(milliseconds: 500),
                                pageBuilder: (_, __, ___) => const SpotlightScreen(),
                                transitionsBuilder: (_, anim, __, child) =>
                                    FadeTransition(opacity: anim, child: child),
                              ),
                            );
                          },
                          child: const Text(
                            'Skip',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
