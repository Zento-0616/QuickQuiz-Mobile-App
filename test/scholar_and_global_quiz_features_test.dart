import 'package:flutter_test/flutter_test.dart';
import 'package:quickquiz/models/question_model.dart';
import 'package:quickquiz/models/quiz_model.dart';
import 'package:quickquiz/models/quiz_result_model.dart';
import 'package:quickquiz/models/quiz_settings_model.dart';
import 'package:quickquiz/models/user_model.dart';
import 'package:quickquiz/viewmodels/quiz_viewmodel.dart';

void main() {
  group('1. Quiz Integrity & Proctoring Penalty Scoring Tests', () {
    late QuizModel testQuiz;

    setUp(() {
      testQuiz = QuizModel(
        id: 'quiz_test_1',
        title: 'Network Security Fundamentals',
        questions: [
          const QuestionModel(
            question: 'What does SSL stand for?',
            options: [
              'Secure Sockets Layer',
              'System Socket Level',
              'Secure System Line',
              'Simple Security Logic',
            ],
            correctAnswerIndex: 0,
            explanation: 'SSL stands for Secure Sockets Layer.',
            difficulty: QuizDifficulty.easy,
          ),
          const QuestionModel(
            question: 'Which port is standard for HTTPS?',
            options: ['80', '443', '22', '8080'],
            correctAnswerIndex: 1,
            explanation: 'Port 443 is used for HTTPS.',
            difficulty: QuizDifficulty.easy,
          ),
        ],
        difficulty: QuizDifficulty.easy,
        createdAt: DateTime.now(),
        sourceFileName: 'Security.pdf',
        isGlobal: true,
      );
    });

    test('Default baseline integrity score starts at 100%', () {
      final vm = QuizViewModel(testQuiz);
      expect(vm.calculateIntegrity(), equals(100.0));
      expect(vm.answerChangesCount, equals(0));
      expect(vm.backAttemptsCount, equals(0));
      expect(vm.screenshotAttemptsCount, equals(0));
      vm.dispose();
    });

    test('Deducts 5% for changing an already-selected answer', () {
      final vm = QuizViewModel(testQuiz);
      // Select first option
      vm.selectAnswer(0);
      expect(vm.answerChangesCount, equals(0));
      expect(vm.calculateIntegrity(), equals(100.0));

      // Change answer to option 1 (-5%)
      vm.selectAnswer(1);
      expect(vm.answerChangesCount, equals(1));
      expect(vm.calculateIntegrity(), equals(95.0));

      // Change answer again to option 2 (-5% more = -10%)
      vm.selectAnswer(2);
      expect(vm.answerChangesCount, equals(2));
      expect(vm.calculateIntegrity(), equals(90.0));
      vm.dispose();
    });

    test('Deducts 10% on exit or back navigation attempts', () {
      final vm = QuizViewModel(testQuiz);
      vm.recordBackAttempt();
      expect(vm.backAttemptsCount, equals(1));
      expect(vm.calculateIntegrity(), equals(90.0));

      vm.recordBackAttempt();
      expect(vm.backAttemptsCount, equals(2));
      expect(vm.calculateIntegrity(), equals(80.0));
      vm.dispose();
    });

    test('Deducts 10% on app switch / phone backgrounding', () {
      final vm = QuizViewModel(testQuiz);
      vm.recordAppSwitchAttempt();
      expect(vm.screenshotAttemptsCount, equals(1));
      expect(vm.calculateIntegrity(), equals(90.0));

      vm.recordAppSwitchAttempt();
      expect(vm.screenshotAttemptsCount, equals(2));
      expect(vm.calculateIntegrity(), equals(80.0));
      vm.dispose();
    });

    test('Cumulative penalties clamp cleanly between 0% and 100%', () {
      final vm = QuizViewModel(testQuiz);
      // 5 changes = -25%
      for (int i = 0; i < 5; i++) {
        vm.selectAnswer(i % 4);
      }
      // 5 back attempts = -50%
      for (int i = 0; i < 5; i++) {
        vm.recordBackAttempt();
      }
      // 4 app switches = -40%
      for (int i = 0; i < 4; i++) {
        vm.recordAppSwitchAttempt();
      }
      expect(vm.calculateIntegrity(), equals(0.0));
      vm.dispose();
    });

    test('QuizResultModel serializes and deserializes integrity metrics accurately', () {
      final result = QuizResultModel(
        quizId: 'q_1',
        userId: 'u_123',
        fileName: 'CyberSec.pdf',
        difficulty: QuizDifficulty.medium,
        questionCount: 10,
        correctCount: 8,
        createdAt: DateTime.now(),
        questions: const [],
        integrityPercentage: 85.0,
        answerChangesCount: 1,
        backAttemptsCount: 1,
        screenshotAttemptsCount: 0,
        delayDeductions: 0,
      );

      final json = result.toJson();
      expect(json['integrityPercentage'], equals(85.0));
      expect(json['answerChangesCount'], equals(1));
      expect(json['backAttemptsCount'], equals(1));

      final deserialized = QuizResultModel.fromJson(json);
      expect(deserialized.integrityPercentage, equals(85.0));
      expect(deserialized.answerChangesCount, equals(1));
      expect(deserialized.backAttemptsCount, equals(1));
    });
  });

  group('2. Scholar Settings & Profile Full Name Tests', () {
    test('UserModel preserves full name and nickname without truncation', () {
      final user = UserModel(
        uid: 'scholar_rey',
        name: 'REYNALDO SEROJE',
        nickname: 'Reynaldo',
        email: 'reynaldo@example.com',
        role: 'scholar',
        age: 22,
        createdAt: DateTime.now(),
        region: 'PH',
      );

      expect(user.name, equals('REYNALDO SEROJE'));
      expect(user.effectiveNickname, equals('Reynaldo'));
      expect(user.regionFlag, equals('🇵🇭'));
    });
  });

  group('3. Quiz Model Daily and Weekly Tournament Schedule Presets', () {
    test('QuizModel supports standard, daily, and weekly recurrence', () {
      final dailyQuiz = QuizModel(
        id: 'daily_1',
        title: 'Daily Micro Challenge',
        questions: const [],
        difficulty: QuizDifficulty.medium,
        createdAt: DateTime.now(),
        sourceFileName: 'Daily.txt',
        quizScheduleType: 'daily',
      );
      expect(dailyQuiz.quizScheduleType, equals('daily'));

      final weeklyQuiz = dailyQuiz.copyWith(quizScheduleType: 'weekly');
      expect(weeklyQuiz.quizScheduleType, equals('weekly'));

      final json = weeklyQuiz.toJson();
      expect(json['quizScheduleType'], equals('weekly'));

      final fromJson = QuizModel.fromJson(json);
      expect(fromJson.quizScheduleType, equals('weekly'));
    });
  });
}
