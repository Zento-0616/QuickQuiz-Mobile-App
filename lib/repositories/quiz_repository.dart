import 'package:flutter/foundation.dart';

import '../models/question_model.dart';
import '../models/quiz_model.dart';
import '../models/quiz_result_model.dart';
import '../models/quiz_settings_model.dart';
import '../services/firestore_service.dart';
import '../services/gemini_service.dart';
import '../services/question_bank_service.dart';
import '../services/quiz_api_service.dart';

class QuizRepository {
  final QuestionBankService _questionBankService;
  final FirestoreService _firestoreService;
  final QuizApiService _quizApiService;
  final GeminiService _geminiService;

  QuizRepository({
    QuestionBankService? questionBankService,
    FirestoreService? firestoreService,
    QuizApiService? quizApiService,
    GeminiService? geminiService,
  })  : _questionBankService = questionBankService ?? QuestionBankService(),
        _firestoreService = firestoreService ?? FirestoreService(),
        _quizApiService = quizApiService ?? QuizApiService(),
        _geminiService = geminiService ?? GeminiService();

  Future<List<String>> getCategories() => _questionBankService.getCategories();

  /// Dynamically generates high-quality multiple choice questions from study notes
  /// using Google Gemini (Google AI Studio SDK or Firebase Cloud Functions).
  ///
  /// For uploaded documents, real Google AI Studio question generation is strictly
  /// enforced — mock template generation has been erased.
  Future<QuizModel> generateQuiz({
    String? documentText,
    required String sourceFileName,
    required int questionCount,
    required QuizDifficulty difficulty,
    String? category,
    List<String>? tags,
  }) async {
    // 1. If study material text is provided, use Google AI Studio (Gemini)
    if (documentText != null && documentText.trim().length >= 10) {
      final hasKey = await _geminiService.isConfiguredAsync;

      // Direct Google AI Studio official SDK
      if (hasKey) {
        try {
          debugPrint('[QuizRepository] Generating quiz via Google AI Studio official SDK...');
          final aiQuiz = await _geminiService.generateQuiz(
            documentText: documentText,
            sourceFileName: sourceFileName,
            questionCount: questionCount,
            difficulty: difficulty,
          );
          debugPrint('[QuizRepository] Successfully generated ${aiQuiz.questionCount} questions via AI Studio SDK.');
          return aiQuiz.copyWith(
            questions: aiQuiz.questions.map((q) => q.randomizeAnswers()).toList(),
          );
        } catch (e) {
          debugPrint('[QuizRepository] Google AI Studio SDK failed: $e');
          if (e is GeminiApiKeyMissingException) {
            rethrow;
          }
          debugPrint('[QuizRepository] Attempting fallback to Cloud Functions backend proxy...');
        }
      }

      // Secure Firebase Cloud Functions backend proxy
      try {
        debugPrint('[QuizRepository] Generating quiz via Google Gemini AI Cloud Function...');
        final aiQuiz = await _quizApiService.generateQuiz(
          documentText: documentText,
          sourceFileName: sourceFileName,
          questionCount: questionCount,
          difficulty: difficulty,
        );
        debugPrint('[QuizRepository] Successfully generated ${aiQuiz.questionCount} questions via Gemini Cloud Function.');
        return aiQuiz.copyWith(
          questions: aiQuiz.questions.map((q) => q.randomizeAnswers()).toList(),
        );
      } catch (cloudFnError) {
        debugPrint('[QuizRepository] Cloud Functions proxy failed: $cloudFnError');
      }

      // If neither AI Studio direct SDK nor Cloud Functions succeeded,
      // strictly do NOT generate fake mock questions. Throw an explicit exception.

      if (!hasKey) {
        throw const GeminiApiKeyMissingException(
          'Google AI Studio API key not found. Please connect your Gemini API key from https://aistudio.google.com/ to analyze documents and generate real MCQs.',
        );
      } else {
        throw const GeminiGenerationException(
          'Failed to generate questions with Google AI Studio. Please verify your Gemini API key and network connection.',
        );
      }
    }

    // 2. Fallback to Question Bank Service
    final questions = await _questionBankService.queryQuestions(
      category: category,
      difficulty: difficulty,
      tags: tags,
      count: questionCount,
    );

    return QuizModel(
      sourceFileName: sourceFileName,
      difficulty: difficulty,
      questions: questions.map((q) => q.randomizeAnswers()).toList(),
      timeLimitSeconds: QuizSettingsModel.calculateTimeLimitInSeconds(
        questionCount,
        difficulty,
      ),
    );
  }

  Future<void> saveQuizResult(QuizResultModel result) {
    return _firestoreService.saveQuizResult(result);
  }

  Future<List<QuizResultModel>> getQuizHistory(String userId) {
    return _firestoreService.getQuizHistory(userId);
  }

  Future<void> deleteQuizResult(String quizId) {
    return _firestoreService.deleteQuizResult(quizId);
  }

  /// Regenerates a single question using Google AI Studio.
  Future<QuestionModel> regenerateQuestion({
    required String documentText,
    required QuestionModel oldQuestion,
    required QuizDifficulty difficulty,
    List<String> existingQuestionStems = const [],
  }) async {
    return _geminiService.regenerateSingleQuestion(
      documentText: documentText,
      oldQuestion: oldQuestion,
      difficulty: difficulty,
      existingQuestionStems: existingQuestionStems,
    );
  }
}

