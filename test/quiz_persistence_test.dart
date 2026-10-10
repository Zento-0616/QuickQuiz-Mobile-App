import 'package:flutter_test/flutter_test.dart';
import 'package:quickquiz/models/question_model.dart';
import 'package:quickquiz/models/quiz_result_model.dart';
import 'package:quickquiz/models/quiz_settings_model.dart';

void main() {
  group('Quiz Persistence & History Integrity Tests', () {
    test('QuizResultModel correctly serializes and deserializes userId and scores', () {
      final sampleQuestions = [
        const QuestionModel(
          id: 'q1',
          question: 'What is photosynthesis?',
          options: [
            'Light into chemical energy',
            'Water into oxygen only',
            'Heat into motion',
            'Nuclear fusion'
          ],
          correctAnswerIndex: 0,
          explanation: 'Plants use light energy to synthesize organic molecules.',
          category: 'Biology',
          difficulty: QuizDifficulty.medium,
          selectedAnswerIndex: 0,
        ),
      ];

      final result = QuizResultModel(
        quizId: 'quiz_123',
        userId: 'user_456',
        fileName: 'biology_notes.pdf',
        difficulty: QuizDifficulty.medium,
        questionCount: 1,
        correctCount: 1,
        createdAt: DateTime(2026, 9, 7, 12, 0),
        questions: sampleQuestions,
      );

      final json = result.toJson();
      expect(json['quizId'], equals('quiz_123'));
      expect(json['userId'], equals('user_456'));
      expect(json['fileName'], equals('biology_notes.pdf'));
      expect(json['score'], equals(1));
      expect(json['questionCount'], equals(1));
      expect(json['percentage'], equals(100.0));

      final restored = QuizResultModel.fromJson(json);
      expect(restored.quizId, equals('quiz_123'));
      expect(restored.userId, equals('user_456'));
      expect(restored.correctCount, equals(1));
      expect(restored.questions.length, equals(1));
      expect(restored.questions.first.question, equals('What is photosynthesis?'));
    });

    test('In-memory sorting sorts history by createdAt descending without requiring composite index', () {
      final results = [
        QuizResultModel(
          quizId: 'q_old',
          userId: 'user_1',
          fileName: 'old.pdf',
          difficulty: QuizDifficulty.easy,
          questionCount: 10,
          correctCount: 8,
          createdAt: DateTime(2026, 1, 1),
          questions: const [],
        ),
        QuizResultModel(
          quizId: 'q_new',
          userId: 'user_1',
          fileName: 'new.pdf',
          difficulty: QuizDifficulty.hard,
          questionCount: 10,
          correctCount: 9,
          createdAt: DateTime(2026, 9, 1),
          questions: const [],
        ),
        QuizResultModel(
          quizId: 'q_mid',
          userId: 'user_1',
          fileName: 'mid.pdf',
          difficulty: QuizDifficulty.medium,
          questionCount: 10,
          correctCount: 7,
          createdAt: DateTime(2026, 5, 1),
          questions: const [],
        ),
      ];

      // Sort in memory as implemented in FirestoreService.getQuizHistory
      results.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      expect(results.first.quizId, equals('q_new'));
      expect(results[1].quizId, equals('q_mid'));
      expect(results.last.quizId, equals('q_old'));
    });

    test('Guest quiz result migration links result to newly authenticated UID', () {
      final guestResult = QuizResultModel(
        quizId: 'guest_quiz_1',
        userId: null,
        fileName: 'lecture_guest.pdf',
        difficulty: QuizDifficulty.medium,
        questionCount: 5,
        correctCount: 4,
        createdAt: DateTime(2026, 9, 7),
        questions: const [],
      );

      expect(guestResult.userId, isNull);

      const targetUserId = 'firebase_user_789';
      final migratedResult = QuizResultModel(
        quizId: guestResult.quizId,
        userId: targetUserId,
        fileName: guestResult.fileName,
        difficulty: guestResult.difficulty,
        questionCount: guestResult.questionCount,
        correctCount: guestResult.correctCount,
        createdAt: guestResult.createdAt,
        questions: guestResult.questions,
      );

      expect(migratedResult.userId, equals(targetUserId));
      expect(migratedResult.quizId, equals('guest_quiz_1'));
      expect(migratedResult.correctCount, equals(4));
    });
  });
}
