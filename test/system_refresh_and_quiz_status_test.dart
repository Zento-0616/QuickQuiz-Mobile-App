import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quickquiz/models/quiz_model.dart';
import 'package:quickquiz/models/quiz_result_model.dart';
import 'package:quickquiz/models/quiz_settings_model.dart';
import 'package:quickquiz/models/user_model.dart';
import 'package:quickquiz/services/local_storage_service.dart';
import 'package:quickquiz/services/firestore_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. LocalStorageService Cleanup Tests', () {
    late LocalStorageService localStorage;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      localStorage = LocalStorageService();
    });

    test('clearAllQuizHistoryLocally removes all records from local storage', () async {
      final sample1 = QuizResultModel(
        quizId: 'q1',
        fileName: 'deck1.pdf',
        difficulty: QuizDifficulty.medium,
        correctCount: 4,
        questionCount: 5,
        createdAt: DateTime.now(),
        userId: 'scholar_1',
        questions: const [],
      );
      final sample2 = QuizResultModel(
        quizId: 'q2',
        fileName: 'deck2.pdf',
        difficulty: QuizDifficulty.hard,
        correctCount: 9,
        questionCount: 10,
        createdAt: DateTime.now(),
        userId: 'scholar_2',
        questions: const [],
      );

      await localStorage.saveQuizResultLocally(sample1);
      await localStorage.saveQuizResultLocally(sample2);

      final before1 = await localStorage.getQuizHistoryLocally(userId: 'scholar_1');
      final before2 = await localStorage.getQuizHistoryLocally(userId: 'scholar_2');
      expect(before1.length, 1);
      expect(before2.length, 1);

      await localStorage.clearAllQuizHistoryLocally();

      final after1 = await localStorage.getQuizHistoryLocally(userId: 'scholar_1');
      final after2 = await localStorage.getQuizHistoryLocally(userId: 'scholar_2');
      expect(after1, isEmpty);
      expect(after2, isEmpty);
    });

    test('clearScholarQuizHistoryLocally removes only matching scholar records', () async {
      final sample1 = QuizResultModel(
        quizId: 'q1',
        fileName: 'deck1.pdf',
        difficulty: QuizDifficulty.medium,
        correctCount: 4,
        questionCount: 5,
        createdAt: DateTime.now(),
        userId: 'scholar_target',
        questions: const [],
      );
      final sample2 = QuizResultModel(
        quizId: 'q2',
        fileName: 'deck2.pdf',
        difficulty: QuizDifficulty.hard,
        correctCount: 9,
        questionCount: 10,
        createdAt: DateTime.now(),
        userId: 'scholar_safe',
        questions: const [],
      );

      await localStorage.saveQuizResultLocally(sample1);
      await localStorage.saveQuizResultLocally(sample2);

      // Purge only target scholar
      await localStorage.clearScholarQuizHistoryLocally('scholar_target');

      final targetAfter = await localStorage.getQuizHistoryLocally(userId: 'scholar_target');
      final safeAfter = await localStorage.getQuizHistoryLocally(userId: 'scholar_safe');

      expect(targetAfter, isEmpty);
      expect(safeAfter.length, 1);
      expect(safeAfter.first.quizId, 'q2');
    });
  });

  group('2. FirestoreService System Refresh & Scholar Purge Tests', () {
    late FirestoreService firestoreService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      firestoreService = FirestoreService();
    });

    test('clearAllGeneratedQuizDocuments purges quiz history while leaving users safe', () async {
      final res = QuizResultModel(
        quizId: 'quiz_gen_1',
        fileName: 'test.pdf',
        difficulty: QuizDifficulty.easy,
        correctCount: 5,
        questionCount: 5,
        createdAt: DateTime.now(),
        userId: 'user_123',
        questions: const [],
      );

      await firestoreService.saveQuizResult(res);

      final purgedCount = await firestoreService.clearAllGeneratedQuizDocuments();
      expect(purgedCount, greaterThanOrEqualTo(1));

      final remaining = await firestoreService.getQuizHistory('user_123');
      expect(remaining, isEmpty);
    });

    test('clearScholarQuizDocuments isolates deletion to specified scholar', () async {
      final resTarget = QuizResultModel(
        quizId: 'quiz_target',
        fileName: 'target.pdf',
        difficulty: QuizDifficulty.medium,
        correctCount: 4,
        questionCount: 5,
        createdAt: DateTime.now(),
        userId: 'user_target',
        questions: const [],
      );
      final resSafe = QuizResultModel(
        quizId: 'quiz_safe',
        fileName: 'safe.pdf',
        difficulty: QuizDifficulty.hard,
        correctCount: 5,
        questionCount: 5,
        createdAt: DateTime.now(),
        userId: 'user_safe',
        questions: const [],
      );

      await firestoreService.saveQuizResult(resTarget);
      await firestoreService.saveQuizResult(resSafe);

      final deleted = await firestoreService.clearScholarQuizDocuments('user_target');
      expect(deleted, greaterThanOrEqualTo(1));

      final targetResults = await firestoreService.getQuizHistory('user_target');
      final safeResults = await firestoreService.getQuizHistory('user_safe');

      expect(targetResults, isEmpty);
      expect(safeResults.length, 1);
      expect(safeResults.first.quizId, 'quiz_safe');
    });
  });

  group('3. QuizModel Status & Stopped State Tests', () {
    test('QuizModel supports Stopped and Done status', () {
      final quizActive = QuizModel(
        id: 'q_act',
        title: 'Active Quiz',
        sourceFileName: 'source.pdf',
        difficulty: QuizDifficulty.medium,
        questions: const [],
        status: 'Active',
      );
      final quizStopped = QuizModel(
        id: 'q_stop',
        title: 'Concluded Quiz',
        sourceFileName: 'source.pdf',
        difficulty: QuizDifficulty.hard,
        questions: const [],
        status: 'Stopped',
      );

      expect(quizActive.status, 'Active');
      expect(quizStopped.status, 'Stopped');

      final json = quizStopped.toJson();
      expect(json['status'], 'Stopped');

      final deserialized = QuizModel.fromJson(json);
      expect(deserialized.status, 'Stopped');
      expect(deserialized.id, 'q_stop');
    });

    test('QuizModel updateQuizStatus updates in-memory fallback', () async {
      SharedPreferences.setMockInitialValues({});
      final service = FirestoreService();

      final adminUser = UserModel(
        uid: 'admin_test_uid',
        email: 'admin@quickquiz.com',
        name: 'Admin',
        nickname: 'Admin',
        role: 'admin',
        createdAt: DateTime.now(),
      );

      final quiz = QuizModel(
        id: 'arena_quiz_1',
        title: 'Arena Quiz 1',
        sourceFileName: 'source.pdf',
        difficulty: QuizDifficulty.easy,
        questions: const [],
        isPublished: true,
        status: 'Active',
      );

      await service.savePublishedQuiz(quiz, user: adminUser);
      await service.updateQuizStatus('arena_quiz_1', 'Stopped');

      final published = await service.getPublishedQuizzes();
      final updated = published.firstWhere((q) => q.id == 'arena_quiz_1');
      expect(updated.status, 'Stopped');
    });
  });
}
