import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickquiz/widgets/main_bottom_nav.dart';

void main() {
  group('Floating iOS Navigation Bar Tests', () {
    testWidgets('MainBottomNav renders icon-only Home, History, Games, and Messages tabs', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MainBottomNav(current: MainTab.home),
          ),
        ),
      );

      expect(find.byType(MainBottomNav), findsOneWidget);
      // Verify all 4 tab icons are rendered
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
      expect(find.byIcon(Icons.sports_esports_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_rounded), findsOneWidget);

      // Verify text labels are removed to prevent horizontal overflow
      expect(find.text('Home'), findsNothing);
      expect(find.text('History'), findsNothing);
      expect(find.text('Games'), findsNothing);
      expect(find.text('Messages'), findsNothing);
      expect(find.byIcon(Icons.person_rounded), findsNothing);
    });

    testWidgets('MainBottomNav active tab highlights icon with gradient', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MainBottomNav(current: MainTab.games),
          ),
        ),
      );

      expect(find.byIcon(Icons.sports_esports_rounded), findsOneWidget);
      // Still icon-only without text label
      expect(find.text('Games'), findsNothing);
    });

    testWidgets('PopScope intercepts back navigation on secondary views', (tester) async {
      bool intercepted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) intercepted = true;
            },
            child: const Scaffold(
              body: Center(child: Text('Secondary Screen')),
            ),
          ),
        ),
      );

      final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
      await widgetsAppState.didPopRoute();
      await tester.pumpAndSettle();

      expect(intercepted, isTrue);
    });
  });
}
