import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/flashcard_model.dart';
import '../models/quiz_result_model.dart';
import '../models/study_notes_model.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';

/// Thin wrapper over SharedPreferences. Handles guest quiz flags, onboarding flags,
/// and offline local quiz history persistence.
class LocalStorageService {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _instance async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  // ---------------------------------------------------------------------
  // Local Quiz History Fallback
  // ---------------------------------------------------------------------

  static const String _prefLocalQuizHistory = 'local_quiz_history';

  Future<void> saveQuizResultLocally(QuizResultModel result) async {
    final isGuest = result.userId == null ||
        result.userId!.isEmpty ||
        result.userId!.startsWith('guest_');
    if (isGuest) {
      // Do not record guest quiz results
      return;
    }

    final prefs = await _instance;
    final history = await getQuizHistoryLocally();
    history.removeWhere((q) => q.quizId == result.quizId);
    history.insert(0, result);

    final rawJson = history.map((q) => jsonEncode(q.toJson())).toList();
    await prefs.setStringList(_prefLocalQuizHistory, rawJson);
  }

  Future<List<QuizResultModel>> getQuizHistoryLocally({String? userId}) async {
    final prefs = await _instance;
    final rawList = prefs.getStringList(_prefLocalQuizHistory) ?? [];
    final list = <QuizResultModel>[];
    for (final str in rawList) {
      try {
        final Map<String, dynamic> map = jsonDecode(str);
        final model = QuizResultModel.fromJson(map);
        if (userId == null) {
          // Return all records when no filter is provided
          list.add(model);
        } else if (userId.isNotEmpty) {
          // Strictly isolate to the requesting scholar
          if (model.userId == userId) {
            list.add(model);
          }
        } else {
          // Only general unassigned records when userId is empty string
          if (model.userId == null || model.userId!.isEmpty) {
            list.add(model);
          }
        }
      } catch (_) {}
    }
    return list;
  }

  Future<void> deleteQuizResultLocally(String quizId) async {
    final prefs = await _instance;
    final history = await getQuizHistoryLocally();
    history.removeWhere((q) => q.quizId == quizId);
    final rawJson = history.map((q) => jsonEncode(q.toJson())).toList();
    await prefs.setStringList(_prefLocalQuizHistory, rawJson);
  }

  Future<void> clearAllQuizHistoryLocally() async {
    final prefs = await _instance;
    await prefs.remove(_prefLocalQuizHistory);
  }

  Future<void> clearScholarQuizHistoryLocally(String userId) async {
    if (userId.isEmpty) return;
    final prefs = await _instance;
    final history = await getQuizHistoryLocally();
    history.removeWhere((q) => q.userId == userId);
    final rawJson = history.map((q) => jsonEncode(q.toJson())).toList();
    await prefs.setStringList(_prefLocalQuizHistory, rawJson);
  }

  // ---------------------------------------------------------------------
  // Local Study Notes History Persistence
  // ---------------------------------------------------------------------

  static const String _prefLocalStudyNotes = 'local_study_notes_history';

  Future<void> saveStudyNotesLocally(StudyNotesModel notes, {String? userId}) async {
    final prefs = await _instance;
    final history = await getStudyNotesLocally();
    history.removeWhere((n) => n.id == notes.id);
    history.insert(0, notes);

    final rawJson = history.map((n) {
      final json = n.toJson();
      if (userId != null && userId.isNotEmpty) {
        json['userId'] = userId;
      }
      return jsonEncode(json);
    }).toList();
    await prefs.setStringList(_prefLocalStudyNotes, rawJson);
  }

  Future<List<StudyNotesModel>> getStudyNotesLocally({String? userId}) async {
    final prefs = await _instance;
    final rawList = prefs.getStringList(_prefLocalStudyNotes) ?? [];
    final list = <StudyNotesModel>[];
    for (final str in rawList) {
      try {
        final Map<String, dynamic> map = jsonDecode(str);
        final model = StudyNotesModel.fromJson(map);
        final recordUserId = map['userId'] as String?;
        if (userId == null) {
          list.add(model);
        } else if (userId.isNotEmpty) {
          if (recordUserId == null || recordUserId.isEmpty || recordUserId == userId) {
            list.add(model);
          }
        } else {
          list.add(model);
        }
      } catch (_) {}
    }
    return list;
  }

