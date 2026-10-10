import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quickquiz/models/flashcard_model.dart';
import 'package:quickquiz/viewmodels/auth_viewmodel.dart';
import 'package:quickquiz/viewmodels/flashcard_viewmodel.dart';
import 'package:quickquiz/views/flashcards/flashcard_view.dart';
import 'package:quickquiz/widgets/quick_quiz_top_bar.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('QuickQuizTopBar Pixel Overflow Prevention Tests', () {
    testWidgets('QuickQuizTopBar does not overflow on narrow mobile screens (360x640) with back button & extraActions', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AuthViewModel(),
          child: MaterialApp(
            home: Scaffold(
              appBar: QuickQuizTopBar(
                showBackButton: true,
                extraActions: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () {},
                  ),
                ],
              ),
              body: const Center(child: Text('History Content')),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(QuickQuizTopBar), findsOneWidget);
      expect(find.text('QuickQuiz'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('QuickQuizTopBar handles Messages screen with multiple extraActions on 390x844 without overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AuthViewModel(),
          child: MaterialApp(
            home: Scaffold(
              appBar: QuickQuizTopBar(
                extraActions: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 21),
                    onPressed: () {},
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    icon: const Icon(Icons.group_add_rounded, size: 21),
                    onPressed: () {},
                  ),
                ],
              ),
              body: const Center(child: Text('Messages Content')),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(QuickQuizTopBar), findsOneWidget);
      expect(find.text('QuickQuiz'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Flashcard Self-Assessment and Mastery Flow Tests', () {
    late FlashcardDeckModel testDeck;

    setUp(() {
      testDeck = FlashcardDeckModel(
        id: 'deck_flow_test',
        title: 'Network Security Deck',
        sourceFileName: 'NetSec.pdf',
        cards: [
          const FlashcardModel(id: 'c1', front: 'TLS Handshake', back: 'Cryptographic protocol negotiation between client and server.'),
          const FlashcardModel(id: 'c2', front: 'Diffie-Hellman', back: 'Key exchange algorithm allowing shared secret generation.'),
          const FlashcardModel(id: 'c3', front: 'Man-in-the-Middle', back: 'Attack where adversary relays and alters communication.'),
        ],
      );
    });

    testWidgets('FlashcardView flips card and displays Still Learning and Got It buttons', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AuthViewModel(),
          child: MaterialApp(
            home: FlashcardView(deck: testDeck),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Front card initially shown
      expect(find.text('TLS Handshake'), findsOneWidget);
      expect(find.text('Reveal Answer'), findsOneWidget);

      // Tap Reveal Answer
      await tester.tap(find.text('Reveal Answer'));
      await tester.pumpAndSettle();

      // Back card and rating buttons should now be visible
      expect(find.text('ANSWER & EXPLANATION'), findsOneWidget);
      expect(find.text('Still Learning'), findsOneWidget);
      expect(find.text('Got It! Mastered'), findsOneWidget);

      // Tap Got It! Mastered -> advances to card 2 and marks card 1 mastered
      await tester.tap(find.text('Got It! Mastered'));
      await tester.pumpAndSettle();

      // Should now be on Card 2 (Diffie-Hellman)
      expect(find.text('Diffie-Hellman'), findsOneWidget);
      expect(find.text('CARD 2 OF 3'), findsOneWidget);
    });

    testWidgets('FlashcardView completion view allows marking all cards mastered (100%)', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final vm = FlashcardViewModel(testDeck);
      // Advance to completion without marking cards
      vm.nextCard();
      vm.nextCard();
      vm.nextCard(); // complete deck
      expect(vm.isDeckCompleted, true);
      expect(vm.masteredCount, 0);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthViewModel()),
            ChangeNotifierProvider.value(value: vm),
          ],
          child: MaterialApp(
            home: FlashcardView(deck: vm.deck, viewModel: vm),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Completion screen shown
      expect(find.text('Session Complete'), findsOneWidget);
      expect(find.text('Deck Review Finished!'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('Mark All as Mastered (100%)'), findsOneWidget);

      // Tap Mark All as Mastered (100%)
      await tester.tap(find.text('Mark All as Mastered (100%)'));
      await tester.pumpAndSettle();

      // Should now show 100% and 3 mastered!
      expect(find.text('100% Mastery Achieved!'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('3'), findsNWidgets(2)); // Total cards = 3, Mastered = 3
    });
  });
}
