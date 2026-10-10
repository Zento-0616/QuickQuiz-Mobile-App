import 'package:flutter_test/flutter_test.dart';
import 'package:quickquiz/models/dama_game_model.dart';
import 'package:quickquiz/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Scholar Online Presence Filter Tests', () {
    test('User is currently online only if isOnline is true and lastActive within 5 minutes', () {
      final now = DateTime.now();

      final onlineActive = UserModel(
        uid: 'user_online_active',
        name: 'Active Scholar',
        email: 'active@quickquiz.com',
        createdAt: now,
        isOnline: true,
        lastActive: now.subtract(const Duration(minutes: 2)),
      );
      expect(onlineActive.isCurrentlyOnline, isTrue);

      // Stale presence (> 5 minutes ago) should NOT be counted as currently online
      final onlineStale = UserModel(
        uid: 'user_online_stale',
        name: 'Stale Scholar',
        email: 'stale@quickquiz.com',
        createdAt: now,
        isOnline: true,
        lastActive: now.subtract(const Duration(minutes: 6)),
      );
      expect(onlineStale.isCurrentlyOnline, isFalse);

      // Explicitly offline user
      final offlineRecent = UserModel(
        uid: 'user_offline_recent',
        name: 'Offline Scholar',
        email: 'offline@quickquiz.com',
        createdAt: now,
        isOnline: false,
        lastActive: now.subtract(const Duration(seconds: 30)),
      );
      expect(offlineRecent.isCurrentlyOnline, isFalse);

      // User with null lastActive
      final noLastActive = UserModel(
        uid: 'user_no_active',
        name: 'No Active Scholar',
        email: 'noactive@quickquiz.com',
        createdAt: now,
        isOnline: true,
        lastActive: null,
      );
      expect(noLastActive.isCurrentlyOnline, isFalse);
    });
  });

  group('2. Dama Board Clone & Evaluation Tests', () {
    test('DamaBoard.clone creates a deep, independent copy of grid and state', () {
      final original = DamaBoard();
      final copy = original.clone();

      expect(copy.currentTurn, equals(original.currentTurn));
      expect(copy.capturedByP1, equals(original.capturedByP1));
      expect(copy.capturedByP2, equals(original.capturedByP2));

      // Modify clone grid
      copy.grid[5][0] = null;
      expect(original.grid[5][0], isNotNull);
      expect(copy.grid[5][0], isNull);
    });

    test('evaluateBoard scores material advantage and piece position correctly', () {
      final board = DamaBoard();
      // Clear board
      board.grid = List.generate(DamaBoard.size, (_) => List.filled(DamaBoard.size, null));

      // 1 regular piece for Player 2
      board.grid[2][1] = DamaPiece(player: 2);
      final scoreP2Single = board.evaluateBoard(2);
      expect(scoreP2Single, greaterThan(0));

      // Promoting or adding King for Player 2 significantly increases evaluation score
      board.grid[4][3] = DamaPiece(player: 2, isKing: true);
      final scoreWithKing = board.evaluateBoard(2);
      expect(scoreWithKing, greaterThan(scoreP2Single + 200));

      // Adding equal pieces for Player 1 balances the score
      board.grid[5][2] = DamaPiece(player: 1);
      board.grid[3][4] = DamaPiece(player: 1, isKing: true);
      final balancedScore = board.evaluateBoard(2);
      expect(balancedScore, closeTo(0, 100));
    });
  });

  group('3. Dama Grandmaster Minimax AI Tests', () {
    test('Grandmaster AI (Hard) finds legal move and prioritizes capture opportunities', () {
      final board = DamaBoard();
      board.grid = List.generate(DamaBoard.size, (_) => List.filled(DamaBoard.size, null));

      // Place Player 2 piece at [2, 1] and Player 1 piece at [3, 2], with [4, 3] empty
      board.grid[2][1] = DamaPiece(player: 2);
      board.grid[3][2] = DamaPiece(player: 1);
      board.currentTurn = 2;

      final move = board.getAiMove(DamaDifficulty.hard);
      expect(move, isNotNull);
      expect(move!.isCapture, isTrue);
      expect(move.fromRow, 2);
      expect(move.fromCol, 1);
      expect(move.toRow, 4);
      expect(move.toCol, 3);
    });

    test('Grandmaster AI (Hard) executes full Minimax search without throwing on standard board', () {
      final board = DamaBoard();
      board.currentTurn = 2;

      final stopwatch = Stopwatch()..start();
      final move = board.getAiMove(DamaDifficulty.hard);
      stopwatch.stop();

      expect(move, isNotNull);
      expect(board.grid[move!.fromRow][move.fromCol]?.player, 2);
      // Minimax depth 4 with alpha-beta should be fast and finish well under 3000ms
      expect(stopwatch.elapsedMilliseconds, lessThan(3000));
    });
  });
}
