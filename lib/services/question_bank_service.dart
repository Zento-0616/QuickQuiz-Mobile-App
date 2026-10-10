import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import '../models/question_model.dart';
import '../models/quiz_settings_model.dart';

class QuestionBankService {
  static const String defaultAssetPath = 'assets/data/question_bank.json';

  final String assetPath;
  List<QuestionModel>? _cachedQuestions;
  final Random _rng;

  QuestionBankService({
    this.assetPath = defaultAssetPath,
    Random? rng,
    List<QuestionModel>? preloadedQuestions,
  })  : _rng = rng ?? Random(),
        _cachedQuestions = preloadedQuestions;

  Future<List<QuestionModel>> loadQuestions() async {
    if (_cachedQuestions != null) {
      return _cachedQuestions!;
    }

    try {
      final jsonString = await rootBundle.loadString(assetPath);
      final dynamic decoded = jsonDecode(jsonString);

      final List<dynamic> rawQuestions = decoded is Map<String, dynamic>
          ? (decoded['questions'] as List<dynamic>? ?? [])
          : (decoded as List<dynamic>);

      _cachedQuestions = rawQuestions
          .map((item) => QuestionModel.fromJson(item as Map<String, dynamic>).randomizeAnswers(rng: _rng))
          .toList();

      return _cachedQuestions!;
    } catch (e) {
      return [];
    }
  }

  Future<List<String>> getCategories() async {
    final questions = await loadQuestions();
    final categories = <String>{'All'};
    for (final q in questions) {
      if (q.category.trim().isNotEmpty) {
        categories.add(q.category.trim());
      }
    }
    return categories.toList();
  }

  Future<List<String>> getAllTags() async {
    final questions = await loadQuestions();
    final tags = <String>{};
    for (final q in questions) {
      tags.addAll(q.tags);
    }
    return tags.toList();
  }

  Future<List<QuestionModel>> queryQuestions({
    String? category,
    QuizDifficulty? difficulty,
    List<String>? tags,
    required int count,
  }) async {
    final allQuestions = await loadQuestions();
    if (allQuestions.isEmpty) {
      return [];
    }

    final primaryMatches = allQuestions.where((q) {
      final matchesCategory = category == null ||
          category.isEmpty ||
          category.toLowerCase() == 'all' ||
          category.toLowerCase() == 'all categories' ||
          q.category.toLowerCase() == category.toLowerCase();

      final matchesDifficulty = difficulty == null || q.difficulty == difficulty;

      final matchesTags = tags == null ||
          tags.isEmpty ||
          q.tags.any((t) => tags.contains(t));

      return matchesCategory && matchesDifficulty && matchesTags;
    }).toList();

    primaryMatches.shuffle(_rng);

    if (primaryMatches.length >= count) {
      return primaryMatches.take(count).map((q) => q.randomizeAnswers(rng: _rng)).toList();
    }

    final result = List<QuestionModel>.from(primaryMatches);
    final usedIds = result.map((q) => q.id ?? q.question).toSet();

    if (difficulty != null) {
      final sameDifficultyPool = allQuestions
          .where((q) =>
              q.difficulty == difficulty && !usedIds.contains(q.id ?? q.question))
          .toList()
        ..shuffle(_rng);

      for (final q in sameDifficultyPool) {
        if (result.length >= count) break;
        result.add(q);
        usedIds.add(q.id ?? q.question);
      }
    }

    if (result.length < count) {
      final remainingPool = allQuestions
          .where((q) => !usedIds.contains(q.id ?? q.question))
          .toList()
        ..shuffle(_rng);

      for (final q in remainingPool) {
        if (result.length >= count) break;
        result.add(q);
        usedIds.add(q.id ?? q.question);
      }
    }

    var cycleIndex = 0;
    while (result.length < count && allQuestions.isNotEmpty) {
      final source = allQuestions[cycleIndex % allQuestions.length];
      result.add(source.copyWith(
        id: '${source.id ?? "q"}_copy_${result.length}',
      ));
      cycleIndex++;
    }

    return result.take(count).map((q) => q.randomizeAnswers(rng: _rng)).toList();
  }
}
