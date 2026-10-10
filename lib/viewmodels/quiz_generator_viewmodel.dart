import 'dart:async';

import '../models/document_model.dart';
import '../models/quiz_model.dart';
import '../models/quiz_settings_model.dart';
import '../repositories/quiz_repository.dart';
import '../services/gemini_service.dart';
import '../services/local_storage_service.dart';
import 'auth_viewmodel.dart';
import 'base_viewmodel.dart';

/// The rotating loading copy shown while a quiz is prepared with Gemini AI.
const List<String> _generationSteps = [
  'Analyzing document concepts...',
  'Extracting key subject topics...',
  'Generating exam questions with Gemini AI...',
  'Crafting realistic options and explanations...',
  'Preparing your exam session...',
  'Almost ready...',
];

/// Manages quiz settings (question count, difficulty, and category),
/// the free‑quiz / sign‑in gate, and dynamic question generation with Google Gemini.
class QuizGeneratorViewModel extends BaseViewModel {
  final QuizRepository _repository;
  final AuthViewModel _authViewModel;

  Timer? _loadingMessageTimer;
  int _loadingStepIndex = 0;

  List<String> _categories = const ['All'];
  List<String> get categories => _categories;

  QuizGeneratorViewModel({
    required AuthViewModel authViewModel,
    QuizRepository? repository,
  })  : _authViewModel = authViewModel,
        _repository = repository ?? QuizRepository() {
    _loadCategories();
  }

  QuizSettingsModel _settings = const QuizSettingsModel();
  QuizSettingsModel get settings => _settings;

  QuizModel? _generatedQuiz;
  QuizModel? get generatedQuiz => _generatedQuiz;

  bool _requiresSignIn = false;
  bool get requiresSignIn => _requiresSignIn;

  bool _requiresGeminiApiKey = false;
  bool get requiresGeminiApiKey => _requiresGeminiApiKey;

  Future<void> _loadCategories() async {
    try {
      final loaded = await _repository.getCategories();
      if (loaded.isNotEmpty) {
        _categories = loaded;
        notifyListeners();
      }
    } catch (_) {}
  }

  void updateQuestionCount(int count) {
    _settings = _settings.copyWith(questionCount: count);
    notifyListeners();
  }

  void updateDifficulty(QuizDifficulty difficulty) {
    _settings = _settings.copyWith(difficulty: difficulty);
    notifyListeners();
  }

  void updateCategory(String category) {
    _settings = _settings.copyWith(category: category);
    notifyListeners();
  }

  /// Serves questions dynamically by querying Google AI Studio (Gemini)
  /// or cloud functions based on user-selected criteria.
  Future<bool> generateQuiz(DocumentModel document) async {
    if (isLoading) return false;

    _requiresSignIn = false;
    _requiresGeminiApiKey = false;

    if (!document.hasExtractedText) {
      setError('Please upload and analyze a file first.');
      return false;
    }
    if (!_settings.isValid) {
      setError(
        'Please choose between ${QuizSettingsModel.minQuestions} and '
        '${QuizSettingsModel.maxQuestions} questions.',
      );
      return false;
    }

    final allowed = await _authViewModel.canCreateQuiz();
    if (!allowed) {
      _requiresSignIn = true;
      setIdle();
      return false;
    }

    _startLoadingRotation();

    try {
      final quiz = await _repository.generateQuiz(
        documentText: document.extractedText,
        sourceFileName: document.fileName,
        questionCount: _settings.questionCount,
        difficulty: _settings.difficulty,
        category: _settings.category,
      );

      _generatedQuiz = quiz;
      _authViewModel.markGuestQuizUsedAfterSuccess();
      _stopLoadingRotation();
      setSuccess();
      return true;
    } catch (e) {
      _stopLoadingRotation();
      if (e is GeminiApiKeyMissingException) {
        _requiresGeminiApiKey = true;
        setError(e.message);
      } else if (e is GeminiGenerationException) {
        setError(e.message);
      } else {
        setError('Failed to generate quiz: $e');
      }
      return false;
    }
  }

  void clearSignInRequired() {
    _requiresSignIn = false;
    notifyListeners();
  }

  void clearGeminiApiKeyRequired() {
    _requiresGeminiApiKey = false;
    notifyListeners();
  }

  Future<void> saveGeminiApiKey(String apiKey) async {
    await LocalStorageService().saveGeminiApiKey(apiKey);
    _requiresGeminiApiKey = false;
    notifyListeners();
  }

  void _startLoadingRotation() {
    _loadingStepIndex = 0;
    setLoading(_generationSteps[0]);
    _loadingMessageTimer?.cancel();
    _loadingMessageTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (_loadingStepIndex < _generationSteps.length - 1) {
        _loadingStepIndex++;
        setLoading(_generationSteps[_loadingStepIndex]);
      }
    });
  }

  void _stopLoadingRotation() {
    _loadingMessageTimer?.cancel();
    _loadingMessageTimer = null;
  }

  @override
  void dispose() {
    _loadingMessageTimer?.cancel();
    super.dispose();
  }
}