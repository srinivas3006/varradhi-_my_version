import 'package:flutter/foundation.dart';
import '../services/tts_service.dart';

/// Centralized coordinator enforcing mutually exclusive media playback:
/// - Only 1 video OR 1 TTS session can be active across the entire app/feed.
/// - Automatically pauses video when TTS starts, and stops TTS when video starts.
/// - Coordinates instant media suspension on swiping, app backgrounding, and navigation.
class SpotlightMediaCoordinator extends ChangeNotifier {
  static final SpotlightMediaCoordinator instance = SpotlightMediaCoordinator._internal();
  SpotlightMediaCoordinator._internal();

  String? _activeVideoArticleId;
  String? _activeTtsArticleId;

  String? get activeVideoArticleId => _activeVideoArticleId;
  String? get activeTtsArticleId => _activeTtsArticleId;
  bool get hasActiveMedia => _activeVideoArticleId != null || _activeTtsArticleId != null;

  /// Called when an inline or card video starts playing.
  void notifyVideoStarted(String articleId) {
    if (_activeTtsArticleId != null) {
      AppTtsService.instance.stop();
      _activeTtsArticleId = null;
    }
    _activeVideoArticleId = articleId;
    notifyListeners();
  }

  /// Called when video playback completes, pauses, or gets disposed.
  void notifyVideoStopped(String articleId) {
    if (_activeVideoArticleId == articleId) {
      _activeVideoArticleId = null;
      notifyListeners();
    }
  }

  /// Called when Text-To-Speech starts for an article.
  void notifyTtsStarted(String articleId) {
    if (_activeVideoArticleId != null) {
      _activeVideoArticleId = null;
    }
    _activeTtsArticleId = articleId;
    notifyListeners();
  }

  /// Called when TTS completes, cancels, or stops.
  void notifyTtsStopped() {
    _activeTtsArticleId = null;
    notifyListeners();
  }

  /// Stops all active audio and video instances simultaneously.
  void stopAll() {
    AppTtsService.instance.stop();
    _activeTtsArticleId = null;
    _activeVideoArticleId = null;
    notifyListeners();
  }
}
