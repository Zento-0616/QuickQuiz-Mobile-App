import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks previously generated question stems per document and session to ensure
/// the AI does not repeat questions even when the user generates quizzes multiple times
/// from the exact same study material.
class QuestionHistoryService {
  static final QuestionHistoryService _instance = QuestionHistoryService._internal();
  factory QuestionHistoryService() => _instance;
  QuestionHistoryService._internal();

  static const String _prefPrefix = 'quickquiz_generated_questions_';

  /// In-memory cache of question stems keyed by normalized document identifier.
  final Map<String, Set<String>> _inMemoryStems = {};

  /// Normalizes a document key (e.g. file name + length or hash)
  String _documentKey(String sourceFileName) {
    return sourceFileName.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_\-\.]'), '_');
  }

  /// Normalizes a question stem for deduplication comparison
  static String normalizeStem(String stem) {
    return stem
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .trim();
  }

  /// Retrieves previously generated question stems for this document
  Future<List<String>> getPreviousQuestionStems(String sourceFileName) async {
    final key = _documentKey(sourceFileName);

    if (_inMemoryStems.containsKey(key)) {
      return _inMemoryStems[key]!.toList();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedJson = prefs.getString('$_prefPrefix$key');
      if (storedJson != null) {
        final decoded = jsonDecode(storedJson) as List?;
        if (decoded != null) {
          final stems = decoded.map((e) => e.toString()).toSet();
          _inMemoryStems[key] = stems;
          return stems.toList();
        }
      }
    } catch (e) {
      debugPrint('[QuestionHistoryService] Error loading question history: $e');
    }

    _inMemoryStems[key] = <String>{};
    return [];
  }

  /// Records newly generated question stems to avoid repeating them in future generations
  Future<void> recordGeneratedQuestions(
    String sourceFileName,
    List<String> rawQuestionStems,
  ) async {
    if (rawQuestionStems.isEmpty) return;

    final key = _documentKey(sourceFileName);
    final set = _inMemoryStems[key] ?? <String>{};

    for (final stem in rawQuestionStems) {
      final trimmed = stem.trim();
      if (trimmed.isNotEmpty) {
        set.add(trimmed);
      }
    }

    // Cap history at 100 most recent questions per document to avoid unbounded growth
    final cappedList = set.toList();
    if (cappedList.length > 100) {
      cappedList.removeRange(0, cappedList.length - 100);
    }
    _inMemoryStems[key] = cappedList.toSet();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefPrefix$key', jsonEncode(cappedList));
      debugPrint('[QuestionHistoryService] Recorded ${rawQuestionStems.length} question stems for $key (total tracked: ${cappedList.length})');
    } catch (e) {
      debugPrint('[QuestionHistoryService] Error saving question history: $e');
    }
  }

  /// Checks if a candidate question stem is duplicate or semantically near-identical
  bool isDuplicate(String sourceFileName, String candidateStem) {
    final key = _documentKey(sourceFileName);
    final existing = _inMemoryStems[key];
    if (existing == null || existing.isEmpty) return false;

    final normalizedCandidate = normalizeStem(candidateStem);
    if (normalizedCandidate.isEmpty) return false;

    for (final stem in existing) {
      final normalizedExisting = normalizeStem(stem);
      if (normalizedCandidate == normalizedExisting) return true;

      // Jaccard token overlap for near-identical rephrasing
      if (_hasHighTokenOverlap(candidateStem, stem)) return true;
    }

    return false;
  }

  bool _hasHighTokenOverlap(String a, String b) {
    final wordsA = a.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 3).toSet();
    final wordsB = b.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 3).toSet();
    if (wordsA.isEmpty || wordsB.isEmpty) return false;

    final intersection = wordsA.intersection(wordsB).length;
    final union = wordsA.union(wordsB).length;
    final jaccard = union > 0 ? intersection / union : 0.0;
    return jaccard > 0.80; // 80%+ overlap in significant keywords
  }

  /// Clears stored question history for a given document
  Future<void> clearHistoryForDocument(String sourceFileName) async {
    final key = _documentKey(sourceFileName);
    _inMemoryStems.remove(key);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefPrefix$key');
    } catch (_) {}
  }
}
