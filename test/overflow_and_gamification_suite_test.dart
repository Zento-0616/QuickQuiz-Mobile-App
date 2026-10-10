import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quickquiz/app/theme.dart';
import 'package:quickquiz/controllers/inbox_notification_controller.dart';
import 'package:quickquiz/models/admin_settings_model.dart';
import 'package:quickquiz/models/broadcast_alert_model.dart';
import 'package:quickquiz/models/user_model.dart';
import 'package:quickquiz/services/progression_service.dart';
import 'package:quickquiz/viewmodels/auth_viewmodel.dart';
import 'package:quickquiz/views/admin/admin_settings_screen.dart';
import 'package:quickquiz/widgets/admin_bottom_nav.dart';
import 'package:quickquiz/widgets/scholar_feedback_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('1. Layout & UI Overflow Fixes Tests', () {
    testWidgets('ScholarFeedbackDialog renders without overflow on narrow 320px screen', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ScholarFeedbackDialog.show(context),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify dialog header and components exist without throwing FlutterError overflow
      expect(find.text('Scholar Feedback'), findsOneWidget);
      expect(find.text('Suggestion'), findsOneWidget);
      expect(find.text('Issue Report'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Submit Feedback'), findsOneWidget);
    });

    testWidgets('AdminBottomNavBar renders all 7 tabs without overflow on 320px width', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      AdminTab selected = AdminTab.home;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AdminBottomNavBar(
              currentTab: selected,
              onTabSelected: (tab) => selected = tab,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify all 7 tabs render
      expect(find.byIcon(Icons.dashboard_rounded), findsOneWidget);
      expect(find.byIcon(Icons.auto_stories_rounded), findsOneWidget);
      expect(find.byIcon(Icons.school_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_rounded), findsOneWidget);
      expect(find.byIcon(Icons.rate_review_rounded), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
    });
  });

  group('2. Interactive Inbox & Notification Badge Clearing Tests', () {
    test('InboxNotificationController calculates unread badge and clears on markAsRead', () async {
      final controller = InboxNotificationController();
      const userId = 'scholar_456';

      final alert1 = BroadcastAlertModel(
        id: 'alert_1',
        title: 'New Event',
        message: 'Tournament is live!',
        createdAt: DateTime.now(),
        readByUsers: [],
      );

      final alert2 = BroadcastAlertModel(
        id: 'alert_2',
        title: 'Welcome',
        message: 'Welcome to QuickQuiz!',
        createdAt: DateTime.now(),
        readByUsers: [userId], // Already read by this user
      );

      controller.setInboxData(alerts: [alert1, alert2], requests: []);

      // Initial state: alert1 is unread, alert2 is read
      expect(controller.unreadTotalCount(userId), equals(1));
      expect(controller.getTabTitle(userId), equals('Inbox (1)'));

      // Mark alert1 as read
      await controller.markAlertAsRead(alertId: 'alert_1', userId: userId);

      // Verify immediate badge clearing
      expect(controller.unreadTotalCount(userId), equals(0));
      expect(controller.getTabTitle(userId), equals('Inbox'));
    });
  });

  group('3. Admin EXP Control Panel & Progression Mechanics Tests', () {
    test('AdminSettingsModel loads defaults and persists changes', () async {
      final initial = await AdminSettingsModel.loadSettings();
      expect(initial.repeatQuizExpEnabled, isFalse);
      expect(initial.dailyExpCap, equals(500));

      // Save updated settings
      final updated = AdminSettingsModel(
        repeatQuizExpEnabled: true,
        dailyExpCap: 1000,
      );
      await updated.saveSettings();

      final reloaded = await AdminSettingsModel.loadSettings();
      expect(reloaded.repeatQuizExpEnabled, isTrue);
      expect(reloaded.dailyExpCap, equals(1000));
    });

    test('ProgressionService respects Repeat Quiz EXP Disabled toggle', () {
      final testUser = UserModel(
        uid: 'user_1',
        name: 'Alex Scholar',
        email: 'alex@example.com',
        createdAt: DateTime.now(),
        completedOfficialQuizIds: ['official_quiz_101'],
      );

      // Repeat quiz when repeatExpEnabled is false -> Earns 0 EXP
      final resultRepeatDisabled = ProgressionService.processQuizCompletion(
        user: testUser,
        questionCount: 10,
        correctCount: 10,
        isRepeat: true,
        repeatExpEnabled: false,
      );

      expect(resultRepeatDisabled.earnedExp, equals(0));

      // Repeat quiz when repeatExpEnabled is true -> Earns regular EXP
      final resultRepeatEnabled = ProgressionService.processQuizCompletion(
        user: testUser,
        questionCount: 10,
        correctCount: 10,
        isRepeat: true,
        repeatExpEnabled: true,
      );

      expect(resultRepeatEnabled.earnedExp, greaterThan(0));
    });

    test('ProgressionService clamps EXP gain to Daily EXP Cap', () {
      final testUser = UserModel(
        uid: 'user_2',
        name: 'Sam Scholar',
        email: 'sam@example.com',
        createdAt: DateTime.now(),
      );

      // Daily cap is 500, already earned 450 today
      final result = ProgressionService.processQuizCompletion(
        user: testUser,
        questionCount: 20,
        correctCount: 20, // would normally yield 200+ EXP
        dailyExpCap: 500,
        currentDailyExp: 450,
      );

      // Should be clamped to 50 (500 - 450)
      expect(result.earnedExp, equals(50));
    });

    testWidgets('AdminSettingsScreen renders EXP controls and allows toggling', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: AdminSettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Repeat Quiz EXP Gain'), findsNothing);
      expect(find.text('Daily Scholar EXP Cap'), findsOneWidget);
      expect(find.text('Day 1'), findsOneWidget);

      await tester.ensureVisible(find.text('Save Daily Scholar EXP Caps'));
      expect(find.text('Save Daily Scholar EXP Caps'), findsOneWidget);

      // Tap preset chip 1000
      await tester.ensureVisible(find.text('1000 EXP'));
      await tester.tap(find.text('1000 EXP'));
      await tester.pumpAndSettle();

      // Tap Save
      await tester.ensureVisible(find.text('Save Daily Scholar EXP Caps'));
      await tester.tap(find.text('Save Daily Scholar EXP Caps'));
      await tester.pumpAndSettle();

      final saved = await AdminSettingsModel.loadSettings();
      expect(saved.dailyExpCap, equals(1000));
    });
  });

  group('4. User Region Flags & Guest Hygiene Tests', () {
    test('UserModel converts country code to Unicode Flag Emoji', () {
      final userUS = UserModel(uid: '1', name: 'US', email: '1@a.com', createdAt: DateTime.now(), region: 'US');
      final userPH = UserModel(uid: '2', name: 'PH', email: '2@a.com', createdAt: DateTime.now(), region: 'PH');
      final userGB = UserModel(uid: '3', name: 'GB', email: '3@a.com', createdAt: DateTime.now(), region: 'GB');
      final userInvalid = UserModel(uid: '4', name: 'Inv', email: '4@a.com', createdAt: DateTime.now(), region: 'XYZ');

      expect(userUS.regionFlag, equals('🇺🇸'));
      expect(userPH.regionFlag, equals('🇵🇭'));
      expect(userGB.regionFlag, equals('🇬🇧'));
      expect(userInvalid.regionFlag, equals('🌐'));
    });

    test('Guest users are flagged and excluded from EXP gains in AuthViewModel', () async {
      final authVM = AuthViewModel();
      final guest = UserModel(
        uid: 'guest_test_999',
        name: 'Guest User',
        email: 'guest_test_999@guest.quickquiz.app',
        role: 'user',
        exp: 0,
        level: 1,
        createdAt: DateTime.now(),
      );

      expect(guest.isGuest, isTrue);

      authVM.setCurrentUserForTesting(guest);
      await authVM.recordQuizExp(questionCount: 10, correctCount: 10);

      // Guest remains at 0 EXP
      expect(authVM.currentUser!.exp, equals(0));
    });
  });
}
