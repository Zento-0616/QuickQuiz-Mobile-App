/// Represents an authenticated QuickQuiz user with gamification and social metadata.
class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final DateTime createdAt;
  final int age;
  final String nickname;
  final String role; // 'user' or 'admin'
  final int level;
  final int exp;
  final int dailyStreak;
  final DateTime? lastLoginDate;
  final int quizzesPlayed;
  final int totalCorrect;
  final int totalQuestions;
  final String? bio;
  final bool isOnline;
  final DateTime? lastActive;
  final bool darkMode;
  final bool hapticsEnabled;
  final bool soundEnabled;
  final bool notifyQuizDrops;
  final bool notifyFriendRequests;
  final bool notifyChatMessages;
  final String region;
  final List<String> completedOfficialQuizIds;
  final int globalQuizCount;
  final double globalTotalScore;
  final int damaWins;
  final int damaLosses;
  final int damaDraws;
  final bool isInMatch;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.createdAt,
    this.photoUrl,
    this.age = 18,
    this.nickname = '',
    this.role = 'user',
    this.level = 1,
    this.exp = 0,
    this.dailyStreak = 1,
    this.lastLoginDate,
    this.quizzesPlayed = 0,
    this.totalCorrect = 0,
    this.totalQuestions = 0,
    this.bio = 'Ready to turn notes into knowledge!',
    this.isOnline = false,
    this.lastActive,
    this.darkMode = false,
    this.hapticsEnabled = true,
    this.soundEnabled = true,
    this.notifyQuizDrops = true,
    this.notifyFriendRequests = true,
    this.notifyChatMessages = true,
    this.region = 'US',
    this.completedOfficialQuizIds = const [],
    this.globalQuizCount = 0,
    this.globalTotalScore = 0.0,
    this.damaWins = 0,
    this.damaLosses = 0,
    this.damaDraws = 0,
    this.isInMatch = false,
  });

  String get realName => name;

  String get effectiveNickname =>
      nickname.isNotEmpty ? nickname : (name.isNotEmpty ? name.split(' ').first : 'Scholar');

  bool get isAdmin => role == 'admin';

  bool get isGuest => uid.startsWith('guest_') || role == 'guest';

  /// Returns true only if the user has an active online flag AND reported
  /// activity within the last 5 minutes (preventing stale Firestore documents
  /// from appearing online).
  bool get isCurrentlyOnline {
    if (!isOnline) return false;
    final active = lastActive ?? lastLoginDate;
    if (active == null) return false;
    final diff = DateTime.now().difference(active);
    return !diff.isNegative && diff.inMinutes <= 5;
  }

  String get regionFlag {
    if (region.isEmpty) return '🌐';
    final reg = region.toUpperCase();
    if (reg.length != 2) return '🌐';
    try {
      final int first = reg.codeUnitAt(0) - 0x41 + 0x1F1E6;
      final int second = reg.codeUnitAt(1) - 0x41 + 0x1F1E6;
      return String.fromCharCode(first) + String.fromCharCode(second);
    } catch (_) {
      return '🌐';
    }
  }

  int get winRate => quizzesPlayed > 0 && totalQuestions > 0
      ? ((totalCorrect / totalQuestions) * 100).round()
      : (quizzesPlayed > 0 ? 100 : 0);

  int get expForNextLevel => level * 150;

  int get currentLevelExp => exp % expForNextLevel;

  double get levelProgressFraction =>
      expForNextLevel > 0 ? (currentLevelExp / expForNextLevel).clamp(0.0, 1.0) : 0.0;

  double get globalAvgScore =>
      globalQuizCount > 0 ? (globalTotalScore / globalQuizCount) : 0.0;

  int get damaMatchesPlayed => damaWins + damaLosses + damaDraws;

  int get damaWinRate =>
      damaMatchesPlayed > 0 ? ((damaWins / damaMatchesPlayed) * 100).round() : 0;

  String get damaRecord =>
      '${damaWins}W - ${damaLosses}L${damaDraws > 0 ? " - ${damaDraws}D" : ""}';

  /// Builds a [UserModel] from a Firestore document map or local cache.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawName = json['name'] as String? ?? 'Student';
    return UserModel(
      uid: json['uid'] as String? ?? '',
      name: rawName,
      email: json['email'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
      createdAt: _parseDate(json['createdAt']),
      age: json['age'] as int? ?? 18,
      nickname: json['nickname'] as String? ?? (json['name'] != null ? json['name'].toString().split(' ').first : 'Scholar'),
      role: json['role'] as String? ?? 'user',
      level: json['level'] as int? ?? 1,
      exp: json['exp'] as int? ?? 0,
      dailyStreak: json['dailyStreak'] as int? ?? 1,
      lastLoginDate: json['lastLoginDate'] != null ? _parseDate(json['lastLoginDate']) : null,
      quizzesPlayed: json['quizzesPlayed'] as int? ?? 0,
      totalCorrect: json['totalCorrect'] as int? ?? 0,
      totalQuestions: json['totalQuestions'] as int? ?? 0,
      bio: json['bio'] as String? ?? 'Ready to turn notes into knowledge!',
      isOnline: json['isOnline'] as bool? ?? false,
      lastActive: json['lastActive'] != null ? _parseDate(json['lastActive']) : null,
      darkMode: json['darkMode'] as bool? ?? false,
      hapticsEnabled: json['hapticsEnabled'] as bool? ?? true,
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      notifyQuizDrops: json['notifyQuizDrops'] as bool? ?? true,
      notifyFriendRequests: json['notifyFriendRequests'] as bool? ?? true,
      notifyChatMessages: json['notifyChatMessages'] as bool? ?? true,
      region: json['region'] as String? ?? 'US',
      completedOfficialQuizIds: (json['completedOfficialQuizIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      globalQuizCount: json['globalQuizCount'] as int? ?? 0,
      globalTotalScore: (json['globalTotalScore'] as num?)?.toDouble() ?? 0.0,
      damaWins: (json['damaWins'] as num?)?.toInt() ?? 0,
      damaLosses: (json['damaLosses'] as num?)?.toInt() ?? 0,
      damaDraws: (json['damaDraws'] as num?)?.toInt() ?? 0,
      isInMatch: json['isInMatch'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'createdAt': createdAt.toIso8601String(),
      'age': age,
      'nickname': nickname.isNotEmpty ? nickname : effectiveNickname,
      'role': role,
      'level': level,
      'exp': exp,
      'dailyStreak': dailyStreak,
      'lastLoginDate': lastLoginDate?.toIso8601String(),
      'quizzesPlayed': quizzesPlayed,
      'totalCorrect': totalCorrect,
      'totalQuestions': totalQuestions,
      'bio': bio,
      'isOnline': isOnline,
      'lastActive': lastActive?.toIso8601String(),
      'darkMode': darkMode,
      'hapticsEnabled': hapticsEnabled,
      'soundEnabled': soundEnabled,
      'notifyQuizDrops': notifyQuizDrops,
      'notifyFriendRequests': notifyFriendRequests,
      'notifyChatMessages': notifyChatMessages,
      'region': region,
      'completedOfficialQuizIds': completedOfficialQuizIds,
      'globalQuizCount': globalQuizCount,
      'globalTotalScore': globalTotalScore,
      'globalAvgScore': globalAvgScore,
      'damaWins': damaWins,
      'damaLosses': damaLosses,
      'damaDraws': damaDraws,
      'damaWinRate': damaWinRate,
      'isInMatch': isInMatch,
    };
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? photoUrl,
    DateTime? createdAt,
    int? age,
    String? nickname,
    String? role,
    int? level,
    int? exp,
    int? dailyStreak,
    DateTime? lastLoginDate,
    int? quizzesPlayed,
    int? totalCorrect,
    int? totalQuestions,
    String? bio,
    bool? isOnline,
    DateTime? lastActive,
    bool? darkMode,
    bool? hapticsEnabled,
    bool? soundEnabled,
    bool? notifyQuizDrops,
    bool? notifyFriendRequests,
    bool? notifyChatMessages,
    String? region,
    List<String>? completedOfficialQuizIds,
    int? globalQuizCount,
    double? globalTotalScore,
    int? damaWins,
    int? damaLosses,
    int? damaDraws,
    bool? isInMatch,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      age: age ?? this.age,
      nickname: nickname ?? this.nickname,
      role: role ?? this.role,
      level: level ?? this.level,
      exp: exp ?? this.exp,
      dailyStreak: dailyStreak ?? this.dailyStreak,
      lastLoginDate: lastLoginDate ?? this.lastLoginDate,
      quizzesPlayed: quizzesPlayed ?? this.quizzesPlayed,
      totalCorrect: totalCorrect ?? this.totalCorrect,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      bio: bio ?? this.bio,
      isOnline: isOnline ?? this.isOnline,
      lastActive: lastActive ?? this.lastActive,
      darkMode: darkMode ?? this.darkMode,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      notifyQuizDrops: notifyQuizDrops ?? this.notifyQuizDrops,
      notifyFriendRequests: notifyFriendRequests ?? this.notifyFriendRequests,
      notifyChatMessages: notifyChatMessages ?? this.notifyChatMessages,
      region: region ?? this.region,
      completedOfficialQuizIds: completedOfficialQuizIds ?? this.completedOfficialQuizIds,
      globalQuizCount: globalQuizCount ?? this.globalQuizCount,
      globalTotalScore: globalTotalScore ?? this.globalTotalScore,
      damaWins: damaWins ?? this.damaWins,
      damaLosses: damaLosses ?? this.damaLosses,
      damaDraws: damaDraws ?? this.damaDraws,
      isInMatch: isInMatch ?? this.isInMatch,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.now();
    }
  }
}
