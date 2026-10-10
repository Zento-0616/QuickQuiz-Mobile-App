enum GameMatchStatus {
  pending,
  accepted,
  declined,
  cancelled,
  playing,
  completed,
}

extension GameMatchStatusExtension on GameMatchStatus {
  String toValue() {
    switch (this) {
      case GameMatchStatus.pending:
        return 'pending';
      case GameMatchStatus.accepted:
        return 'accepted';
      case GameMatchStatus.declined:
        return 'declined';
      case GameMatchStatus.cancelled:
        return 'cancelled';
      case GameMatchStatus.playing:
        return 'playing';
      case GameMatchStatus.completed:
        return 'completed';
    }
  }

  static GameMatchStatus fromValue(String? value) {
    switch (value) {
      case 'accepted':
        return GameMatchStatus.accepted;
      case 'declined':
        return GameMatchStatus.declined;
      case 'cancelled':
        return GameMatchStatus.cancelled;
      case 'playing':
        return GameMatchStatus.playing;
      case 'completed':
        return GameMatchStatus.completed;
      case 'pending':
      default:
        return GameMatchStatus.pending;
    }
  }
}

class GameMatchModel {
  final String id;
  final String gameType;
  final String hostId;
  final String hostName;
  final String? hostAvatar;
  final int hostLevel;
  final String opponentId;
  final String opponentName;
  final String? opponentAvatar;
  final int opponentLevel;
  final GameMatchStatus status;
  final int currentTurn;
  final Map<String, dynamic>? lastMove;
  final bool isGameOver;
  final String? winnerId;
  final String? drawOfferedBy;
  final bool isDraw;
  final bool isDirectInvite;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GameMatchModel({
    required this.id,
    this.gameType = 'dama',
    required this.hostId,
    required this.hostName,
    this.hostAvatar,
    this.hostLevel = 1,
    required this.opponentId,
    required this.opponentName,
    this.opponentAvatar,
    this.opponentLevel = 1,
    this.status = GameMatchStatus.pending,
    this.currentTurn = 1,
    this.lastMove,
    this.isGameOver = false,
    this.winnerId,
    this.drawOfferedBy,
    this.isDraw = false,
    this.isDirectInvite = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GameMatchModel.fromJson(Map<String, dynamic> json) {
    return GameMatchModel(
      id: json['id'] as String? ?? '',
      gameType: json['gameType'] as String? ?? 'dama',
      hostId: json['hostId'] as String? ?? '',
      hostName: json['hostName'] as String? ?? 'Scholar Host',
      hostAvatar: json['hostAvatar'] as String?,
      hostLevel: (json['hostLevel'] as num?)?.toInt() ?? 1,
      opponentId: json['opponentId'] as String? ?? '',
      opponentName: json['opponentName'] as String? ?? 'Scholar Opponent',
      opponentAvatar: json['opponentAvatar'] as String?,
      opponentLevel: (json['opponentLevel'] as num?)?.toInt() ?? 1,
      status: GameMatchStatusExtension.fromValue(json['status'] as String?),
      currentTurn: (json['currentTurn'] as num?)?.toInt() ?? 1,
      lastMove: json['lastMove'] != null ? Map<String, dynamic>.from(json['lastMove'] as Map) : null,
      isGameOver: json['isGameOver'] as bool? ?? false,
      winnerId: json['winnerId'] as String?,
      drawOfferedBy: json['drawOfferedBy'] as String?,
      isDraw: json['isDraw'] as bool? ?? false,
      isDirectInvite: json['isDirectInvite'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gameType': gameType,
      'hostId': hostId,
      'hostName': hostName,
      if (hostAvatar != null) 'hostAvatar': hostAvatar,
      'hostLevel': hostLevel,
      'opponentId': opponentId,
      'opponentName': opponentName,
      if (opponentAvatar != null) 'opponentAvatar': opponentAvatar,
      'opponentLevel': opponentLevel,
      'status': status.toValue(),
      'currentTurn': currentTurn,
      if (lastMove != null) 'lastMove': lastMove,
      'isGameOver': isGameOver,
      if (winnerId != null) 'winnerId': winnerId,
      if (drawOfferedBy != null) 'drawOfferedBy': drawOfferedBy,
      'isDraw': isDraw,
      'isDirectInvite': isDirectInvite,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory GameMatchModel.fromMap(Map<String, dynamic> map, [String? id]) {
    final copy = Map<String, dynamic>.from(map);
    if (id != null && (copy['id'] == null || (copy['id'] as String).isEmpty)) {
      copy['id'] = id;
    }
    return GameMatchModel.fromJson(copy);
  }

  Map<String, dynamic> toMap() => toJson();

  GameMatchModel copyWith({
    String? id,
    String? gameType,
    String? hostId,
    String? hostName,
    String? hostAvatar,
    int? hostLevel,
    String? opponentId,
    String? opponentName,
    String? opponentAvatar,
    int? opponentLevel,
    GameMatchStatus? status,
    int? currentTurn,
    Map<String, dynamic>? lastMove,
    bool? isGameOver,
    String? winnerId,
    String? drawOfferedBy,
    bool? isDraw,
    bool? isDirectInvite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GameMatchModel(
      id: id ?? this.id,
      gameType: gameType ?? this.gameType,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      hostAvatar: hostAvatar ?? this.hostAvatar,
      hostLevel: hostLevel ?? this.hostLevel,
      opponentId: opponentId ?? this.opponentId,
      opponentName: opponentName ?? this.opponentName,
      opponentAvatar: opponentAvatar ?? this.opponentAvatar,
      opponentLevel: opponentLevel ?? this.opponentLevel,
      status: status ?? this.status,
      currentTurn: currentTurn ?? this.currentTurn,
      lastMove: lastMove ?? this.lastMove,
      isGameOver: isGameOver ?? this.isGameOver,
      winnerId: winnerId ?? this.winnerId,
      drawOfferedBy: drawOfferedBy ?? this.drawOfferedBy,
      isDraw: isDraw ?? this.isDraw,
      isDirectInvite: isDirectInvite ?? this.isDirectInvite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
