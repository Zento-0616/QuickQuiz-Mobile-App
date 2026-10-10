import 'package:flutter_test/flutter_test.dart';
import 'package:quickquiz/models/question_model.dart';
import 'package:quickquiz/utils/text_sanitizer.dart';

void main() {
  group('TextSanitizer', () {
    test('stripLeadingArtifacts removes bullets, asterisks, dashes, and letters', () {
      expect(TextSanitizer.stripLeadingArtifacts('• Cost of infrastructure'), 'Cost of infrastructure');
      expect(TextSanitizer.stripLeadingArtifacts('* High availability cluster'), 'High availability cluster');
      expect(TextSanitizer.stripLeadingArtifacts('- Fault tolerance protocol'), 'Fault tolerance protocol');
      expect(TextSanitizer.stripLeadingArtifacts('A) Layer 3 Routing'), 'Layer 3 Routing');
      expect(TextSanitizer.stripLeadingArtifacts('1. Encryption algorithm'), 'Encryption algorithm');
      expect(TextSanitizer.stripLeadingArtifacts('(B) Data encapsulation'), 'Data encapsulation');
    });

    test('cleanDoublePeriods fixes double period typos and ensures proper spacing', () {
      expect(
        TextSanitizer.cleanDoublePeriods('This is a process.. Which solution works best?'),
        'This is a process. Which solution works best?',
      );
      expect(
        TextSanitizer.cleanDoublePeriods('Operational execution..'),
        'Operational execution.',
      );
      expect(
        TextSanitizer.cleanDoublePeriods('Sentence ending.Next sentence begins.'),
        'Sentence ending. Next sentence begins.',
      );
    });

    test('deduplicateAndSanitizeOptions removes bullet duplicates and maintains 4 unique options', () {
      final rawOptions = [
        '• Cost',
        'Cost',
        '• Performance',
        'Scalability',
      ];

      final result = TextSanitizer.deduplicateAndSanitizeOptions(
        rawOptions: rawOptions,
        rawCorrectAnswerIndex: 0,
      );

      expect(result.options.length, 4);
      // All 4 options must be distinct (case-insensitive)
      final uniqueSet = result.options.map((o) => o.toLowerCase().trim()).toSet();
      expect(uniqueSet.length, 4);
      // First option was correct answer 'Cost', should be retained
      expect(result.options[result.correctAnswerIndex].toLowerCase(), 'cost');
    });

    test('deduplicateAndSanitizeOptions aligns correct answer when given as text', () {
      final rawOptions = [
        'A) Cloud Computing',
        'B) Edge Computing',
        'C) Fog Computing',
        'D) Grid Computing',
      ];

      final result = TextSanitizer.deduplicateAndSanitizeOptions(
        rawOptions: rawOptions,
        rawCorrectAnswerText: 'Edge Computing',
      );

      expect(result.options[0], 'Cloud Computing');
      expect(result.options[1], 'Edge Computing');
      expect(result.options[2], 'Fog Computing');
      expect(result.options[3], 'Grid Computing');
      expect(result.correctAnswerIndex, 1);
    });

    test('isMetadataOrHeader detects slide dates, page numbers, and fragmented titles', () {
      expect(TextSanitizer.isMetadataOrHeader('October 16 - 21, 2025 OVERVIEW: SOFTWARE AND'), isTrue);
      expect(TextSanitizer.isMetadataOrHeader('Page 1 of 12'), isTrue);
      expect(TextSanitizer.isMetadataOrHeader('SLIDE 5'), isTrue);
      expect(TextSanitizer.isMetadataOrHeader('CHAPTER 2: ARCHITECTURAL PATTERNS'), isTrue);
      expect(TextSanitizer.isMetadataOrHeader('10/16/2025'), isTrue);
      expect(
        TextSanitizer.isMetadataOrHeader('Relational database indexing significantly improves query throughput.'),
        isFalse,
      );
    });

    test('cleanMetadataArtifacts strips embedded dates and dangling conjunctions', () {
      expect(
        TextSanitizer.cleanMetadataArtifacts('Engineering October 16 - 21, 2025 OVERVIEW: SOFTWARE AND'),
        'Engineering SOFTWARE',
      );
      expect(
        TextSanitizer.cleanMetadataArtifacts('Database systems on 10/15/2025 for'),
        'Database systems on',
      );
    });
  });

  group('QuestionModel.fromJson with TextSanitizer', () {
    test('parses and sanitizes JSON with correctAnswer string', () {
      final json = {
        'question': 'What is the function of the process.. Which method is preferred?',
        'options': [
          '• High Cost',
          'High Cost',
          '* Low Latency',
          '- Scalability'
        ],
        'correctAnswer': '• High Cost',
        'explanation': 'Addresses operational overhead..'
      };

      final question = QuestionModel.fromJson(json);

      expect(question.question, 'What is the function of the process. Which method is preferred?');
      expect(question.explanation, 'Addresses operational overhead.');
      expect(question.options.length, 4);
      expect(question.options.toSet().length, 4);
      expect(question.options[question.correctAnswerIndex], 'High Cost');
    });

    test('parses letter correctAnswer like "B"', () {
      final json = {
        'question': 'Which protocol operates at Layer 4?',
        'options': ['IP', 'TCP', 'Ethernet', 'HTTP'],
        'correctAnswer': 'B',
        'explanation': 'TCP is a transport layer protocol.'
      };

      final question = QuestionModel.fromJson(json);
      expect(question.correctAnswerIndex, 1);
      expect(question.options[question.correctAnswerIndex], 'TCP');
    });
  });
}
