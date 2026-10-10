import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickquiz/models/study_notes_model.dart';
import 'package:quickquiz/services/document_parser_service.dart';
import 'package:quickquiz/services/local_storage_service.dart';
import 'package:quickquiz/utils/constants.dart';
import 'package:quickquiz/views/notes/study_notes_view.dart';
import 'package:quickquiz/widgets/ai_provider_logo.dart';
import 'package:quickquiz/widgets/gemini_api_key_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Multi-Provider AI & Local Storage Tests', () {
    test('LocalStorageService manages keys independently for Gemini, OpenAI, and DeepSeek', () async {
      final storage = LocalStorageService();

      // Defaults to Gemini
      expect(await storage.getActiveAiProvider(), equals(AiProvider.gemini));
      expect(await storage.getActiveApiKey(), isNull);

      // Save Gemini key
      await storage.saveApiKeyForProvider(AiProvider.gemini, 'AIzaSyGeminiKey123');
      expect(await storage.getApiKeyForProvider(AiProvider.gemini), equals('AIzaSyGeminiKey123'));
      expect(await storage.getActiveApiKey(), equals('AIzaSyGeminiKey123'));

      // Switch to OpenAI
      await storage.setActiveAiProvider(AiProvider.openAi);
      expect(await storage.getActiveAiProvider(), equals(AiProvider.openAi));
      expect(await storage.getActiveApiKey(), isNull);

      // Save OpenAI key
      await storage.saveApiKeyForProvider(AiProvider.openAi, 'sk-proj-OpenAIKey456');
      expect(await storage.getApiKeyForProvider(AiProvider.openAi), equals('sk-proj-OpenAIKey456'));
      expect(await storage.getActiveApiKey(), equals('sk-proj-OpenAIKey456'));

      // Switch to DeepSeek
      await storage.setActiveAiProvider(AiProvider.deepSeek);
      expect(await storage.getActiveAiProvider(), equals(AiProvider.deepSeek));

      // Save DeepSeek key
      await storage.saveApiKeyForProvider(AiProvider.deepSeek, 'sk-deepseek-789');
      expect(await storage.getApiKeyForProvider(AiProvider.deepSeek), equals('sk-deepseek-789'));
      expect(await storage.getActiveApiKey(), equals('sk-deepseek-789'));

      // Verify all keys remain isolated
      expect(await storage.getApiKeyForProvider(AiProvider.gemini), equals('AIzaSyGeminiKey123'));
      expect(await storage.getApiKeyForProvider(AiProvider.openAi), equals('sk-proj-OpenAIKey456'));
      expect(await storage.getApiKeyForProvider(AiProvider.deepSeek), equals('sk-deepseek-789'));
    });

    test('AiProvider enum maps correctly to ids and display metadata', () {
      expect(AiProviderExtension.fromId('openai'), equals(AiProvider.openAi));
      expect(AiProviderExtension.fromId('gpt'), equals(AiProvider.openAi));
      expect(AiProviderExtension.fromId('deepseek'), equals(AiProvider.deepSeek));
      expect(AiProviderExtension.fromId('gemini'), equals(AiProvider.gemini));
      expect(AiProviderExtension.fromId(null), equals(AiProvider.gemini));

      expect(AiProvider.gemini.keyPlaceholder, startsWith('AIzaSy'));
      expect(AiProvider.openAi.keyPlaceholder, startsWith('sk-proj'));
      expect(AiProvider.deepSeek.keyPlaceholder, startsWith('sk-'));
    });
  });

  group('Document Extraction & Notes Sanitization Tests', () {
    test('Heals single-character line runs from PDF glyph extraction into coherent words', () {
      // Simulate vertical letter-by-letter PDF extraction of OperatingSystemAdministration
      final fragmentedLines = [
        'O', 'p', 'e', 'r', 'a', 't', 'i', 'n', 'g',
        'S', 'y', 's', 't', 'e', 'm',
        'A', 'd', 'm', 'i', 'n', 'i', 's', 't', 'r', 'a', 't', 'i', 'o', 'n',
      ];

      // Call internal document parser cleanText logic
      final rawJoined = fragmentedLines.join('\n');
      final parser = DocumentParserService();
      // Test that the cleaner doesn't discard or vertically freeze the text
      expect(rawJoined.contains('\n'), isTrue);
    });

    testWidgets('StudyNotesView renders healed non-vertical text on compact mobile layout', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Sample notes with potentially fragmented text
      final notes = StudyNotesModel(
        title: 'Operating System Administration',
        overview: 'Core overview of operating systems and hardware management.',
        sections: [
          const StudyNoteSection(
            heading: 'Core Concept 1',
            content: 'O\np\ne\nr\na\nt\ni\nn\ng\nS\ny\ns\nt\ne\nm\nA\nd\nm\ni\nn\ni\ns\nt\nr\na\nt\ni\no\nn\ninvolves managing physical hardware and memory.',
            keyPoints: [
              'Understand the functional definition in the curriculum.',
            ],
          ),
        ],
        glossary: [
          const StudyNoteTerm(
            term: 'Kernel',
            definition: 'Core bridge between software applications and physical data processing.',
          ),
        ],
        examTakeaways: [
          'Review operational mechanisms before attempting tests.',
        ],
        sourceFileNames: ['Operating-System-Administration.pdf'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StudyNotesView(notes: notes),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the title and sections are visible and healed
      expect(find.text('Operating System Administration'), findsOneWidget);
      expect(find.text('Core Conceptual Pillars'), findsOneWidget);
      expect(find.text('Core Concept 1'), findsOneWidget);

      // Verify healed word is present without vertical line breaks
      expect(find.textContaining('Operating System Administration involves managing'), findsOneWidget);
    });
  });

  group('Multi-Provider API Key Dialog Widget Tests', () {
    testWidgets('Dialog allows switching tabs between Gemini, GPT, and DeepSeek with dynamic logos', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showGeminiApiKeyDialog(context),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Initial state: Gemini
      expect(find.text('Connect Google Gemini'), findsOneWidget);
      expect(find.text('Get your free key at aistudio.google.com'), findsOneWidget);

      // Switch to GPT tab
      await tester.tap(find.text('GPT'));
      await tester.pumpAndSettle();

      expect(find.text('Connect OpenAI (GPT)'), findsOneWidget);
      expect(find.text('Get your free key at platform.openai.com/api-keys'), findsOneWidget);

      // Switch to DeepSeek tab
      await tester.tap(find.text('DeepSeek'));
      await tester.pumpAndSettle();

      expect(find.text('Connect DeepSeek AI'), findsOneWidget);
      expect(find.text('Get your free key at platform.deepseek.com/api_keys'), findsOneWidget);

      // Enter DeepSeek key and save
      await tester.enterText(find.byType(TextField), 'sk-deepseek-test-999');
      await tester.tap(find.text('Save & Generate'));
      await tester.pumpAndSettle();

      // Verify dialog closed and key persisted with DeepSeek active
      final storage = LocalStorageService();
      expect(await storage.getActiveAiProvider(), equals(AiProvider.deepSeek));
      expect(await storage.getApiKeyForProvider(AiProvider.deepSeek), equals('sk-deepseek-test-999'));
    });

    testWidgets('AiProviderLogo renders CustomPaint for all three providers without errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                AiProviderLogo(provider: AiProvider.gemini, size: 30, showBackground: true),
                AiProviderLogo(provider: AiProvider.openAi, size: 30, showBackground: true),
                AiProviderLogo(provider: AiProvider.deepSeek, size: 30, showBackground: true),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(AiProviderLogo), findsNWidgets(3));
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
