import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'poster_detail_screen.dart';

/// Screen 18: PostersScreen
/// - APIs: GET /api/v1/posters/?category=...
/// - Destination: PosterDetailScreen
class PostersScreen extends StatefulWidget {
  const PostersScreen({super.key});

  @override
  State<PostersScreen> createState() => _PostersScreenState();
}

class _PostersScreenState extends State<PostersScreen> {
  static const List<Map<String, String>> _categories = [
    {'slug': 'good_morning', 'name': 'Good Morning'},
    {'slug': 'devotional', 'name': 'Devotional'},
    {'slug': 'festival', 'name': 'Festival'},
    {'slug': 'motivational', 'name': 'Motivational'},
    {'slug': 'love', 'name': 'Love'},
    {'slug': 'special_day', 'name': 'Special Day'},
    {'slug': 'daily_quote', 'name': 'Quotes'},
    {'slug': 'health_tip', 'name': 'Health Tips'},
  ];

  String _selectedCategory = 'good_morning';
  List<dynamic> _posters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPosters();
  }

  Future<void> _fetchPosters() async {
    setState(() => _isLoading = true);
    final results = await ApiService.instance.getPosters(category: _selectedCategory);
    if (mounted) {
      setState(() {
        _posters = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Posters & Greetings'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Category horizontal chip bar
          Container(
            height: 44,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = cat['slug'] == _selectedCategory;

                return GestureDetector(
                  onTap: () {
                    if (isSelected) return;
                    setState(() => _selectedCategory = cat['slug']!);
                    _fetchPosters();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : (isDark ? Colors.white12 : Colors.black12),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        cat['name']!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Posters Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _posters.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.photo_library_outlined, size: 56, color: isDark ? Colors.white24 : Colors.black26),
                            const SizedBox(height: 12),
                            const Text(
                              'No posters in this category yet',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchPosters,
                        color: AppColors.primary,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.72,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: _posters.length,
                          itemBuilder: (context, index) {
                            final poster = _posters[index] as Map<String, dynamic>;
                            final imageUrl = poster['image_url'] ?? poster['thumbnail_url'] ?? '';
                            final title = poster['title'] ?? 'Greeting';

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PosterDetailScreen(poster: poster),
                                  ),
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(
                                        color: isDark ? Colors.white10 : Colors.black12,
                                      ),
                                      errorWidget: (_, __, ___) => Container(
                                        color: isDark ? Colors.white10 : Colors.black12,
                                        child: const Icon(Icons.broken_image_rounded),
                                      ),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withValues(alpha: 0.7),
                                          ],
                                          stops: const [0.6, 1.0],
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 10,
                                      left: 10,
                                      right: 10,
                                      child: Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
