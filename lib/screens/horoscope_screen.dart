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
    {'name': 'మేషం', 'symbol': '♈'},
    {'name': 'వృషభం', 'symbol': '♉'},
    {'name': 'మిథునం', 'symbol': '♊'},
    {'name': 'కర్కాటకం', 'symbol': '♋'},
    {'name': 'సింహం', 'symbol': '♌'},
    {'name': 'కన్య', 'symbol': '♍'},
    {'name': 'తుల', 'symbol': '♎'},
    {'name': 'వృశ్చికం', 'symbol': '♏'},
    {'name': 'ధనుస్సు', 'symbol': '♐'},
    {'name': 'మకరం', 'symbol': '♑'},
    {'name': 'కుంభం', 'symbol': '♒'},
    {'name': 'మీనం', 'symbol': '♓'},
  ];

  int _selected = 0;

  static const _readings = <String>[];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('నేటి రాశి ఫలాలు')),
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
                    const Text('నేటి రాశి భవిష్యత్తు',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(height: 16),
                    Text(
                      _selected < _readings.length 
                          ? _readings[_selected] 
                          : 'నేటి రాశి ఫలాలు మరియు జ్యోతిష్య అంచనాలు రూపొందించబడుతున్నాయి. దిన ఫలాలు ఉదయపు ఎడిషన్‌తో పాటు నిరంతరం నవీకరించబడతాయి.',
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
