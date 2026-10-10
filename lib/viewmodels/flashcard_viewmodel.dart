import 'dart:math';
import '../models/flashcard_model.dart';
import '../services/local_storage_service.dart';
import '../views/generation_method/generation_method_view.dart';
import 'base_viewmodel.dart';

class FlashcardViewModel extends BaseViewModel {
  FlashcardDeckModel _deck;
  int _currentIndex = 0;
  bool _isFlipped = false;
  final Set<String> _masteredCardIds = {};
  bool _isDeckCompleted = false;
  final String? _userId;
  final LocalStorageService _storage;

  FlashcardViewModel(
    FlashcardDeckModel deck, {
    String? userId,
    LocalStorageService? storage,
  })  : _deck = deck,
        _userId = userId,
        _storage = storage ?? LocalStorageService() {
    for (final c in deck.cards) {
      if (c.isMastered) {
        _masteredCardIds.add(c.id);
      }
    }
  }

  FlashcardDeckModel get deck => _deck;
  int get currentIndex => _currentIndex;
  bool get isFlipped => _isFlipped;
  bool get isDeckCompleted => _isDeckCompleted;

  int get totalCards => _deck.cards.length;
  bool get isEmpty => totalCards == 0;
  bool get isFirst => _currentIndex == 0;
  bool get isLast => _currentIndex >= totalCards - 1;

  double get progress => totalCards > 0 ? (_currentIndex + 1) / totalCards : 0.0;
  int get masteredCount => _masteredCardIds.length;
  int get unmasteredCount => totalCards - masteredCount;
  double get masteryRate => totalCards > 0 ? (masteredCount / totalCards) * 100 : 0.0;

  FlashcardModel? get currentCard =>
      (!isEmpty && _currentIndex >= 0 && _currentIndex < totalCards)
          ? _deck.cards[_currentIndex]
          : null;

  bool get isCurrentMastered =>
      currentCard != null && _masteredCardIds.contains(currentCard!.id);

  void flipCard() {
    _isFlipped = !_isFlipped;
    notifyListeners();
  }

  void nextCard() {
    if (isLast) {
      _isDeckCompleted = true;
      _persistDeck();
      notifyListeners();
      return;
    }
    _currentIndex++;
    _isFlipped = false;
    notifyListeners();
  }

  void previousCard() {
    if (_currentIndex > 0) {
      _currentIndex--;
      _isFlipped = false;
      _isDeckCompleted = false;
      notifyListeners();
    }
  }

  /// Mark current card as Mastered (true) or Still Learning (false)
  /// and automatically persist and transition to next card.
  void markCurrentMastered(bool mastered, {bool advance = true}) {
    final card = currentCard;
    if (card == null) return;

    if (mastered) {
      _masteredCardIds.add(card.id);
    } else {
      _masteredCardIds.remove(card.id);
    }

    final updatedCards = _deck.cards.map((c) {
      if (c.id == card.id) {
        return c.copyWith(isMastered: mastered);
      }
      return c;
    }).toList();

    _deck = _deck.copyWith(cards: updatedCards);
    _persistDeck();

    if (advance) {
      nextCard();
    } else {
      notifyListeners();
    }
  }

  void toggleMastered() {
    final card = currentCard;
    if (card == null) return;

    if (_masteredCardIds.contains(card.id)) {
      _masteredCardIds.remove(card.id);
    } else {
      _masteredCardIds.add(card.id);
    }

    // Update card in deck
    final updatedCards = _deck.cards.map((c) {
      if (c.id == card.id) {
        return c.copyWith(isMastered: _masteredCardIds.contains(c.id));
      }
      return c;
    }).toList();

    _deck = _deck.copyWith(cards: updatedCards);
    _persistDeck();
    notifyListeners();
  }

  /// Mark every single card in this deck as mastered (100% mastery)
  Future<void> markAllCardsMastered() async {
    for (final c in _deck.cards) {
      _masteredCardIds.add(c.id);
    }

    final updatedCards = _deck.cards.map((c) {
      return c.copyWith(isMastered: true);
    }).toList();

    _deck = _deck.copyWith(cards: updatedCards);
    await _persistDeck();
    notifyListeners();
  }

  /// Reset the practice session to focus solely on unmastered cards
  void reviewUnmasteredOnly() {
    final unmastered = _deck.cards.where((c) => !_masteredCardIds.contains(c.id)).toList();
    if (unmastered.isNotEmpty) {
      _deck = _deck.copyWith(cards: unmastered);
      _currentIndex = 0;
      _isFlipped = false;
      _isDeckCompleted = false;
      notifyListeners();
    }
  }

  void shuffleDeck() {
    final shuffled = List<FlashcardModel>.from(_deck.cards)..shuffle(Random());
    _deck = _deck.copyWith(cards: shuffled);
    _currentIndex = 0;
    _isFlipped = false;
    _isDeckCompleted = false;
    notifyListeners();
  }

  void resetDeck() {
    _currentIndex = 0;
    _isFlipped = false;
    _isDeckCompleted = false;
    notifyListeners();
  }

  Future<void> saveCurrentState() async {
    await _persistDeck();
  }

  Future<void> _persistDeck() async {
    try {
      await _storage.saveFlashcardDeckLocally(_deck, userId: _userId);
      GenerationMethodView.updateDeckCache(_deck);
    } catch (_) {}
  }
}
