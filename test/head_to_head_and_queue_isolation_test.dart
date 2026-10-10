import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickquiz/models/game_match_model.dart';
import 'package:quickquiz/models/user_model.dart';
import 'package:quickquiz/services/game_session_service.dart';
import 'package:quickquiz/services/head_to_head_service.dart';
import 'package:quickquiz/viewmodels/auth_viewmodel.dart';
import 'package:quickquiz/widgets/game_invitation_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GameSessionService.fallbackMatches.clear();
    GameSessionService.fallbackQueue.clear();
  });

  group('HeadToHeadService Tests', () {
    late HeadToHeadService service;

    setUp(() {
      service = HeadToHeadService();
    });

    test('Initial record starts at 0 wins, 0 losses, 0 draws', () async {
      final record = await service.getRecord(
        userId: 'player_1',
        opponentId: 'opponent_1',
        opponentName: 'Rival Scholar',
      );

      expect(record.wins, equals(0));
      expect(record.losses, equals(0));
      expect(record.draws, equals(0));
      expect(record.totalMatches, equals(0));
      expect(record.winRate, equals(0.0));
      expect(record.summary, equals('0 W - 0 L'));
    });

    test('recordMatchOutcome correctly increments wins, losses, and draws',
        () async {
      // 1 Win
      final r1 = await service.recordMatchOutcome(
        userId: 'player_1',
        opponentId: 'opponent_1',
        opponentName: 'Rival Scholar',
        isWin: true,
        isDraw: false,
      );
      expect(r1.wins, equals(1));
      expect(r1.losses, equals(0));
      expect(r1.draws, equals(0));
      expect(r1.summary, equals('1 W - 0 L'));

      // 1 Loss
      final r2 = await service.recordMatchOutcome(
        userId: 'player_1',
        opponentId: 'opponent_1',
        opponentName: 'Rival Scholar',
        isWin: false,
        isDraw: false,
      );
      expect(r2.wins, equals(1));
      expect(r2.losses, equals(1));
      expect(r2.summary, equals('1 W - 1 L'));

      // 1 Draw
      final r3 = await service.recordMatchOutcome(
        userId: 'player_1',
        opponentId: 'opponent_1',
        opponentName: 'Rival Scholar',
        isWin: false,
        isDraw: true,
      );
      expect(r3.wins, equals(1));
      expect(r3.losses, equals(1));
      expect(r3.draws, equals(1));
      expect(r3.summary, equals('1 W - 1 L - 1 D'));
      expect(r3.totalMatches, equals(3));
      expect(r3.winRate, closeTo(33.3, 0.1));
    });

    test('HeadToHead record persists in SharedPreferences and memory cache',
        () async {
      await service.recordMatchOutcome(
        userId: 'player_alpha',
        opponentId: 'opponent_beta',
        opponentName: 'Beta Scholar',
        isWin: true,
        isDraw: false,
      );

      // Verify cached record
      final cached = service.getCachedRecord(
        userId: 'player_alpha',
        opponentId: 'opponent_beta',
      );
      expect(cached.wins, equals(1));

      // Verify retrieved record from fresh call
      final retrieved = await service.getRecord(
        userId: 'player_alpha',
        opponentId: 'opponent_beta',
      );
      expect(retrieved.wins, equals(1));
      expect(retrieved.opponentName, equals('Beta Scholar'));
    });
  });

  group('Queue Matchmaking vs Direct Invite Isolation Tests', () {
    late GameSessionService service;
    late UserModel user1;
    late UserModel user2;

    setUp(() {
      service = GameSessionService();
      user1 = UserModel(
        uid: 'scholar_1',
        name: 'Alpha Scholar',
        email: 'alpha@quickquiz.com',
        nickname: 'Alpha',
        level: 10,
        createdAt: DateTime.now(),
      );
      user2 = UserModel(
        uid: 'scholar_2',
        name: 'Beta Scholar',
        email: 'beta@quickquiz.com',
        nickname: 'Beta',
        level: 8,
        createdAt: DateTime.now(),
      );
    });

    test('sendChallenge creates a match with isDirectInvite = true', () async {
      final challenge = await service.sendChallenge(
        host: user1,
        opponent: user2,
        gameType: 'dama',
      );

      expect(challenge.isDirectInvite, isTrue);
      expect(challenge.status, equals(GameMatchStatus.pending));
    });

    test(
        'enterMatchmaking paired match has isDirectInvite = false and status = playing',
        () async {
      // User 1 enters queue
      final waitTicket =
          await service.enterMatchmaking(user: user1, gameType: 'dama');
      expect(waitTicket, isNull);

      // User 2 enters queue -> triggers pairing
      final pairedMatch =
          await service.enterMatchmaking(user: user2, gameType: 'dama');
      expect(pairedMatch, isNotNull);
      expect(pairedMatch!.isDirectInvite, isFalse);
      expect(pairedMatch.status, equals(GameMatchStatus.playing));
    });

    testWidgets(
        'GameInvitationOverlay ignores matches where isDirectInvite is false',
        (tester) async {
      // Create a match where isDirectInvite is false (e.g. from matchmaking queue)
      GameSessionService.fallbackMatches['queue_match_1'] = GameMatchModel(
        id: 'queue_match_1',
        hostId: user1.uid,
        hostName: user1.effectiveNickname,
        opponentId: user2.uid,
        opponentName: user2.effectiveNickname,
        gameType: 'dama',
        status: GameMatchStatus.pending,
        isDirectInvite: false,
        currentTurn: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Build overlay widget with user2 as current logged-in user
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => AuthViewModel()..setCurrentUserForTesting(user2),
              ),
            ],
            child: const GameInvitationOverlay(
              child: Scaffold(
                body: Center(child: Text('Main Content')),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // No challenge notification banner should be shown because isDirectInvite is false!
      expect(find.text('Live Invitation'), findsNothing);
      expect(find.text('Dama Match'), findsNothing);

      // Now add a match with isDirectInvite = true
      GameSessionService.fallbackMatches['direct_match_1'] = GameMatchModel(
        id: 'direct_match_1',
        hostId: user1.uid,
        hostName: user1.effectiveNickname,
        opponentId: user2.uid,
        opponentName: user2.effectiveNickname,
        gameType: 'dama',
        status: GameMatchStatus.pending,
        isDirectInvite: true,
        currentTurn: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Rebuild & pump
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Now the banner SHOULD be displayed
      expect(find.text('Live Invitation'), findsOneWidget);
      expect(find.text('Dama Match'), findsOneWidget);
    });
  });
}
