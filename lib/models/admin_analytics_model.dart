library admin_analytics_model;

import 'question_model.dart';
import 'quiz_result_model.dart';

/// Data classes supporting the Admin Live Metrics and Quiz Performance Analytics Suite.

class AdminLiveMetrics {
  final int activeScholarsOnline;
  final int totalRegisteredScholars;
  final int quizzesPlayedToday;
  final double platformAverageAccuracy;

  const AdminLiveMetrics({
    int? activeScholarsOnline,
    int? activePlayersOnline,
    int? totalRegisteredScholars,
    int? totalRegisteredPlayers,
    this.quizzesPlayedToday = 0,
    this.platformAverageAccuracy = 0.0,
  })  : activeScholarsOnline = activeScholarsOnline ?? activePlayersOnline ?? 0,
        totalRegisteredScholars = totalRegisteredScholars ?? totalRegisteredPlayers ?? 0;

  // Backward compatibility aliases
  int get activePlayersOnline => activeScholarsOnline;
  int get totalRegisteredPlayers => totalRegisteredScholars;

  factory AdminLiveMetrics.initial() => const AdminLiveMetrics();
}

typedef ScholarScoreRecord = PlayerScoreRecord;

class PlayerScoreRecord {
  final String userId;
  final String nickname;
  final String? avatar;
  final int score;
  final int questionCount;
  final double percentage;
  final int timeElapsedSeconds;
  final int expEarned;
  final DateTime createdAt;
  final bool isPass;
  final List<QuestionModel> questions;
  final QuizResultModel? result;

  const PlayerScoreRecord({
    required this.userId,
    required this.nickname,
    this.avatar,
    required this.score,
    required this.questionCount,
    required this.percentage,
    required this.timeElapsedSeconds,
    required this.expEarned,
    required this.createdAt,
    required this.isPass,
    this.questions = const [],
    this.result,
  });

  String get formattedScore => '$score / $questionCount';
  String get formattedPercentage => '${percentage.toStringAsFixed(1)}%';
  String get formattedTime {
    final m = timeElapsedSeconds ~/ 60;
    final s = timeElapsedSeconds % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }
}

class QuizAnalyticsData {
  final String quizId;
  final String quizTitle;
  final int totalPlays;
  final ScholarScoreRecord? topScholar;
  final double averageScore;
  final int passCount;
  final int failCount;
  final double passRate;
  final List<ScholarScoreRecord> scholarBreakdown;

  const QuizAnalyticsData({
    required this.quizId,
    required this.quizTitle,
    required this.totalPlays,
    ScholarScoreRecord? topScholar,
    ScholarScoreRecord? topPlayer,
    required this.averageScore,
    required this.passCount,
    required this.failCount,
    required this.passRate,
    List<ScholarScoreRecord>? scholarBreakdown,
    List<ScholarScoreRecord>? playerBreakdown,
  })  : topScholar = topScholar ?? topPlayer,
        scholarBreakdown = scholarBreakdown ?? playerBreakdown ?? const [];

  // Backward compatibility getters
  ScholarScoreRecord? get topPlayer => topScholar;
  List<ScholarScoreRecord> get playerBreakdown => scholarBreakdown;

  factory QuizAnalyticsData.empty({required String quizId, required String quizTitle}) {
    return QuizAnalyticsData(
      quizId: quizId,
      quizTitle: quizTitle,
      totalPlays: 0,
      averageScore: 0.0,
      passCount: 0,
      failCount: 0,
      passRate: 0.0,
      scholarBreakdown: const [],
    );
  }
}
