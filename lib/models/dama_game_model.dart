import 'dart:math';

enum DamaMode { pvp, vsAi }
enum DamaDifficulty { easy, medium, hard }

class DamaPiece {
  final int player;
  bool isKing;

  DamaPiece({
    required this.player,
    this.isKing = false,
  });

  DamaPiece copyWith({int? player, bool? isKing}) {
    return DamaPiece(
      player: player ?? this.player,
      isKing: isKing ?? this.isKing,
    );
  }
}

class DamaMove {
  final int fromRow;
  final int fromCol;
  final int toRow;
  final int toCol;
  final List<Point<int>> capturedTiles;
  final bool becameKing;

  const DamaMove({
    required this.fromRow,
    required this.fromCol,
    required this.toRow,
    required this.toCol,
    this.capturedTiles = const [],
    this.becameKing = false,
  });

  bool get isCapture => capturedTiles.isNotEmpty;
}

class DamaBoard {
  static const int size = 8;
  late List<List<DamaPiece?>> grid;
  int currentTurn = 1;
  int capturedByP1 = 0;
  int capturedByP2 = 0;
  bool isGameOver = false;
  int? winner;
  bool isDraw = false;
  int consecutiveNonCaptureMoves = 0;
  final List<DamaMove> moveHistory = [];

  Point<int>? multiCapturePiece;

  DamaBoard() {
    reset();
  }

