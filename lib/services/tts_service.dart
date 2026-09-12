import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/news_article.dart';
import '../repositories/news_article_repository.dart';
import '../state/app_state.dart';

/// Global, robust Text-To-Speech service for the Varadhi app.
/// Ensures consistent behavior across Spotlight (Main/Local feed) and Full Article screen.
/// - Splits long text into natural sentence-sized chunks (300-400 chars) to prevent cutoffs.
/// - Smooth continuous sequential playback with automated recovery.
/// - Dynamic playback speed control (1.0x, 1.25x, 1.5x).
class AppTtsService extends ChangeNotifier {
  AppTtsService._internal() {
    _initTts();
  }
  static final AppTtsService instance = AppTtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();

  bool _isPlaying = false;
  bool _isLoading = false;
  String? _currentArticleId;

  List<String> _chunks = [];
  int _currentChunkIndex = 0;
  bool _isDisposed = false;

  // Speed Control (1.0x, 1.25x, 1.5x)
  double _playbackSpeed = 1.0;
  double get playbackSpeed => _playbackSpeed;
  String get playbackSpeedText => '${_playbackSpeed}x';

  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String? get currentArticleId => _currentArticleId;
  int get currentChunkIndex => _currentChunkIndex;
  int get totalChunks => _chunks.length;
  double get progress => _chunks.isNotEmpty ? (_currentChunkIndex + 1) / _chunks.length : 0.0;

  bool isArticlePlaying(String articleId) => _isPlaying && _currentArticleId == articleId;
  bool isArticleLoading(String articleId) => _isLoading && _currentArticleId == articleId;

  void _initTts() async {
    try {
      await _flutterTts.awaitSpeakCompletion(true);
    } catch (_) {}

    _flutterTts.setCompletionHandler(() {
      _onChunkComplete();
    });

    _flutterTts.setErrorHandler((dynamic msg) {
      debugPrint('TTS Error on chunk $_currentChunkIndex: $msg');
      // If a specific chunk encounters a playback glitch, auto-recover by advancing to the next chunk
      _skipToNextChunkOrStop();
    });

    _flutterTts.setCancelHandler(() {
      _stopInternal();
    });
  }

  double _getTtsSpeechRate(double speed) {
    if (speed >= 1.5) return 0.70;
    if (speed >= 1.25) return 0.60;
    return 0.50; // 1.0x baseline human speech rate
  }

  Future<void> cycleSpeed() async {
    if (_playbackSpeed == 1.0) {
      await setSpeed(1.25);
    } else if (_playbackSpeed == 1.25) {
      await setSpeed(1.5);
    } else {
      await setSpeed(1.0);
    }
  }

  Future<void> setSpeed(double speed) async {
    _playbackSpeed = speed;
    final rate = _getTtsSpeechRate(speed);
    try {
      await _flutterTts.setSpeechRate(rate);
    } catch (_) {}
    notifyListeners();
  }

  void _onChunkComplete() async {
    if (_isDisposed || !_isPlaying) return;

    if (_currentChunkIndex + 1 < _chunks.length) {
      _currentChunkIndex++;
      final nextChunk = _chunks[_currentChunkIndex];
      debugPrint('TTS: Smooth playback chunk ${_currentChunkIndex + 1}/${_chunks.length}');
      notifyListeners();
      await _flutterTts.speak(nextChunk);
    } else {
      debugPrint('TTS: Completed full playback of all ${_chunks.length} chunks.');
      _stopInternal();
    }
  }

  void _skipToNextChunkOrStop() async {
    if (_isDisposed || !_isPlaying) return;

    if (_currentChunkIndex + 1 < _chunks.length) {
      _currentChunkIndex++;
      final nextChunk = _chunks[_currentChunkIndex];
      debugPrint('TTS: Auto-recovering, advancing to chunk ${_currentChunkIndex + 1}/${_chunks.length}');
      notifyListeners();
      await _flutterTts.speak(nextChunk);
    } else {
      _stopInternal();
    }
  }

  void _stopInternal() {
    _isPlaying = false;
    _isLoading = false;
    _currentArticleId = null;
    _chunks = [];
    _currentChunkIndex = 0;
    notifyListeners();
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
    _stopInternal();
  }

