import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum TournamentStatus { upcoming, live, completed }

class TournamentModel {
  final String id;
  final String title;
  final String description;
  final String topic;
  final DateTime startDateTime;
  final int durationMinutes;
  final int winnerExpReward;
  final int runnerUpExpReward;
  final int participantExpReward;
  final TournamentStatus status;
  final int teamSize;
  final List<String> registeredScholarIds;
  final DateTime createdAt;
  final String gameType; // 'clash_of_minds' or 'dama'
  final String? documentSourceText;
  final List<Map<String, dynamic>>? customQuestions;
  final String? winningTeamName;
  final List<String>? winningScholarNames;
  final String? mvpScholarName;
  final DateTime? completedAt;

  TournamentModel({
    String? id,
    required this.title,
    this.description = 'Scholar Tournament Battle',
    required this.topic,
    required this.startDateTime,
    this.durationMinutes = 10,
    this.winnerExpReward = 1000,
    this.runnerUpExpReward = 500,
    this.participantExpReward = 150,
    this.status = TournamentStatus.upcoming,
    this.teamSize = 1,
    this.registeredScholarIds = const [],
    DateTime? createdAt,
    this.gameType = 'dama',
    this.documentSourceText,
    this.customQuestions,
    this.winningTeamName,
    this.winningScholarNames,
    this.mvpScholarName,
    this.completedAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  bool get isLive => status == TournamentStatus.live;
  bool get isUpcoming => status == TournamentStatus.upcoming;
  bool get isCompleted => status == TournamentStatus.completed;
  bool get isDama => gameType == 'dama';
  bool get isClashOfMinds => gameType == 'clash_of_minds';

  String get formattedDate => DateFormat('EEE, MMM d, yyyy').format(startDateTime);
  String get formattedTime => DateFormat('h:mm a').format(startDateTime);
  String get formattedDateTime => '$formattedDate at $formattedTime';

  Duration get timeUntilStart {
    final now = DateTime.now();
    if (now.isAfter(startDateTime)) return Duration.zero;
    return startDateTime.difference(now);
  }

  factory TournamentModel.fromJson(Map<String, dynamic> json) {
    final rawRegistered = json['registeredScholarIds'] as List? ?? [];
    final registered = rawRegistered.map((e) => e.toString()).toList();

    final rawWinners = json['winningScholarNames'] as List? ?? [];
    final winningScholars = rawWinners.map((e) => e.toString()).toList();

    final rawQuestions = json['customQuestions'] as List? ?? [];
    final customQs = rawQuestions
        .whereType<Map>()
        .map((q) => Map<String, dynamic>.from(q))
        .toList();

    TournamentStatus status = TournamentStatus.upcoming;
    final statusStr = (json['status'] ?? 'upcoming').toString().toLowerCase();
    if (statusStr == 'live') {
      status = TournamentStatus.live;
    } else if (statusStr == 'completed') {
      status = TournamentStatus.completed;
    }

    return TournamentModel(
      id: json['id'] as String? ?? _uuid.v4(),
      title: json['title'] as String? ?? '3v3 Clash of Minds',
      description: json['description'] as String? ?? '',
      topic: json['topic'] as String? ?? 'General Knowledge & Logic',
      startDateTime: json['startDateTime'] != null
          ? (DateTime.tryParse(json['startDateTime'].toString()) ?? DateTime.now().add(const Duration(hours: 1)))
          : DateTime.now().add(const Duration(hours: 1)),
      durationMinutes: json['durationMinutes'] as int? ?? 10,
      winnerExpReward: json['winnerExpReward'] as int? ?? 1000,
      runnerUpExpReward: json['runnerUpExpReward'] as int? ?? 500,
      participantExpReward: json['participantExpReward'] as int? ?? 150,
      status: status,
      teamSize: json['teamSize'] as int? ?? 3,
      registeredScholarIds: registered,
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      gameType: json['gameType'] as String? ?? 'clash_of_minds',
      documentSourceText: json['documentSourceText'] as String?,
      customQuestions: customQs.isNotEmpty ? customQs : null,
      winningTeamName: json['winningTeamName'] as String?,
      winningScholarNames: winningScholars.isNotEmpty ? winningScholars : null,
      mvpScholarName: json['mvpScholarName'] as String?,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'topic': topic,
      'startDateTime': startDateTime.toIso8601String(),
      'durationMinutes': durationMinutes,
      'winnerExpReward': winnerExpReward,
      'runnerUpExpReward': runnerUpExpReward,
      'participantExpReward': participantExpReward,
      'status': status.name,
      'teamSize': teamSize,
      'registeredScholarIds': registeredScholarIds,
      'createdAt': createdAt.toIso8601String(),
      'gameType': gameType,
      'documentSourceText': documentSourceText,
      'customQuestions': customQuestions,
      'winningTeamName': winningTeamName,
      'winningScholarNames': winningScholarNames,
      'mvpScholarName': mvpScholarName,
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  TournamentModel copyWith({
    String? id,
    String? title,
    String? description,
    String? topic,
    DateTime? startDateTime,
    int? durationMinutes,
    int? winnerExpReward,
    int? runnerUpExpReward,
    int? participantExpReward,
    TournamentStatus? status,
    int? teamSize,
    List<String>? registeredScholarIds,
    DateTime? createdAt,
    String? gameType,
    String? documentSourceText,
    List<Map<String, dynamic>>? customQuestions,
    String? winningTeamName,
    List<String>? winningScholarNames,
    String? mvpScholarName,
    DateTime? completedAt,
  }) {
    return TournamentModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      topic: topic ?? this.topic,
      startDateTime: startDateTime ?? this.startDateTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      winnerExpReward: winnerExpReward ?? this.winnerExpReward,
      runnerUpExpReward: runnerUpExpReward ?? this.runnerUpExpReward,
      participantExpReward: participantExpReward ?? this.participantExpReward,
      status: status ?? this.status,
      teamSize: teamSize ?? this.teamSize,
      registeredScholarIds: registeredScholarIds ?? this.registeredScholarIds,
      createdAt: createdAt ?? this.createdAt,
      gameType: gameType ?? this.gameType,
      documentSourceText: documentSourceText ?? this.documentSourceText,
      customQuestions: customQuestions ?? this.customQuestions,
      winningTeamName: winningTeamName ?? this.winningTeamName,
      winningScholarNames: winningScholarNames ?? this.winningScholarNames,
      mvpScholarName: mvpScholarName ?? this.mvpScholarName,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
