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

  String get apiValue => name;

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

  static int? calculateTimeLimitInSeconds(int count, QuizDifficulty difficulty) {
    if (difficulty == QuizDifficulty.easy) {
      return null;
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

  int? get timeLimitInSeconds =>
      calculateTimeLimitInSeconds(questionCount, difficulty);

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
