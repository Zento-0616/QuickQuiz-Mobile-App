import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/tournament_model.dart';

class TournamentService {
  static final TournamentService _instance = TournamentService._internal();
  factory TournamentService() => _instance;
  TournamentService._internal();

  CollectionReference<Map<String, dynamic>>? get _collection {
    try {
      return FirebaseFirestore.instance.collection('tournaments');
    } catch (_) {
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>>? get _finishedCollection {
    try {
      return FirebaseFirestore.instance.collection('finished_tournaments');
    } catch (_) {
      return null;
    }
  }

  static TournamentModel get defaultTournament => TournamentModel(
        id: 'default_dama_grand_cup',
        title: 'Grand Scholar Dama Championship',
        description: '8x8 Dama tournament battle! Crown your kings, execute flying jumps, and take the championship cup.',
        topic: 'Dama & Strategic Checkers',
        startDateTime: DateTime.now(),
        durationMinutes: 15,
        winnerExpReward: 1500,
        runnerUpExpReward: 700,
        participantExpReward: 200,
        status: TournamentStatus.upcoming,
        teamSize: 1,
        gameType: 'dama',
      );

  // In-memory active tournament lists - empty until created by Admin
  static final List<TournamentModel> _fallbackTournaments = [];

  // Fallback in-memory list for finished Clash of Minds tournaments
  static final List<TournamentModel> _fallbackFinishedTournaments = [
    TournamentModel(
      id: 'finished_siege_season_1',
      title: 'Clash of Minds: Genesis Invitational',
      description: 'The inaugural 3v3 tournament championship siege.',
      topic: 'Science & Innovation',
      startDateTime: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      durationMinutes: 10,
      winnerExpReward: 1200,
      runnerUpExpReward: 600,
      participantExpReward: 200,
      status: TournamentStatus.completed,
      teamSize: 3,
      gameType: 'clash_of_minds',
      winningTeamName: 'Blue Citadel Vanguard',
      winningScholarNames: ['Naldz', 'Reynaldo Seroje', 'Kate'],
      mvpScholarName: 'Reynaldo Seroje',
      completedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    TournamentModel(
      id: 'finished_siege_logic_cup',
      title: 'Clash of Minds: Logic Masters Cup',
      description: '3v3 battle of high-level mathematics, logic algorithms and puzzle theory.',
      topic: 'Mathematics & Logic',
      startDateTime: DateTime.now().subtract(const Duration(days: 3, hours: 5)),
      durationMinutes: 10,
      winnerExpReward: 1500,
      runnerUpExpReward: 750,
      participantExpReward: 250,
      status: TournamentStatus.completed,
      teamSize: 3,
      gameType: 'clash_of_minds',
      winningTeamName: 'Red Citadel Cyber Syndicate',
      winningScholarNames: ['jhone', 'Alex_Prime', 'Sophia_Logic'],
      mvpScholarName: 'jhone',
      completedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  // Fallback in-memory list for Dama tournaments - empty until created by Admin
  static final List<TournamentModel> _fallbackDamaTournaments = [];

  Future<List<TournamentModel>> getTournaments({String gameType = 'dama'}) async {
    try {
      final col = _collection;
      if (col != null) {
        final snapshot = await col
            .where('gameType', isEqualTo: gameType)
            .get()
            .timeout(const Duration(seconds: 4));

        final list = snapshot.docs
            .map((doc) => TournamentModel.fromJson(doc.data()))
            .where((t) => t.status != TournamentStatus.completed)
            .toList();
        list.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
        return list;
      }
    } catch (e) {
      debugPrint('[TournamentService] getTournaments error: $e');
    }

    if (gameType == 'dama') {
      return List.from(_fallbackDamaTournaments);
    }
    return List.from(_fallbackTournaments);
  }

  Stream<List<TournamentModel>> streamTournaments({String gameType = 'dama'}) {
    try {
      final col = _collection;
      if (col != null) {
        return col
            .where('gameType', isEqualTo: gameType)
            .snapshots()
            .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => TournamentModel.fromJson(doc.data()))
              .where((t) => t.status != TournamentStatus.completed)
              .toList();
          list.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
          return list;
        });
      }
    } catch (_) {}

    return Stream.periodic(
      const Duration(seconds: 3),
      (_) {
        final list = gameType == 'dama'
            ? List<TournamentModel>.from(_fallbackDamaTournaments)
            : List<TournamentModel>.from(_fallbackTournaments);
        return list.where((t) => t.status != TournamentStatus.completed).toList();
      },
    );
  }

  Stream<List<TournamentModel>> streamDamaTournaments() {
    return streamTournaments(gameType: 'dama');
  }

  // Finished Clash of Minds tournaments stream
  Stream<List<TournamentModel>> streamFinishedTournaments() {
    try {
      final col = _finishedCollection;
      if (col != null) {
        return col
            .orderBy('completedAt', descending: true)
            .snapshots()
            .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return List.from(_fallbackFinishedTournaments);
          }
          return snapshot.docs.map((doc) => TournamentModel.fromJson(doc.data())).toList();
        });
      }
    } catch (_) {}

