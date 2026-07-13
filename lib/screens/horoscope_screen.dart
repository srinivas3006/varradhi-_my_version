import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/ads/banner_ad_slot.dart';

class HoroscopeScreen extends StatefulWidget {
  const HoroscopeScreen({super.key});

  @override
  State<HoroscopeScreen> createState() => _HoroscopeScreenState();
}

class _HoroscopeScreenState extends State<HoroscopeScreen> {
  static const _signs = [
    {'name': 'Aries', 'symbol': '♈'},
    {'name': 'Taurus', 'symbol': '♉'},
    {'name': 'Gemini', 'symbol': '♊'},
    {'name': 'Cancer', 'symbol': '♋'},
    {'name': 'Leo', 'symbol': '♌'},
    {'name': 'Virgo', 'symbol': '♍'},
    {'name': 'Libra', 'symbol': '♎'},
    {'name': 'Scorpio', 'symbol': '♏'},
    {'name': 'Sagittarius', 'symbol': '♐'},
    {'name': 'Capricorn', 'symbol': '♑'},
    {'name': 'Aquarius', 'symbol': '♒'},
    {'name': 'Pisces', 'symbol': '♓'},
  ];

  int _selected = 0;

  static const _readings = [
    'A promising day for new beginnings. Trust your instincts on a financial decision.',
    'Focus on relationships today — a small gesture goes a long way with loved ones.',
    'Your communication skills shine. A good day to negotiate or pitch an idea.',
    'Take time for self-care. Emotional clarity comes after a quiet moment alone.',
    'Leadership opportunities arise at work. Step up, but stay open to feedback.',
    'Small details matter today. Double-check important documents before signing.',
    'Balance is key — don\'t let work overshadow personal time this evening.',
    'An intense but rewarding day. Trust the process on a long-term goal.',
    'Travel or learning something new brings unexpected joy today.',
    'Discipline pays off. A pending task finally moves forward.',
    'Innovative thinking helps solve a nagging problem at work or home.',
    'Intuition is heightened. Listen to your gut on a decision you\'ve been avoiding.',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Daily Horoscope')),
      body: Column(
        children: [
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _signs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final isSelected = index == _selected;
                return GestureDetector(
                  onTap: () => setState(() => _selected = index),
                  child: Container(
                    width: 64,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2)),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_signs[index]['symbol']!,
                            style: TextStyle(
                                fontSize: 22,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textDark)),
                        const SizedBox(height: 4),
                        Text(_signs[index]['name']!,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textMuted)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _signs[_selected]['name']!,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark),
                    ),
                    const SizedBox(height: 4),
                    const Text('Today\'s reading',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(height: 16),
                    Text(
                      _readings[_selected],
                      style: const TextStyle(
                          fontSize: 15, height: 1.6, color: Color(0xFF2E2E2E)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const BannerAdSlot(),
        ],
      ),
    );
  }
}
