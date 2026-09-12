import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ugc_draft.dart';

/// Repository for persisting and recovering UGC drafts across app launches.
class UgcDraftRepository {
  static const String _draftKey = 'vaaradhi_ugc_pending_draft_v1';

  final SharedPreferences? _prefs;

  UgcDraftRepository({SharedPreferences? prefs}) : _prefs = prefs;

  static final UgcDraftRepository instance = UgcDraftRepository();

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  /// Saves or updates the active draft in local storage.
  Future<void> saveDraft(UgcDraft draft) async {
    try {
      final prefs = await _getPrefs();
      final jsonStr = jsonEncode(draft.toJson());
      await prefs.setString(_draftKey, jsonStr);
    } catch (e) {
      debugPrint('[UgcDraftRepository] Failed to save draft: $e');
    }
  }

  /// Loads the pending draft if present. Returns null if no draft exists.
  Future<UgcDraft?> loadDraft() async {
    try {
      final prefs = await _getPrefs();
      final jsonStr = prefs.getString(_draftKey);
      if (jsonStr == null || jsonStr.trim().isEmpty) return null;

      final Map<String, dynamic> data = jsonDecode(jsonStr);
      return UgcDraft.fromJson(data);
    } catch (e) {
      debugPrint('[UgcDraftRepository] Failed to load draft: $e');
      return null;
    }
  }

  /// Clears the pending draft upon successful upload or user discard.
  Future<void> clearDraft() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_draftKey);
    } catch (e) {
      debugPrint('[UgcDraftRepository] Failed to clear draft: $e');
    }
  }

  /// Checks whether a pending draft exists.
  Future<bool> hasDraft() async {
    try {
      final prefs = await _getPrefs();
      return prefs.containsKey(_draftKey);
    } catch (_) {
      return false;
    }
  }
}
