import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';
import '../models/game_match_model.dart';
import '../models/user_model.dart';

class GameSessionService {
  static final GameSessionService _instance = GameSessionService._internal();
  factory GameSessionService({FirebaseFirestore? firestore}) {
    if (firestore != null) {
      return GameSessionService._withDb(firestore);
    }
    return _instance;
  }

  GameSessionService._internal() : _customDb = null;
  GameSessionService._withDb(FirebaseFirestore firestore) : _customDb = firestore;

  final FirebaseFirestore? _customDb;
  final _uuid = const Uuid();

  FirebaseFirestore get _db => _customDb ?? FirebaseFirestore.instance;

  bool get _isFirebaseAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // Fallback in-memory stores for offline / unit tests
  static final Map<String, GameMatchModel> fallbackMatches = {};
  static final Map<String, Map<String, dynamic>> fallbackQueue = {};

  // ---------------------------------------------------------------------------
  // Challenge & Invitation
  // ---------------------------------------------------------------------------

  /// Sends a live match invitation to an opponent scholar
  Future<GameMatchModel> sendChallenge({
    required UserModel host,
    required UserModel opponent,
    String gameType = 'dama',
    bool isDirectInvite = true,
  }) async {
    final matchId = 'match_${_uuid.v4().substring(0, 8)}';
    final now = DateTime.now();

    final match = GameMatchModel(
      id: matchId,
      gameType: gameType,
      hostId: host.uid,
      hostName: host.effectiveNickname,
      hostAvatar: host.photoUrl,
      hostLevel: host.level,
      opponentId: opponent.uid,
      opponentName: opponent.effectiveNickname,
      opponentAvatar: opponent.photoUrl,
      opponentLevel: opponent.level,
      status: GameMatchStatus.pending,
      currentTurn: 1, // Host is White/Light pieces, moves first
      isGameOver: false,
      isDraw: false,
      isDirectInvite: isDirectInvite,
      createdAt: now,
      updatedAt: now,
    );

    fallbackMatches[matchId] = match;

    try {
      if (_customDb != null || _isFirebaseAvailable) {
        await _db
            .collection('game_matches')
            .doc(matchId)
            .set(match.toJson())
            .timeout(const Duration(seconds: 4));
      }
    } catch (_) {}

    return match;
  }

  /// Streams incoming pending direct challenges targeted to [userId]
  Stream<List<GameMatchModel>> streamIncomingChallenges(String userId) {
    if (userId.isEmpty) {
      return Stream.value(const []);
    }

    if (_customDb != null || _isFirebaseAvailable) {
      return _db
          .collection('game_matches')
          .where('opponentId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .where('isDirectInvite', isEqualTo: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) => GameMatchModel.fromJson(doc.data())).toList();
          });
    }

