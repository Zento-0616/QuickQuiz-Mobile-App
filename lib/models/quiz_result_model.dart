import 'quiz_model.dart';
import 'quiz_settings_model.dart';
import 'question_model.dart';

class QuizResultModel {
  final String quizId;
  final String? userId;
  final String fileName;
  final QuizDifficulty difficulty;
  final int questionCount;
  final int correctCount;
  final DateTime createdAt;
  final List<QuestionModel> questions;
  final List<String> suggestions;
  final int? timeElapsedSeconds;
  final int? expEarned;
  final String? userNickname;
  final String? userAvatar;
  final double? integrityPercentage;
  final int answerChangesCount;
  final int backAttemptsCount;
  final int screenshotAttemptsCount;
  final int delayDeductions;

  const QuizResultModel({
    required this.quizId,
    required this.userId,
    required this.fileName,
    required this.difficulty,
    required this.questionCount,
    required this.correctCount,
    required this.createdAt,
    required this.questions,
    this.suggestions = const [],
    this.timeElapsedSeconds,
    this.expEarned,
    this.userNickname,
    this.userAvatar,
    this.integrityPercentage,
    this.answerChangesCount = 0,
    this.backAttemptsCount = 0,
    this.screenshotAttemptsCount = 0,
    this.delayDeductions = 0,
  });

  QuizResultModel copyWith({
    String? quizId,
    String? userId,
    String? fileName,
    QuizDifficulty? difficulty,
    int? questionCount,
    int? correctCount,
    DateTime? createdAt,
    List<QuestionModel>? questions,
    List<String>? suggestions,
    int? timeElapsedSeconds,
    int? expEarned,
    String? userNickname,
    String? userAvatar,
    double? integrityPercentage,
    int? answerChangesCount,
    int? backAttemptsCount,
    int? screenshotAttemptsCount,
    int? delayDeductions,
  }) {
    return QuizResultModel(
      quizId: quizId ?? this.quizId,
      userId: userId ?? this.userId,
      fileName: fileName ?? this.fileName,
      difficulty: difficulty ?? this.difficulty,
      questionCount: questionCount ?? this.questionCount,
      correctCount: correctCount ?? this.correctCount,
      createdAt: createdAt ?? this.createdAt,
      questions: questions ?? this.questions,
      suggestions: suggestions ?? this.suggestions,
      timeElapsedSeconds: timeElapsedSeconds ?? this.timeElapsedSeconds,
      expEarned: expEarned ?? this.expEarned,
      userNickname: userNickname ?? this.userNickname,
      userAvatar: userAvatar ?? this.userAvatar,
      integrityPercentage: integrityPercentage ?? this.integrityPercentage,
      answerChangesCount: answerChangesCount ?? this.answerChangesCount,
      backAttemptsCount: backAttemptsCount ?? this.backAttemptsCount,
      screenshotAttemptsCount: screenshotAttemptsCount ?? this.screenshotAttemptsCount,
      delayDeductions: delayDeductions ?? this.delayDeductions,
    );
  }

  int get incorrectCount => questionCount - correctCount;

  double get percentage =>
      questionCount == 0 ? 0 : (correctCount / questionCount) * 100;

  int get roundedPercentage => percentage.round();

  String get performanceMessage {
    final p = roundedPercentage;
    if (p >= 90) return "Excellent! You've mastered this material.";
    if (p >= 75) return "Great job! You're doing well.";
    if (p >= 50) return "Good effort! Review the questions you missed.";
    return 'Keep practicing! Review the material and try again.';
  }

  static List<String> generateImprovementSuggestions({
    required int score,
    required int total,
    required QuizDifficulty difficulty,
    List<QuestionModel> questions = const [],
  }) {
    final pct = total == 0 ? 0 : ((score / total) * 100).round();
    final missedQuestions = questions.where((q) => !q.isCorrect).toList();
    final missedCategories = missedQuestions
        .map((q) => q.category.trim())
        .where((c) => c.isNotEmpty && c.toLowerCase() != 'general knowledge')
        .toSet()
        .toList();

    final tips = <String>[];

    if (pct < 70) {
      tips.add(
        'Trick - Process of Elimination: Quickly disqualify 2 obviously incorrect options first (watch for absolute traps like "always", "never", or "only") to raise your guessing odds to 50/50.',
      );
      tips.add(
        'Trick - Read the Question Stem Twice: Identify the core variable or keyword before reading the options so you are not misled by tricky distractor phrasing.',
      );
    } else {
      tips.add(
        'Trick - Opposing Options Clue: When two choices directly contradict each other, the correct answer is almost always one of those two opposing choices.',
      );
      tips.add(
        'Trick - Time Pacing: Flag ambiguous questions instantly and move on. Answering easy questions first prevents rushing at the end.',
      );
    }

    if (pct < 60) {
      tips.add(
        'Study Strategy - Active Recall: Close your study notes and write down a 3-bullet summary of each missed question without peeking.',
      );
      if (missedCategories.isNotEmpty) {
        tips.add(
          'Targeted Review: Dedicate your next study session specifically to ${missedCategories.take(2).join(" & ")} concepts.',
        );
      } else {
        tips.add(
          'Targeted Review: Review the ${missedQuestions.length} missed questions and write down why each correct answer is valid.',
        );
      }
    } else if (pct < 85) {
      tips.add(
        'Study Strategy - The Feynman Technique: Explain the toughest concept from this quiz out loud in plain English as if explaining to a beginner.',
      );
      tips.add(
        'Spaced Interval: Retake this quiz or a variant in 48 hours to transfer these insights into permanent long-term memory.',
      );
    } else {
      tips.add(
        'Study Strategy - Interleaving: Mix this topic with related subjects to strengthen your cognitive flexibility and prevent pattern memorization.',
      );
      tips.add(
        'Next Level: Try the Hard difficulty mode or a 15-question set to challenge yourself on advanced edge cases.',
      );
    }

    return tips;
  }

