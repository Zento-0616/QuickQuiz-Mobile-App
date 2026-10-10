import 'package:flutter_test/flutter_test.dart';
import 'package:quickquiz/models/question_model.dart';
import 'package:quickquiz/models/quiz_model.dart';
import 'package:quickquiz/models/quiz_settings_model.dart';
import 'package:quickquiz/viewmodels/quiz_viewmodel.dart';

void main() {
  group('Timer & Difficulty Logic - Duration Mapping Tests', () {
    test('Easy Mode: Countdown timer is disabled entirely (unlimited time)', () {
      for (final count in [5, 10, 20, 30, 40, 50]) {
        final seconds = QuizSettingsModel.calculateTimeLimitInSeconds(
          count,
          QuizDifficulty.easy,
        );
        expect(seconds, isNull, reason: 'Easy mode must have unlimited time (null timer)');
      }

      const settings = QuizSettingsModel(
        questionCount: 20,
        difficulty: QuizDifficulty.easy,
      );
      expect(settings.timeLimitInSeconds, isNull);
      expect(settings.formattedEstimatedTime, equals('Unlimited Time'));
    });

    test('Medium & Hard Modes: Dynamic countdown timer mapped to question count', () {
      final testCases = <int, int>{
        50: 60 * 60, // 50 questions -> 60 minutes (3600 seconds)
        40: 50 * 60, // 40 questions -> 50 minutes (3000 seconds)
        30: 40 * 60, // 30 questions -> 40 minutes (2400 seconds)
        20: 30 * 60, // 20 questions -> 30 minutes (1800 seconds)
        10: 10 * 60, // 10 questions -> 10 minutes (600 seconds)
        5: 5 * 60,   // 5 questions  -> 5 minutes (300 seconds)
      };

      for (final diff in [QuizDifficulty.medium, QuizDifficulty.hard]) {
        testCases.forEach((questionCount, expectedSeconds) {
          final computed = QuizSettingsModel.calculateTimeLimitInSeconds(
            questionCount,
            diff,
          );
          expect(
            computed,
            equals(expectedSeconds),
            reason: '$questionCount questions on ${diff.label} should be $expectedSeconds seconds (${expectedSeconds ~/ 60} min)',
          );
        });
      }
    });

    test('QuizSettingsModel formattedEstimatedTime produces user-friendly string', () {
      const settings10 = QuizSettingsModel(
        questionCount: 10,
        difficulty: QuizDifficulty.medium,
      );
      expect(settings10.formattedEstimatedTime, equals('10 mins'));

      const settings50 = QuizSettingsModel(
        questionCount: 50,
        difficulty: QuizDifficulty.hard,
      );
      expect(settings50.formattedEstimatedTime, equals('60 mins'));
    });
  });

  group('QuizViewModel Timer Session Tests', () {
    QuestionModel dummyQuestion(int index) => QuestionModel(
          id: 'q_$index',
          question: 'Sample question stem #$index?',
          options: const ['Option A', 'Option B', 'Option C', 'Option D'],
          correctAnswerIndex: 0,
          explanation: 'Sample explanation for question $index.',
          category: 'Computer Science',
          difficulty: QuizDifficulty.medium,
        );

    test('Easy Mode: isCountdown is false and formattedTime is Unlimited', () {
      final quiz = QuizModel(
        sourceFileName: 'test.pdf',
        difficulty: QuizDifficulty.easy,
        questions: List.generate(5, dummyQuestion),
      );

      final vm = QuizViewModel(quiz);
      expect(vm.isCountdown, isFalse);
      expect(vm.formattedTime, equals('Unlimited'));
      vm.dispose();
    });

    test('Medium Mode: isCountdown is true and starts with mapped remaining seconds', () {
      final quiz = QuizModel(
        sourceFileName: 'test.pdf',
        difficulty: QuizDifficulty.medium,
        questions: List.generate(10, dummyQuestion),
      );

      final vm = QuizViewModel(quiz);
      expect(vm.isCountdown, isTrue);
      // 10 questions mapped to 10 minutes (600 seconds)
      expect(vm.remainingSeconds, inInclusiveRange(598, 600));
      expect(vm.formattedTime, anyOf('10:00', '09:59'));
      vm.dispose();
    });

    test('Hard Mode: isCountdown is true and starts with mapped remaining seconds', () {
      final quiz = QuizModel(
        sourceFileName: 'test.pdf',
        difficulty: QuizDifficulty.hard,
        questions: List.generate(20, dummyQuestion),
      );

      final vm = QuizViewModel(quiz);
      expect(vm.isCountdown, isTrue);
      // 20 questions mapped to 30 minutes (1800 seconds)
      expect(vm.remainingSeconds, inInclusiveRange(1798, 1800));
      vm.dispose();
    });

    test('Countdown timer triggers onTimeUp when time expires', () async {
      final quiz = QuizModel(
        sourceFileName: 'test.pdf',
        difficulty: QuizDifficulty.medium,
        questions: List.generate(5, dummyQuestion),
        timeLimitSeconds: 1, // 1 second test limit
      );

      var timeUpFired = false;
      final vm = QuizViewModel(quiz)
        ..onTimeUp = () {
          timeUpFired = true;
        };

      expect(vm.isTimeUp, isFalse);

      // Wait 1.5 seconds for timer tick
      await Future.delayed(const Duration(milliseconds: 1500));

      expect(vm.isTimeUp, isTrue);
      expect(timeUpFired, isTrue);
      vm.dispose();
    });
  });
}