  void reset() {
    grid = List.generate(size, (_) => List.filled(size, null));
    capturedByP1 = 0;
    capturedByP2 = 0;
    currentTurn = 1;
    isGameOver = false;
    winner = null;
    isDraw = false;
    consecutiveNonCaptureMoves = 0;
    moveHistory.clear();
    multiCapturePiece = null;

    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < size; c++) {
        if ((r + c) % 2 == 1) {
          grid[r][c] = DamaPiece(player: 2);
        }
      }
    }

    for (int r = 5; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if ((r + c) % 2 == 1) {
          grid[r][c] = DamaPiece(player: 1);
        }
      }
    }
  }

  bool isDarkTile(int r, int c) => (r + c) % 2 == 1;

  bool isInBounds(int r, int c) => r >= 0 && r < size && c >= 0 && c < size;

  DamaPiece? getPiece(int r, int c) {
    if (!isInBounds(r, c)) return null;
    return grid[r][c];
  }

  List<DamaMove> getCaptureMovesForPiece(int r, int c) {
    final piece = getPiece(r, c);
    if (piece == null) return [];

    final captures = <DamaMove>[];
    const directions = [
      Point(-1, -1),
      Point(-1, 1),
      Point(1, -1),
      Point(1, 1),
    ];

    if (piece.isKing) {
      for (final d in directions) {
        int scanR = r + d.x;
        int scanC = c + d.y;
        Point<int>? enemyPos;

        while (isInBounds(scanR, scanC)) {
          final target = grid[scanR][scanC];
          if (target == null) {
            if (enemyPos != null) {
              captures.add(DamaMove(
                fromRow: r,
                fromCol: c,
                toRow: scanR,
                toCol: scanC,
                capturedTiles: [enemyPos],
                becameKing: false,
              ));
            }
          } else if (target.player != piece.player) {
            if (enemyPos != null) break;
            enemyPos = Point(scanR, scanC);
          } else {
            break;
          }
          scanR += d.x;
          scanC += d.y;
        }
      }
    } else {
      for (final d in directions) {
        final midR = r + d.x;
        final midC = c + d.y;
        final endR = r + (d.x * 2);
        final endC = c + (d.y * 2);

        if (isInBounds(endR, endC)) {
          final midPiece = grid[midR][midC];
          final endPiece = grid[endR][endC];

          if (midPiece != null &&
              midPiece.player != piece.player &&
              endPiece == null) {
            final willBeKing = (piece.player == 1 && endR == 0) ||
                               (piece.player == 2 && endR == size - 1);
            captures.add(DamaMove(
              fromRow: r,
              fromCol: c,
              toRow: endR,
              toCol: endC,
              capturedTiles: [Point(midR, midC)],
              becameKing: willBeKing,
            ));
          }
        }
      }
    }

    return captures;
  }

  List<DamaMove> getLegalMoves(int r, int c) {
    final piece = getPiece(r, c);
    if (piece == null || piece.player != currentTurn) return [];

    if (multiCapturePiece != null) {
      if (multiCapturePiece!.x == r && multiCapturePiece!.y == c) {
        return getCaptureMovesForPiece(r, c);
      }
      return [];
    }

    bool playerHasCaptures = false;
    for (int row = 0; row < size; row++) {
      for (int col = 0; col < size; col++) {
        if (grid[row][col]?.player == currentTurn) {
          if (getCaptureMovesForPiece(row, col).isNotEmpty) {
            playerHasCaptures = true;
            break;
          }
        }
      }
      if (playerHasCaptures) break;
    }

    if (playerHasCaptures) {
      return getCaptureMovesForPiece(r, c);
    }

    final simpleMoves = <DamaMove>[];
    final directions = piece.isKing
        ? const [Point(-1, -1), Point(-1, 1), Point(1, -1), Point(1, 1)]
        : (piece.player == 1
            ? const [Point(-1, -1), Point(-1, 1)]
            : const [Point(1, -1), Point(1, 1)]);

    if (piece.isKing) {
      for (final d in directions) {
        int nr = r + d.x;
        int nc = c + d.y;
        while (isInBounds(nr, nc) && grid[nr][nc] == null) {
          simpleMoves.add(DamaMove(
            fromRow: r,
            fromCol: c,
            toRow: nr,
            toCol: nc,
          ));
          nr += d.x;
          nc += d.y;
        }
      }
    } else {
      for (final d in directions) {
        final nr = r + d.x;
        final nc = c + d.y;
        if (isInBounds(nr, nc) && grid[nr][nc] == null) {
          final willBeKing = (piece.player == 1 && nr == 0) ||
                             (piece.player == 2 && nr == size - 1);
          simpleMoves.add(DamaMove(
            fromRow: r,
            fromCol: c,
            toRow: nr,
            toCol: nc,
            becameKing: willBeKing,
          ));
        }
      }
    }

    return simpleMoves;
  }

  List<DamaMove> getAllLegalMoves(int player) {
    if (multiCapturePiece != null && currentTurn == player) {
      return getCaptureMovesForPiece(multiCapturePiece!.x, multiCapturePiece!.y);
    }

    final moves = <DamaMove>[];
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (grid[r][c]?.player == player) {
          moves.addAll(getLegalMoves(r, c));
        }
      }
    }
    return moves;
  }

  bool makeMove(DamaMove move) {
    if (isGameOver) return false;

    if (!isInBounds(move.fromRow, move.fromCol) || !isInBounds(move.toRow, move.toCol)) {
      return false;
    }

    final piece = grid[move.fromRow][move.fromCol];
    if (piece == null || piece.player != currentTurn) return false;
    if (grid[move.toRow][move.toCol] != null) return false;

    grid[move.fromRow][move.fromCol] = null;

    for (final cap in move.capturedTiles) {
      final removed = grid[cap.x][cap.y];
      if (removed != null) {
        if (removed.player == 2) capturedByP1++;
        if (removed.player == 1) capturedByP2++;
      }
      grid[cap.x][cap.y] = null;
    }

    bool promoted = piece.isKing;
    if (piece.player == 1 && move.toRow == 0) promoted = true;
    if (piece.player == 2 && move.toRow == size - 1) promoted = true;

    final movedPiece = piece.copyWith(isKing: promoted);
    grid[move.toRow][move.toCol] = movedPiece;

    moveHistory.add(DamaMove(
      fromRow: move.fromRow,
      fromCol: move.fromCol,
      toRow: move.toRow,
      toCol: move.toCol,
      capturedTiles: move.capturedTiles,
      becameKing: promoted && !piece.isKing,
    ));

    if (move.isCapture) {
      final chainedCaptures = getCaptureMovesForPiece(move.toRow, move.toCol);
      if (chainedCaptures.isNotEmpty) {
        multiCapturePiece = Point(move.toRow, move.toCol);
        return true;
      }
    }

    multiCapturePiece = null;
    currentTurn = currentTurn == 1 ? 2 : 1;

    if (move.isCapture) {
      consecutiveNonCaptureMoves = 0;
    } else {
      consecutiveNonCaptureMoves++;
    }

    _checkGameOver();

    return true;
  }

  void _checkGameOver() {
    int p1Pieces = 0;
    int p2Pieces = 0;

    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (grid[r][c]?.player == 1) p1Pieces++;
        if (grid[r][c]?.player == 2) p2Pieces++;
      }
    }

    if (p1Pieces == 0) {
      isGameOver = true;
      winner = 2;
      return;
    }
    if (p2Pieces == 0) {
      isGameOver = true;
      winner = 1;
      return;
    }

    final nextMoves = getAllLegalMoves(currentTurn);
    if (nextMoves.isEmpty) {
      isGameOver = true;
      winner = currentTurn == 1 ? 2 : 1;
    }
  }

  DamaBoard._empty() {
    grid = List.generate(size, (_) => List.filled(size, null));
  }

  DamaBoard clone() {
    final copy = DamaBoard._empty();
    copy.currentTurn = currentTurn;
    copy.capturedByP1 = capturedByP1;
    copy.capturedByP2 = capturedByP2;
    copy.isGameOver = isGameOver;
    copy.winner = winner;
    copy.isDraw = isDraw;
    copy.consecutiveNonCaptureMoves = consecutiveNonCaptureMoves;
    copy.multiCapturePiece = multiCapturePiece;
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        final p = grid[r][c];
        if (p != null) {
          copy.grid[r][c] = DamaPiece(player: p.player, isKing: p.isKing);
        }
      }
    }
    return copy;
  }

  bool isRunAndHideDeadlock() {
    if (isGameOver) return false;

    int p1Pieces = 0;
    int p2Pieces = 0;
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        final p = grid[r][c];
        if (p?.player == 1) p1Pieces++;
        if (p?.player == 2) p2Pieces++;
      }
    }

    if (p1Pieces <= 2 && p2Pieces <= 2 && consecutiveNonCaptureMoves >= 10) {
      return true;
    }

    if (consecutiveNonCaptureMoves >= 20) {
      return true;
    }

    return false;
  }

  int evaluateBoard(int forPlayer) {
    if (isGameOver) {
      if (winner == forPlayer) return 100000;
      if (winner != null && winner != forPlayer) return -100000;
      return 0;
    }

    final opponent = forPlayer == 1 ? 2 : 1;
    int score = 0;

    int myPieces = 0;
    int myKings = 0;
    int oppPieces = 0;
    int oppKings = 0;

    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        final p = grid[r][c];
        if (p == null) continue;

        final isMe = p.player == forPlayer;
        final baseVal = p.isKing ? 260 : 100;
        int posVal = 0;

        if ((r == 3 || r == 4) && (c == 3 || c == 4)) {
          posVal += 18;
        } else if ((r >= 2 && r <= 5) && (c >= 2 && c <= 5)) {
          posVal += 10;
        }

        if (c == 0 || c == size - 1) {
          posVal += 10;
        }

        if (!p.isKing) {
          if (p.player == 2) {
            posVal += r * 7;
            if (r == 0) posVal += 35;
          } else {
            posVal += (7 - r) * 7;
            if (r == 7) posVal += 35;
          }
        } else {
          posVal += 25;
        }

        if (isMe) {
          myPieces++;
          if (p.isKing) myKings++;
          score += baseVal + posVal;
        } else {
          oppPieces++;
          if (p.isKing) oppKings++;
          score -= (baseVal + posVal);
        }
      }
    }

    score += (myPieces - oppPieces) * 40;
    score += (myKings - oppKings) * 60;

    final myMoves = getAllLegalMoves(forPlayer).length;
    final oppMoves = getAllLegalMoves(opponent).length;
    score += (myMoves - oppMoves) * 6;

    return score;
  }

  int _minimax({
    required DamaBoard board,
    required int depth,
    required int alpha,
    required int beta,
    required bool isMaximizing,
    required int aiPlayer,
  }) {
    if (depth == 0 || board.isGameOver) {
      return board.evaluateBoard(aiPlayer);
    }

    final currentPlayer = isMaximizing ? aiPlayer : (aiPlayer == 1 ? 2 : 1);
    final legalMoves = board.getAllLegalMoves(currentPlayer);

    if (legalMoves.isEmpty) {
      return isMaximizing ? -100000 + depth : 100000 - depth;
    }

    legalMoves.sort((a, b) {
      if (a.isCapture != b.isCapture) {
        return a.isCapture ? -1 : 1;
      }
      if (a.becameKing != b.becameKing) {
        return a.becameKing ? -1 : 1;
      }
      return 0;
    });

    if (isMaximizing) {
      int maxEval = -999999;
      for (final move in legalMoves) {
        final nextBoard = board.clone();
        nextBoard.makeMove(move);
        while (nextBoard.multiCapturePiece != null && !nextBoard.isGameOver) {
          final chainMoves = nextBoard.getCaptureMovesForPiece(
            nextBoard.multiCapturePiece!.x,
            nextBoard.multiCapturePiece!.y,
          );
          if (chainMoves.isEmpty) break;
          nextBoard.makeMove(chainMoves.first);
        }

        final eval = _minimax(
          board: nextBoard,
          depth: depth - 1,
          alpha: alpha,
          beta: beta,
          isMaximizing: false,
          aiPlayer: aiPlayer,
        );
        maxEval = max(maxEval, eval);
        alpha = max(alpha, eval);
        if (beta <= alpha) break;
      }
      return maxEval;
    } else {
      int minEval = 999999;
      for (final move in legalMoves) {
        final nextBoard = board.clone();
        nextBoard.makeMove(move);
        while (nextBoard.multiCapturePiece != null && !nextBoard.isGameOver) {
          final chainMoves = nextBoard.getCaptureMovesForPiece(
            nextBoard.multiCapturePiece!.x,
            nextBoard.multiCapturePiece!.y,
          );
          if (chainMoves.isEmpty) break;
          nextBoard.makeMove(chainMoves.first);
        }

        final eval = _minimax(
          board: nextBoard,
          depth: depth - 1,
          alpha: alpha,
          beta: beta,
          isMaximizing: true,
          aiPlayer: aiPlayer,
        );
        minEval = min(minEval, eval);
        beta = min(beta, eval);
        if (beta <= alpha) break;
      }
      return minEval;
    }
  }

  DamaMove? getAiMove(DamaDifficulty difficulty) {
    if (isGameOver) return null;

    final legalMoves = getAllLegalMoves(currentTurn);
    if (legalMoves.isEmpty) {
      isGameOver = true;
      winner = currentTurn == 1 ? 2 : 1;
      return null;
    }

    if (difficulty == DamaDifficulty.easy) {
      final captures = legalMoves.where((m) => m.isCapture).toList();
      final pool = captures.isNotEmpty ? captures : legalMoves;
      return pool[Random().nextInt(pool.length)];
    }

    final depth = difficulty == DamaDifficulty.hard ? 4 : 2;

    DamaMove bestMove = legalMoves.first;
    int bestScore = -999999;

    legalMoves.sort((a, b) {
      if (a.isCapture != b.isCapture) return a.isCapture ? -1 : 1;
      if (a.becameKing != b.becameKing) return a.becameKing ? -1 : 1;
      return 0;
    });

    for (final move in legalMoves) {
      final nextBoard = clone();
      nextBoard.makeMove(move);
      while (nextBoard.multiCapturePiece != null && !nextBoard.isGameOver) {
        final chainMoves = nextBoard.getCaptureMovesForPiece(
          nextBoard.multiCapturePiece!.x,
          nextBoard.multiCapturePiece!.y,
        );
        if (chainMoves.isEmpty) break;
        nextBoard.makeMove(chainMoves.first);
      }

      int score = _minimax(
        board: nextBoard,
        depth: depth - 1,
        alpha: -999999,
        beta: 999999,
        isMaximizing: false,
        aiPlayer: currentTurn,
      );

      if (move.isCapture) score += 20;
      if (move.becameKing) score += 25;

      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }

    return bestMove;
  }
}