  factory QuizResultModel.fromQuiz(
    QuizModel quiz, {
    String? userId,
    int? timeElapsedSeconds,
    int? expEarned,
    String? userNickname,
    String? userAvatar,
    double? integrityPercentage,
    int answerChangesCount = 0,
    int backAttemptsCount = 0,
    int screenshotAttemptsCount = 0,
    int delayDeductions = 0,
  }) {
    final correct = quiz.questions.where((q) => q.isCorrect).length;
    final generatedSuggestions = generateImprovementSuggestions(
      score: correct,
      total: quiz.questionCount,
      difficulty: quiz.difficulty,
      questions: quiz.questions,
    );

    return QuizResultModel(
      quizId: quiz.id,
      userId: userId,
      fileName: quiz.sourceFileName,
      difficulty: quiz.difficulty,
      questionCount: quiz.questionCount,
      correctCount: correct,
      createdAt: DateTime.now(),
      questions: quiz.questions,
      suggestions: generatedSuggestions,
      timeElapsedSeconds: timeElapsedSeconds,
      expEarned: expEarned,
      userNickname: userNickname,
      userAvatar: userAvatar,
      integrityPercentage: integrityPercentage,
      answerChangesCount: answerChangesCount,
      backAttemptsCount: backAttemptsCount,
      screenshotAttemptsCount: screenshotAttemptsCount,
      delayDeductions: delayDeductions,
    );
  }

  factory QuizResultModel.fromJson(Map<String, dynamic> json) {
    final questionsJson = json['questions'] as List<dynamic>? ?? [];
    final questions = questionsJson
        .map((q) => QuestionModel.fromJson(q as Map<String, dynamic>))
        .toList();

    final count = (json['questionCount'] as num?)?.toInt() ?? 0;
    final score = (json['score'] as num?)?.toInt() ?? 0;
    final difficulty = QuizDifficulty.values.firstWhere(
      (d) => d.apiValue == json['difficulty'],
      orElse: () => QuizDifficulty.medium,
    );

    final rawSuggestions = json['suggestions'] as List<dynamic>?;
    List<String> suggestions;
    if (rawSuggestions != null && rawSuggestions.isNotEmpty) {
      suggestions = rawSuggestions.map((e) => e.toString()).toList();
    } else {
      suggestions = generateImprovementSuggestions(
        score: score,
        total: count,
        difficulty: difficulty,
        questions: questions,
      );
    }

    return QuizResultModel(
      quizId: json['quizId'] as String? ?? '',
      userId: json['userId'] as String?,
      fileName: json['fileName'] as String? ?? 'Untitled',
      difficulty: difficulty,
      questionCount: count,
      correctCount: score,
      createdAt: _parseDate(json['createdAt']),
      questions: questions,
      suggestions: suggestions,
      timeElapsedSeconds: (json['timeElapsedSeconds'] as num?)?.toInt(),
      expEarned: (json['expEarned'] as num?)?.toInt(),
      userNickname: json['userNickname'] as String?,
      userAvatar: json['userAvatar'] as String?,
      integrityPercentage: (json['integrityPercentage'] as num?)?.toDouble(),
      answerChangesCount: (json['answerChangesCount'] as num?)?.toInt() ?? 0,
      backAttemptsCount: (json['backAttemptsCount'] as num?)?.toInt() ?? 0,
      screenshotAttemptsCount: (json['screenshotAttemptsCount'] as num?)?.toInt() ?? 0,
      delayDeductions: (json['delayDeductions'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quizId': quizId,
      'userId': userId,
      'fileName': fileName,
      'difficulty': difficulty.apiValue,
      'questionCount': questionCount,
      'score': correctCount,
      'percentage': percentage,
      'createdAt': createdAt.toIso8601String(),
      'questions': questions.map((q) => q.toJson()).toList(),
      'suggestions': suggestions,
      'timeElapsedSeconds': timeElapsedSeconds,
      'expEarned': expEarned,
      'userNickname': userNickname,
      'userAvatar': userAvatar,
      'integrityPercentage': integrityPercentage,
      'answerChangesCount': answerChangesCount,
      'backAttemptsCount': backAttemptsCount,
      'screenshotAttemptsCount': screenshotAttemptsCount,
      'delayDeductions': delayDeductions,
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.now();
    }
  }
}