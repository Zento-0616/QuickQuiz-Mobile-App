import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quickquiz/app/theme.dart';
import 'package:quickquiz/models/feedback_model.dart';
import 'package:quickquiz/viewmodels/auth_viewmodel.dart';
import 'package:quickquiz/views/admin/admin_settings_screen.dart';
import 'package:quickquiz/views/auth/auth_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UI/UX Enhancements & Bug Fixes Tests', () {
    testWidgets('1. AdminSettingsScreen excludes Repeat Quiz EXP and has NO horizontal overflow on 320px screen', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
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

      // Repeat Quiz EXP Gain must be deleted
      expect(find.text('Repeat Quiz EXP Gain'), findsNothing);

      // Daily EXP Cap must be present
      expect(find.text('Daily Scholar EXP Cap'), findsOneWidget);

      // Verify no FlutterError overflow occurred on narrow 320px screen
      expect(tester.takeException(), isNull);
    });

    testWidgets('2. AuthView renders official Google SVG logo and visible Sign In controls', (tester) async {
      final authVM = AuthViewModel();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthViewModel>.value(value: authVM),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const AuthView(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Sign In tab and button must be clearly rendered
      expect(find.text('Sign In'), findsAtLeastNWidgets(2)); // Tab and button
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);

      // Google SVG icon must be present in the tree
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('3. FeedbackModel respects resolved state and does not reopen', () {
      final feedback = FeedbackModel(
        id: 'fb-1',
        userId: 'user-1',
        userName: 'Zento',
        userEmail: 'zento@example.com',
        type: 'issue_report',
        title: 'Overflow bug',
        message: 'Fixed and verified',
        status: 'resolved',
        createdAt: DateTime.now(),
      );

      expect(feedback.isResolved, isTrue);
      // Status remains resolved
      expect(feedback.status, equals('resolved'));
    });
  });
}