    return Stream.periodic(
      const Duration(seconds: 3),
      (_) => List<TournamentModel>.from(_fallbackFinishedTournaments),
    );
  }

  Future<List<TournamentModel>> getFinishedTournaments() async {
    try {
      final col = _finishedCollection;
      if (col != null) {
        final snapshot = await col
            .orderBy('completedAt', descending: true)
            .get()
            .timeout(const Duration(seconds: 4));

        if (snapshot.docs.isNotEmpty) {
          return snapshot.docs.map((doc) => TournamentModel.fromJson(doc.data())).toList();
        }
      }
    } catch (_) {}

    return List.from(_fallbackFinishedTournaments);
  }

  Future<void> saveTournament(TournamentModel tournament) async {
    final list = tournament.isDama ? _fallbackDamaTournaments : _fallbackTournaments;
    final idx = list.indexWhere((t) => t.id == tournament.id);
    if (idx != -1) {
      list[idx] = tournament;
    } else {
      list.insert(0, tournament);
    }

    try {
      final col = _collection;
      if (col != null) {
        await col
            .doc(tournament.id)
            .set(tournament.toJson())
            .timeout(const Duration(seconds: 4));
      }
    } catch (e) {
      debugPrint('[TournamentService] saveTournament error: $e');
    }
  }

  Future<void> saveDamaTournament(TournamentModel tournament) async {
    final damaTournament = tournament.copyWith(gameType: 'dama');
    await saveTournament(damaTournament);
  }

  Future<void> closeAndArchiveTournament(
    TournamentModel tournament, {
    String? winningTeamName,
    List<String>? winningScholarNames,
    String? mvpScholarName,
  }) async {
    final finished = tournament.copyWith(
      status: TournamentStatus.completed,
      winningTeamName: winningTeamName ?? 'Blue Citadel Vanguard',
      winningScholarNames: winningScholarNames ?? ['Champion Scholars'],
      mvpScholarName: mvpScholarName,
      completedAt: DateTime.now(),
    );

    // Remove from active list and add to finished
    if (finished.isDama) {
      _fallbackDamaTournaments.removeWhere((t) => t.id == tournament.id);
    } else {
      _fallbackTournaments.removeWhere((t) => t.id == tournament.id || t.id == 'default_3v3_grand_cup');
      _fallbackFinishedTournaments.insert(0, finished);
    }

    try {
      final col = _collection;
      if (col != null) {
        // Delete from active tournaments collection so it no longer appears as active
        await col.doc(tournament.id).delete().timeout(const Duration(seconds: 4));
      }

      final fCol = _finishedCollection;
      if (fCol != null) {
        await fCol.doc(finished.id).set(finished.toJson()).timeout(const Duration(seconds: 4));
      }
    } catch (e) {
      debugPrint('[TournamentService] closeAndArchiveTournament error: $e');
    }
  }

  Future<void> deleteTournament(String tournamentId) async {
    _fallbackTournaments.removeWhere((t) => t.id == tournamentId);
    _fallbackDamaTournaments.removeWhere((t) => t.id == tournamentId);

    try {
      final col = _collection;
      if (col != null) {
        await col.doc(tournamentId).delete().timeout(const Duration(seconds: 4));
      }
    } catch (e) {
      debugPrint('[TournamentService] deleteTournament error: $e');
    }
  }

  Future<void> joinTournament(String tournamentId, String userId) async {
    void updateList(List<TournamentModel> list) {
      final idx = list.indexWhere((t) => t.id == tournamentId);
      if (idx != -1) {
        final t = list[idx];
        if (!t.registeredScholarIds.contains(userId)) {
          final updatedList = List<String>.from(t.registeredScholarIds)..add(userId);
          list[idx] = t.copyWith(registeredScholarIds: updatedList);
        }
      }
    }

    updateList(_fallbackTournaments);
    updateList(_fallbackDamaTournaments);

    try {
      final col = _collection;
      if (col != null) {
        await col.doc(tournamentId).update({
          'registeredScholarIds': FieldValue.arrayUnion([userId]),
        }).timeout(const Duration(seconds: 4));
      }
    } catch (_) {}
  }

  Future<void> setTournamentStatus(String tournamentId, TournamentStatus status) async {
    void updateStatus(List<TournamentModel> list) {
      final idx = list.indexWhere((t) => t.id == tournamentId);
      if (idx != -1) {
        list[idx] = list[idx].copyWith(status: status);
      }
    }

    updateStatus(_fallbackTournaments);
    updateStatus(_fallbackDamaTournaments);

    try {
      final col = _collection;
      if (col != null) {
        await col.doc(tournamentId).update({
          'status': status.name,
        }).timeout(const Duration(seconds: 4));
      }
    } catch (_) {}
  }
}
