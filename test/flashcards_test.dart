import 'package:flutter_test/flutter_test.dart';
import 'package:quickquiz/models/flashcard_model.dart';
import 'package:quickquiz/viewmodels/flashcard_viewmodel.dart';

void main() {
  group('FlashcardModel Tests', () {
    test('FlashcardModel initializes correctly and serializes to/from JSON', () {
      final card = FlashcardModel(
        id: 'card_1',
        front: 'What is Mitosis?',
        back: 'A type of cell division resulting in two daughter cells.',
        hint: 'Occurs in somatic cells',
        category: 'Cell Biology',
        isMastered: false,
      );

      expect(card.front, 'What is Mitosis?');
      expect(card.back, 'A type of cell division resulting in two daughter cells.');
      expect(card.hint, 'Occurs in somatic cells');
      expect(card.category, 'Cell Biology');
      expect(card.isMastered, false);

      final json = card.toJson();
      final revived = FlashcardModel.fromJson(json);

      expect(revived.id, card.id);
      expect(revived.front, card.front);
      expect(revived.back, card.back);
      expect(revived.hint, card.hint);
      expect(revived.category, card.category);
      expect(revived.isMastered, card.isMastered);
    });

    test('FlashcardModel copyWith updates fields properly', () {
      final card = FlashcardModel(
        id: 'card_2',
        front: 'Newton\'s Second Law',
        back: 'F = ma',
      );

      final updated = card.copyWith(isMastered: true, hint: 'Force equals mass times acceleration');
      expect(updated.isMastered, true);
      expect(updated.hint, 'Force equals mass times acceleration');
      expect(updated.front, 'Newton\'s Second Law');
      expect(card.isMastered, false);
    });
  });

  group('FlashcardDeckModel Tests', () {
    test('FlashcardDeckModel calculates counts, mastery rate, and converts to Markdown', () {
      final cards = [
        FlashcardModel(id: 'c1', front: 'Term 1', back: 'Definition 1', isMastered: true),
        FlashcardModel(id: 'c2', front: 'Term 2', back: 'Definition 2', isMastered: false),
        FlashcardModel(id: 'c3', front: 'Term 3', back: 'Definition 3', isMastered: true),
        FlashcardModel(id: 'c4', front: 'Term 4', back: 'Definition 4', isMastered: false),
      ];

      final deck = FlashcardDeckModel(
        id: 'deck_1',
        title: 'Physics & Biology Deck',
        cards: cards,
        sourceFileName: 'Lecture1.pdf',
      );

      expect(deck.cardCount, 4);
      expect(deck.masteredCount, 2);
      expect(deck.masteryPercentage, 50.0);

      final md = deck.toMarkdown();
      expect(md.contains('# Physics & Biology Deck'), isTrue);
      expect(md.contains('Card 1: Term 1'), isTrue);
      expect(md.contains('Definition 1'), isTrue);
      expect(md.contains('Lecture1.pdf'), isTrue);
    });

    test('FlashcardDeckModel handles empty deck gracefully', () {
      final deck = FlashcardDeckModel(
        id: 'empty_deck',
        title: 'Empty Deck',
        cards: [],
        sourceFileName: 'empty.txt',
      );

      expect(deck.cardCount, 0);
      expect(deck.masteredCount, 0);
      expect(deck.masteryPercentage, 0.0);
    });
  });

  group('FlashcardViewModel Tests', () {
    late FlashcardDeckModel testDeck;
    late FlashcardViewModel vm;

    setUp(() {
      testDeck = FlashcardDeckModel(
        id: 'deck_test',
        title: 'Computer Science Deck',
        sourceFileName: 'CS101.pdf',
        cards: [
          FlashcardModel(id: 'cs1', front: 'Recursion', back: 'A function calling itself.'),
          FlashcardModel(id: 'cs2', front: 'Polymorphism', back: 'Ability of an object to take many forms.'),
          FlashcardModel(id: 'cs3', front: 'Big O', back: 'Upper bound asymptotic complexity.'),
        ],
      );
      vm = FlashcardViewModel(testDeck);
    });

    test('Initial state is at card 0, unflipped, and not completed', () {
      expect(vm.currentIndex, 0);
      expect(vm.isFlipped, false);
      expect(vm.isDeckCompleted, false);
      expect(vm.isFirst, true);
      expect(vm.isLast, false);
      expect(vm.currentCard?.front, 'Recursion');
    });

    test('flipCard toggles flipped state and notifies listeners', () {
      bool notified = false;
      vm.addListener(() => notified = true);

      vm.flipCard();
      expect(vm.isFlipped, true);
      expect(notified, true);

      vm.flipCard();
      expect(vm.isFlipped, false);
    });

    test('nextCard advances card, resets flip, and completes deck on final card', () {
      expect(vm.currentIndex, 0);

      vm.flipCard();
      expect(vm.isFlipped, true);

      vm.nextCard();
      expect(vm.currentIndex, 1);
      expect(vm.isFlipped, false); // Resets flip on navigation
      expect(vm.currentCard?.front, 'Polymorphism');
      expect(vm.isFirst, false);
      expect(vm.isLast, false);

      vm.nextCard();
      expect(vm.currentIndex, 2);
      expect(vm.isLast, true);
      expect(vm.isDeckCompleted, false);

      // On last card, nextCard finishes the deck
      vm.nextCard();
      expect(vm.isDeckCompleted, true);
    });

    test('previousCard moves back without going below 0', () {
      vm.nextCard(); // at 1
      expect(vm.currentIndex, 1);

      vm.previousCard(); // at 0
      expect(vm.currentIndex, 0);

      vm.previousCard(); // stays at 0
      expect(vm.currentIndex, 0);
    });

    test('toggleMastered toggles current card status and updates stats', () {
      expect(vm.isCurrentMastered, false);
      expect(vm.masteredCount, 0);

      vm.toggleMastered();
      expect(vm.isCurrentMastered, true);
      expect(vm.masteredCount, 1);
      expect(vm.masteryRate, closeTo(33.33, 0.5));

      vm.toggleMastered();
      expect(vm.isCurrentMastered, false);
      expect(vm.masteredCount, 0);
    });

    test('shuffleDeck randomizes order and resets index to 0', () {
      vm.nextCard();
      vm.shuffleDeck();
      expect(vm.currentIndex, 0);
      expect(vm.isFlipped, false);
      expect(vm.isDeckCompleted, false);
      expect(vm.totalCards, 3);
    });

    test('resetDeck restores initial uncompleted state', () {
      vm.nextCard();
      vm.nextCard();
      vm.nextCard(); // completed
      expect(vm.isDeckCompleted, true);

      vm.resetDeck();
      expect(vm.isDeckCompleted, false);
      expect(vm.currentIndex, 0);
      expect(vm.isFlipped, false);
    });

    test('markCurrentMastered updates mastery and advances automatically', () {
      expect(vm.currentIndex, 0);
      expect(vm.masteredCount, 0);

      // Rate card 0 as Mastered (true)
      vm.markCurrentMastered(true, advance: true);
      expect(vm.currentIndex, 1);
      expect(vm.masteredCount, 1);
      expect(vm.deck.cards[0].isMastered, true);

      // Rate card 1 as Still Learning (false)
      vm.markCurrentMastered(false, advance: true);
      expect(vm.currentIndex, 2);
      expect(vm.masteredCount, 1);
      expect(vm.deck.cards[1].isMastered, false);

      // Rate card 2 as Mastered (true) -> reaches end of deck
      vm.markCurrentMastered(true, advance: true);
      expect(vm.isDeckCompleted, true);
      expect(vm.masteredCount, 2);
      expect(vm.deck.cards[2].isMastered, true);
      expect(vm.masteryRate, closeTo(66.67, 0.5));
    });

    test('markAllCardsMastered sets 100% mastery across entire deck', () async {
      expect(vm.masteredCount, 0);
      await vm.markAllCardsMastered();
      expect(vm.masteredCount, 3);
      expect(vm.masteryRate, 100.0);
      expect(vm.unmasteredCount, 0);
      expect(vm.deck.cards.every((c) => c.isMastered), true);
    });

    test('reviewUnmasteredOnly sets deck to only unmastered cards for focused drill', () {
      // Master card 0 and card 2
      vm.markCurrentMastered(true, advance: true); // card 0
      vm.markCurrentMastered(false, advance: true); // card 1 (Still Learning)
      vm.markCurrentMastered(true, advance: true); // card 2

      expect(vm.masteredCount, 2);
      expect(vm.unmasteredCount, 1);

      // Filter to unmastered
      vm.reviewUnmasteredOnly();
      expect(vm.totalCards, 1);
      expect(vm.currentCard?.id, 'cs2');
      expect(vm.isDeckCompleted, false);
      expect(vm.currentIndex, 0);
    });
  });
}