    return Stream.fromFuture(Future.value()).asyncExpand((_) async* {
      yield fallbackMatches.values
          .where((m) => m.opponentId == userId && m.status == GameMatchStatus.pending && m.isDirectInvite)
          .toList();
      yield* Stream.periodic(const Duration(milliseconds: 200), (_) {
        return fallbackMatches.values
            .where((m) => m.opponentId == userId && m.status == GameMatchStatus.pending && m.isDirectInvite)
            .toList();
      });
    });
  }

  /// Streams live updates of a specific match
  Stream<GameMatchModel?> streamMatch(String matchId) {
    if (matchId.isEmpty) {
      return Stream.value(null);
    }

    if (_customDb != null || _isFirebaseAvailable) {
      return _db
          .collection('game_matches')
          .doc(matchId)
          .snapshots()
          .map((doc) {
            if (!doc.exists || doc.data() == null) return null;
            return GameMatchModel.fromJson(doc.data()!);
          });
    }

    return Stream.fromFuture(Future.value()).asyncExpand((_) async* {
      yield fallbackMatches[matchId];
      yield* Stream.periodic(const Duration(milliseconds: 200), (_) {
        return fallbackMatches[matchId];
      });
    });
  }

  /// Responds to an incoming challenge (accept or decline)
  Future<void> respondToChallenge({
    required String matchId,
    required bool accept,
  }) async {
    final status = accept ? GameMatchStatus.playing : GameMatchStatus.declined;
    final now = DateTime.now();

    final current = fallbackMatches[matchId];
    if (current != null) {
      fallbackMatches[matchId] = current.copyWith(
        status: status,
        updatedAt: now,
      );
    }

    try {
      if (_customDb != null || _isFirebaseAvailable) {
        await _db
            .collection('game_matches')
            .doc(matchId)
            .update({
              'status': status.toValue(),
              'updatedAt': now.toIso8601String(),
            })
            .timeout(const Duration(seconds: 4));
      }
    } catch (_) {}
  }

  /// Cancels a pending challenge before opponent answers
  Future<void> cancelChallenge(String matchId) async {
    final now = DateTime.now();
    final current = fallbackMatches[matchId];
    if (current != null) {
      fallbackMatches[matchId] = current.copyWith(
        status: GameMatchStatus.cancelled,
        updatedAt: now,
      );
    }

    try {
      if (_customDb != null || _isFirebaseAvailable) {
        await _db
            .collection('game_matches')
            .doc(matchId)
            .update({
              'status': GameMatchStatus.cancelled.toValue(),
              'updatedAt': now.toIso8601String(),
            })
            .timeout(const Duration(seconds: 4));
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Live Game Moves & Actions
  // ---------------------------------------------------------------------------

  /// Broadcasts a validated player move to the shared game session
  Future<void> sendMove({
    required String matchId,
    required Map<String, dynamic> moveData,
    required int nextTurn,
    bool isGameOver = false,
    String? winnerId,
    bool isDraw = false,
  }) async {
    final now = DateTime.now();
    final current = fallbackMatches[matchId];
    if (current != null) {
      fallbackMatches[matchId] = current.copyWith(
        lastMove: moveData,
        currentTurn: nextTurn,
        isGameOver: isGameOver,
        winnerId: winnerId,
        isDraw: isDraw,
        status: isGameOver ? GameMatchStatus.completed : GameMatchStatus.playing,
        drawOfferedBy: null, // Clear any pending draw offer on move
        updatedAt: now,
      );
    }

    try {
      if (_customDb != null || _isFirebaseAvailable) {
        await _db
            .collection('game_matches')
            .doc(matchId)
            .update({
              'lastMove': moveData,
              'currentTurn': nextTurn,
              'isGameOver': isGameOver,
              if (winnerId != null) 'winnerId': winnerId,
              'isDraw': isDraw,
              'status': isGameOver ? GameMatchStatus.completed.toValue() : GameMatchStatus.playing.toValue(),
              'drawOfferedBy': FieldValue.delete(),
              'updatedAt': now.toIso8601String(),
            })
            .timeout(const Duration(seconds: 4));
      }
    } catch (_) {}
  }

  /// Sends a draw proposal to the remote opponent
  Future<void> offerDraw({
    required String matchId,
    required String fromUserId,
  }) async {
    final now = DateTime.now();
    final current = fallbackMatches[matchId];
    if (current != null) {
      fallbackMatches[matchId] = current.copyWith(
        drawOfferedBy: fromUserId,
        updatedAt: now,
      );
    }

    try {
      if (_customDb != null || _isFirebaseAvailable) {
        await _db
            .collection('game_matches')
            .doc(matchId)
            .update({
              'drawOfferedBy': fromUserId,
              'updatedAt': now.toIso8601String(),
            })
            .timeout(const Duration(seconds: 4));
      }
    } catch (_) {}
  }

  /// Responds to a draw offer
  Future<void> respondToDraw({
    required String matchId,
    required bool accept,
  }) async {
    final now = DateTime.now();
    final current = fallbackMatches[matchId];
    if (current != null) {
      fallbackMatches[matchId] = current.copyWith(
        isGameOver: accept ? true : current.isGameOver,
        isDraw: accept ? true : current.isDraw,
        winnerId: accept ? 'draw' : current.winnerId,
        status: accept ? GameMatchStatus.completed : current.status,
        drawOfferedBy: null,
        updatedAt: now,
      );
    }

    try {
      if (_customDb != null || _isFirebaseAvailable) {
        await _db
            .collection('game_matches')
            .doc(matchId)
            .update({
              if (accept) ...{
                'isGameOver': true,
                'isDraw': true,
                'winnerId': 'draw',
                'status': GameMatchStatus.completed.toValue(),
              },
              'drawOfferedBy': FieldValue.delete(),
              'updatedAt': now.toIso8601String(),
            })
            .timeout(const Duration(seconds: 4));
      }
    } catch (_) {}
  }

  /// Concludes match via resignation
  Future<void> resignMatch({
    required String matchId,
    required String winnerUserId,
  }) async {
    final now = DateTime.now();
    final current = fallbackMatches[matchId];
    if (current != null) {
      fallbackMatches[matchId] = current.copyWith(
        isGameOver: true,
        winnerId: winnerUserId,
        status: GameMatchStatus.completed,
        updatedAt: now,
      );
    }

    try {
      if (_customDb != null || _isFirebaseAvailable) {
        await _db
            .collection('game_matches')
            .doc(matchId)
            .update({
              'isGameOver': true,
              'winnerId': winnerUserId,
              'status': GameMatchStatus.completed.toValue(),
              'updatedAt': now.toIso8601String(),
            })
            .timeout(const Duration(seconds: 4));
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Matchmaking Queue
  // ---------------------------------------------------------------------------

  /// Enters matchmaking queue: pairs with another waiting scholar if present,
  /// or creates a waiting ticket.
  Future<GameMatchModel?> enterMatchmaking({
    required UserModel user,
    String gameType = 'dama',
  }) async {
    final now = DateTime.now();
    final ticketId = 'queue_${user.uid}';

    if (_customDb != null || _isFirebaseAvailable) {
      try {
        // 1. Search for an existing waiting ticket from another user
        final querySnap = await _db
            .collection('game_matchmaking')
            .where('gameType', isEqualTo: gameType)
            .where('status', isEqualTo: 'waiting')
            .limit(5)
            .get()
            .timeout(const Duration(seconds: 3));

        for (final doc in querySnap.docs) {
          final data = doc.data();
          final otherUid = data['userId'] as String? ?? '';
          if (otherUid.isNotEmpty && otherUid != user.uid) {
            // Found a waiting scholar! Pair together.
            final otherUser = UserModel(
              uid: otherUid,
              name: data['userName'] as String? ?? 'Scholar',
              email: '',
              nickname: data['userNickname'] as String? ?? 'Scholar',
              photoUrl: data['userAvatar'] as String?,
              level: (data['userLevel'] as num?)?.toInt() ?? 1,
              createdAt: now,
            );

            // Create match directly in playing status (no challenge notification sent)
            final matchId = 'match_${_uuid.v4().substring(0, 8)}';
            final match = GameMatchModel(
              id: matchId,
              gameType: gameType,
              hostId: otherUser.uid,
              hostName: otherUser.effectiveNickname,
              hostAvatar: otherUser.photoUrl,
              hostLevel: otherUser.level,
              opponentId: user.uid,
              opponentName: user.effectiveNickname,
              opponentAvatar: user.photoUrl,
              opponentLevel: user.level,
              status: GameMatchStatus.playing,
              currentTurn: 1, // Host moves first
              isGameOver: false,
              isDraw: false,
              isDirectInvite: false,
              createdAt: now,
              updatedAt: now,
            );

            fallbackMatches[matchId] = match;

            await _db.collection('game_matches').doc(matchId).set(match.toJson()).timeout(const Duration(seconds: 4));

            // Clean up other ticket and notify waiting player
            await doc.reference.update({
              'status': 'paired',
              'matchId': match.id,
            });

            return match;
          }
        }

        // 2. No other scholar waiting in queue: create a waiting ticket
        await _db.collection('game_matchmaking').doc(ticketId).set({
          'ticketId': ticketId,
          'gameType': gameType,
          'userId': user.uid,
          'userName': user.name,
          'userNickname': user.effectiveNickname,
          'userAvatar': user.photoUrl,
          'userLevel': user.level,
          'status': 'waiting',
          'createdAt': now.toIso8601String(),
        });
      } catch (_) {}
    } else {
      // Fallback in-memory pairing
      for (final entry in fallbackQueue.entries) {
        final data = entry.value;
        if (data['gameType'] == gameType &&
            data['status'] == 'waiting' &&
            data['userId'] != user.uid) {
          final otherUser = UserModel(
            uid: data['userId'] as String,
            name: data['userName'] as String,
            email: '',
            nickname: data['userNickname'] as String,
            level: (data['userLevel'] as num).toInt(),
            createdAt: now,
          );

          final matchId = 'match_${_uuid.v4().substring(0, 8)}';
          final match = GameMatchModel(
            id: matchId,
            gameType: gameType,
            hostId: otherUser.uid,
            hostName: otherUser.effectiveNickname,
            hostAvatar: otherUser.photoUrl,
            hostLevel: otherUser.level,
            opponentId: user.uid,
            opponentName: user.effectiveNickname,
            opponentAvatar: user.photoUrl,
            opponentLevel: user.level,
            status: GameMatchStatus.playing,
            currentTurn: 1,
            isGameOver: false,
            isDraw: false,
            isDirectInvite: false,
            createdAt: now,
            updatedAt: now,
          );
          fallbackMatches[matchId] = match;
          entry.value['status'] = 'paired';
          entry.value['matchId'] = match.id;
          return match;
        }
      }

      fallbackQueue[ticketId] = {
        'ticketId': ticketId,
        'gameType': gameType,
        'userId': user.uid,
        'userName': user.name,
        'userNickname': user.effectiveNickname,
        'userAvatar': user.photoUrl,
        'userLevel': user.level,
        'status': 'waiting',
        'createdAt': now.toIso8601String(),
      };
    }

    return null;
  }

  /// Streams ticket status while waiting in matchmaking queue
  Stream<String?> streamMatchmakingTicket(String userId) {
    final ticketId = 'queue_$userId';

    if (_customDb != null || _isFirebaseAvailable) {
      return _db
          .collection('game_matchmaking')
          .doc(ticketId)
          .snapshots()
          .map((doc) {
            if (!doc.exists || doc.data() == null) return null;
            final data = doc.data()!;
            if (data['status'] == 'paired') {
              return data['matchId'] as String?;
            }
            return null;
          });
    }

    return Stream.periodic(const Duration(milliseconds: 500), (_) {
      final data = fallbackQueue[ticketId];
      if (data?['status'] == 'paired') {
        return data?['matchId'] as String?;
      }
      return null;
    });
  }

  /// Cancels matchmaking ticket
  Future<void> leaveMatchmaking(String userId) async {
    final ticketId = 'queue_$userId';
    fallbackQueue.remove(ticketId);

    try {
      if (_customDb != null || _isFirebaseAvailable) {
        await _db
            .collection('game_matchmaking')
            .doc(ticketId)
            .delete()
            .timeout(const Duration(seconds: 3));
      }
    } catch (_) {}
  }
}
