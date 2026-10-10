import '../models/flashcard_model.dart';
import '../models/quiz_result_model.dart';
import '../models/study_notes_model.dart';
import '../repositories/quiz_repository.dart';
import '../services/firestore_service.dart';
import '../services/local_storage_service.dart';
import 'base_viewmodel.dart';

enum HistoryCategoryFilter { all, quizzes, notes, flashcards }

/// Manages the History screen: loading a scholar's past quizzes,
/// study notes, and flashcard decks with category filtering.
class HistoryViewModel extends BaseViewModel {
  final QuizRepository _repository;
  final LocalStorageService _storage;

  HistoryViewModel({
    QuizRepository? repository,
    LocalStorageService? storage,
  })  : _repository = repository ?? QuizRepository(),
        _storage = storage ?? LocalStorageService();

  List<QuizResultModel> _quizHistory = [];
  List<StudyNotesModel> _notesHistory = [];
  List<FlashcardDeckModel> _flashcardHistory = [];

  HistoryCategoryFilter _activeFilter = HistoryCategoryFilter.all;
  HistoryCategoryFilter get activeFilter => _activeFilter;

  List<QuizResultModel> get history => _quizHistory;
  List<QuizResultModel> get quizHistory => _quizHistory;
  List<StudyNotesModel> get notesHistory => _notesHistory;
  List<FlashcardDeckModel> get flashcardHistory => _flashcardHistory;

  int get totalQuizzes => _quizHistory.length;
  int get totalNotes => _notesHistory.length;
  int get totalFlashcards => _flashcardHistory.length;
  int get totalItems => _quizHistory.length + _notesHistory.length + _flashcardHistory.length;

  double get averageScore {
    if (_quizHistory.isEmpty) return 0;
    final total = _quizHistory.fold<double>(0, (sum, r) => sum + r.percentage);
    return total / _quizHistory.length;
  }

  double get bestScore {
    if (_quizHistory.isEmpty) return 0;
    return _quizHistory.map((r) => r.percentage).reduce((a, b) => a > b ? a : b);
  }

  void setFilter(HistoryCategoryFilter filter) {
    if (_activeFilter != filter) {
      _activeFilter = filter;
      notifyListeners();
    }
  }

  Future<void> loadHistory(String userId) async {
    await loadAllHistory(userId);
  }

  Future<void> loadAllHistory(String userId) async {
    setLoading();
    try {
      final results = await Future.wait([
        _repository.getQuizHistory(userId).catchError((_) => <QuizResultModel>[]),
        _storage.getStudyNotesLocally(userId: userId).catchError((_) => <StudyNotesModel>[]),
        _storage.getFlashcardDecksLocally(userId: userId).catchError((_) => <FlashcardDeckModel>[]),
      ]);

      _quizHistory = results[0] as List<QuizResultModel>;
      _notesHistory = results[1] as List<StudyNotesModel>;
      _flashcardHistory = results[2] as List<FlashcardDeckModel>;

      setSuccess();
    } on FirestoreServiceException catch (e) {
      setError(e.message);
    } catch (_) {
      setError("We couldn't load your study history right now.");
    }
  }

  Future<void> saveResult(QuizResultModel result) async {
    try {
      await _repository.saveQuizResult(result);
    } catch (_) {
      // Swallowed by design
    }
  }

  Future<void> deleteResult(String quizId) async {
    try {
      await _repository.deleteQuizResult(quizId);
      _quizHistory = _quizHistory.where((r) => r.quizId != quizId).toList();
      notifyListeners();
    } catch (_) {
      setError("We couldn't delete that quiz. Please try again.");
    }
  }

  Future<void> deleteNotes(String notesId) async {
    try {
      await _storage.deleteStudyNotesLocally(notesId);
      _notesHistory = _notesHistory.where((n) => n.id != notesId).toList();
      notifyListeners();
    } catch (_) {
      setError("We couldn't delete those study notes. Please try again.");
    }
  }

  Future<void> deleteFlashcards(String deckId) async {
    try {
      await _storage.deleteFlashcardDeckLocally(deckId);
      _flashcardHistory = _flashcardHistory.where((d) => d.id != deckId).toList();
      notifyListeners();
    } catch (_) {
      setError("We couldn't delete that flashcard deck. Please try again.");
    }
  }
}
