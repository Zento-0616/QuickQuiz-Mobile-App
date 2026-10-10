import 'dart:math';

import '../utils/text_sanitizer.dart';
import 'quiz_settings_model.dart';

enum QuestionType {
  multipleChoice,
  fillInBlank;

  String get apiValue {
    switch (this) {
      case QuestionType.multipleChoice:
        return 'multiple_choice';
      case QuestionType.fillInBlank:
        return 'fill_in_the_blank';
    }
  }

  static QuestionType fromString(String? value) {
    if (value == null) return QuestionType.multipleChoice;
    final val = value.toLowerCase().replaceAll('-', '_').trim();
    if (val == 'fill_in_the_blank' || val == 'fill_in_blank' || val == 'blank') {
      return QuestionType.fillInBlank;
    }
    return QuestionType.multipleChoice;
  }
}

/// A single question (MCQ or Fill-in-the-Blank) within a generated quiz.
///
/// Supports rich metadata including category, difficulty, question type, and relevant tags.
class QuestionModel {
  final String? id;
  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final String explanation;
  final String category;
  final QuizDifficulty difficulty;
  final List<String> tags;
  final QuestionType type;

  /// Accepted alias spellings or variants for Fill-in-the-Blank questions
  final List<String> acceptableAnswers;

  final String? hint;

  /// The option index the user picked (for multiple choice).
  final int? selectedAnswerIndex;

  /// The text string the user entered (for Fill-in-the-Blank).
  final String? userTextAnswer;

  /// Whether the user marked this question for later review during an exam.
  final bool isFlagged;

  const QuestionModel({
    this.id,
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    required this.explanation,
    this.hint,
    this.category = 'General Knowledge',
    this.difficulty = QuizDifficulty.medium,
    this.tags = const [],
    this.type = QuestionType.multipleChoice,
    this.acceptableAnswers = const [],
    this.selectedAnswerIndex,
    this.userTextAnswer,
    this.isFlagged = false,
  });

  bool get isFillInBlank => type == QuestionType.fillInBlank;
  bool get isMultipleChoice => type == QuestionType.multipleChoice;

  bool get isAnswered => isFillInBlank
      ? (userTextAnswer != null && userTextAnswer!.trim().isNotEmpty)
      : (selectedAnswerIndex != null);

  bool get isCorrect {
    if (isFillInBlank) {
      if (userTextAnswer == null || userTextAnswer!.trim().isEmpty) return false;
      return checkFillInBlankCorrectness(userTextAnswer!);
    }
    return selectedAnswerIndex != null && selectedAnswerIndex == correctAnswerIndex;
  }

  String get effectiveCorrectAnswerText {
    if (correctAnswerIndex >= 0 && correctAnswerIndex < options.length) {
      return options[correctAnswerIndex];
    }
    if (acceptableAnswers.isNotEmpty) {
      return acceptableAnswers.first;
    }
    return '';
  }

  bool checkFillInBlankCorrectness(String answer) {
    final cleanInput = normalizeAnswerText(answer);
    if (cleanInput.isEmpty) return false;

    // Check against primary target
    final primaryTarget = normalizeAnswerText(effectiveCorrectAnswerText);
    if (primaryTarget.isNotEmpty && cleanInput == primaryTarget) {
      return true;
    }

    // Check against accepted alternatives
    for (final alt in acceptableAnswers) {
      if (normalizeAnswerText(alt) == cleanInput) {
        return true;
      }
    }

    return false;
  }

  static String normalizeAnswerText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'^[^\w\d]+|[^\w\d]+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Returns the hint, or derives a smart educational clue without revealing
  /// the direct answer if no explicit hint was set.
  String get effectiveHint {
    if (hint != null && hint!.trim().isNotEmpty) {
      return hint!.trim();
    }
    final tagClue = tags.isNotEmpty ? tags.first : category;
    if (explanation.isNotEmpty) {
      final sentences = explanation.split(RegExp(r'\. |\n'));
      if (sentences.isNotEmpty) {
        final first = sentences.first.trim();
        final correctText = (correctAnswerIndex >= 0 && correctAnswerIndex < options.length)
            ? options[correctAnswerIndex]
            : '';
        if (first.isNotEmpty &&
            (correctText.isEmpty || !first.toLowerCase().contains(correctText.toLowerCase()))) {
          return first.endsWith('.') ? first : '$first.';
        }
      }
    }
    return 'Focus on core principles related to $tagClue.';
  }

