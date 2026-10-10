import 'package:uuid/uuid.dart';

import 'question_model.dart';
import 'quiz_settings_model.dart';

const _uuid = Uuid();

/// A generated or admin-published quiz: metadata about its source/settings
/// plus the list of questions.
class QuizModel {
  final String id;
  final String title;
  final String sourceFileName;
  final QuizDifficulty difficulty;
  final List<QuestionModel> questions;
  final DateTime createdAt;
  final int? timeLimitSeconds;
  final List<String> topicTags;
  final double expMultiplier;
  final int? expReward; // Simple 1-1000 EXP reward
  final bool isPublished;
  final bool isGlobal;
  final bool isUnlimitedPlay;
  final bool allowRepeatExp; // Per-quiz toggle for re-earning EXP on replay
  final String? authorId;
  final String? authorName;
  final int playCount;
  final String? description;
  final int minLevel;
  final String category;
  final String status;
  final String quizScheduleType; // 'standard', 'daily', 'weekly'
  final DateTime? expiresAt; // Time until quiz closes
  final DateTime? closedAt; // When quiz was marked done/closed

  QuizModel({
    String? id,
    String? title,
    required this.sourceFileName,
    required this.difficulty,
    required this.questions,
    DateTime? createdAt,
    int? timeLimitSeconds,
    List<String>? topicTags,
    this.expMultiplier = 1.0,
    this.expReward,
    this.isPublished = false,
    this.isGlobal = true,
    this.isUnlimitedPlay = false,
    this.allowRepeatExp = false,
    this.authorId,
    this.authorName,
    this.playCount = 0,
    this.description,
    this.minLevel = 1,
    this.category = 'General',
    this.status = 'Active',
    this.quizScheduleType = 'standard',
    this.expiresAt,
    this.closedAt,
  })  : id = id ?? _uuid.v4(),
        title = (title != null && title.isNotEmpty) ? title : sourceFileName,
        createdAt = createdAt ?? DateTime.now(),
        topicTags = topicTags ?? const ['General'],
        timeLimitSeconds = timeLimitSeconds ??
            QuizSettingsModel.calculateTimeLimitInSeconds(
              questions.length,
              difficulty,
            );

  int get questionCount => questions.length;

  bool get isClosed {
    final s = status.toLowerCase();
    if (s == 'stopped' || s == 'done' || s == 'concluded') return true;
    if (expiresAt != null && expiresAt!.isBefore(DateTime.now())) return true;
    return false;
  }

