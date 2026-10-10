enum QuizDifficulty { easy, medium, hard }

extension QuizDifficultyX on QuizDifficulty {
  String get label {
    switch (this) {
      case QuizDifficulty.easy:
        return 'Easy';
      case QuizDifficulty.medium:
        return 'Medium';
      case QuizDifficulty.hard:
        return 'Hard';
    }
  }

  /// Sent to the backend as-is; keep this stable since it's part of the
  /// AI prompt contract.
  String get apiValue => name; // 'easy' | 'medium' | 'hard'

  String get description {
    switch (this) {
      case QuizDifficulty.easy:
        return 'Clear definitions and basic recall. Direct and easy to pick.';
      case QuizDifficulty.medium:
        return 'Comprehension & cause-and-effect. Plausible distractors from the material.';
      case QuizDifficulty.hard:
        return 'Deep conceptual mastery & formulas. Features MCQs and Fill-in-the-Blank questions with locked strict answering.';
    }
  }
}

/// User-chosen settings before quiz generation.
class QuizSettingsModel {
  static const int minQuestions = 5;
  static const int maxQuestions = 50;

  final int questionCount;
  final QuizDifficulty difficulty;
  final String category;

  const QuizSettingsModel({
    this.questionCount = 10,
    this.difficulty = QuizDifficulty.medium,
    this.category = 'All',
  });

  bool get isValid =>
      questionCount >= minQuestions && questionCount <= maxQuestions;

  /// Calculates the dynamic countdown duration in seconds according to difficulty
  /// and question count specifications:
  /// - Easy: null (countdown disabled / unlimited time)
  /// - Medium & Hard:
  ///     50 questions: 60 minutes (3600s)
  ///     40 questions: 50 minutes (3000s)
  ///     30 questions: 40 minutes (2400s)
  ///     20 questions: 30 minutes (1800s)
  ///     10 questions: 10 minutes (600s)
  ///      5 questions: 5 minutes (300s)
  static int? calculateTimeLimitInSeconds(int count, QuizDifficulty difficulty) {
    if (difficulty == QuizDifficulty.easy) {
      return null; // Unlimited time
    }

    final clamped = count.clamp(minQuestions, maxQuestions);

    if (clamped <= 5) return 5 * 60;
    if (clamped <= 10) {
      final ratio = (clamped - 5) / (10 - 5);
      return (5 * 60 + ratio * (10 * 60 - 5 * 60)).round();
    }
    if (clamped <= 20) {
      final ratio = (clamped - 10) / (20 - 10);
      return (10 * 60 + ratio * (30 * 60 - 10 * 60)).round();
    }
    if (clamped <= 30) {
      final ratio = (clamped - 20) / (30 - 20);
      return (30 * 60 + ratio * (40 * 60 - 30 * 60)).round();
    }
    if (clamped <= 40) {
      final ratio = (clamped - 30) / (40 - 30);
      return (40 * 60 + ratio * (50 * 60 - 40 * 60)).round();
    }
    final ratio = (clamped - 40) / (50 - 40);
    return (50 * 60 + ratio * (60 * 60 - 50 * 60)).round();
  }

  /// The countdown limit for the current settings instance, or null if unlimited.
  int? get timeLimitInSeconds =>
      calculateTimeLimitInSeconds(questionCount, difficulty);

  /// Human-friendly display of the estimated exam duration.
  String get formattedEstimatedTime {
    final seconds = timeLimitInSeconds;
    if (seconds == null) {
      return 'Unlimited Time';
    }
    final minutes = (seconds / 60).round();
    return '$minutes mins';
  }

  QuizSettingsModel copyWith({
    int? questionCount,
    QuizDifficulty? difficulty,
    String? category,
  }) {
    return QuizSettingsModel(
      questionCount: questionCount ?? this.questionCount,
      difficulty: difficulty ?? this.difficulty,
      category: category ?? this.category,
    );
  }
}