  Future<void> deleteStudyNotesLocally(String notesId) async {
    final prefs = await _instance;
    final history = await getStudyNotesLocally();
    history.removeWhere((n) => n.id == notesId);
    final rawJson = history.map((n) => jsonEncode(n.toJson())).toList();
    await prefs.setStringList(_prefLocalStudyNotes, rawJson);
  }

  Future<void> clearAllStudyNotesLocally() async {
    final prefs = await _instance;
    await prefs.remove(_prefLocalStudyNotes);
  }

  // ---------------------------------------------------------------------
  // Local Flashcard Decks History Persistence
  // ---------------------------------------------------------------------

  static const String _prefLocalFlashcardDecks = 'local_flashcard_decks_history';

  Future<void> saveFlashcardDeckLocally(FlashcardDeckModel deck, {String? userId}) async {
    final prefs = await _instance;
    final history = await getFlashcardDecksLocally();
    history.removeWhere((d) => d.id == deck.id);
    history.insert(0, deck);

    final rawJson = history.map((d) {
      final json = d.toJson();
      if (userId != null && userId.isNotEmpty) {
        json['userId'] = userId;
      }
      return jsonEncode(json);
    }).toList();
    await prefs.setStringList(_prefLocalFlashcardDecks, rawJson);
  }

  Future<List<FlashcardDeckModel>> getFlashcardDecksLocally({String? userId}) async {
    final prefs = await _instance;
    final rawList = prefs.getStringList(_prefLocalFlashcardDecks) ?? [];
    final list = <FlashcardDeckModel>[];
    for (final str in rawList) {
      try {
        final Map<String, dynamic> map = jsonDecode(str);
        final model = FlashcardDeckModel.fromJson(map);
        final recordUserId = map['userId'] as String?;
        if (userId == null) {
          list.add(model);
        } else if (userId.isNotEmpty) {
          if (recordUserId == null || recordUserId.isEmpty || recordUserId == userId) {
            list.add(model);
          }
        } else {
          list.add(model);
        }
      } catch (_) {}
    }
    return list;
  }

  Future<void> deleteFlashcardDeckLocally(String deckId) async {
    final prefs = await _instance;
    final history = await getFlashcardDecksLocally();
    history.removeWhere((d) => d.id == deckId);
    final rawJson = history.map((d) => jsonEncode(d.toJson())).toList();
    await prefs.setStringList(_prefLocalFlashcardDecks, rawJson);
  }

  Future<void> clearAllFlashcardDecksLocally() async {
    final prefs = await _instance;
    await prefs.remove(_prefLocalFlashcardDecks);
  }

  // ---------------------------------------------------------------------
  // Guest free-quiz flag
  // ---------------------------------------------------------------------

  Future<bool> getGuestQuizUsed() async {
    final prefs = await _instance;
    return prefs.getBool(AppConstants.prefGuestQuizUsed) ?? false;
  }

  /// Must ONLY be called after a quiz has been successfully generated.
  Future<void> markGuestQuizUsed() async {
    final prefs = await _instance;
    await prefs.setBool(AppConstants.prefGuestQuizUsed, true);
  }

  Future<void> resetGuestQuizUsed() async {
    final prefs = await _instance;
    await prefs.remove(AppConstants.prefGuestQuizUsed);
  }

  // ---------------------------------------------------------------------
  // Onboarding flag
  // ---------------------------------------------------------------------

  Future<bool> getOnboardingComplete() async {
    final prefs = await _instance;
    return prefs.getBool(AppConstants.prefOnboardingComplete) ?? false;
  }

