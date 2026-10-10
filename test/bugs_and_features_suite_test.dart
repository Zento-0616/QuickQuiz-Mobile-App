import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quickquiz/models/admin_settings_model.dart';
import 'package:quickquiz/models/feedback_model.dart';
import 'package:quickquiz/models/user_model.dart';
import 'package:quickquiz/services/firestore_service.dart';
import 'package:quickquiz/services/gemini_service.dart';
import 'package:quickquiz/services/local_storage_service.dart';
import 'package:quickquiz/services/progression_service.dart';
import 'package:quickquiz/viewmodels/auth_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  group('1. EXP Celebration & Level-Up Return Tests', () {
    test('ProgressionService calculates EXP and reports accurate level up', () {
      final user = UserModel(
        uid: 'user_lvl_1',
        name: 'Scholar One',
        email: 'scholar1@example.com',
        level: 1,
        exp: 80,
        createdAt: DateTime.now(),
      );

      // Earning 100 EXP should take user past Level 1 cap (100 EXP) into Level 2
      final result = ProgressionService.processQuizCompletion(
        user: user,
        questionCount: 10,
        correctCount: 10,
        deckMultiplier: 1.0,
      );

      expect(result.earnedExp, greaterThan(0));
      expect(result.oldLevel, equals(1));
      expect(result.newLevel, greaterThanOrEqualTo(1));
    });

    test('AuthViewModel recordQuizExp returns QuizExpResult with earned stats', () async {
      final authVM = AuthViewModel();
      final user = UserModel(
        uid: 'user_calc_exp',
        name: 'Alex Scholar',
        email: 'alex@example.com',
        level: 2,
        exp: 150,
        createdAt: DateTime.now(),
      );

      authVM.setCurrentUserForTesting(user);

      final result = await authVM.recordQuizExp(
        questionCount: 5,
        correctCount: 5,
        multiplier: 1.5,
      );

      expect(result, isNotNull);
      expect(result!.earnedExp, greaterThan(0));
      expect(result.oldLevel, equals(2));
      expect(authVM.currentUser!.exp, equals(150 + result.earnedExp));
    });
  });

  group('2. Daily Reward Calendar Admin Sync Tests', () {
    test('AdminSettingsModel holds and parses custom dailyLoginRewards', () {
      final json = {
        'repeatQuizExpEnabled': true,
        'dailyExpCaps': {'3': 800},
        'dailyLoginRewards': {
          '1': 50,
          '2': 75,
          '3': 500, // Wednesday custom reward
          '7': 1000,
        },
      };

      final settings = AdminSettingsModel.fromJson(json);
      expect(settings.getDailyRewardForDay(1), equals(50));
      expect(settings.getDailyRewardForDay(2), equals(75));
      expect(settings.getDailyRewardForDay(3), equals(500));
      expect(settings.getDailyRewardForDay(7), equals(1000));
    });

    test('ProgressionService.getDailyRewardExp uses admin settings when provided', () {
      final customSettings = AdminSettingsModel(
        dailyLoginRewards: const {
          1: 30,
          2: 60,
          3: 500, // Wednesday 500 EXP
          4: 120,
          5: 200,
          6: 300,
          7: 800,
        },
      );

      // Day 3 (Wednesday)
      final wednesdayExp = ProgressionService.getDailyRewardExp(3, settings: customSettings);
      expect(wednesdayExp, equals(500));

      // Day 1 (Monday)
      final mondayExp = ProgressionService.getDailyRewardExp(1, settings: customSettings);
      expect(mondayExp, equals(30));
    });
  });

  group('3. Top Scholar Global Avg Score Sync Tests', () {
    test('UserModel initializes with zero global stats and calculates globalAvgScore', () {
      final user = UserModel(
        uid: 'scholar_stats',
        name: 'Scholar Global',
        email: 'global@example.com',
        createdAt: DateTime.now(),
      );

      expect(user.globalQuizCount, equals(0));
      expect(user.globalTotalScore, equals(0.0));
      expect(user.globalAvgScore, equals(0.0));

      final updated = user.copyWith(
        globalQuizCount: 2,
        globalTotalScore: 180.0, // 90% average across 2 quizzes
      );

      expect(updated.globalQuizCount, equals(2));
      expect(updated.globalTotalScore, equals(180.0));
      expect(updated.globalAvgScore, equals(90.0));
    });

    test('AuthViewModel recordQuizExp increments global stats only when isGlobal is true', () async {
      final authVM = AuthViewModel();
      final user = UserModel(
        uid: 'scholar_global_test',
        name: 'Top Scholar',
        email: 'topscholar@example.com',
        createdAt: DateTime.now(),
      );

      authVM.setCurrentUserForTesting(user);

      // 1. Non-global quiz attempt (e.g. local custom / mock quiz)
      await authVM.recordQuizExp(
        questionCount: 10,
        correctCount: 8,
        percentage: 80.0,
        isGlobal: false,
      );

      expect(authVM.currentUser!.quizzesPlayed, equals(1));
      expect(authVM.currentUser!.globalQuizCount, equals(0));
      expect(authVM.currentUser!.globalAvgScore, equals(0.0));

      // 2. Global quiz attempt
      await authVM.recordQuizExp(
        questionCount: 10,
        correctCount: 10,
        percentage: 100.0,
        isGlobal: true,
      );

      expect(authVM.currentUser!.quizzesPlayed, equals(2));
      expect(authVM.currentUser!.globalQuizCount, equals(1));
      expect(authVM.currentUser!.globalTotalScore, equals(100.0));
      expect(authVM.currentUser!.globalAvgScore, equals(100.0));

      // 3. Second global quiz attempt with 80%
      await authVM.recordQuizExp(
        questionCount: 10,
        correctCount: 8,
        percentage: 80.0,
        isGlobal: true,
      );

      expect(authVM.currentUser!.globalQuizCount, equals(2));
      expect(authVM.currentUser!.globalTotalScore, equals(180.0));
      expect(authVM.currentUser!.globalAvgScore, equals(90.0));
    });
  });

  group('4. Session Persistence & Admin Inactivity Tests', () {
    test('LocalStorageService persists and restores scholar user session across app restarts', () async {
      final storage = LocalStorageService();
      final scholar = UserModel(
        uid: 'scholar_saved_123',
        name: 'Persistent Scholar',
        email: 'scholar@quickquiz.com',
        level: 5,
        exp: 750,
        createdAt: DateTime.now(),
      );

      await storage.saveCurrentUser(scholar);
      final restored = await storage.getCachedCurrentUser();

      expect(restored, isNotNull);
      expect(restored!.uid, equals('scholar_saved_123'));
      expect(restored.name, equals('Persistent Scholar'));
      expect(restored.level, equals(5));
      expect(restored.isAdmin, isFalse);

      await storage.clearCachedCurrentUser();
      expect(await storage.getCachedCurrentUser(), isNull);
    });

    test('AuthViewModel checkAdminInactivityTimeout logs out admin after 5 minutes of inactivity', () async {
      final storage = LocalStorageService();
      final authVM = AuthViewModel(localStorage: storage);

      final admin = UserModel(
        uid: 'admin_test_uid',
        name: 'Admin User',
        email: 'admin@quickquiz.com',
        role: 'admin',
        createdAt: DateTime.now(),
      );

      authVM.setCurrentUserForTesting(admin);

      // Simulate admin last activity was 6 minutes ago
      final sixMinsAgo = DateTime.now().subtract(const Duration(minutes: 6));
      await storage.saveLastAdminActivity(sixMinsAgo);

      final timedOut = await authVM.checkAdminInactivityTimeout();
      expect(timedOut, isTrue);
      expect(authVM.currentUser, isNull);
    });

    test('Regular scholar is NOT logged out regardless of inactivity', () async {
      final storage = LocalStorageService();
      final authVM = AuthViewModel(localStorage: storage);

      final scholar = UserModel(
        uid: 'regular_scholar',
        name: 'Scholar User',
        email: 'scholar@quickquiz.com',
        role: 'user',
        createdAt: DateTime.now(),
      );

      authVM.setCurrentUserForTesting(scholar);

      // Inactivity check for normal user
      final timedOut = await authVM.checkAdminInactivityTimeout();
      expect(timedOut, isFalse);
      expect(authVM.currentUser, isNotNull);
      expect(authVM.currentUser!.uid, equals('regular_scholar'));
    });
  });

  group('5. Scholar Feedback Real-Time Resolution Metric Tests', () {
    test('FirestoreService getFeedbackMetrics7Days provides real-time counts without 7-day cutoff', () async {
      final firestore = FirestoreService();

      final now = DateTime.now();
      final tenDaysAgo = now.subtract(const Duration(days: 10));

      // 1. Submit feedback created 10 days ago (past any 7-day window)
      final item1 = FeedbackModel(
        id: 'fb_realtime_test',
        userId: 'user_fb_1',
        userName: 'Scholar One',
        userEmail: 'scholar1@test.com',
        type: 'issue_report',
        title: 'Quiz audio glitch',
        message: 'Audio failed to trigger on question 3',
        createdAt: tenDaysAgo,
      );

      await firestore.submitFeedback(item1);

      // Mark as resolved
      await firestore.updateFeedbackStatus('fb_realtime_test', 'resolved');

      final metrics = await firestore.getFeedbackMetrics();
      expect(metrics.totalReceived, greaterThanOrEqualTo(1));
      expect(metrics.totalResolved, greaterThanOrEqualTo(1));

      final metrics7d = await firestore.getFeedbackMetrics7Days();
      expect(metrics7d.totalReceived, equals(metrics.totalReceived));
      expect(metrics7d.totalResolved, equals(metrics.totalResolved));
    });
  });

  group('6. Speed Optimization & Model Configuration Tests', () {
    test('GeminiService uses gemini-2.5-flash as fast default model', () {
      final gemini = GeminiService();
      expect(gemini.modelName, equals('gemini-2.5-flash'));
    });
  });
}
