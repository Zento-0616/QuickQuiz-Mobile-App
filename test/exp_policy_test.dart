import 'package:flutter_test/flutter_test.dart';
import 'package:quickquiz/models/admin_settings_model.dart';
import 'package:quickquiz/models/question_model.dart';
import 'package:quickquiz/models/quiz_model.dart';
import 'package:quickquiz/models/quiz_settings_model.dart';
import 'package:quickquiz/models/user_model.dart';
import 'package:quickquiz/services/progression_service.dart';
import 'package:quickquiz/viewmodels/auth_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('1. EXP Policy - Official vs Practice Quiz Validation', () {
    test('User practice quiz (isPublished=false, standard) is classified as practice (0 EXP)', () {
      final practiceQuiz = QuizModel(
        title: 'Photosynthesis Review',
        sourceFileName: 'biology_notes.pdf',
        difficulty: QuizDifficulty.hard,
        isPublished: false,
        quizScheduleType: 'standard',
        category: 'Biology',
        questions: [
          QuestionModel(
            question: 'What organelle performs photosynthesis?',
            options: ['Chloroplast', 'Mitochondria', 'Ribosome', 'Nucleus'],
            correctAnswerIndex: 0,
            explanation: 'Chloroplasts contain chlorophyll.',
          ),
        ],
      );

      final isOfficialQuiz = practiceQuiz.isPublished ||
          practiceQuiz.quizScheduleType == 'daily' ||
          practiceQuiz.category == 'Daily Challenge';

      expect(isOfficialQuiz, isFalse);
    });

    test('Official Admin Quiz awards EXP', () {
      final officialQuiz = QuizModel(
        title: 'Grand Finals Arena Quiz',
        sourceFileName: 'arena_final.pdf',
        difficulty: QuizDifficulty.medium,
        isPublished: true,
        quizScheduleType: 'standard',
        questions: [],
      );

      final isOfficialQuiz = officialQuiz.isPublished ||
          officialQuiz.quizScheduleType == 'daily' ||
          officialQuiz.category == 'Daily Challenge';

      expect(isOfficialQuiz, isTrue);
    });

    test('Daily Quiz awards EXP regardless of source file', () {
      final dailyQuiz = QuizModel(
        title: 'Daily Science Drop',
        sourceFileName: 'daily_drop.pdf',
        difficulty: QuizDifficulty.medium,
        isPublished: false,
        quizScheduleType: 'daily',
        category: 'Daily Challenge',
        questions: [],
      );

      final isOfficialQuiz = dailyQuiz.isPublished ||
          dailyQuiz.quizScheduleType == 'daily' ||
          dailyQuiz.category == 'Daily Challenge';

      expect(isOfficialQuiz, isTrue);
    });
  });

  group('2. Daily Reward Claim & EXP Calculations', () {
    test('Daily login streak calculates escalating EXP correctly', () {
      // Day 1 streak
      final day1Exp = ProgressionService.getDailyRewardExp(1);
      expect(day1Exp, equals(30));

      // Day 7 streak cap reward
      final day7Exp = ProgressionService.getDailyRewardExp(7);
      expect(day7Exp, equals(250));
    });

    test('Admin custom daily rewards override default progression', () {
      final customSettings = AdminSettingsModel(
        dailyLoginRewards: const {
          1: 100,
          2: 200,
          3: 300,
          4: 400,
          5: 500,
          6: 600,
          7: 1500,
        },
      );

      final day7Exp = ProgressionService.getDailyRewardExp(7, settings: customSettings);
      expect(day7Exp, equals(1500));
    });

    test('ProgressionService handles leveling up when user gains EXP', () {
      final user = UserModel(
        uid: 'streak_claimer',
        name: 'Daily Scholar',
        email: 'daily@example.com',
        level: 1,
        exp: 80,
        createdAt: DateTime.now(),
      );

      final result = ProgressionService.processQuizCompletion(
        user: user,
        questionCount: 5,
        correctCount: 5,
      );

      expect(result.earnedExp, greaterThan(0));
      expect(result.oldLevel, equals(1));
      expect(result.newLevel, greaterThanOrEqualTo(1));
    });
  });
}
