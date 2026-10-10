import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../models/quiz_model.dart';
import '../models/quiz_settings_model.dart';
import '../utils/constants.dart';

/// Thrown for any quiz-generation failure the ViewModel should show as a
/// friendly message.
class QuizGenerationException implements Exception {
  final String message;
  const QuizGenerationException(this.message);
}

/// Calls the `generateQuiz` Cloud Function. This is the ONLY place the
/// app talks to the AI backend — no AI provider API key ever exists in
/// this codebase. The actual prompt and provider call live server-side
/// in `functions/index.js`.
///
///   Flutter app -> generateQuiz Cloud Function -> AI provider -> JSON -> app
class QuizApiService {
  final FirebaseFunctions? _customFunctions;

  QuizApiService({FirebaseFunctions? functions})
      : _customFunctions = functions;

  FirebaseFunctions get _functions =>
      _customFunctions ??
      FirebaseFunctions.instanceFor(
        region: AppConstants.cloudFunctionsRegion,
      );

  Future<QuizModel> generateQuiz({
    required String documentText,
    required String sourceFileName,
    required int questionCount,
    required QuizDifficulty difficulty,
  }) async {
    final HttpsCallable callable = _functions.httpsCallable(
      AppConstants.generateQuizFunctionName,
      options: HttpsCallableOptions(
        // Generation can legitimately take a while for 50 questions —
        // give it real room before treating it as a network failure.
        timeout: const Duration(seconds: 90),
      ),
    );

    late final HttpsCallableResult result;
    try {
      debugPrint('[QuizApiService] Calling ${AppConstants.generateQuizFunctionName} in ${AppConstants.cloudFunctionsRegion}...');
      result = await callable.call<Map<String, dynamic>>({
        'documentText': documentText,
        'questionCount': questionCount,
        'difficulty': difficulty.apiValue,
      });
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[QuizApiService] FirebaseFunctionsException: [${e.code}] ${e.message} (details: ${e.details})');
      throw QuizGenerationException(_mapFunctionsError(e));
    } catch (e) {
      debugPrint('[QuizApiService] General error calling function: $e');
      throw QuizGenerationException(
        "Could not connect to the quiz generation service: ${e.toString().replaceAll('Exception: ', '')}",
      );
    }

    try {
      final data = Map<String, dynamic>.from(result.data as Map);
      return QuizModel.fromApiResponse(
        json: data,
        sourceFileName: sourceFileName,
        difficulty: difficulty,
        expectedQuestionCount: questionCount,
      );
    } on FormatException catch (e) {
      // The function is expected to validate this itself, but the client
      // re-validates independently — never trust and render unvalidated
      // AI output.
      debugPrint('[QuizApiService] Invalid quiz format received: $e');
      throw const QuizGenerationException(
        'We received an invalid quiz from the server. Please try again.',
      );
    } catch (e) {
      debugPrint('[QuizApiService] Error parsing quiz response: $e');
      throw const QuizGenerationException(
        "We couldn't generate your quiz right now. Please try again.",
      );
    }
  }

  String _mapFunctionsError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'not-found':
        return "The backend function 'generateQuiz' was not found (404). Please ensure the Cloud Function is deployed to Firebase.";
      case 'deadline-exceeded':
        return 'That took too long. Try a shorter document or fewer questions.';
      case 'resource-exhausted':
        return "We're getting a lot of requests right now. Please try again shortly.";
      case 'invalid-argument':
        return e.message ??
            'Something about this request was invalid. Please try again.';
      case 'unauthenticated':
        return 'Please sign in and try again.';
      case 'permission-denied':
        return 'Permission denied. Please verify your Firebase project permissions.';
      case 'unavailable':
        return 'The quiz generation service is currently unavailable. Please check your network and try again.';
      case 'internal':
        return e.message != null && e.message!.isNotEmpty
            ? 'Server error: ${e.message}'
            : 'Internal server error. Check your Cloud Function logs and AI API key.';
      default:
        if (e.message != null && e.message!.isNotEmpty) {
          return e.message!;
        }
        return "Server error (${e.code}). Please check your backend setup.";
    }
  }
}
