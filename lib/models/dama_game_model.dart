import 'dart:math';

enum DamaMode { pvp, vsAi }
enum DamaDifficulty { easy, medium, hard }

class DamaPiece {
  final int player; // 1: Player 1 (Blue/Cyan), 2: Player 2 (Rose/Red)
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
  int currentTurn = 1; // 1: Player 1, 2: Player 2
  int capturedByP1 = 0;
  int capturedByP2 = 0;
  bool isGameOver = false;
  int? winner; // 1, 2, or null
  bool isDraw = false;
  int consecutiveNonCaptureMoves = 0;
  final List<DamaMove> moveHistory = [];

  /// Tracks the active piece mid-combo during consecutive chained captures
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

    // Player 2 (Rose/Red) at top (rows 0, 1, 2) on dark squares
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < size; c++) {
        if ((r + c) % 2 == 1) {
          grid[r][c] = DamaPiece(player: 2);
        }
      }
    }

    // Player 1 (Blue/Cyan) at bottom (rows 5, 6, 7) on dark squares
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

  /// Calculates all atomic capture jumps possible from [r, c]
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
      // Flying King: slides diagonally, jumps over 1 enemy piece into any empty tile behind
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
            if (enemyPos != null) break; // Cannot jump over multiple pieces in single hop
            enemyPos = Point(scanR, scanC);
          } else {
            // Blocked by friendly piece
            break;
          }
          scanR += d.x;
          scanC += d.y;
        }
      }
    } else {
      // Regular piece: 1 diagonal jump over enemy to adjacent empty square
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

  /// Returns legal moves for piece at [r, c] adhering to dama rules:
  /// - If mid-chain capture is active, only the active piece may move and must capture.
  /// - Mandatory capture: If any capture exists on the board, non-capture moves are disallowed.
  List<DamaMove> getLegalMoves(int r, int c) {
    final piece = getPiece(r, c);
    if (piece == null || piece.player != currentTurn) return [];

    // 1. If mid-chain jump is active, only the active piece can move
    if (multiCapturePiece != null) {
      if (multiCapturePiece!.x == r && multiCapturePiece!.y == c) {
        return getCaptureMovesForPiece(r, c);
      }
      return [];
    }

    // 2. Mandatory capture check: does any piece of current player have captures?
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
      // Must capture!
      return getCaptureMovesForPiece(r, c);
    }

    // 3. Regular non-capture moves
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

  /// Returns all legal moves available for the specified player
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

  /// Executes an atomic move on the board.
  /// Updates captured count, handles King promotion, checks consecutive chained captures,
  /// and switches turn or declares game over.
  bool makeMove(DamaMove move) {
    if (isGameOver) return false;

    if (!isInBounds(move.fromRow, move.fromCol) || !isInBounds(move.toRow, move.toCol)) {
      return false;
    }

    final piece = grid[move.fromRow][move.fromCol];
    if (piece == null || piece.player != currentTurn) return false;
    if (grid[move.toRow][move.toCol] != null) return false;

    // Remove piece from origin
    grid[move.fromRow][move.fromCol] = null;

    // Remove captured pieces & increment score
    for (final cap in move.capturedTiles) {
      final removed = grid[cap.x][cap.y];
      if (removed != null) {
        if (removed.player == 2) capturedByP1++;
        if (removed.player == 1) capturedByP2++;
      }
      grid[cap.x][cap.y] = null;
    }

    // King promotion check
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

    // Multi-jump consecutive capture logic:
    // If this move was a capture, check if the piece at (toRow, toCol) has further captures
    if (move.isCapture) {
      final chainedCaptures = getCaptureMovesForPiece(move.toRow, move.toCol);
      if (chainedCaptures.isNotEmpty) {
        // Continue chained capturing sequence
        multiCapturePiece = Point(move.toRow, move.toCol);
        // Do NOT switch turn yet!
        return true;
      }
    }

    // Turn complete: clear chained piece and switch turn
    multiCapturePiece = null;
    currentTurn = currentTurn == 1 ? 2 : 1;

    // Track consecutive non-capture moves for run-and-hide deadlock detection
    if (move.isCapture) {
      consecutiveNonCaptureMoves = 0;
    } else {
      consecutiveNonCaptureMoves++;
    }

    // Check game over
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

  /// Detects if the game has reached an impossible-to-beat or evasive deadlock
  /// ("run and hide" loop where pieces evade without any captures).
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

    // When both sides have reduced forces (<= 2 pieces each) and no captures for 10 moves
    if (p1Pieces <= 2 && p2Pieces <= 2 && consecutiveNonCaptureMoves >= 10) {
      return true;
    }

    // 20 consecutive moves without any capture at all (evasive stalemate)
    if (consecutiveNonCaptureMoves >= 20) {
      return true;
    }

    return false;
  }

  /// Evaluates board position from the perspective of [forPlayer].
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

        // Center dominance
        if ((r == 3 || r == 4) && (c == 3 || c == 4)) {
          posVal += 18;
        } else if ((r >= 2 && r <= 5) && (c >= 2 && c <= 5)) {
          posVal += 10;
        }

        // Edge protection (pieces on border cannot be flanked/jumped from outer edge)
        if (c == 0 || c == size - 1) {
          posVal += 10;
        }

        // Row advancement for normal pieces
        if (!p.isKing) {
          if (p.player == 2) {
            // Player 2 advances downwards towards row 7
            posVal += r * 7;
            // Guard back row (row 0) to block P1 promotions
            if (r == 0) posVal += 35;
          } else {
            // Player 1 advances upwards towards row 0
            posVal += (7 - r) * 7;
            // Guard back row (row 7) to block P2 promotions
            if (r == 7) posVal += 35;
          }
        } else {
          // Kings are highly active
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

    // Material differential multiplier
    score += (myPieces - oppPieces) * 40;
    score += (myKings - oppKings) * 60;

    // Mobility difference
    final myMoves = getAllLegalMoves(forPlayer).length;
    final oppMoves = getAllLegalMoves(opponent).length;
    score += (myMoves - oppMoves) * 6;

    return score;
  }

  /// Minimax search with Alpha-Beta pruning for tactical lookahead
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

    // Move ordering heuristic: search captures first for higher alpha-beta pruning cutoffs
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
        if (beta <= alpha) break; // Alpha-beta cutoff
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
        if (beta <= alpha) break; // Alpha-beta cutoff
      }
      return minEval;
    }
  }

  /// AI move evaluation for vs AI mode:
  /// - Easy: Casual random moves with capture priority
  /// - Medium: 2-ply tactical lookahead
  /// - Hard (Grandmaster): 4-ply Minimax with Alpha-Beta pruning, king defense, and multi-jump lookahead
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

    // Depth 4 for Grandmaster (Hard), Depth 2 for Scholar (Medium)
    final depth = difficulty == DamaDifficulty.hard ? 4 : 2;

    DamaMove bestMove = legalMoves.first;
    int bestScore = -999999;

    // Move ordering
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

      // Add tactical bonuses
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
