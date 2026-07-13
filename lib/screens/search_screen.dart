import 'package:flutter/material.dart';
import '../data/mock_news.dart';
import '../localization/app_translations.dart';
import '../models/news_article.dart';
import '../theme/app_theme.dart';
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
  final List<String> _recent = ['ISRO satellite', 'Sensex', 'Metro phase 2'];

  static const _trending = [
    'Cricket series',
    'AI chipset',
    'Box office',
    'Monsoon alert',
    'Sensex record',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _runSearch(String query) {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() {
      _results = mockArticles
          .where((a) =>
              a.title.toLowerCase().contains(query.toLowerCase()) ||
              a.summary.toLowerCase().contains(query.toLowerCase()) ||
              a.category.toLowerCase().contains(query.toLowerCase()))
          .toList();
      if (!_recent.contains(query)) {
        _recent.insert(0, query);
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
            onChanged: _runSearch,
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
    if (_results.isEmpty) {
      return Center(
        child: Text(tr('no_results'), style: const TextStyle(color: AppColors.textMuted)),
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
            child: Image.network(article.imageUrl,
                width: 56, height: 56, fit: BoxFit.cover),
          ),
          title: Text(article.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
          subtitle: Text('${article.source} · ${article.timeAgo}',
              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => NewsDetailScreen(article: article)),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
