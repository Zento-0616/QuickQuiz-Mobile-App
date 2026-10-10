import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickquiz/models/chess_game_model.dart';
import 'package:quickquiz/models/dama_game_model.dart';
import 'package:quickquiz/models/study_notes_model.dart';
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

  group('Multi-Provider AI Expansion Tests (Grok, Groq, Anthropic)', () {
    test('LocalStorageService manages keys independently for all 6 providers', () async {
      final storage = LocalStorageService();

      // Verify defaults
      expect(await storage.getActiveAiProvider(), equals(AiProvider.gemini));
      expect(await storage.getActiveApiKey(), isNull);

      // Grok
      await storage.saveApiKeyForProvider(AiProvider.grok, 'xai-test-grok-123');
      expect(await storage.getApiKeyForProvider(AiProvider.grok), equals('xai-test-grok-123'));

      // Groq
      await storage.saveApiKeyForProvider(AiProvider.groq, 'gsk_test_groq_456');
      expect(await storage.getApiKeyForProvider(AiProvider.groq), equals('gsk_test_groq_456'));

      // Anthropic
      await storage.saveApiKeyForProvider(AiProvider.anthropic, 'sk-ant-api03-test-789');
      expect(await storage.getApiKeyForProvider(AiProvider.anthropic), equals('sk-ant-api03-test-789'));

      // Active provider switching
      await storage.setActiveAiProvider(AiProvider.grok);
      expect(await storage.getActiveApiKey(), equals('xai-test-grok-123'));

      await storage.setActiveAiProvider(AiProvider.groq);
      expect(await storage.getActiveApiKey(), equals('gsk_test_groq_456'));

      await storage.setActiveAiProvider(AiProvider.anthropic);
      expect(await storage.getActiveApiKey(), equals('sk-ant-api03-test-789'));

      // Isolation check
      expect(await storage.getApiKeyForProvider(AiProvider.gemini), isNull);
      expect(await storage.getApiKeyForProvider(AiProvider.openAi), isNull);
      expect(await storage.getApiKeyForProvider(AiProvider.deepSeek), isNull);
    });

    test('AiProvider enum maps IDs, names, models, and placeholders accurately', () {
      expect(AiProviderExtension.fromId('grok'), equals(AiProvider.grok));
      expect(AiProviderExtension.fromId('xai'), equals(AiProvider.grok));
      expect(AiProviderExtension.fromId('groq'), equals(AiProvider.groq));
      expect(AiProviderExtension.fromId('anthropic'), equals(AiProvider.anthropic));
      expect(AiProviderExtension.fromId('claude'), equals(AiProvider.anthropic));

      expect(AiProvider.grok.keyPlaceholder, startsWith('xai-'));
      expect(AiProvider.groq.keyPlaceholder, startsWith('gsk_'));
      expect(AiProvider.anthropic.keyPlaceholder, startsWith('sk-ant-'));

      expect(AiProvider.grok.modelName, equals('Grok-2'));
      expect(AiProvider.groq.modelName, equals('Llama 3.3 70B'));
      expect(AiProvider.anthropic.modelName, equals('Claude 3.5 Sonnet'));
    });

    testWidgets('AiProviderLogo renders all 6 provider painters correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                AiProviderLogo(provider: AiProvider.gemini, size: 28),
                AiProviderLogo(provider: AiProvider.openAi, size: 28),
                AiProviderLogo(provider: AiProvider.deepSeek, size: 28),
                AiProviderLogo(provider: AiProvider.grok, size: 28),
                AiProviderLogo(provider: AiProvider.groq, size: 28),
                AiProviderLogo(provider: AiProvider.anthropic, size: 28),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(AiProviderLogo), findsNWidgets(6));
      expect(tester.takeException(), isNull);
    });

    testWidgets('GeminiApiKeyDialog supports Grok, Groq, and Claude tabs', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

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

      // Tap Grok chip
      await tester.tap(find.text('Grok'));
      await tester.pumpAndSettle();
      expect(find.text('Connect xAI (Grok)'), findsOneWidget);

      // Tap Groq chip
      await tester.tap(find.text('Groq'));
      await tester.pumpAndSettle();
      expect(find.text('Connect Groq Cloud'), findsOneWidget);

      // Tap Claude chip
      await tester.tap(find.text('Claude'));
      await tester.pumpAndSettle();
      expect(find.text('Connect Anthropic (Claude)'), findsOneWidget);

      // Enter Anthropic key and save
      await tester.enterText(find.byType(TextField), 'sk-ant-test-key-555');
      await tester.tap(find.text('Save & Generate'));
      await tester.pumpAndSettle();

      final storage = LocalStorageService();
      expect(await storage.getActiveAiProvider(), equals(AiProvider.anthropic));
      expect(await storage.getApiKeyForProvider(AiProvider.anthropic), equals('sk-ant-test-key-555'));
    });
  });

  group('Easy-to-Study Note Format Tests', () {
    test('StudyNoteSection serializes and parses 8-part format', () {
      const section = StudyNoteSection(
        heading: 'Flutter Widgets',
        content: 'Building blocks of Flutter apps.',
        definition: 'A widget is an immutable description of part of a user interface.',
        purpose: 'Used to construct reactive, high-performance cross-platform UIs.',
        keyPoints: [
          'Everything in Flutter is a widget',
          'StatelessWidget for static UI',
          'StatefulWidget for dynamic UI',
        ],
        example: 'Text("Hello World"), Container(color: Colors.blue)',
        comparison: 'Stateless (No internal mutable state) vs Stateful (Has dynamic state)',
        rememberThis: 'Widgets are immutable; state is kept in State objects!',
        examQuestion: 'Q: What is the base class for UI components in Flutter?\nA: Widget.',
      );

      final map = section.toJson();
      expect(map['definition'], equals(section.definition));
      expect(map['purpose'], equals(section.purpose));
      expect(map['example'], equals(section.example));
      expect(map['comparison'], equals(section.comparison));
      expect(map['rememberThis'], equals(section.rememberThis));
      expect(map['examQuestion'], equals(section.examQuestion));

      final restored = StudyNoteSection.fromJson(map);
      expect(restored.definition, equals(section.definition));
      expect(restored.purpose, equals(section.purpose));
      expect(restored.example, equals(section.example));
      expect(restored.comparison, equals(section.comparison));
      expect(restored.rememberThis, equals(section.rememberThis));
      expect(restored.examQuestion, equals(section.examQuestion));
    });

    test('StudyNotesModel toMarkdown outputs strict 8-part structured format', () {
      final notes = StudyNotesModel(
        title: 'Flutter Architecture',
        overview: 'Comprehensive review of Flutter reactive architecture.',
        sections: [
          const StudyNoteSection(
            heading: 'State Management',
            content: 'How UI reflects state changes.',
            definition: 'State is data that can change over time.',
            purpose: 'Keeps the visual display synchronized with underlying data models.',
            keyPoints: [
              'Ephemeral state vs App state',
              'Provider, Riverpod, or Bloc for scalable apps',
            ],
            example: 'Counter incrementing with setState(() => _counter++)',
            comparison: 'Local State (Widget only) vs Global State (Entire app)',
            rememberThis: 'Rebuild only what needs rebuilding for optimal performance.',
            examQuestion: 'Q: What method triggers a rebuild in a StatefulWidget?\nA: setState().',
          ),
        ],
        sourceFileNames: ['flutter_arch.pdf'],
      );

      final md = notes.toMarkdown();
      expect(md, contains('### 1. State Management'));
      expect(md, contains('**Definition:**'));
      expect(md, contains('State is data that can change over time.'));
      expect(md, contains('**Purpose / Function:**'));
      expect(md, contains('👉 Keeps the visual display synchronized'));
      expect(md, contains('**Key Points:**'));
      expect(md, contains('**Example:**'));
      expect(md, contains('**Difference / Comparison:**'));
      expect(md, contains('**Remember ⭐:**'));
      expect(md, contains('**Possible Exam Question:**'));
      expect(md, contains('Q: What method triggers a rebuild in a StatefulWidget?'));
    });

    testWidgets('StudyNotesView renders all 8-part cards clearly', (tester) async {
      tester.view.physicalSize = const Size(380, 750);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final notes = StudyNotesModel(
        title: 'Easy Study Notes Demo',
        overview: 'Testing the 8-part structured visual layout.',
        sections: [
          const StudyNoteSection(
            heading: 'Async Await in Dart',
            content: 'Asynchronous programming model.',
            definition: 'A way to write non-blocking asynchronous code.',
            purpose: 'Prevents freezing the user interface during network or disk I/O.',
            keyPoints: [
              'Returns a Future',
              'await can only be used inside async functions',
            ],
            example: 'final data = await http.get(url);',
            comparison: 'Future.then() (Callback based) vs async/await (Synchronous style)',
            rememberThis: 'Always handle errors with try/catch when using await.',
            examQuestion: 'Q: What does an async function return?\nA: A Future.',
          ),
        ],
        sourceFileNames: ['dart_async.pdf'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StudyNotesView(notes: notes),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Async Await in Dart'), findsOneWidget);
      expect(find.text('Definition:'), findsOneWidget);
      expect(find.text('Key Points:'), findsOneWidget);
      expect(find.text('Possible Exam Question:'), findsOneWidget);
      expect(find.textContaining('A way to write non-blocking asynchronous code'), findsOneWidget);
      expect(
        find.byWidgetPredicate((widget) =>
            widget is RichText && widget.text.toPlainText().contains('Prevents freezing the user interface')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((widget) =>
            widget is RichText && widget.text.toPlainText().contains('Always handle errors with try/catch')),
        findsOneWidget,
      );
    });
  });

  group('Board Game Enhancements: Deadlock & Light Effects', () {
    test('ChessBoard detects run-and-hide deadlock and insufficient material', () {
      final board = ChessBoard();

      // Initially neither is true
      expect(board.halfmoveClock, equals(0));
      expect(board.isDeadlockOrRunAndHide(), isFalse);
      expect(board.isInsufficientMaterial(), isFalse);

      // Simulate 30 half-moves (15 moves each) with knights shuffling back and forth (no captures, no pawns)
      board.halfmoveClock = 30;
      expect(board.isDeadlockOrRunAndHide(), isTrue);

      // Pawn move resets halfmove clock
      const pawnMove = ChessMove(
        fromRow: 6,
        fromCol: 4,
        toRow: 4,
        toCol: 4,
      );
      board.makeMove(pawnMove);
      expect(board.halfmoveClock, equals(0));

      // Test Insufficient material (bare kings)
      board.grid = List.generate(8, (_) => List.generate(8, (_) => null));
      board.grid[0][4] = ChessPiece(type: ChessPieceType.king, player: 2);
      board.grid[7][4] = ChessPiece(type: ChessPieceType.king, player: 1);
      expect(board.isInsufficientMaterial(), isTrue);
      expect(board.isDeadlockOrRunAndHide(), isTrue);
    });

    test('DamaBoard tracks consecutive non-capture moves and detects run-and-hide', () {
      final board = DamaBoard();
      expect(board.consecutiveNonCaptureMoves, equals(0));
      expect(board.isRunAndHideDeadlock(), isFalse);

      // Clear board down to 1 piece each
      for (int r = 0; r < 8; r++) {
        for (int c = 0; c < 8; c++) {
          board.grid[r][c] = null;
        }
      }
      board.grid[2][1] = DamaPiece(player: 1, isKing: true);
      board.grid[5][6] = DamaPiece(player: 2, isKing: true);

      // 1 piece each, 5 moves without capture -> not yet deadlock
      board.consecutiveNonCaptureMoves = 5;
      expect(board.isRunAndHideDeadlock(), isFalse);

      // 10 non-capture moves with <= 2 pieces -> run-and-hide triggered!
      board.consecutiveNonCaptureMoves = 10;
      expect(board.isRunAndHideDeadlock(), isTrue);

      // If a capture occurs, counter resets
      board.makeMove(const DamaMove(
        fromRow: 2,
        fromCol: 1,
        toRow: 6,
        toCol: 5,
        capturedTiles: [Point(5, 6)],
      ));
      expect(board.consecutiveNonCaptureMoves, equals(0));
    });
  });
}
