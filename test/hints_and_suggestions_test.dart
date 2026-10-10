import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickquiz/models/question_model.dart';
import 'package:quickquiz/models/quiz_model.dart';
import 'package:quickquiz/models/quiz_result_model.dart';
import 'package:quickquiz/models/quiz_settings_model.dart';
import 'package:quickquiz/views/quiz/quiz_view.dart';
import 'package:quickquiz/services/ad_service.dart';
import 'package:provider/provider.dart';

void main() {
  group('MCQ Hints & Study Suggestions Tests', () {
    test('QuestionModel stores, serializes, and provides effectiveHint fallback', () {
      const qWithHint = QuestionModel(
        question: 'What is HTTPS?',
        options: ['Secure HTTP', 'Hypertext Test', 'Host Protocol', 'None'],
        correctAnswerIndex: 0,
        explanation: 'HTTPS encrypts communication over networks.',
        hint: 'Think of secure network transport.',
        difficulty: QuizDifficulty.easy,
      );

      expect(qWithHint.hint, 'Think of secure network transport.');
      expect(qWithHint.effectiveHint, 'Think of secure network transport.');

      final json = qWithHint.toJson();
      expect(json['hint'], 'Think of secure network transport.');

      final parsed = QuestionModel.fromJson(json);
      expect(parsed.hint, 'Think of secure network transport.');
      expect(parsed.effectiveHint, 'Think of secure network transport.');

      // Question without explicit hint should derive a smart fallback clue
      const qWithoutHint = QuestionModel(
        question: 'What is CPU?',
        options: ['Central Processing Unit', 'Central Power', 'Core Plug', 'None'],
        correctAnswerIndex: 0,
        explanation: 'The processor executes programmatic instructions.',
        category: 'Hardware',
        difficulty: QuizDifficulty.medium,
      );

      expect(qWithoutHint.hint, isNull);
      expect(qWithoutHint.effectiveHint, isNotEmpty);
      expect(qWithoutHint.effectiveHint, contains('The processor executes'));
    });

    test('QuizResultModel generates exam tricks and study suggestions based on performance', () {
      final quizLowScore = QuizModel(
        id: 'quiz_low',
        sourceFileName: 'biology_notes.pdf',
        difficulty: QuizDifficulty.medium,
        questions: const [
          QuestionModel(
            question: 'Q1',
            options: ['A', 'B', 'C', 'D'],
            correctAnswerIndex: 0,
            selectedAnswerIndex: 1, // Wrong
            explanation: 'Exp 1',
          ),
          QuestionModel(
            question: 'Q2',
            options: ['A', 'B', 'C', 'D'],
            correctAnswerIndex: 2,
            selectedAnswerIndex: 2, // Correct
            explanation: 'Exp 2',
          ),
          QuestionModel(
            question: 'Q3',
            options: ['A', 'B', 'C', 'D'],
            correctAnswerIndex: 3,
            selectedAnswerIndex: 0, // Wrong
            explanation: 'Exp 3',
          ),
        ],
      );

      final resultLow = QuizResultModel.fromQuiz(quizLowScore);
      expect(resultLow.correctCount, 1);
      expect(resultLow.suggestions, isNotEmpty);
      // Low score should include elimination trick and active recall study tip
      expect(
        resultLow.suggestions.any((s) => s.toLowerCase().contains('elimination')),
        isTrue,
      );
      expect(
        resultLow.suggestions.any((s) => s.toLowerCase().contains('active recall')),
        isTrue,
      );

      // Verify JSON roundtrip preserves suggestions
      final json = resultLow.toJson();
      expect(json['suggestions'], isA<List>());
      final restored = QuizResultModel.fromJson(json);
      expect(restored.suggestions.length, resultLow.suggestions.length);
    });

    test('Logo asset files exist in both assets/icons and assets/icon', () {
      final iconsFile = File('assets/icons/quickquiz_logo.png');
      final iconFile = File('assets/icon/quickquiz_logo.png');
      expect(iconsFile.existsSync(), isTrue);
      expect(iconFile.existsSync(), isTrue);
    });

    testWidgets('QuizView displays Hint card on Easy and Medium difficulty and toggles it', (tester) async {
      final easyQuiz = QuizModel(
        id: 'easy_quiz',
        sourceFileName: 'easy.pdf',
        difficulty: QuizDifficulty.easy,
        questions: const [
          QuestionModel(
            question: 'What is 2 + 2?',
            options: ['3', '4', '5', '6'],
            correctAnswerIndex: 1,
            explanation: '2 plus 2 equals 4.',
            hint: 'It is an even single-digit number.',
            difficulty: QuizDifficulty.easy,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              Provider<AdService>.value(value: AdService()),
            ],
            child: QuizView(quiz: easyQuiz),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Easy difficulty should show "Need a hint?"
      expect(find.text('Need a hint? Tap to reveal'), findsOneWidget);

      // Tap to reveal hint
      await tester.tap(find.text('Need a hint? Tap to reveal'));
      await tester.pumpAndSettle();

      expect(find.text('Question Hint'), findsOneWidget);
      expect(find.text('It is an even single-digit number.'), findsOneWidget);
    });

    testWidgets('QuizView HIDES Hint card on Hard difficulty', (tester) async {
      final hardQuiz = QuizModel(
        id: 'hard_quiz',
        sourceFileName: 'hard.pdf',
        difficulty: QuizDifficulty.hard,
        questions: const [
          QuestionModel(
            question: 'Complex calculus problem?',
            options: ['A', 'B', 'C', 'D'],
            correctAnswerIndex: 0,
            explanation: 'Detailed derivation.',
            hint: 'Should not show on hard.',
            difficulty: QuizDifficulty.hard,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              Provider<AdService>.value(value: AdService()),
            ],
            child: QuizView(quiz: hardQuiz),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Hard difficulty should NEVER show hint button
      expect(find.text('Need a hint? Tap to reveal'), findsNothing);
      expect(find.text('Question Hint'), findsNothing);
    });
  });
}