  /// Parses one question object and throws a [FormatException] if the shape is invalid.
  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    final questionText = json['question'];
    final options = json['options'];
    final rawCorrectIndex = json['correctAnswerIndex'];
    final rawCorrectAnswer = json['correctAnswer'];
    final explanation = json['explanation'];
    final hint = (json['hint'] as String?)?.trim();
    final selectedIndex = json['selectedAnswerIndex'];
    final userTextAnswer = json['userTextAnswer'] as String?;
    final isFlagged = json['isFlagged'] == true;
    final id = json['id'] as String?;
    final category = (json['category'] as String?)?.trim() ?? 'General Knowledge';
    final type = QuestionType.fromString(json['type'] as String?);

    final rawAcceptable = json['acceptableAnswers'];
    final acceptableAnswers = rawAcceptable is List
        ? rawAcceptable.map((a) => a.toString().trim()).where((a) => a.isNotEmpty).toList()
        : const <String>[];

    QuizDifficulty difficulty = QuizDifficulty.medium;
    final diffStr = json['difficulty'] as String?;
    if (diffStr != null) {
      difficulty = QuizDifficulty.values.firstWhere(
        (d) => d.apiValue.toLowerCase() == diffStr.toLowerCase(),
        orElse: () => QuizDifficulty.medium,
      );
    }

    final rawTags = json['tags'];
    final tags = rawTags is List
        ? rawTags.map((t) => t.toString()).toList()
        : const <String>[];

    if (questionText is! String || questionText.trim().isEmpty) {
      throw const FormatException('Question text missing or invalid.');
    }

    List<String> optionStrings = [];
    if (options is List) {
      optionStrings = options.map((o) => o.toString()).toList();
    }

    // Resolve correct answer index or text
    int? parsedIndex;
    if (rawCorrectIndex is int) {
      parsedIndex = rawCorrectIndex;
    } else if (rawCorrectIndex is String) {
      parsedIndex = int.tryParse(rawCorrectIndex);
    }

    String? parsedCorrectText;
    if (rawCorrectAnswer is String) {
      parsedCorrectText = rawCorrectAnswer.trim();
      if (parsedCorrectText.length == 1 &&
          parsedCorrectText.toUpperCase().codeUnitAt(0) >= 65 &&
          parsedCorrectText.toUpperCase().codeUnitAt(0) <= 68) {
        parsedIndex ??= parsedCorrectText.toUpperCase().codeUnitAt(0) - 65;
      }
    }

    if (type == QuestionType.fillInBlank) {
      // For fill in the blank, option list can be minimal or just the correct answer
      if (optionStrings.isEmpty && parsedCorrectText != null && parsedCorrectText.isNotEmpty) {
        optionStrings = [parsedCorrectText];
        parsedIndex = 0;
      } else if (optionStrings.isEmpty && acceptableAnswers.isNotEmpty) {
        optionStrings = [acceptableAnswers.first];
        parsedIndex = 0;
      }
    } else {
      if (optionStrings.isEmpty) {
        throw const FormatException('Multiple choice question must have options.');
      }
    }

    if (parsedIndex == null && (parsedCorrectText == null || parsedCorrectText.isEmpty)) {
      if (acceptableAnswers.isNotEmpty) {
        parsedCorrectText = acceptableAnswers.first;
      } else {
        throw const FormatException('Question must specify correctAnswer or correctAnswerIndex.');
      }
    }

    final sanitizedQuestion = TextSanitizer.sanitizeQuestion(questionText);
    final sanitizedExplanation = explanation is String
        ? TextSanitizer.sanitizeText(explanation)
        : 'Conceptual analysis based on study material.';

    // For multiple choice, deduplicate and ensure aligned index
    List<String> finalOptions = optionStrings;
    int finalIndex = parsedIndex ?? 0;

