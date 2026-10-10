import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickquiz/models/question_model.dart';
import 'package:quickquiz/models/quiz_model.dart';
import 'package:quickquiz/models/quiz_settings_model.dart';
import 'package:quickquiz/services/question_bank_service.dart';

void main() {
  group('1. QuizModel Global and Unlimited Features', () {
    test('QuizModel defaults isGlobal to true and isUnlimitedPlay to false', () {
      final quiz = QuizModel(
        sourceFileName: 'Test Deck',
        difficulty: QuizDifficulty.easy,
        questions: const [],
      );

      expect(quiz.isGlobal, isTrue);
      expect(quiz.isUnlimitedPlay, isFalse);
    });

    test('QuizModel preserves isGlobal and isUnlimitedPlay through serialization', () {
      final quiz = QuizModel(
        title: 'Unlimited Physics',
        sourceFileName: 'physics.pdf',
        difficulty: QuizDifficulty.hard,
        questions: const [],
        isGlobal: false,
        isUnlimitedPlay: true,
      );

      final json = quiz.toJson();
      expect(json['isGlobal'], isFalse);
      expect(json['isUnlimitedPlay'], isTrue);

      final restored = QuizModel.fromJson(json);
      expect(restored.isGlobal, isFalse);
      expect(restored.isUnlimitedPlay, isTrue);
    });

    test('QuizModel copyWith allows updating isGlobal and isUnlimitedPlay', () {
      final quiz = QuizModel(
        sourceFileName: 'Test Deck',
        difficulty: QuizDifficulty.medium,
        questions: const [],
      );

      final modified = quiz.copyWith(
        isGlobal: false,
        isUnlimitedPlay: true,
      );

      expect(modified.isGlobal, isFalse);
      expect(modified.isUnlimitedPlay, isTrue);
    });
  });

  group('2. MCQ Answer Randomization Tests (A, B, C, D)', () {
    test('randomizeAnswers distributes correct answers across all positions (0, 1, 2, 3)', () {
      final baseQuestion = QuestionModel(
        question: 'What is the speed of light in vacuum?',
        options: [
          '299,792 km/s', // Correct answer
          '150,000 km/s',
          '384,400 km/s',
          '1,080 km/h',
        ],
        correctAnswerIndex: 0,
        explanation: 'The speed of light in vacuum is approximately 299,792 km/s.',
      );

      final observedPositions = <int>{};
      final rng = Random(42);

      for (int i = 0; i < 50; i++) {
        final randomized = baseQuestion.randomizeAnswers(rng: rng);

        // Verify the correct answer string remains accurate at the new index
        expect(
          randomized.options[randomized.correctAnswerIndex],
          equals('299,792 km/s'),
        );
        expect(randomized.options.length, equals(4));

        observedPositions.add(randomized.correctAnswerIndex);
      }

      // Over 50 iterations, positions 0 (A), 1 (B), 2 (C), and 3 (D) must all be hit
      expect(observedPositions, containsAll([0, 1, 2, 3]));
      expect(observedPositions.length, equals(4));
    });

    test('QuestionBankService queries return randomized answer positions', () async {
      final preloaded = [
        QuestionModel(
          id: 'q1',
          question: 'Question 1',
          options: ['Option A (Correct)', 'Wrong 1', 'Wrong 2', 'Wrong 3'],
          correctAnswerIndex: 0,
          explanation: 'Exp 1',
          category: 'Science',
          difficulty: QuizDifficulty.easy,
        ),
        QuestionModel(
          id: 'q2',
          question: 'Question 2',
          options: ['Option A (Correct)', 'Wrong 1', 'Wrong 2', 'Wrong 3'],
          correctAnswerIndex: 0,
          explanation: 'Exp 2',
          category: 'Science',
          difficulty: QuizDifficulty.easy,
        ),
        QuestionModel(
          id: 'q3',
          question: 'Question 3',
          options: ['Option A (Correct)', 'Wrong 1', 'Wrong 2', 'Wrong 3'],
          correctAnswerIndex: 0,
          explanation: 'Exp 3',
          category: 'Science',
          difficulty: QuizDifficulty.easy,
        ),
        QuestionModel(
          id: 'q4',
          question: 'Question 4',
          options: ['Option A (Correct)', 'Wrong 1', 'Wrong 2', 'Wrong 3'],
          correctAnswerIndex: 0,
          explanation: 'Exp 4',
          category: 'Science',
          difficulty: QuizDifficulty.easy,
        ),
      ];

      final service = QuestionBankService(
        preloadedQuestions: preloaded,
        rng: Random(123),
      );

      final queried = await service.queryQuestions(count: 4);
      expect(queried.length, equals(4));

      // Check that not all queried questions have correctAnswerIndex == 0
      final nonZeroPositions = queried.where((q) => q.correctAnswerIndex != 0).toList();
      expect(nonZeroPositions.isNotEmpty, isTrue);

      // Verify that every question still has the correct answer pointing to Option A (Correct)
      for (final q in queried) {
        expect(q.options[q.correctAnswerIndex], equals('Option A (Correct)'));
      }
    });
  });
}
