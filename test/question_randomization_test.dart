import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quickquiz/services/question_history_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuestionHistoryService Tests', () {
    late QuestionHistoryService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      service = QuestionHistoryService();
      await service.clearHistoryForDocument('biology_notes.pdf');
    });

    test('normalizeStem removes non-alphanumeric characters and converts to lowercase', () {
      expect(
        QuestionHistoryService.normalizeStem('What is the primary function of Mitochondria?'),
        'whatistheprimaryfunctionofmitochondria',
      );
      expect(
        QuestionHistoryService.normalizeStem('  1. Which component (Layer 3) handles routing?  '),
        '1whichcomponentlayer3handlesrouting',
      );
    });

    test('Records questions and detects exact duplicate stems', () async {
      const docName = 'biology_notes.pdf';

      expect(service.isDuplicate(docName, 'What is cellular respiration?'), false);

      await service.recordGeneratedQuestions(docName, [
        'What is cellular respiration?',
        'Describe the process of photosynthesis in plants.',
      ]);

      // Same question (case-insensitive, punctuation-insensitive) should be duplicate
      expect(service.isDuplicate(docName, 'What is cellular respiration?'), true);
      expect(service.isDuplicate(docName, 'what is cellular respiration'), true);
      expect(service.isDuplicate(docName, 'Describe the process of photosynthesis in plants!'), true);

      // Unrelated question should not be duplicate
      expect(service.isDuplicate(docName, 'What is the role of ribosomes?'), false);
    });

    test('Detects near-duplicate question stems using token overlap', () async {
      const docName = 'biology_notes.pdf';

      await service.recordGeneratedQuestions(docName, [
        'What is the fundamental mechanism of oxidative phosphorylation in cellular mitochondria?',
      ]);

      // Rephrased candidate with >80% overlapping key tokens
      final nearDuplicate =
          'What is the fundamental mechanism of oxidative phosphorylation in cellular mitochondria?';
      expect(service.isDuplicate(docName, nearDuplicate), true);
    });

    test('Stores and retrieves previous question stems across calls', () async {
      const docName = 'biology_notes.pdf';

      final stems = [
        'Question A about genetics',
        'Question B about alleles',
        'Question C about phenotype',
      ];

      await service.recordGeneratedQuestions(docName, stems);
      final retrieved = await service.getPreviousQuestionStems(docName);

      expect(retrieved.length, 3);
      expect(retrieved.contains('Question A about genetics'), true);
      expect(retrieved.contains('Question B about alleles'), true);
      expect(retrieved.contains('Question C about phenotype'), true);

      // Clearing history resets it
      await service.clearHistoryForDocument(docName);
      final afterClear = await service.getPreviousQuestionStems(docName);
      expect(afterClear.isEmpty, true);
    });
  });
}