    if (type == QuestionType.multipleChoice && optionStrings.isNotEmpty) {
      final sanitizedResult = TextSanitizer.deduplicateAndSanitizeOptions(
        rawOptions: optionStrings,
        rawCorrectAnswerIndex: parsedIndex,
        rawCorrectAnswerText: parsedCorrectText,
      );
      finalOptions = sanitizedResult.options;
      finalIndex = sanitizedResult.correctAnswerIndex;
    }

    return QuestionModel(
      id: id,
      question: sanitizedQuestion,
      options: finalOptions,
      correctAnswerIndex: finalIndex,
      explanation: sanitizedExplanation,
      hint: hint != null && hint.isNotEmpty ? TextSanitizer.sanitizeText(hint) : null,
      category: category,
      difficulty: difficulty,
      tags: tags,
      type: type,
      acceptableAnswers: acceptableAnswers,
      selectedAnswerIndex: selectedIndex as int?,
      userTextAnswer: userTextAnswer,
      isFlagged: isFlagged,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'question': question,
      'options': options,
      'correctAnswerIndex': correctAnswerIndex,
      'explanation': explanation,
      if (hint != null) 'hint': hint,
      'category': category,
      'difficulty': difficulty.apiValue,
      'tags': tags,
      'type': type.apiValue,
      'acceptableAnswers': acceptableAnswers,
      'selectedAnswerIndex': selectedAnswerIndex,
      if (userTextAnswer != null) 'userTextAnswer': userTextAnswer,
      'isFlagged': isFlagged,
    };
  }

  QuestionModel copyWith({
    String? id,
    String? question,
    List<String>? options,
    int? correctAnswerIndex,
    String? explanation,
    String? hint,
    String? category,
    QuizDifficulty? difficulty,
    List<String>? tags,
    QuestionType? type,
    List<String>? acceptableAnswers,
    int? selectedAnswerIndex,
    String? userTextAnswer,
    bool clearSelection = false,
    bool? isFlagged,
  }) {
    return QuestionModel(
      id: id ?? this.id,
      question: question ?? this.question,
      options: options ?? this.options,
      correctAnswerIndex: correctAnswerIndex ?? this.correctAnswerIndex,
      explanation: explanation ?? this.explanation,
      hint: hint ?? this.hint,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      tags: tags ?? this.tags,
      type: type ?? this.type,
      acceptableAnswers: acceptableAnswers ?? this.acceptableAnswers,
      selectedAnswerIndex:
          clearSelection ? null : (selectedAnswerIndex ?? this.selectedAnswerIndex),
      userTextAnswer:
          clearSelection ? null : (userTextAnswer ?? this.userTextAnswer),
      isFlagged: isFlagged ?? this.isFlagged,
    );
  }

  /// Randomly distributes the correct answer across indices 0, 1, 2, 3 (A, B, C, D)
  /// ensuring it never predictably defaults to option A for multiple choice questions.
  QuestionModel randomizeAnswers({Random? rng}) {
    if (isFillInBlank || options.length < 2) return this;
    final r = rng ?? Random();
    final correctText = (correctAnswerIndex >= 0 && correctAnswerIndex < options.length)
        ? options[correctAnswerIndex]
        : options.first;

    final distractors = <String>[];
    for (int i = 0; i < options.length; i++) {
      if (i != correctAnswerIndex) {
        distractors.add(options[i]);
      }
    }
    distractors.shuffle(r);
    final newCorrectIndex = r.nextInt(options.length);
    final newOptions = List<String>.from(distractors);
    newOptions.insert(newCorrectIndex.clamp(0, newOptions.length), correctText);

    return copyWith(
      options: newOptions,
      correctAnswerIndex: newCorrectIndex.clamp(0, newOptions.length - 1),
    );
  }

  /// Formats the question in the standard structured layout
  String formatStructuredLayout([int? questionNumber]) {
    final prefix = questionNumber != null ? '$questionNumber. ' : '';
    if (isFillInBlank) {
      return '$prefix$question\n   [Fill-in-the-Blank: $effectiveCorrectAnswerText]';
    }
    final buffer = StringBuffer('$prefix$question\n');
    for (int i = 0; i < options.length; i++) {
      final letter = String.fromCharCode(65 + i);
      buffer.writeln('   $letter. ${options[i]}');
    }
    return buffer.toString().trimRight();
  }
}