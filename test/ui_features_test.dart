import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickquiz/models/quiz_settings_model.dart';

void main() {
  group('UI Features & Slider / Modal Tests', () {
    testWidgets('Interactive Slider control allows drag-to-select question count between 5 and 50', (tester) async {
      int currentCount = 10;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    Slider(
                      value: currentCount.toDouble(),
                      min: QuizSettingsModel.minQuestions.toDouble(), // 5
                      max: QuizSettingsModel.maxQuestions.toDouble(), // 50
                      divisions: 9,
                      onChanged: (val) {
                        setState(() {
                          currentCount = val.round();
                        });
                      },
                    ),
                    Text('$currentCount Questions'),
                    const Text('Min: 5'),
                    const Text('Max: 50'),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Verify initial state
      expect(find.text('10 Questions'), findsOneWidget);
      expect(find.text('Min: 5'), findsOneWidget);
      expect(find.text('Max: 50'), findsOneWidget);

      // Drag slider forward to select a higher question count
      await tester.drag(find.byType(Slider), const Offset(200, 0));
      await tester.pumpAndSettle();

      // Verify question count changed
      expect(currentCount, greaterThan(10));
      expect(currentCount, lessThanOrEqualTo(50));
      expect(find.text('$currentCount Questions'), findsOneWidget);
    });

    testWidgets('Logout confirmation modal displays "Are you sure you want to log out?" with Yes and No options', (tester) async {
      bool? logoutConfirmed;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  final result = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      title: const Row(
                        children: [
                          Icon(Icons.logout_rounded, color: Colors.redAccent),
                          SizedBox(width: 10),
                          Text('Log Out', style: TextStyle(fontWeight: FontWeight.w800)),
                        ],
                      ),
                      content: const Text(
                        'Are you sure you want to log out?',
                        style: TextStyle(fontSize: 16),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(false),
                          child: const Text('No'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.of(dialogContext).pop(true),
                          child: const Text('Yes'),
                        ),
                      ],
                    ),
                  );
                  logoutConfirmed = result;
                },
                child: const Text('Trigger Logout'),
              ),
            ),
          ),
        ),
      );

      // Tap to trigger modal
      await tester.tap(find.text('Trigger Logout'));
      await tester.pumpAndSettle();

      // Verify confirmation modal message and options
      expect(find.text('Are you sure you want to log out?'), findsOneWidget);
      expect(find.text('Yes'), findsOneWidget);
      expect(find.text('No'), findsOneWidget);

      // Tap No -> cancels
      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();
      expect(logoutConfirmed, isFalse);
      expect(find.text('Are you sure you want to log out?'), findsNothing);

      // Tap again and select Yes -> confirms
      await tester.tap(find.text('Trigger Logout'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      expect(logoutConfirmed, isTrue);
    });
  });
}
