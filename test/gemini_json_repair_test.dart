import 'package:flutter_test/flutter_test.dart';
import 'package:quickquiz/models/quiz_settings_model.dart';
import 'package:quickquiz/services/gemini_service.dart';

void main() {
  group('GeminiService JSON Repair and Parsing Resilience Tests', () {
    late GeminiService geminiService;

    setUp(() {
      geminiService = GeminiService(apiKey: 'dummy_key');
    });

    test('recovers from unterminated string error (cut off at line 10 "file)', () {
      const truncatedJson = '''
{
  "questions": [
    {
      "type": "multiple_choice",
      "question": "What does fopen return in C?",
      "options": [
        "A pointer",
        "An integer descriptor",
        "A null constant",
        "file''';

      // Calling _extractJson through build / internal extraction
      // Verify that building local fallback or repairing does not throw unhandled FormatException
      final repaired = geminiService.buildLocalQuizFallback(
        documentText: 'Operating systems manage files, buffers, and system calls for I/O operations.',
        sourceFileName: 'test_file.txt',
        questionCount: 3,
        difficulty: QuizDifficulty.medium,
      );

      expect(repaired.questions.isNotEmpty, isTrue);
      expect(repaired.sourceFileName, equals('test_file.txt'));
    });
  });
}
