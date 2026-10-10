import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quickquiz/models/question_model.dart';
import 'package:quickquiz/models/quiz_model.dart';
import 'package:quickquiz/models/quiz_result_model.dart';
import 'package:quickquiz/models/quiz_settings_model.dart';
import 'package:quickquiz/models/user_model.dart';
import 'package:quickquiz/services/ad_service.dart';
import 'package:quickquiz/services/firestore_service.dart';
import 'package:quickquiz/services/social_service.dart';
import 'package:quickquiz/viewmodels/auth_viewmodel.dart';
import 'package:quickquiz/widgets/banner_ad_widget.dart';
import 'package:quickquiz/views/admin/admin_home_screen.dart';
import 'package:quickquiz/views/admin/ai_quiz_studio_modal.dart';
import 'package:quickquiz/widgets/admin_bottom_nav.dart';
import 'package:quickquiz/widgets/pre_quiz_confirmation_dialog.dart';
import 'package:quickquiz/viewmodels/quiz_viewmodel.dart';
import 'package:quickquiz/providers/theme_provider.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('Admin Role Segregation & Hygiene Tests', () {
    test('Leaderboard strictly excludes admin accounts', () async {
      final socialService = SocialService();
      final leaderboard = await socialService.getLeaderboard();

      // Ensure no returned user is an admin
      for (final u in leaderboard) {
        expect(u.isAdmin, isFalse);
        expect(u.role, isNot('admin'));
      }
    });

    test('AuthViewModel excludes admin from gaining EXP and streaks', () async {
      final authVM = AuthViewModel();
      final adminUser = UserModel(
        uid: 'admin_test_123',
        name: 'Super Admin',
        nickname: 'SuperAdmin',
        email: 'admin@quickquiz.com',
        role: 'admin',
        exp: 1000,
        level: 10,
        dailyStreak: 5,
        createdAt: DateTime.now(),
      );

      authVM.setCurrentUserForTesting(adminUser);

      // Attempt to record quiz completion EXP
      await authVM.recordQuizExp(questionCount: 10, correctCount: 10, multiplier: 2.0);

      // Verify stats have NOT changed
      expect(authVM.currentUser!.exp, equals(1000));
      expect(authVM.currentUser!.level, equals(10));
      expect(authVM.currentUser!.dailyStreak, equals(5));

      // Attempt daily streak claim
      await authVM.claimDailyReward();
      expect(authVM.currentUser!.exp, equals(1000));
    });

    test('AdService bypasses interstitial completely for admins', () {
      final adService = AdService();
      bool completed = false;

      // Call showInterstitial with isAdmin: true
      adService.showInterstitial(
        onComplete: () {
          completed = true;
        },
        isAdmin: true,
      );

      expect(completed, isTrue);
    });

    testWidgets('BannerAdWidget renders SizedBox.shrink for admin accounts', (tester) async {
      final authVM = AuthViewModel();
      final adminUser = UserModel(
        uid: 'admin_test_456',
        name: 'Admin User',
        nickname: 'AdminUser',
        email: 'admin@quickquiz.com',
        role: 'admin',
        createdAt: DateTime.now(),
      );
      authVM.setCurrentUserForTesting(adminUser);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthViewModel>.value(
            value: authVM,
            child: const Scaffold(
              body: BannerAdWidget(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // BannerAdWidget should return SizedBox.shrink()
      expect(find.byType(BannerAdWidget), findsOneWidget);
      expect(find.text('ADVERTISEMENT'), findsNothing);
      expect(find.text('Sponsored Ad'), findsNothing);
    });
  });

  group('Backend Analytics & Data Queries Tests', () {
    test('FirestoreService live metrics aggregation', () async {
      final service = FirestoreService();
      final metrics = await service.getAdminLiveMetrics();

      expect(metrics.activePlayersOnline, isNonNegative);
      expect(metrics.totalRegisteredPlayers, isNonNegative);
      expect(metrics.quizzesPlayedToday, isNonNegative);
      expect(metrics.platformAverageAccuracy, inInclusiveRange(0.0, 100.0));
    });

    test('Admin quiz filtering by search query, status, and date range', () async {
      final service = FirestoreService();
      final adminUser = UserModel(
        uid: 'admin_test_789',
        name: 'Admin Tester',
        nickname: 'AdminTester',
        email: 'admin@quickquiz.com',
        role: 'admin',
        createdAt: DateTime.now(),
      );

      final quizA = QuizModel(
        title: 'Quantum Physics Intro',
        sourceFileName: 'quantum.pdf',
        difficulty: QuizDifficulty.hard,
        category: 'Science',
        minLevel: 5,
        status: 'Active',
        isPublished: true,
        questions: [
          QuestionModel(
            question: 'What is a photon?',
            options: ['A quantum of light', 'An electron', 'A quark', 'A neutrino'],
            correctAnswerIndex: 0,
            explanation: 'A photon is the elementary particle of light.',
          ),
        ],
      );

      final quizB = QuizModel(
        title: 'Ancient Greek Philosophy',
        sourceFileName: 'philosophy.txt',
        difficulty: QuizDifficulty.medium,
        category: 'History',
        minLevel: 1,
        status: 'Draft',
        isPublished: true,
        questions: [
          QuestionModel(
            question: 'Who taught Plato?',
            options: ['Socrates', 'Aristotle', 'Homer', 'Pythagoras'],
            correctAnswerIndex: 0,
            explanation: 'Socrates was the mentor and teacher of Plato.',
          ),
        ],
      );

      await service.savePublishedQuiz(quizA, user: adminUser);
      await service.savePublishedQuiz(quizB, user: adminUser);

      // Search by title
      final searchResults = await service.getAdminQuizzes(query: 'Quantum');
      expect(searchResults.any((q) => q.title.contains('Quantum')), isTrue);
      expect(searchResults.any((q) => q.title.contains('Greek')), isFalse);

      // Filter by category
      final catResults = await service.getAdminQuizzes(query: 'History');
      expect(catResults.any((q) => q.category == 'History'), isTrue);

      // Filter by status
      final activeResults = await service.getAdminQuizzes(status: 'Active');
      expect(activeResults.every((q) => q.status == 'Active'), isTrue);

      final draftResults = await service.getAdminQuizzes(status: 'Draft');
      expect(draftResults.every((q) => q.status == 'Draft'), isTrue);

      // Filter by date range (today)
      final now = DateTime.now();
      final todayRange = DateTimeRange(start: DateTime(now.year, now.month, now.day), end: now);
      final dateResults = await service.getAdminQuizzes(dateRange: todayRange);
      expect(dateResults.isNotEmpty, isTrue);

      // Update quiz status
      await service.updateQuizStatus(quizB.id, 'Active');
      final updatedQuizzes = await service.getAdminQuizzes(status: 'Active');
      expect(updatedQuizzes.any((q) => q.id == quizB.id), isTrue);
    });

    test('Quiz Performance Analytics and Player Breakdown calculation', () async {
      final service = FirestoreService();

      final result1 = QuizResultModel(
        quizId: 'test_deck_101',
        userId: 'user_alice',
        userNickname: 'Alice',
        fileName: 'Cell Biology',
        difficulty: QuizDifficulty.medium,
        questionCount: 10,
        correctCount: 9, // 90%
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        questions: const [],
        timeElapsedSeconds: 65,
        expEarned: 135,
      );

      final result2 = QuizResultModel(
        quizId: 'test_deck_101',
        userId: 'user_bob',
        userNickname: 'Bob',
        fileName: 'Cell Biology',
        difficulty: QuizDifficulty.medium,
        questionCount: 10,
        correctCount: 5, // 50%
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        questions: const [],
        timeElapsedSeconds: 90,
        expEarned: 50,
      );

      await service.saveQuizResult(result1);
      await service.saveQuizResult(result2);

      final analytics = await service.getQuizPerformanceAnalytics('test_deck_101', fileName: 'Cell Biology');

      expect(analytics.totalPlays, equals(2));
      expect(analytics.averageScore, equals(70.0));
      expect(analytics.passCount, equals(1)); // Alice passed (>=60%)
      expect(analytics.failCount, equals(1)); // Bob failed (<60%)
      expect(analytics.passRate, equals(50.0));

      // Top player should be Alice (higher score)
      expect(analytics.topPlayer, isNotNull);
      expect(analytics.topPlayer!.nickname, equals('Alice'));
      expect(analytics.topPlayer!.score, equals(9));

      // Player breakdown table entries
      expect(analytics.playerBreakdown.length, equals(2));
      expect(analytics.playerBreakdown.any((p) => p.nickname == 'Alice' && p.isPass), isTrue);
      expect(analytics.playerBreakdown.any((p) => p.nickname == 'Bob' && !p.isPass), isTrue);
    });
  });

  group('AdminHomeScreen 5-Tab Navigation Tests', () {
    testWidgets('Renders Live Metrics, Quick Actions Hub, and Navigates All 5 Tabs', (tester) async {
      final authVM = AuthViewModel();
      final themeProvider = ThemeProvider();
      final adminUser = UserModel(
        uid: 'admin_dashboard_tester',
        name: 'Chief Admin',
        nickname: 'ChiefAdmin',
        email: 'admin@quickquiz.com',
        role: 'admin',
        createdAt: DateTime.now(),
      );
      authVM.setCurrentUserForTesting(adminUser);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthViewModel>.value(value: authVM),
            ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ],
          child: const MaterialApp(
            home: AdminHomeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Title & Hygiene
      expect(find.text('ADMIN DASHBOARD'), findsOneWidget);
      expect(find.text('QuickQuiz Control Center • Ad-Free Mode'), findsOneWidget);

      // Tab 0: Home (Live Metrics & Quick Actions Hub)
      expect(find.text('Platform Live Metrics'), findsOneWidget);
      expect(find.text('Active Online'), findsOneWidget);
      expect(find.text('Total Scholars'), findsOneWidget);
      expect(find.text('Quizzes Today'), findsOneWidget);
      expect(find.text('Avg Accuracy'), findsOneWidget);

      expect(find.text('Quick Actions Hub'), findsOneWidget);
      expect(find.text('Create AI Quiz'), findsOneWidget); // Floating button erased on Home tab, now only in hub
      expect(find.text('Scholar Feedback'), findsWidgets); // Quick action button & 7-day tracker widget
      expect(find.text('Broadcast Alert'), findsOneWidget);

      // Bottom nav is present
      expect(find.byType(AdminBottomNavBar), findsOneWidget);

      // Switch to Tab 1: Created Quizzes
      await tester.tap(find.byIcon(Icons.auto_stories_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Created Quizzes & Deep-Dive Analytics'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('Archived'), findsOneWidget);

      // Switch to Tab 2: Scholars
      await tester.tap(find.byIcon(Icons.school_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Scholar Profiles & Moderation'), findsOneWidget);
      expect(find.text('Scholars & Leaderboard'), findsOneWidget);

      // Switch to Tab 3: Messages
      await tester.tap(find.byIcon(Icons.chat_bubble_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Scholar Inquiries & Support Messages'), findsOneWidget);
      expect(find.text('Scholar Support & Messages'), findsOneWidget);

      // Switch to Tab 4: Settings
      await tester.tap(find.byIcon(Icons.settings_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Security, Preferences & Platform Hygiene'), findsOneWidget);
      expect(find.text('Change Admin Password'), findsOneWidget);
      expect(find.text('Dark Theme'), findsOneWidget);
      expect(find.text('Sound Effects'), findsOneWidget);
    });
  });

  group('PreQuizConfirmationDialog & Difficulty Tiers Tests', () {
    testWidgets('Renders Easy Tier rules (Unlimited time, answer flexibility)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PreQuizConfirmationDialog(
              difficulty: QuizDifficulty.easy,
              quizTitle: 'Biology 101',
              questionCount: 5,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('UNLIMITED • EASY'), findsOneWidget);
      expect(find.text('Biology 101'), findsOneWidget);
      expect(find.text('Unlimited Time: No countdown timer. Proceed at your own pace.'), findsOneWidget);
      expect(find.text('Start Quiz'), findsOneWidget);
    });

    testWidgets('Renders Hard Tier rules (Strict Mode alert, locked answers)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PreQuizConfirmationDialog(
              difficulty: QuizDifficulty.hard,
              quizTitle: 'Quantum Mechanics',
              questionCount: 30,
              timeLimitSeconds: 600,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('STRICT MODE • HARD'), findsOneWidget);
      expect(find.text('Quantum Mechanics'), findsOneWidget);
      expect(find.text('NO CHANGING ANSWERS: Once you tap an option, your answer is permanently locked in!'), findsOneWidget);
      expect(find.text('No Hints Allowed: Strictly testing advanced recall and concepts.'), findsOneWidget);
      expect(find.text('Start Quiz'), findsOneWidget);
    });

    testWidgets('Confirmation button returns true and Cancel returns false', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await PreQuizConfirmationDialog.show(
                    context: context,
                    difficulty: QuizDifficulty.hard,
                    quizTitle: 'Calculus III',
                  );
                },
                child: const Text('Launch Modal'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Launch Modal'));
      await tester.pumpAndSettle();

      // Cancel button
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);

      // Re-open dialog
      await tester.tap(find.text('Launch Modal'));
      await tester.pumpAndSettle();

      // Confirm button
      expect(find.text('Start Quiz'), findsOneWidget);
      await tester.tap(find.text('Start Quiz'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });
  });

  group('QuizViewModel Strict Mode & Difficulty Mechanics Tests', () {
    test('Easy mode allows unlimited time and changing answers', () {
      final quiz = QuizModel(
        title: 'Easy Quiz',
        sourceFileName: 'notes.txt',
        difficulty: QuizDifficulty.easy,
        category: 'General',
        questions: [
          QuestionModel(
            question: 'What color is the sky?',
            options: ['Blue', 'Green', 'Red', 'Yellow'],
            correctAnswerIndex: 0,
            explanation: 'The sky appears blue.',
          ),
        ],
      );

      final vm = QuizViewModel(quiz);
      expect(vm.isCountdown, isFalse);
      expect(vm.formattedTime, equals('Unlimited'));

      // Select answer 0
      vm.selectAnswer(0);
      expect(vm.currentQuestion.selectedAnswerIndex, equals(0));
      expect(vm.isAnswerLocked, isFalse);

      // Change answer to 2 (allowed in easy mode)
      vm.selectAnswer(2);
      expect(vm.currentQuestion.selectedAnswerIndex, equals(2));

      vm.dispose();
    });

    test('Hard mode strictly locks answer once chosen', () {
      final quiz = QuizModel(
        title: 'Hard Quiz',
        sourceFileName: 'notes.txt',
        difficulty: QuizDifficulty.hard,
        category: 'Advanced',
        questions: [
          QuestionModel(
            question: 'What is Schrödinger equation?',
            options: ['Option A', 'Option B', 'Option C', 'Option D'],
            correctAnswerIndex: 0,
            explanation: 'Wave equation describing quantum state.',
          ),
        ],
      );

      final vm = QuizViewModel(quiz);
      expect(vm.isCountdown, isTrue);
      expect(vm.isAnswerLocked, isFalse);

      // First selection: select Option 1
      vm.selectAnswer(1);
      expect(vm.currentQuestion.selectedAnswerIndex, equals(1));
      expect(vm.isAnswerLocked, isTrue);

      // Attempt to change answer to Option 3 (STRICT MODE: must be blocked)
      vm.selectAnswer(3);
      expect(vm.currentQuestion.selectedAnswerIndex, equals(1)); // Still 1!

      // Attempt to change answer to Option 0 (STRICT MODE: must be blocked)
      vm.selectAnswer(0);
      expect(vm.currentQuestion.selectedAnswerIndex, equals(1)); // Still 1!

      vm.dispose();
    });
  });

  group('AiQuizStudioModal Overflow Protection & Controls Tests', () {
    testWidgets('Level Requirement Gate uses horizontal scroll and renders strictly 4 question count options', (tester) async {
      final authVM = AuthViewModel();
      final adminUser = UserModel(
        uid: 'admin_studio_test',
        name: 'Studio Admin',
        nickname: 'StudioAdmin',
        email: 'admin@quickquiz.com',
        role: 'admin',
        createdAt: DateTime.now(),
      );
      authVM.setCurrentUserForTesting(adminUser);

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<AuthViewModel>.value(
              value: authVM,
              child: AiQuizStudioModal(onPublished: () {}),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Title
      expect(find.text('AI Quiz Generator Studio'), findsOneWidget);
      expect(find.text('1. Document Drop Zone'), findsOneWidget);
      expect(find.text('2. Quiz Configuration & Gating'), findsOneWidget);

      // Level Requirement Gate
      expect(find.text('Level Requirement Gate:'), findsOneWidget);

      // Verify horizontal SingleChildScrollView wraps the ChoiceChips
      final horizontalScrollViewFinder = find.byWidgetPredicate(
        (widget) => widget is SingleChildScrollView && widget.scrollDirection == Axis.horizontal,
      );
      expect(horizontalScrollViewFinder, findsOneWidget);

      // Level gate ChoiceChips
      expect(find.text('Lvl 1+'), findsOneWidget);
      expect(find.text('Lvl 5+'), findsOneWidget);
      expect(find.text('Lvl 10+'), findsOneWidget);
      expect(find.text('Lvl 15+'), findsOneWidget);
      expect(find.text('Lvl 20+'), findsOneWidget);

      // Question count selector displays default 5 MCQs
      expect(find.text('5 MCQs'), findsOneWidget);

      // Open question count dropdown
      await tester.ensureVisible(find.text('5 MCQs'));
      await tester.tap(find.text('5 MCQs'));
      await tester.pumpAndSettle();

      // Verify strictly 4 options: 5, 10, 30, 50
      expect(find.text('5 MCQs'), findsWidgets);
      expect(find.text('10 MCQs'), findsWidgets);
      expect(find.text('30 MCQs'), findsWidgets);
      expect(find.text('50 MCQs'), findsWidgets);
    });
  });
}
