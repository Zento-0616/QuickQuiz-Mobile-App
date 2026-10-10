import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:quickquiz/models/dama_game_model.dart';
import 'package:quickquiz/models/game_match_model.dart';
import 'package:quickquiz/models/user_model.dart';
import 'package:quickquiz/services/game_session_service.dart';
import 'package:quickquiz/viewmodels/auth_viewmodel.dart';
import 'package:quickquiz/widgets/game_invitation_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GameMatchModel Serialization & State Tests', () {
    test('Round-trip serialization toMap and fromMap preserves all fields', () {
      final now = DateTime.now();
      final original = GameMatchModel(
        id: 'match_test_1',
        hostId: 'user_host_1',
        hostName: 'Host Scholar',
        hostAvatar: 'https://example.com/host.png',
        hostLevel: 5,
        opponentId: 'user_opp_2',
        opponentName: 'Challenger Scholar',
        opponentAvatar: 'https://example.com/opp.png',
        opponentLevel: 4,
        gameType: 'dama',
        status: GameMatchStatus.playing,
        currentTurn: 1,
        lastMove: {'fromRow': 2, 'fromCol': 3, 'toRow': 3, 'toCol': 4},
        isGameOver: false,
        winnerId: null,
        drawOfferedBy: 'user_opp_2',
        createdAt: now,
        updatedAt: now,
      );

      final map = original.toMap();
      final reconstructed = GameMatchModel.fromMap(map, 'match_test_1');

      expect(reconstructed.id, equals(original.id));
      expect(reconstructed.hostId, equals(original.hostId));
      expect(reconstructed.hostName, equals(original.hostName));
      expect(reconstructed.opponentId, equals(original.opponentId));
      expect(reconstructed.opponentName, equals(original.opponentName));
      expect(reconstructed.gameType, equals(original.gameType));
      expect(reconstructed.status, equals(GameMatchStatus.playing));
      expect(reconstructed.currentTurn, equals(1));
      expect(reconstructed.lastMove, isNotNull);
      expect(reconstructed.lastMove!['fromRow'], equals(2));
      expect(reconstructed.drawOfferedBy, equals('user_opp_2'));
    });

    test('copyWith updates specific properties without altering untouched fields', () {
      final match = GameMatchModel(
        id: 'm1',
        hostId: 'h1',
        hostName: 'Host',
        opponentId: 'o1',
        opponentName: 'Opp',
        gameType: 'dama',
        status: GameMatchStatus.pending,
        currentTurn: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final accepted = match.copyWith(
        status: GameMatchStatus.accepted,
        currentTurn: 2,
      );

      expect(accepted.id, equals('m1'));
      expect(accepted.status, equals(GameMatchStatus.accepted));
      expect(accepted.currentTurn, equals(2));
      expect(accepted.hostName, equals('Host'));
    });
  });

  group('GameSessionService Real-time Matchmaking & Sync Tests', () {
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

    test('sendChallenge creates a pending challenge receivable by opponent stream', () async {
      final challenge = await service.sendChallenge(
        host: user1,
        opponent: user2,
        gameType: 'dama',
      );

      expect(challenge.id, isNotEmpty);
      expect(challenge.hostId, equals('scholar_1'));
      expect(challenge.opponentId, equals('scholar_2'));
      expect(challenge.status, equals(GameMatchStatus.pending));

      // Opponent streams incoming challenges
      final incoming = await service.streamIncomingChallenges('scholar_2').first;
      expect(incoming.length, greaterThanOrEqualTo(1));
      expect(incoming.any((c) => c.id == challenge.id), isTrue);
    });

    test('respondToChallenge accept updates status to playing', () async {
      final challenge = await service.sendChallenge(
        host: user1,
        opponent: user2,
        gameType: 'dama',
      );

      await service.respondToChallenge(matchId: challenge.id, accept: true);

      final updated = await service.streamMatch(challenge.id).first;
      expect(updated, isNotNull);
      expect(updated!.status, equals(GameMatchStatus.playing));
    });

    test('respondToChallenge decline updates status to declined', () async {
      final challenge = await service.sendChallenge(
        host: user1,
        opponent: user2,
        gameType: 'dama',
      );

      await service.respondToChallenge(matchId: challenge.id, accept: false);

      final updated = await service.streamMatch(challenge.id).first;
      expect(updated, isNotNull);
      expect(updated!.status, equals(GameMatchStatus.declined));
    });

    test('cancelChallenge updates status to cancelled', () async {
      final challenge = await service.sendChallenge(
        host: user1,
        opponent: user2,
        gameType: 'dama',
      );

      await service.cancelChallenge(challenge.id);

      final updated = await service.streamMatch(challenge.id).first;
      expect(updated, isNotNull);
      expect(updated!.status, equals(GameMatchStatus.cancelled));
    });

    test('sendMove synchronizes move coordinates and turns', () async {
      final challenge = await service.sendChallenge(
        host: user1,
        opponent: user2,
        gameType: 'dama',
      );

      await service.respondToChallenge(matchId: challenge.id, accept: true);

      final moveMap = {'fromRow': 2, 'fromCol': 1, 'toRow': 3, 'toCol': 2};
      await service.sendMove(
        matchId: challenge.id,
        moveData: moveMap,
        nextTurn: 2,
      );

      final afterMove = await service.streamMatch(challenge.id).first;
      expect(afterMove, isNotNull);
      expect(afterMove!.currentTurn, equals(2));
      expect(afterMove.lastMove!['fromRow'], equals(2));
      expect(afterMove.lastMove!['toRow'], equals(3));
    });

    test('offerDraw and respondToDraw manage peaceful stalemate flow', () async {
      final challenge = await service.sendChallenge(
        host: user1,
        opponent: user2,
        gameType: 'dama',
      );

      await service.respondToChallenge(matchId: challenge.id, accept: true);

      // Offer draw from user2
      await service.offerDraw(matchId: challenge.id, fromUserId: user2.uid);
      var current = await service.streamMatch(challenge.id).first;
      expect(current!.drawOfferedBy, equals('scholar_2'));

      // Accept draw
      await service.respondToDraw(matchId: challenge.id, accept: true);
      current = await service.streamMatch(challenge.id).first;
      expect(current!.isGameOver, isTrue);
      expect(current.status, equals(GameMatchStatus.completed));
      expect(current.winnerId, equals('draw'));
    });

    test('resignMatch awards victory to the remaining player and ends game', () async {
      final challenge = await service.sendChallenge(
        host: user1,
        opponent: user2,
        gameType: 'dama',
      );

      await service.respondToChallenge(matchId: challenge.id, accept: true);

      // User 1 resigns, user 2 is awarded victory
      await service.resignMatch(matchId: challenge.id, winnerUserId: user2.uid);

      final afterResign = await service.streamMatch(challenge.id).first;
      expect(afterResign!.isGameOver, isTrue);
      expect(afterResign.winnerId, equals('scholar_2'));
      expect(afterResign.status, equals(GameMatchStatus.completed));
    });

    test('Matchmaking queue automatically pairs two waiting players', () async {
      // Player 1 enters queue
      final matchImmediate = await service.enterMatchmaking(user: user1, gameType: 'dama');
      expect(matchImmediate, isNull); // Queued, waiting for opponent

      // Player 2 enters queue
      final pairedMatch = await service.enterMatchmaking(user: user2, gameType: 'dama');
      expect(pairedMatch, isNotNull);
      expect(pairedMatch!.hostId, equals('scholar_1'));
      expect(pairedMatch.opponentId, equals('scholar_2'));
      expect(pairedMatch.status, equals(GameMatchStatus.playing));

      // Player 1 receives matchId on ticket stream
      final ticketMatchId = await service.streamMatchmakingTicket('scholar_1').first;
      expect(ticketMatchId, equals(pairedMatch.id));
    });
  });

  group('Dama Board Online Turn & Deadlock Verification', () {
    test('DamaBoard enforces alternating turns and legal move validation', () {
      final board = DamaBoard();
      expect(board.currentTurn, equals(1)); // Player 1 starts (bottom)

      // Player 1 piece exists at row 5, col 0 (dark tile)
      final p1Piece = board.getPiece(5, 0);
      expect(p1Piece, isNotNull);
      expect(p1Piece!.player, equals(1));

      // Player 2 piece exists at row 2, col 1
      final p2Piece = board.getPiece(2, 1);
      expect(p2Piece, isNotNull);
      expect(p2Piece!.player, equals(2));

      // Legal moves for player 1
      final legalMovesP1 = board.getLegalMoves(5, 0);
      expect(legalMovesP1, isNotEmpty);

      // Move piece
      final m = legalMovesP1.first;
      board.makeMove(m);
      expect(board.currentTurn, equals(2)); // Turn passed to Player 2
    });

    test('Run & hide stalemate detection activates during long non-capture sequences', () {
      final board = DamaBoard();
      // Initially no deadlock
      expect(board.isRunAndHideDeadlock(), isFalse);

      // Simulate 2 pieces left
      for (int i = 0; i < 8; i++) {
        for (int j = 0; j < 8; j++) {
          board.grid[i][j] = null;
        }
      }
      board.grid[0][1] = DamaPiece(player: 1, isKing: true);
      board.grid[7][6] = DamaPiece(player: 2, isKing: true);

      // 15 consecutive non-capture moves with <= 2 pieces triggers deadlock
      board.consecutiveNonCaptureMoves = 15;

      expect(board.isRunAndHideDeadlock(), isTrue);
    });
  });

  group('GameInvitationOverlay UI Notification Bar Tests', () {
    testWidgets('Displays sliding top notification bar when challenge arrives and handles actions', (tester) async {
      final host = UserModel(
        uid: 'h_test',
        name: 'Prof. Gauss',
        email: 'gauss@quickquiz.com',
        nickname: 'Gauss',
        level: 15,
        createdAt: DateTime.now(),
      );

      final opponent = UserModel(
        uid: 'opp_test',
        name: 'Ada Lovelace',
        email: 'ada@quickquiz.com',
        nickname: 'Ada',
        level: 12,
        createdAt: DateTime.now(),
      );

      final service = GameSessionService();
      final challenge = await service.sendChallenge(
        host: host,
        opponent: opponent,
        gameType: 'dama',
      );

      // Build overlay widget with fake user
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => AuthViewModel()..setCurrentUserForTesting(opponent),
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

      // Banner elements should be visible
      expect(find.text('Dama Match'), findsOneWidget);
      expect(find.text('Live Invitation'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);

      // Tap Decline
      await tester.tap(find.text('Decline'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Match status should be declined
      final match = await service.streamMatch(challenge.id).first;
      expect(match!.status, equals(GameMatchStatus.declined));
    });

    testWidgets('Tapping Accept navigates to match and updates match status', (tester) async {
      final host = UserModel(
        uid: 'h_test2',
        name: 'Prof. Gauss',
        email: 'gauss2@quickquiz.com',
        nickname: 'Gauss2',
        level: 15,
        createdAt: DateTime.now(),
      );

      final opponent = UserModel(
        uid: 'opp_test2',
        name: 'Ada Lovelace',
        email: 'ada2@quickquiz.com',
        nickname: 'Ada2',
        level: 12,
        createdAt: DateTime.now(),
      );

      final service = GameSessionService();
      final challenge = await service.sendChallenge(
        host: host,
        opponent: opponent,
        gameType: 'dama',
      );

      bool didNavigateToDama = false;
      final testRouter = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: Text('Main Content')),
          ),
          GoRoute(
            path: '/dama',
            builder: (_, state) {
              didNavigateToDama = true;
              return const Scaffold(body: Text('Dama Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => AuthViewModel()..setCurrentUserForTesting(opponent),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: testRouter,
            builder: (ctx, child) => GameInvitationOverlay(
              router: testRouter,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Accept'), findsOneWidget);

      await tester.tap(find.text('Accept'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final match = await service.streamMatch(challenge.id).first;
      expect(match!.status, equals(GameMatchStatus.playing));
      expect(didNavigateToDama, isTrue);
      expect(find.text('Dama Screen'), findsOneWidget);
    });
  });
}
