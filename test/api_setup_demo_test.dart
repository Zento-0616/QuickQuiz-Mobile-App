import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickquiz/utils/constants.dart';
import 'package:quickquiz/widgets/api_setup_demo_dialog.dart';
import 'package:quickquiz/widgets/gemini_api_key_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Interactive API Setup Demo Tests', () {
    testWidgets('ApiSetupDemoDialog renders initial Google AI Studio demo scene and steps', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showApiSetupDemoDialog(context, initialProvider: AiProvider.gemini),
                child: const Text('Open Demo'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Demo'));
      await tester.pumpAndSettle();

      // Check dialog header
      expect(find.text('How to Set Your API Key'), findsOneWidget);
      expect(find.text('Interactive Step-by-Step Demo'), findsOneWidget);

      // Check step pills
      expect(find.text('Step 1'), findsOneWidget);
      expect(find.text('Step 2'), findsOneWidget);
      expect(find.text('Step 3'), findsOneWidget);
      expect(find.text('Step 4'), findsOneWidget);

      // Check scene 1 contents
      expect(find.text('Google AI Studio'), findsOneWidget);
      expect(find.text('Open Developer Studio'), findsOneWidget);

      // Step forward by tapping Step 2
      await tester.tap(find.text('Step 2'));
      await tester.pumpAndSettle();

      expect(find.text('Create Your API Key'), findsOneWidget);

      // Step forward to Step 3
      await tester.tap(find.text('Step 3'));
      await tester.pumpAndSettle();

      expect(find.text('Copy Your Secret Key'), findsOneWidget);

      // Step forward to Step 4
      await tester.tap(find.text('Step 4'));
      await tester.pumpAndSettle();

      expect(find.text('Paste & Save in QuickQuiz'), findsOneWidget);
    });

    testWidgets('ApiSetupDemoDialog switches provider demo to OpenAI and Groq', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showApiSetupDemoDialog(context),
                child: const Text('Open Demo'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Demo'));
      await tester.pumpAndSettle();

      // Switch to OpenAI provider
      await tester.tap(find.text('OpenAI'));
      await tester.pumpAndSettle();

      expect(find.text('Copy OpenAI Portal URL'), findsOneWidget);

      // Switch to DeepSeek provider
      await tester.tap(find.text('DeepSeek'));
      await tester.pumpAndSettle();

      expect(find.text('Copy DeepSeek Portal URL'), findsOneWidget);
    });

    testWidgets('GeminiApiKeyDialog launches ApiSetupDemoDialog when demo button tapped', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showGeminiApiKeyDialog(context),
                child: const Text('Open Key Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Key Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Watch Demo: How to Set Your API Key'), findsOneWidget);

      await tester.tap(find.text('Watch Demo: How to Set Your API Key'));
      await tester.pumpAndSettle();

      // Demo dialog is now open on top
      expect(find.text('How to Set Your API Key'), findsOneWidget);
      expect(find.text('Step 1'), findsOneWidget);
    });
  });
}