  Future<void> markOnboardingComplete() async {
    final prefs = await _instance;
    await prefs.setBool(AppConstants.prefOnboardingComplete, true);
  }

  // ---------------------------------------------------------------------
  // Multi-Provider AI (Gemini, OpenAI, DeepSeek) API Keys
  // ---------------------------------------------------------------------

  Future<AiProvider> getActiveAiProvider() async {
    final prefs = await _instance;
    final id = prefs.getString(AppConstants.prefActiveAiProvider);
    return AiProviderExtension.fromId(id);
  }

  Future<void> setActiveAiProvider(AiProvider provider) async {
    final prefs = await _instance;
    await prefs.setString(AppConstants.prefActiveAiProvider, provider.id);
  }

  String _getPrefKeyForProvider(AiProvider provider) {
    switch (provider) {
      case AiProvider.gemini:
        return AppConstants.prefGeminiApiKey;
      case AiProvider.openAi:
        return AppConstants.prefOpenAiApiKey;
      case AiProvider.deepSeek:
        return AppConstants.prefDeepSeekApiKey;
      case AiProvider.grok:
        return AppConstants.prefGrokApiKey;
      case AiProvider.groq:
        return AppConstants.prefGroqApiKey;
      case AiProvider.anthropic:
        return AppConstants.prefAnthropicApiKey;
    }
  }

  Future<String?> getApiKeyForProvider(AiProvider provider) async {
    final prefs = await _instance;
    final prefKey = _getPrefKeyForProvider(provider);
    final key = prefs.getString(prefKey)?.trim();
    return (key != null && key.isNotEmpty) ? key : null;
  }

  Future<void> saveApiKeyForProvider(AiProvider provider, String apiKey) async {
    final prefs = await _instance;
    final prefKey = _getPrefKeyForProvider(provider);
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(prefKey);
    } else {
      await prefs.setString(prefKey, trimmed);
    }
  }

  Future<void> clearApiKeyForProvider(AiProvider provider) async {
    final prefs = await _instance;
    final prefKey = _getPrefKeyForProvider(provider);
    await prefs.remove(prefKey);
  }

  Future<String?> getActiveApiKey() async {
    final provider = await getActiveAiProvider();
    return getApiKeyForProvider(provider);
  }

  // Backward-compatible methods
  Future<String?> getGeminiApiKey() async {
    return getApiKeyForProvider(AiProvider.gemini);
  }

  Future<void> saveGeminiApiKey(String apiKey) async {
    await saveApiKeyForProvider(AiProvider.gemini, apiKey);
  }

  Future<void> clearGeminiApiKey() async {
    await clearApiKeyForProvider(AiProvider.gemini);
  }

  // ---------------------------------------------------------------------
  // User Session Persistence & Admin Inactivity
  // ---------------------------------------------------------------------

  static const String _prefCachedUser = 'cached_current_user';
  static const String _prefLastAdminActivity = 'last_admin_activity';

  Future<void> saveCurrentUser(UserModel user) async {
    final prefs = await _instance;
    await prefs.setString(_prefCachedUser, jsonEncode(user.toJson()));
  }

  Future<UserModel?> getCachedCurrentUser() async {
    final prefs = await _instance;
    final raw = prefs.getString(_prefCachedUser);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return UserModel.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCachedCurrentUser() async {
    final prefs = await _instance;
    await prefs.remove(_prefCachedUser);
    await prefs.remove(_prefLastAdminActivity);
  }

  Future<void> saveLastAdminActivity(DateTime time) async {
    final prefs = await _instance;
    await prefs.setString(_prefLastAdminActivity, time.toIso8601String());
  }

  Future<DateTime?> getLastAdminActivity() async {
    final prefs = await _instance;
    final str = prefs.getString(_prefLastAdminActivity);
    if (str == null || str.isEmpty) return null;
    return DateTime.tryParse(str);
  }

  Future<void> clearLastAdminActivity() async {
    final prefs = await _instance;
    await prefs.remove(_prefLastAdminActivity);
  }
}

