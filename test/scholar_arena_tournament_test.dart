import 'package:flutter_test/flutter_test.dart';
import 'package:quickquiz/models/tournament_model.dart';
import 'package:quickquiz/services/tournament_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. TournamentModel Tests', () {
    test('TournamentModel constructs with custom admin parameters', () {
      final now = DateTime(2026, 9, 15, 14, 30);
      final tournament = TournamentModel(
        id: 'tourney_test_1',
        title: 'Grand Scholar Dama Championship',
        description: 'Test Description',
        topic: 'Dama & Strategic Checkers',
        startDateTime: now,
        durationMinutes: 15,
        winnerExpReward: 2000,
        runnerUpExpReward: 800,
        participantExpReward: 250,
        status: TournamentStatus.upcoming,
        teamSize: 1,
        registeredScholarIds: ['scholar_alpha', 'scholar_beta'],
        gameType: 'dama',
      );

      expect(tournament.id, 'tourney_test_1');
      expect(tournament.title, 'Grand Scholar Dama Championship');
      expect(tournament.topic, 'Dama & Strategic Checkers');
      expect(tournament.durationMinutes, 15);
      expect(tournament.winnerExpReward, 2000);
      expect(tournament.runnerUpExpReward, 800);
      expect(tournament.participantExpReward, 250);
      expect(tournament.status, TournamentStatus.upcoming);
      expect(tournament.teamSize, 1);
      expect(tournament.registeredScholarIds.length, 2);
    });

    test('TournamentModel JSON serialization and deserialization round-trip', () {
      final startTime = DateTime(2026, 10, 1, 9, 0);
      final tournament = TournamentModel(
        id: 'json_tourney_99',
        title: 'Grand Scholar Dama Championship',
        description: 'Knockout series',
        topic: 'Dama Championship',
        startDateTime: startTime,
        durationMinutes: 10,
        winnerExpReward: 1500,
        runnerUpExpReward: 600,
        participantExpReward: 200,
        status: TournamentStatus.live,
        teamSize: 1,
        registeredScholarIds: ['usr_1', 'usr_2', 'usr_3'],
        gameType: 'dama',
      );

      final json = tournament.toJson();
      expect(json['id'], 'json_tourney_99');
      expect(json['title'], 'Grand Scholar Dama Championship');
      expect(json['topic'], 'Dama Championship');
      expect(json['winnerExpReward'], 1500);
      expect(json['runnerUpExpReward'], 600);
      expect(json['participantExpReward'], 200);
      expect(json['status'], 'live');
      expect(json['durationMinutes'], 10);

      final restored = TournamentModel.fromJson(json);
      expect(restored.id, tournament.id);
      expect(restored.title, tournament.title);
      expect(restored.topic, tournament.topic);
      expect(restored.winnerExpReward, tournament.winnerExpReward);
      expect(restored.runnerUpExpReward, tournament.runnerUpExpReward);
      expect(restored.participantExpReward, tournament.participantExpReward);
      expect(restored.status, TournamentStatus.live);
      expect(restored.isLive, isTrue);
      expect(restored.isUpcoming, isFalse);
    });

    test('TournamentModel copyWith allows partial updating', () {
      final tournament = TournamentModel(
        id: 'copy_tourney_1',
        title: 'Original Title',
        topic: 'General Science',
        startDateTime: DateTime.now(),
        durationMinutes: 5,
        winnerExpReward: 1000,
        runnerUpExpReward: 400,
        participantExpReward: 100,
        status: TournamentStatus.upcoming,
      );

      final updated = tournament.copyWith(
        title: 'Updated Grand Finals',
        status: TournamentStatus.live,
        winnerExpReward: 3000,
      );

      expect(updated.id, tournament.id);
      expect(updated.title, 'Updated Grand Finals');
      expect(updated.topic, 'General Science');
      expect(updated.status, TournamentStatus.live);
      expect(updated.winnerExpReward, 3000);
      expect(updated.runnerUpExpReward, 400);
    });

    test('TournamentModel helpers compute correct strings', () {
      final tournament = TournamentModel(
        title: 'Time Test Tournament',
        topic: 'Mathematics',
        startDateTime: DateTime(2026, 5, 20, 16, 45),
        durationMinutes: 10,
        winnerExpReward: 1200,
        runnerUpExpReward: 500,
        participantExpReward: 150,
      );

      expect(tournament.formattedDate.isNotEmpty, isTrue);
      expect(tournament.formattedTime.isNotEmpty, isTrue);
      expect(tournament.formattedDateTime.isNotEmpty, isTrue);
    });
  });

  group('2. TournamentService In-Memory & Default Tournament Tests', () {
    test('TournamentService default tournament provides fallback tournament', () {
      final defaultTourney = TournamentService.defaultTournament;
      expect(defaultTourney, isNotNull);
      expect(defaultTourney.title.isNotEmpty, isTrue);
      expect(defaultTourney.teamSize, 1);
      expect(defaultTourney.winnerExpReward, greaterThan(0));
    });

    test('TournamentService can save, retrieve and register scholars in-memory', () async {
      final service = TournamentService();
      // Initially empty until created by Admin
      final tournaments = await service.getTournaments();
      expect(tournaments, isA<List<TournamentModel>>());

      final newTournament = TournamentModel(
        id: 'test_memory_cup_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Dama Master Tournament',
        topic: '8x8 Strategy',
        startDateTime: DateTime.now().add(const Duration(hours: 1)),
        durationMinutes: 15,
        winnerExpReward: 1500,
        runnerUpExpReward: 750,
        participantExpReward: 200,
        status: TournamentStatus.upcoming,
        teamSize: 1,
        gameType: 'dama',
      );

      await service.saveTournament(newTournament);
      final updatedList = await service.getTournaments();
      expect(updatedList.any((t) => t.id == newTournament.id), isTrue);

      await service.joinTournament(newTournament.id, 'test_scholar_id_42');
      final joinedList = await service.getTournaments();
      final found = joinedList.firstWhere((t) => t.id == newTournament.id);
      expect(found.registeredScholarIds, contains('test_scholar_id_42'));

      await service.setTournamentStatus(newTournament.id, TournamentStatus.live);
      final liveList = await service.getTournaments();
      final liveFound = liveList.firstWhere((t) => t.id == newTournament.id);
      expect(liveFound.status, TournamentStatus.live);
      expect(liveFound.isLive, isTrue);
    });
  });
}
