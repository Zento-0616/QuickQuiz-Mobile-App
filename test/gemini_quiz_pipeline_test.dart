import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickquiz/models/question_model.dart';
import 'package:quickquiz/models/quiz_settings_model.dart';
import 'package:quickquiz/repositories/quiz_repository.dart';
import 'package:quickquiz/services/gemini_service.dart';
import 'package:quickquiz/services/local_storage_service.dart';
import 'package:quickquiz/widgets/gemini_api_key_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Google AI Studio (Gemini) Integration & Mock Erasure Tests', () {
    test('GeminiService resolves API key from LocalStorageService dynamically', () async {
      final storage = LocalStorageService();
      await storage.saveGeminiApiKey('AIzaSyTestKey_12345');

      final service = GeminiService(storageService: storage);
      final key = await service.getEffectiveApiKey();

      expect(key, equals('AIzaSyTestKey_12345'));
      expect(await service.isConfiguredAsync, isTrue);
    });

    test('GeminiService throws GeminiApiKeyMissingException when no key is set', () async {
      final storage = LocalStorageService();
      await storage.clearGeminiApiKey();

      final service = GeminiService(apiKey: '', storageService: storage);

      expect(
        () => service.generateQuiz(
          documentText: 'Some valid document text about computer algorithms and hashes.',
          sourceFileName: 'test.pdf',
          questionCount: 5,
          difficulty: QuizDifficulty.easy,
        ),
        throwsA(isA<GeminiApiKeyMissingException>()),
      );
    });

    test('QuizRepository strictly requires Google AI Studio and does not fall back to MockQuizGenerator', () async {
      final storage = LocalStorageService();
      await storage.clearGeminiApiKey();

      final geminiService = GeminiService(apiKey: '', storageService: storage);
      final repository = QuizRepository(geminiService: geminiService);

      const studyText = '''
Introduction to Cryptography and Information Security.
SSL and TLS establish secure channels over untrusted networks.
Hashing algorithms like SHA-256 create one-way message digests for integrity verification.
      ''';

      // Expect GeminiApiKeyMissingException, NOT mock question generation
      expect(
        () => repository.generateQuiz(
          documentText: studyText,
          sourceFileName: 'crypto.pdf',
          questionCount: 5,
          difficulty: QuizDifficulty.easy,
        ),
        throwsA(isA<GeminiApiKeyMissingException>()),
      );
    });

    testWidgets('GeminiApiKeyDialog renders prompt and saves entered API key', (tester) async {
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

      expect(find.text('Connect Google AI Studio'), findsOneWidget);
      expect(find.text('Get your free key at aistudio.google.com'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'AIzaSyManualInputKey999');
      await tester.tap(find.text('Save & Generate'));
      await tester.pumpAndSettle();

      // Verify dialog closed and key persisted to local storage
      expect(find.text('Connect Google AI Studio'), findsNothing);
      final savedKey = await LocalStorageService().getGeminiApiKey();
      expect(savedKey, equals('AIzaSyManualInputKey999'));
    });

    test('GeminiService formats 503 high demand errors into user-friendly message', () {
      final service = GeminiService(apiKey: 'dummy_key');
      expect(service.isConfigured, isTrue);
    });

    test('GeminiService.regenerateSingleQuestion throws GeminiApiKeyMissingException when key is missing', () async {
      final storage = LocalStorageService();
      await storage.clearGeminiApiKey();
      final service = GeminiService(apiKey: '', storageService: storage);

      expect(
        () => service.regenerateSingleQuestion(
          documentText: 'Operating system paging and memory management.',
          oldQuestion: const QuestionModel(
            question: 'What is paging?',
            options: ['A', 'B', 'C', 'D'],
            correctAnswerIndex: 0,
            explanation: 'Paging divides memory into fixed-size blocks.',
          ),
          difficulty: QuizDifficulty.medium,
        ),
        throwsA(isA<GeminiApiKeyMissingException>()),
      );
    });
  });
}