  Duration? get timeRemaining {
    if (expiresAt == null || isClosed) return null;
    final diff = expiresAt!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  String get timeRemainingFormatted {
    final tr = timeRemaining;
    if (tr == null) return 'No expiry';
    if (tr == Duration.zero) return 'Expired';
    final days = tr.inDays;
    final hours = tr.inHours % 24;
    final minutes = tr.inMinutes % 60;
    if (days > 0) return '${days}d ${hours}h left';
    if (hours > 0) return '${hours}h ${minutes}m left';
    return '${minutes}m left';
  }

  bool get isHiddenDueToExpiration {
    if (!isClosed) return false;
    final closeTime = closedAt ?? expiresAt;
    if (closeTime == null) return false;
    return DateTime.now().difference(closeTime).inHours >= 24;
  }

  int get effectiveExpReward {
    if (expReward != null && expReward! > 0) return expReward!;
    return (100 * expMultiplier).round().clamp(1, 1000);
  }

  /// Parses the top-level `{"questions": [...]}` response from the backend.
  factory QuizModel.fromApiResponse({
    required Map<String, dynamic> json,
    required String sourceFileName,
    required QuizDifficulty difficulty,
    required int expectedQuestionCount,
  }) {
    final rawQuestions = json['questions'];
    if (rawQuestions is! List || rawQuestions.isEmpty) {
      throw const FormatException('No questions returned by the AI.');
    }

    final questions = rawQuestions
        .map((q) => QuestionModel.fromJson(q as Map<String, dynamic>).randomizeAnswers())
        .toList();

    if (questions.length != expectedQuestionCount) {
      throw FormatException(
        'Expected $expectedQuestionCount questions but received '
        '${questions.length}.',
      );
    }

    return QuizModel(
      sourceFileName: sourceFileName,
      difficulty: difficulty,
      questions: questions,
    );
  }

  factory QuizModel.fromJson(Map<String, dynamic> json) {
    final rawQuestions = json['questions'] as List? ?? [];
    final questions = rawQuestions
        .map((q) => QuestionModel.fromJson(Map<String, dynamic>.from(q as Map)))
        .toList();

    return QuizModel(
      id: json['id'] as String?,
      title: json['title'] as String?,
      sourceFileName: json['sourceFileName'] as String? ?? 'Quiz',
      difficulty: QuizDifficulty.values.firstWhere(
        (d) => d.name == (json['difficulty'] as String? ?? 'medium'),
        orElse: () => QuizDifficulty.medium,
      ),
      questions: questions,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      timeLimitSeconds: json['timeLimitSeconds'] as int?,
      topicTags: (json['topicTags'] as List?)?.map((e) => e.toString()).toList() ?? ['General'],
      expMultiplier: (json['expMultiplier'] as num?)?.toDouble() ?? 1.0,
      expReward: (json['expReward'] as num?)?.toInt(),
      isPublished: json['isPublished'] as bool? ?? false,
      isGlobal: json['isGlobal'] as bool? ?? true,
      isUnlimitedPlay: json['isUnlimitedPlay'] as bool? ?? false,
      allowRepeatExp: json['allowRepeatExp'] as bool? ?? false,
      authorId: json['authorId'] as String?,
      authorName: json['authorName'] as String?,
      playCount: json['playCount'] as int? ?? 0,
      description: json['description'] as String?,
      minLevel: (json['minLevel'] as num?)?.toInt() ?? 1,
      category: json['category'] as String? ?? 'General',
      status: json['status'] as String? ?? 'Active',
      quizScheduleType: json['quizScheduleType'] as String? ?? 'standard',
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
      closedAt: json['closedAt'] != null
          ? DateTime.tryParse(json['closedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'sourceFileName': sourceFileName,
      'difficulty': difficulty.name,
      'questions': questions.map((q) => q.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'timeLimitSeconds': timeLimitSeconds,
      'topicTags': topicTags,
      'expMultiplier': expMultiplier,
      'expReward': expReward,
      'isPublished': isPublished,
      'isGlobal': isGlobal,
      'isUnlimitedPlay': isUnlimitedPlay,
      'allowRepeatExp': allowRepeatExp,
      'authorId': authorId,
      'authorName': authorName,
      'playCount': playCount,
      'description': description,
      'minLevel': minLevel,
      'category': category,
      'status': status,
      'quizScheduleType': quizScheduleType,
      'expiresAt': expiresAt?.toIso8601String(),
      'closedAt': closedAt?.toIso8601String(),
    };
  }

  QuizModel copyWith({
    String? id,
    String? title,
    String? sourceFileName,
    QuizDifficulty? difficulty,
    List<QuestionModel>? questions,
    DateTime? createdAt,
    int? timeLimitSeconds,
    List<String>? topicTags,
    double? expMultiplier,
    int? expReward,
    bool? isPublished,
    bool? isGlobal,
    bool? isUnlimitedPlay,
    bool? allowRepeatExp,
    String? authorId,
    String? authorName,
    int? playCount,
    String? description,
    int? minLevel,
    String? category,
    String? status,
    String? quizScheduleType,
    DateTime? expiresAt,
    DateTime? closedAt,
  }) {
    return QuizModel(
      id: id ?? this.id,
      title: title ?? this.title,
      sourceFileName: sourceFileName ?? this.sourceFileName,
      difficulty: difficulty ?? this.difficulty,
      questions: questions ?? this.questions,
      createdAt: createdAt ?? this.createdAt,
      timeLimitSeconds: timeLimitSeconds ?? this.timeLimitSeconds,
      topicTags: topicTags ?? this.topicTags,
      expMultiplier: expMultiplier ?? this.expMultiplier,
      expReward: expReward ?? this.expReward,
      isPublished: isPublished ?? this.isPublished,
      isGlobal: isGlobal ?? this.isGlobal,
      isUnlimitedPlay: isUnlimitedPlay ?? this.isUnlimitedPlay,
      allowRepeatExp: allowRepeatExp ?? this.allowRepeatExp,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      playCount: playCount ?? this.playCount,
      description: description ?? this.description,
      minLevel: minLevel ?? this.minLevel,
      category: category ?? this.category,
      status: status ?? this.status,
      quizScheduleType: quizScheduleType ?? this.quizScheduleType,
      expiresAt: expiresAt ?? this.expiresAt,
      closedAt: closedAt ?? this.closedAt,
    );
  }

  /// Replaces the question at [index] with an updated copy with selected answer index.
  QuizModel updateAnswer(int index, int selectedAnswerIndex) {
    final updated = List<QuestionModel>.from(questions);
    updated[index] = updated[index].copyWith(
      selectedAnswerIndex: selectedAnswerIndex,
    );
    return copyWith(questions: updated);
  }

  /// Updates the user's typed text answer for Fill-in-the-Blank questions at [index].
  QuizModel updateTextAnswer(int index, String text) {
    final updated = List<QuestionModel>.from(questions);
    updated[index] = updated[index].copyWith(
      userTextAnswer: text,
    );
    return copyWith(questions: updated);
  }

  /// Toggles the review flag on the question at [index].
  QuizModel toggleFlag(int index) {
    final updated = List<QuestionModel>.from(questions);
    updated[index] = updated[index].copyWith(
      isFlagged: !updated[index].isFlagged,
    );
    return copyWith(questions: updated);
  }

  int get answeredCount => questions.where((q) => q.isAnswered).length;

  int get flaggedCount => questions.where((q) => q.isFlagged).length;

  /// Returns a copy of this quiz with every answer and flag cleared.
  QuizModel resetAnswers() {
    final cleared = questions
        .map((q) => q.copyWith(clearSelection: true, isFlagged: false))
        .toList();
    return copyWith(questions: cleared);
  }
}
