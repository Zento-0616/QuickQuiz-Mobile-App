import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickquiz/views/splash/splash_view.dart';
import 'package:quickquiz/widgets/banner_ad_widget.dart';
import 'package:quickquiz/widgets/interstitial_ad_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BannerAdWidget & InterstitialAdDialog Visual Tests', () {
    testWidgets('BannerAdWidget renders fallback test banner when native ad is not loaded', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BannerAdWidget(isVisible: true),
          ),
        ),
      );

      // Verify that the AD badge and sponsor text are clearly visible
      expect(find.text('AD'), findsOneWidget);
      expect(find.text('QuickQuiz Study Sponsor'), findsOneWidget);
      expect(find.text('Learn More'), findsOneWidget);
    });

    testWidgets('InterstitialAdDialog displays countdown timer, sponsor content, and dismisses', (tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  InterstitialAdDialog.show(
                    context,
                    onDismissed: () {
                      dismissed = true;
                    },
                    autoDismissDuration: const Duration(seconds: 2),
                  );
                },
                child: const Text('Show Ad'),
              ),
            ),
          ),
        ),
      );

      // Tap to open ad
      await tester.tap(find.text('Show Ad'));
      await tester.pump(); // Start frame
      await tester.pump(const Duration(milliseconds: 100)); // Render dialog

      expect(find.text('ADVERTISEMENT'), findsOneWidget);
      expect(find.text('QuickQuiz Pro Sponsor'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Advance time by 2 seconds to trigger auto-dismissal
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });

    testWidgets('SplashView displays QuickQuiz logo, branding, and animated status text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashView(
            minDuration: Duration(milliseconds: 500),
          ),
        ),
      );

      // Initial frame
      await tester.pump();

      // Verify branding and logo
      expect(find.text('QuickQuiz'), findsOneWidget);
      expect(find.text('AI-POWERED EXAM PREPARATION'), findsOneWidget);
      expect(find.text('Initializing QuickQuiz...'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);

      // Advance clock slightly
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('QuickQuiz'), findsOneWidget);

      // Finish out timer
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('SplashView has 5-6s default duration and advances staged loading micro-copy', (tester) async {
      const splash = SplashView();
      // Default duration is between 5 and 6 seconds
      expect(splash.minDuration.inMilliseconds, greaterThanOrEqualTo(5000));
      expect(splash.minDuration.inMilliseconds, lessThanOrEqualTo(6000));

      await tester.pumpWidget(
        const MaterialApp(
          home: SplashView(
            minDuration: Duration(milliseconds: 5500),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Initializing QuickQuiz...'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);

      // Advance through loading progression (1800ms -> p = ~0.33, in 0.20-0.42 stage)
      await tester.pump(const Duration(milliseconds: 1800));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Warming up AI engine & study modules...'), findsOneWidget);

      // Advance further (1000ms -> p = ~0.51, in 0.42-0.65 stage)
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Preparing smart flashcards & quizzes...'), findsOneWidget);

      // Advance to end of splash duration
      await tester.pump(const Duration(milliseconds: 2500));
    });
  });
}
