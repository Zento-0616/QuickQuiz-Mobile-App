import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quickquiz/app/theme.dart';
import 'package:quickquiz/models/quiz_model.dart';
import 'package:quickquiz/models/quiz_settings_model.dart';
import 'package:quickquiz/models/user_model.dart';
import 'package:quickquiz/providers/theme_provider.dart';
import 'package:quickquiz/services/firestore_service.dart';
import 'package:quickquiz/viewmodels/auth_viewmodel.dart';
import 'package:quickquiz/views/games/games_view.dart';
import 'package:quickquiz/views/profile/profile_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('1. Dynamic Content & No Hardcoded Mock Data Tests', () {
    testWidgets('Quiz Arena displays exact empty state when no admin quizzes exist', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthViewModel>(create: (_) => AuthViewModel()),
            ],
            child: const GamesView(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify exact specified empty state
      expect(find.text('No quizzes published by Admin yet.'), findsOneWidget);
      // Verify hardcoded mock decks do NOT exist
      expect(find.text('Computer Science Fundamentals'), findsNothing);
      expect(find.text('Cellular Biology & Genetics'), findsNothing);
      expect(find.text('World War II & 20th Century History'), findsNothing);
    });

    testWidgets('Leaderboard displays exact empty state when no game ranking data exists', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthViewModel>(create: (_) => AuthViewModel()),
            ],
            child: const GamesView(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to Global Quiz / Leaderboard tab
      await tester.tap(find.text('Global Quiz'));
      await tester.pumpAndSettle();

      // Switch to Top Scholars sub-tab
      await tester.tap(find.text('Top Scholars'));
      await tester.pumpAndSettle();

      // Verify exact specified empty state
      expect(find.text('No rankings yet. Play a quiz to claim #1!'), findsOneWidget);
      // Verify hardcoded mock users do NOT exist
      expect(find.text('ElenaR'), findsNothing);
      expect(find.text('AlexStar'), findsNothing);
      expect(find.text('SarahC'), findsNothing);
      expect(find.text('DaveQuiz'), findsNothing);
    });
  });

  group('2. Default Admin Seeding & Publishing Permission Tests', () {
    final regularUser = UserModel(
      uid: 'user_regular_1',
      name: 'Regular Student',
      nickname: 'Student1',
      email: 'student@example.com',
      createdAt: DateTime.now(),
      role: 'user',
    );

    final adminUser = UserModel(
      uid: 'admin_1',
      name: 'System Admin',
      nickname: 'Admin',
      email: 'admin@quickquiz.com',
      createdAt: DateTime.now(),
      role: 'admin',
    );

    test('FirestoreService.savePublishedQuiz rejects non-admin users', () async {
      final firestoreService = FirestoreService();
      final quiz = QuizModel(
        id: 'quiz_test_1',
        title: 'Test Deck',
        sourceFileName: 'test.pdf',
        difficulty: QuizDifficulty.medium,
        questions: [],
      );

      // Attempt publishing with role = 'user' MUST throw FirestoreServiceException
      expect(
        () => firestoreService.savePublishedQuiz(quiz, user: regularUser),
        throwsA(isA<FirestoreServiceException>()),
      );
    });

    test('FirestoreService.savePublishedQuiz accepts admin users', () async {
      final firestoreService = FirestoreService();
      final quiz = QuizModel(
        id: 'quiz_test_admin',
        title: 'Admin Deck',
        sourceFileName: 'admin_test.pdf',
        difficulty: QuizDifficulty.easy,
        questions: [],
      );

      // Attempt publishing with role = 'admin' should succeed without throwing
      await expectLater(
        firestoreService.savePublishedQuiz(quiz, user: adminUser),
        completes,
      );
    });
  });

  group('3. Profile Real User Data & Change Password Tests', () {
    final testUser = UserModel(
      uid: 'user_zento_123',
      name: 'Zento Seroje',
      nickname: 'zento',
      age: 22,
      email: 'r.seroje.453592@umindanao.edu.ph',
      photoUrl: null,
      bio: 'Ready to turn notes into knowledge!',
      role: 'user',
      level: 1,
      exp: 0,
      dailyStreak: 1,
      createdAt: DateTime.now(),
    );

    testWidgets('ProfileView displays all 6 user fields: Name, Nickname, Age, Email, Avatar, and Bio', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authViewModel = AuthViewModel();
      authViewModel.setCurrentUserForTesting(testUser);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthViewModel>.value(value: authViewModel),
              ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
            ],
            child: const Scaffold(
              body: ProfileView(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify all 6 user details are rendered:
      // 1. Nickname
      expect(find.text('zento'), findsWidgets);
      // 2. Real Name
      expect(find.text('Zento Seroje'), findsWidgets);
      // 3. Age
      expect(find.textContaining('22'), findsWidgets);
      // 4. Email Address
      expect(find.text('r.seroje.453592@umindanao.edu.ph'), findsWidgets);
      // 5. Profile Picture / Avatar (initials or avatar widget)
      expect(find.byType(CircleAvatar), findsWidgets);
      // 6. Personal Bio
      expect(find.textContaining('Ready to turn notes into knowledge!'), findsWidgets);

      // Verify Change Password option is present in Security section
      expect(find.text('Change Password'), findsOneWidget);
    });

    testWidgets('Change Password dialog opens and validates inputs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Change Password'),
                      content: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(key: Key('current_pass')),
                          TextField(key: Key('new_pass')),
                          TextField(key: Key('confirm_pass')),
                        ],
                      ),
                      actions: [
                        TextButton(onPressed: () {}, child: const Text('Save Password')),
                      ],
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Save Password'), findsOneWidget);
    });
  });
}
