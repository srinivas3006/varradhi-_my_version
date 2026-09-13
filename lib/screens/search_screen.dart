import 'dart:async';
import 'package:flutter/material.dart';
import '../localization/app_translations.dart';
import '../models/news_article.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'news_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<NewsArticle> _results = [];
  final List<String> _recent = ['ఇస్రో ఉపగ్రహం', 'సెన్సెక్స్', 'మెట్రో ఫేజ్ 2'];

  List<String> _trending = [
    'క్రికెట్ సిరీస్',
    'ఏఐ చిప్‌సెట్',
    'బాక్సాఫీస్',
    'వర్షపాతం హెచ్చరిక',
    'సెన్సెక్స్ రికార్డ్',
  ];

  @override
  void initState() {
    super.initState();
    _loadTrending();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  Future<void> _loadTrending() async {
    try {
      final terms = await ApiService.instance.getTrendingSearchKeywords();
      if (mounted && terms.isNotEmpty) {
        setState(() => _trending = terms);
      }
    } catch (_) {
      // Keep curated defaults
    }
  }

  bool _isLoading = false;
  Timer? _debounce;

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _runSearch(query));
  }

  void _runSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _isLoading = true);

    final response = await ApiService.instance.searchArticles(trimmed);

    if (!mounted) return;

    setState(() {
      _results = response.data ?? [];
      _isLoading = false;
      if (!_recent.contains(trimmed)) {
        _recent.insert(0, trimmed);
        if (_recent.length > 6) _recent.removeLast();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        title: Container(
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.chipBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            onSubmitted: _runSearch,
            onChanged: (value) {
              setState(() {});
              _onQueryChanged(value);
            },
            decoration: InputDecoration(
              hintText: tr('search_hint'),
              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13.5),
              prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('cancel'),
                style: const TextStyle(color: AppColors.textDark)),
          ),
        ],
      ),
      body: _controller.text.isEmpty
          ? _buildSuggestions()
          : _isLoading 
              ? const Center(child: CircularProgressIndicator()) 
              : _buildResults(),
    );
  }

  Widget _buildSuggestions() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_recent.isNotEmpty) ...[
          Text(tr('recent_searches'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 10),
          ..._recent.map((q) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history, color: AppColors.textMuted),
                title: Text(q, style: const TextStyle(fontSize: 13.5)),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                  onPressed: () => setState(() => _recent.remove(q)),
                ),
                onTap: () {
                  _controller.text = q;
                  _runSearch(q);
                },
              )),
          const SizedBox(height: 12),
        ],
        Text(tr('trending_searches'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _trending
              .map((t) => GestureDetector(
                    onTap: () {
                      _controller.text = t;
                      _runSearch(t);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.chipBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(t, style: const TextStyle(fontSize: 12.5)),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildResults() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 56, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 12),
            Text(tr('no_results'), style: const TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final article = _results[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: article.imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: article.imageUrl,
                    width: 56,
                    height: 56,
                    memCacheWidth: 150,
                    memCacheHeight: 150,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 56,
                      height: 56,
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 56,
                      height: 56,
                      color: isDark ? Colors.white10 : Colors.black12,
                      child: const Icon(Icons.broken_image_rounded, size: 20),
                    ),
                  )
                : Container(
                    width: 56,
                    height: 56,
                    color: isDark ? Colors.white10 : Colors.black12,
                    child: const Icon(Icons.newspaper_rounded, size: 20),
                  ),
          ),
          title: Text(article.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
          subtitle: Text('${article.source} · ${article.timeAgo}',
              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => NewsDetailScreen(article: article, slug: article.slug)),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
