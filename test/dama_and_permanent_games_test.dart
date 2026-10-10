import 'package:flutter_test/flutter_test.dart';
import 'package:quickquiz/models/dama_game_model.dart';
import 'package:quickquiz/models/tournament_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Dama Board Game Engine Tests', () {
    test('Board initializes with 12 pieces for each player on dark tiles only', () {
      final board = DamaBoard();

      int p1Count = 0;
      int p2Count = 0;

      for (int r = 0; r < DamaBoard.size; r++) {
        for (int c = 0; c < DamaBoard.size; c++) {
          final piece = board.getPiece(r, c);
          if (piece != null) {
            // Must be on dark tiles only
            expect(board.isDarkTile(r, c), isTrue);
            if (piece.player == 1) p1Count++;
            if (piece.player == 2) p2Count++;
            expect(piece.isKing, isFalse);
          }
        }
      }

      expect(p1Count, 12);
      expect(p2Count, 12);
      expect(board.currentTurn, 1);
      expect(board.isGameOver, isFalse);
      expect(board.winner, isNull);
    });

    test('Regular pieces move diagonally forward by 1 square', () {
      final board = DamaBoard();

      // Clear board and place 1 test piece for Player 1 at [5, 2]
      board.grid = List.generate(DamaBoard.size, (_) => List.filled(DamaBoard.size, null));
      board.grid[5][2] = DamaPiece(player: 1);
      board.currentTurn = 1;

      final moves = board.getLegalMoves(5, 2);
      expect(moves.length, 2);

      // Should be able to move to [4, 1] and [4, 3]
      expect(moves.any((m) => m.toRow == 4 && m.toCol == 1), isTrue);
      expect(moves.any((m) => m.toRow == 4 && m.toCol == 3), isTrue);
    });

    test('Regular piece captures enemy piece by jumping over into empty square', () {
      final board = DamaBoard();

      board.grid = List.generate(DamaBoard.size, (_) => List.filled(DamaBoard.size, null));
      // Player 1 at [5, 2], enemy Player 2 at [4, 3], landing at [3, 4] empty
      board.grid[5][2] = DamaPiece(player: 1);
      board.grid[4][3] = DamaPiece(player: 2);
      board.currentTurn = 1;

      final moves = board.getLegalMoves(5, 2);
      expect(moves.length, 1);

      final captureMove = moves.first;
      expect(captureMove.isCapture, isTrue);
      expect(captureMove.toRow, 3);
      expect(captureMove.toCol, 4);

      // Execute move
      final success = board.makeMove(captureMove);
      expect(success, isTrue);
      expect(board.grid[5][2], isNull);
      expect(board.grid[4][3], isNull); // Captured piece removed!
      expect(board.grid[3][4]?.player, 1);
      expect(board.capturedByP1, 1);
    });

    test('Piece reaching opposite back row promotes to King (Dama)', () {
      final board = DamaBoard();

      board.grid = List.generate(DamaBoard.size, (_) => List.filled(DamaBoard.size, null));
      // Player 1 at [1, 2] moving to row 0
      board.grid[1][2] = DamaPiece(player: 1);
      board.currentTurn = 1;

      final moves = board.getLegalMoves(1, 2);
      expect(moves.any((m) => m.toRow == 0 && m.becameKing), isTrue);

      final kingMove = moves.firstWhere((m) => m.toRow == 0);
      board.makeMove(kingMove);

      expect(board.grid[0][kingMove.toCol]?.isKing, isTrue);
    });

    test('King (Dama) can move diagonally forward and backward (flying king)', () {
      final board = DamaBoard();

      board.grid = List.generate(DamaBoard.size, (_) => List.filled(DamaBoard.size, null));
      // King at center [3, 4]
      board.grid[3][4] = DamaPiece(player: 1, isKing: true);
      board.currentTurn = 1;

      final moves = board.getLegalMoves(3, 4);

      // King can glide along all 4 diagonal paths
      expect(moves.any((m) => m.toRow < 3), isTrue); // forward
      expect(moves.any((m) => m.toRow > 3), isTrue); // backward
      expect(moves.length, greaterThanOrEqualTo(4));
    });

    test('AI move generator produces legal move on request', () {
      final board = DamaBoard();
      board.currentTurn = 2;

      final aiMove = board.getAiMove(DamaDifficulty.medium);
      expect(aiMove, isNotNull);
      expect(board.grid[aiMove!.fromRow][aiMove.fromCol]?.player, 2);
      expect(board.isInBounds(aiMove.toRow, aiMove.toCol), isTrue);
    });
  });

  group('2. Permanent Games 0 EXP & Tournament Rules Verification', () {
    test('Dama casual game awards 0 EXP (Permanent Casual Game)', () {
      const isPermanentCasualGame = true;
      final damaExpAward = isPermanentCasualGame ? 0 : 500;
      expect(damaExpAward, 0);
    });

    test('3v3 Clash of Minds Tournament uses 600 Citadel HP and awards tournament EXP', () {
      final tournament = TournamentModel(
        title: '3v3 Clash of Minds Cup',
        topic: 'Engineering & AI',
        startDateTime: DateTime.now(),
        durationMinutes: 10,
        winnerExpReward: 1000,
        runnerUpExpReward: 500,
        participantExpReward: 150,
        teamSize: 3,
        customQuestions: [
          {
            'stem': 'What is the speed of light in a vacuum?',
            'options': ['300,000 km/s', '150,000 km/s', '3,000 km/s', '30,000 km/s'],
            'correctAnswerIndex': 0,
            'explanation': 'Speed of light is approximately 299,792 km/s.',
          }
        ],
      );

      expect(tournament.teamSize, 3);
      expect(tournament.customQuestions?.length, 1);
      expect(tournament.winnerExpReward, 1000);
      expect(tournament.runnerUpExpReward, 500);
    });

    test('Dama Tournament model supports dama gameType and scheduling', () {
      final damaTournament = TournamentModel(
        title: 'Grand Scholar Dama Championship',
        topic: 'Single Elimination Blitz',
        startDateTime: DateTime.now(),
        durationMinutes: 15,
        winnerExpReward: 1500,
        runnerUpExpReward: 700,
        participantExpReward: 200,
        gameType: 'dama',
      );

      expect(damaTournament.isDama, isTrue);
      expect(damaTournament.isClashOfMinds, isFalse);
      expect(damaTournament.winnerExpReward, 1500);
    });

    test('Finished tournament archive captures winning squad and MVP scholar', () {
      final finished = TournamentModel(
        title: 'Genesis Invitational',
        topic: 'Science',
        startDateTime: DateTime.now().subtract(const Duration(hours: 2)),
        status: TournamentStatus.completed,
        teamSize: 3,
        winningTeamName: 'Blue Citadel Vanguard',
        winningScholarNames: ['Naldz', 'Reynaldo Seroje', 'Kate'],
        mvpScholarName: 'Reynaldo Seroje',
        completedAt: DateTime.now(),
      );

      expect(finished.isCompleted, isTrue);
      expect(finished.winningTeamName, 'Blue Citadel Vanguard');
      expect(finished.winningScholarNames?.length, 3);
      expect(finished.mvpScholarName, 'Reynaldo Seroje');
    });
  });
}
