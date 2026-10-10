import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quickquiz/models/question_model.dart';
import 'package:quickquiz/models/quiz_settings_model.dart';
import 'package:quickquiz/services/question_bank_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Question Bank Architecture & Schema Tests', () {
    late List<Map<String, dynamic>> rawQuestions;
    late List<QuestionModel> questions;

    setUpAll(() {
      final file = File('assets/data/question_bank.json');
      expect(file.existsSync(), isTrue, reason: 'assets/data/question_bank.json must exist');

      final jsonStr = file.readAsStringSync();
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      rawQuestions = (decoded['questions'] as List<dynamic>).cast<Map<String, dynamic>>();

      questions = rawQuestions.map((q) => QuestionModel.fromJson(q)).toList();
    });

    test('Contains rich pre-generated question pool (at least 50 questions)', () {
      expect(questions.length, greaterThanOrEqualTo(50));
    });

    test('Each question entry includes required metadata: category, difficulty, tags', () {
      for (final q in questions) {
        // Question stem and options
        expect(q.question.trim().isNotEmpty, isTrue);
        expect(q.options.length, equals(4));
        expect(q.correctAnswerIndex, inInclusiveRange(0, 3));
        expect(q.explanation.trim().isNotEmpty, isTrue);

        // Required Metadata attributes per specification:
        // Category
        expect(q.category.trim().isNotEmpty, isTrue, reason: 'Question ${q.id} missing category');
        // Difficulty
        expect(q.difficulty, isNotNull, reason: 'Question ${q.id} missing difficulty');
        // Tags
        expect(q.tags, isNotEmpty, reason: 'Question ${q.id} must have relevant tags');
      }
    });

    test('Covers multiple distinct academic categories', () {
      final categories = questions.map((q) => q.category).toSet();
      expect(categories.length, greaterThanOrEqualTo(4));
      expect(categories, contains('Computer Science'));
      expect(categories, contains('Biology'));
      expect(categories, contains('World History'));
      expect(categories, contains('Physics'));
    });

    test('Covers all 3 difficulty tiers (easy, medium, hard)', () {
      final difficulties = questions.map((q) => q.difficulty).toSet();
      expect(difficulties, contains(QuizDifficulty.easy));
      expect(difficulties, contains(QuizDifficulty.medium));
      expect(difficulties, contains(QuizDifficulty.hard));
    });

    test('QuestionModel JSON serialization preserves metadata attributes', () {
      final original = questions.first;
      final json = original.toJson();

      expect(json['category'], equals(original.category));
      expect(json['difficulty'], equals(original.difficulty.apiValue));
      expect(json['tags'], equals(original.tags));

      final restored = QuestionModel.fromJson(json);
      expect(restored.category, equals(original.category));
      expect(restored.difficulty, equals(original.difficulty));
      expect(restored.tags, equals(original.tags));
    });
  });

  group('QuestionBankService Dynamic Querying Tests', () {
    late QuestionBankService service;

    setUp(() {
      final file = File('assets/data/question_bank.json');
      final jsonStr = file.readAsStringSync();
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final rawQuestions = (decoded['questions'] as List<dynamic>).cast<Map<String, dynamic>>();
      final preloaded = rawQuestions.map((q) => QuestionModel.fromJson(q)).toList();

      service = QuestionBankService(preloadedQuestions: preloaded);
    });

    test('Dynamically filters by category and difficulty without external API calls', () async {
      final result = await service.queryQuestions(
        category: 'Computer Science',
        difficulty: QuizDifficulty.easy,
        count: 5,
      );

      expect(result.length, equals(5));
      for (final q in result) {
        expect(q.difficulty, equals(QuizDifficulty.easy));
        expect(q.category, equals('Computer Science'));
      }
    });

    test('Supports querying with "All" category', () async {
      final result = await service.queryQuestions(
        category: 'All',
        difficulty: QuizDifficulty.medium,
        count: 10,
      );

      expect(result.length, equals(10));
      for (final q in result) {
        expect(q.difficulty, equals(QuizDifficulty.medium));
      }
    });

    test('Fulfills large question count slider value (up to 50 questions)', () async {
      final result = await service.queryQuestions(
        category: 'All',
        count: 50,
      );

      expect(result.length, equals(50));
    });

    test('Gracefully backfills if specific category has fewer than requested count', () async {
      // Biology only has ~10 questions in bank; requesting 20 will backfill
      final result = await service.queryQuestions(
        category: 'Biology',
        count: 20,
      );

      expect(result.length, equals(20));
      // Primary matches should be Biology
      final biologyCount = result.where((q) => q.category == 'Biology').length;
      expect(biologyCount, greaterThanOrEqualTo(5));
    });

    test('getCategories returns distinct category list starting with All', () async {
      final categories = await service.getCategories();
      expect(categories, isNotEmpty);
      expect(categories.first, equals('All'));
      expect(categories.contains('Computer Science'), isTrue);
    });
  });
}