  /// Toggles speech for an article.
  /// If the current article is already playing, stops it.
  /// Otherwise, fetches the FULL article content if needed, chunks it, and starts speaking.
  Future<void> toggleArticleTts(NewsArticle article, {String? language}) async {
    final articleId = article.id.isNotEmpty ? article.id : article.slug;
    if (articleId.isEmpty) return;

    // 1. If currently playing this same article, stop
    if (_isPlaying && _currentArticleId == articleId) {
      await stop();
      return;
    }

    // 2. Stop any previous audio
    await stop();

    // 3. Mark as loading
    _currentArticleId = articleId;
    _isLoading = true;
    notifyListeners();

    try {
      // 4. RULE: ALWAYS fetch FULL content. Never use trimmed preview.
      String fullContent = article.body.trim();

      if (fullContent.isEmpty || fullContent.length < 60) {
        final slugToFetch = article.slug.isNotEmpty ? article.slug : article.id;
        try {
          final fullArticle = await NewsArticleRepository.instance.getDetail(slugToFetch);
          if (fullArticle.body.trim().isNotEmpty) {
            fullContent = fullArticle.body.trim();
          }
        } catch (e) {
          debugPrint('TTS: Could not fetch detail API for $slugToFetch: $e');
        }
      }

      // Fallback if detail API returned empty
      if (fullContent.isEmpty) {
        fullContent = article.summary.trim();
      }
      if (fullContent.isEmpty) {
        fullContent = article.title;
      }

      // Combine Title and Full Body
      final String fullTextToSpeak = "${article.title}.\n\n$fullContent";

      // 5. Configure Language
      String lang = (language ?? AppState.instance.language).toLowerCase();
      String languageCode = 'en-US';
      if (lang.contains('telugu')) {
        languageCode = 'te-IN';
      } else if (lang.contains('tamil')) {
        languageCode = 'ta-IN';
      } else if (lang.contains('kannada')) {
        languageCode = 'kn-IN';
      } else if (lang.contains('malayalam')) {
        languageCode = 'ml-IN';
      } else if (lang.contains('hindi')) {
        languageCode = 'hi-IN';
      } else if (lang.contains('marathi')) {
        languageCode = 'mr-IN';
      } else if (lang.contains('bengali')) {
        languageCode = 'bn-IN';
      } else if (lang.contains('gujarati')) {
        languageCode = 'gu-IN';
      }

      await _flutterTts.setLanguage(languageCode);
      await _flutterTts.setPitch(1.05);
      await _flutterTts.setSpeechRate(_getTtsSpeechRate(_playbackSpeed));

      // 6. Split into sentence-safe chunks (optimal 350-450 chars) to prevent Android/iOS TTS cutoff
      _chunks = _splitIntoChunks(fullTextToSpeak, maxChunkSize: 380);
      _currentChunkIndex = 0;

      if (_chunks.isEmpty) {
        _stopInternal();
        return;
      }

      // 7. Start playback
      _isLoading = false;
      _isPlaying = true;
      notifyListeners();

      debugPrint('TTS: Starting playback (${_chunks.length} chunks at ${_playbackSpeed}x) for "$articleId"');
      await _flutterTts.speak(_chunks[0]);
    } catch (e) {
      debugPrint('TTS execution error: $e');
      _stopInternal();
    }
  }

  /// Splits long text into natural sentence chunks around punctuation so audio never cuts off
  List<String> _splitIntoChunks(String text, {int maxChunkSize = 380}) {
    if (text.trim().isEmpty) return [];
    if (text.length <= maxChunkSize) {
      return [text.trim()];
    }

    final List<String> chunks = [];
    int start = 0;

    // Clean excessive spaces while preserving newlines
    final cleanText = text.replaceAll(RegExp(r'[ \t]+'), ' ');

    while (start < cleanText.length) {
      int end = (start + maxChunkSize).clamp(0, cleanText.length);

      if (end < cleanText.length) {
        // Look backwards for sentence delimiters (. ! ? \n | ।)
        int lastSentenceBreak = cleanText.lastIndexOf(RegExp(r'[\n.!?।]\s*'), end);
        if (lastSentenceBreak > start + (maxChunkSize ~/ 3)) {
          end = lastSentenceBreak + 1;
        } else {
          // Look backwards for secondary clause delimiters (, ; : -)
          int lastClauseBreak = cleanText.lastIndexOf(RegExp(r'[,;:\-]\s*'), end);
          if (lastClauseBreak > start + (maxChunkSize ~/ 2)) {
            end = lastClauseBreak + 1;
          } else {
            // Fallback to word boundary space
            int lastSpace = cleanText.lastIndexOf(' ', end);
            if (lastSpace > start + (maxChunkSize ~/ 2)) {
              end = lastSpace;
            }
          }
        }
      }

      final chunk = cleanText.substring(start, end).trim();
      if (chunk.isNotEmpty) {
        chunks.add(chunk);
      }
      start = end;
      // Skip leading whitespace for next chunk
      while (start < cleanText.length && (cleanText[start] == ' ' || cleanText[start] == '\n')) {
        start++;
      }
    }

    return chunks;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _flutterTts.stop();
    super.dispose();
  }
}
