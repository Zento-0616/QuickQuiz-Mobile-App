import 'dart:math';

enum ChessMode { pvp, vsAi }
enum ChessDifficulty { easy, medium, hard }
enum ChessPieceType { pawn, knight, bishop, rook, queen, king }

class ChessPiece {
  final int player;
  final ChessPieceType type;
  bool hasMoved;

  ChessPiece({
    required this.player,
    required this.type,
    this.hasMoved = false,
  });

  ChessPiece copyWith({
    int? player,
    ChessPieceType? type,
    bool? hasMoved,
  }) {
    return ChessPiece(
      player: player ?? this.player,
      type: type ?? this.type,
      hasMoved: hasMoved ?? this.hasMoved,
    );
  }

  int get baseValue {
    switch (type) {
      case ChessPieceType.pawn:
        return 100;
      case ChessPieceType.knight:
        return 320;
      case ChessPieceType.bishop:
        return 330;
      case ChessPieceType.rook:
        return 500;
      case ChessPieceType.queen:
        return 900;
      case ChessPieceType.king:
        return 20000;
    }
  }

  String get symbol {
    if (player == 1) {
      switch (type) {
        case ChessPieceType.pawn: return '♙';
        case ChessPieceType.knight: return '♘';
        case ChessPieceType.bishop: return '♗';
        case ChessPieceType.rook: return '♖';
        case ChessPieceType.queen: return '♕';
        case ChessPieceType.king: return '♔';
      }
    } else {
      switch (type) {
        case ChessPieceType.pawn: return '♟';
        case ChessPieceType.knight: return '♞';
        case ChessPieceType.bishop: return '♝';
        case ChessPieceType.rook: return '♜';
        case ChessPieceType.queen: return '♛';
        case ChessPieceType.king: return '♚';
      }
    }
  }
}

class ChessMove {
  final int fromRow;
  final int fromCol;
  final int toRow;
  final int toCol;
  final ChessPieceType? capturedType;
  final bool isCastling;
  final bool isEnPassant;
  final ChessPieceType? promotionType;
  final String notation;

  const ChessMove({
    required this.fromRow,
    required this.fromCol,
    required this.toRow,
    required this.toCol,
    this.capturedType,
    this.isCastling = false,
    this.isEnPassant = false,
    this.promotionType,
    this.notation = '',
  });

  bool get isCapture => capturedType != null || isEnPassant;
}

class ChessBoard {
  static const int size = 8;
  late List<List<ChessPiece?>> grid;
  int currentTurn = 1;
  final List<ChessPiece> capturedByWhite = [];
  final List<ChessPiece> capturedByBlack = [];
  final List<ChessMove> moveHistory = [];
  bool isGameOver = false;
  int? winner;
  bool isDraw = false;
  String? gameOverReason;
  int halfmoveClock = 0;

  Point<int>? enPassantTarget;

  ChessBoard() {
    reset();
  }

  void reset() {
    grid = List.generate(size, (_) => List.filled(size, null));
    currentTurn = 1;
    capturedByWhite.clear();
    capturedByBlack.clear();
    moveHistory.clear();
    isGameOver = false;
    winner = null;
    isDraw = false;
    gameOverReason = null;
    enPassantTarget = null;
    halfmoveClock = 0;

    grid[0][0] = ChessPiece(player: 2, type: ChessPieceType.rook);
    grid[0][1] = ChessPiece(player: 2, type: ChessPieceType.knight);
    grid[0][2] = ChessPiece(player: 2, type: ChessPieceType.bishop);
    grid[0][3] = ChessPiece(player: 2, type: ChessPieceType.queen);
    grid[0][4] = ChessPiece(player: 2, type: ChessPieceType.king);
    grid[0][5] = ChessPiece(player: 2, type: ChessPieceType.bishop);
    grid[0][6] = ChessPiece(player: 2, type: ChessPieceType.knight);
    grid[0][7] = ChessPiece(player: 2, type: ChessPieceType.rook);

    for (int c = 0; c < size; c++) {
      grid[1][c] = ChessPiece(player: 2, type: ChessPieceType.pawn);
    }

    for (int c = 0; c < size; c++) {
      grid[6][c] = ChessPiece(player: 1, type: ChessPieceType.pawn);
    }

    grid[7][0] = ChessPiece(player: 1, type: ChessPieceType.rook);
    grid[7][1] = ChessPiece(player: 1, type: ChessPieceType.knight);
    grid[7][2] = ChessPiece(player: 1, type: ChessPieceType.bishop);
    grid[7][3] = ChessPiece(player: 1, type: ChessPieceType.queen);
    grid[7][4] = ChessPiece(player: 1, type: ChessPieceType.king);
    grid[7][5] = ChessPiece(player: 1, type: ChessPieceType.bishop);
    grid[7][6] = ChessPiece(player: 1, type: ChessPieceType.knight);
    grid[7][7] = ChessPiece(player: 1, type: ChessPieceType.rook);
  }

  ChessBoard clone() {
    final b = ChessBoard();
    b.currentTurn = currentTurn;
    b.isGameOver = isGameOver;
    b.winner = winner;
    b.isDraw = isDraw;
    b.gameOverReason = gameOverReason;
    b.enPassantTarget = enPassantTarget;

    b.halfmoveClock = halfmoveClock;

    b.grid = List.generate(size, (r) => List.generate(size, (c) {
      final p = grid[r][c];
      return p?.copyWith();
    }));

    b.capturedByWhite.clear();
    b.capturedByWhite.addAll(capturedByWhite.map((p) => p.copyWith()));

    b.capturedByBlack.clear();
    b.capturedByBlack.addAll(capturedByBlack.map((p) => p.copyWith()));

    b.moveHistory.clear();
    b.moveHistory.addAll(moveHistory);

    return b;
  }

  bool isInBounds(int r, int c) => r >= 0 && r < size && c >= 0 && c < size;

  ChessPiece? getPiece(int r, int c) {
    if (!isInBounds(r, c)) return null;
    return grid[r][c];
  }

  Point<int>? findKing(int player) {
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        final p = grid[r][c];
        if (p != null && p.player == player && p.type == ChessPieceType.king) {
          return Point(r, c);
        }
      }
    }
    return null;
  }

  List<ChessMove> getPseudoLegalMoves(int r, int c) {
    final piece = getPiece(r, c);
    if (piece == null) return [];

    final moves = <ChessMove>[];
    final oppPlayer = piece.player == 1 ? 2 : 1;

    switch (piece.type) {
      case ChessPieceType.pawn:
        final forward = piece.player == 1 ? -1 : 1;
        final startRow = piece.player == 1 ? 6 : 1;
        final promoRow = piece.player == 1 ? 0 : 7;

        final oneR = r + forward;
        if (isInBounds(oneR, c) && grid[oneR][c] == null) {
          if (oneR == promoRow) {
            for (final promo in [ChessPieceType.queen, ChessPieceType.rook, ChessPieceType.bishop, ChessPieceType.knight]) {
              moves.add(ChessMove(fromRow: r, fromCol: c, toRow: oneR, toCol: c, promotionType: promo));
            }
          } else {
            moves.add(ChessMove(fromRow: r, fromCol: c, toRow: oneR, toCol: c));
          }

          final twoR = r + (forward * 2);
          if (r == startRow && isInBounds(twoR, c) && grid[twoR][c] == null) {
            moves.add(ChessMove(fromRow: r, fromCol: c, toRow: twoR, toCol: c));
          }
        }

        for (final dc in [-1, 1]) {
          final capC = c + dc;
          if (isInBounds(oneR, capC)) {
            final target = grid[oneR][capC];
            if (target != null && target.player == oppPlayer) {
              if (oneR == promoRow) {
                for (final promo in [ChessPieceType.queen, ChessPieceType.rook, ChessPieceType.bishop, ChessPieceType.knight]) {
                  moves.add(ChessMove(fromRow: r, fromCol: c, toRow: oneR, toCol: capC, capturedType: target.type, promotionType: promo));
                }
              } else {
                moves.add(ChessMove(fromRow: r, fromCol: c, toRow: oneR, toCol: capC, capturedType: target.type));
              }
            } else if (enPassantTarget != null && enPassantTarget!.x == oneR && enPassantTarget!.y == capC) {
              moves.add(ChessMove(fromRow: r, fromCol: c, toRow: oneR, toCol: capC, isEnPassant: true, capturedType: ChessPieceType.pawn));
            }
          }
        }
        break;

      case ChessPieceType.knight:
        const knightDeltas = [
          Point(-2, -1), Point(-2, 1), Point(-1, -2), Point(-1, 2),
          Point(1, -2), Point(1, 2), Point(2, -1), Point(2, 1),
        ];
        for (final d in knightDeltas) {
          final nr = r + d.x;
          final nc = c + d.y;
          if (isInBounds(nr, nc)) {
            final target = grid[nr][nc];
            if (target == null) {
              moves.add(ChessMove(fromRow: r, fromCol: c, toRow: nr, toCol: nc));
            } else if (target.player == oppPlayer) {
              moves.add(ChessMove(fromRow: r, fromCol: c, toRow: nr, toCol: nc, capturedType: target.type));
            }
          }
        }
        break;

      case ChessPieceType.bishop:
        _addRayMoves(moves, r, c, oppPlayer, const [Point(-1, -1), Point(-1, 1), Point(1, -1), Point(1, 1)]);
        break;

      case ChessPieceType.rook:
        _addRayMoves(moves, r, c, oppPlayer, const [Point(-1, 0), Point(1, 0), Point(0, -1), Point(0, 1)]);
        break;

      case ChessPieceType.queen:
        _addRayMoves(moves, r, c, oppPlayer, const [
          Point(-1, -1), Point(-1, 1), Point(1, -1), Point(1, 1),
          Point(-1, 0), Point(1, 0), Point(0, -1), Point(0, 1),
        ]);
        break;

      case ChessPieceType.king:
        const kingDeltas = [
          Point(-1, -1), Point(-1, 0), Point(-1, 1),
          Point(0, -1), Point(0, 1),
          Point(1, -1), Point(1, 0), Point(1, 1),
        ];
        for (final d in kingDeltas) {
          final nr = r + d.x;
          final nc = c + d.y;
          if (isInBounds(nr, nc)) {
            final target = grid[nr][nc];
            if (target == null) {
              moves.add(ChessMove(fromRow: r, fromCol: c, toRow: nr, toCol: nc));
            } else if (target.player == oppPlayer) {
              moves.add(ChessMove(fromRow: r, fromCol: c, toRow: nr, toCol: nc, capturedType: target.type));
            }
          }
        }

        if (!piece.hasMoved && !isKingInCheck(piece.player)) {
          final kRook = grid[r][7];
          if (kRook != null && kRook.type == ChessPieceType.rook && !kRook.hasMoved) {
            if (grid[r][5] == null && grid[r][6] == null) {
              if (!isSquareAttacked(r, 5, oppPlayer) && !isSquareAttacked(r, 6, oppPlayer)) {
                moves.add(ChessMove(fromRow: r, fromCol: c, toRow: r, toCol: 6, isCastling: true));
              }
            }
          }
          final qRook = grid[r][0];
          if (qRook != null && qRook.type == ChessPieceType.rook && !qRook.hasMoved) {
            if (grid[r][1] == null && grid[r][2] == null && grid[r][3] == null) {
              if (!isSquareAttacked(r, 3, oppPlayer) && !isSquareAttacked(r, 2, oppPlayer)) {
                moves.add(ChessMove(fromRow: r, fromCol: c, toRow: r, toCol: 2, isCastling: true));
              }
            }
          }
        }
        break;
    }

    return moves;
  }

  void _addRayMoves(List<ChessMove> moves, int r, int c, int oppPlayer, List<Point<int>> directions) {
    for (final d in directions) {
      int nr = r + d.x;
      int nc = c + d.y;
      while (isInBounds(nr, nc)) {
        final target = grid[nr][nc];
        if (target == null) {
          moves.add(ChessMove(fromRow: r, fromCol: c, toRow: nr, toCol: nc));
        } else {
          if (target.player == oppPlayer) {
            moves.add(ChessMove(fromRow: r, fromCol: c, toRow: nr, toCol: nc, capturedType: target.type));
          }
          break;
        }
        nr += d.x;
        nc += d.y;
      }
    }
  }

  bool isSquareAttacked(int r, int c, int byPlayer) {
    final pawnForward = byPlayer == 1 ? -1 : 1;
    final pawnOriginRow = r - pawnForward;
    for (final dc in [-1, 1]) {
      final capC = c + dc;
      if (isInBounds(pawnOriginRow, capC)) {
        final p = grid[pawnOriginRow][capC];
        if (p != null && p.player == byPlayer && p.type == ChessPieceType.pawn) {
          return true;
        }
      }
    }

    const knightDeltas = [
      Point(-2, -1), Point(-2, 1), Point(-1, -2), Point(-1, 2),
      Point(1, -2), Point(1, 2), Point(2, -1), Point(2, 1),
    ];
    for (final d in knightDeltas) {
      final nr = r + d.x;
      final nc = c + d.y;
      if (isInBounds(nr, nc)) {
        final p = grid[nr][nc];
        if (p != null && p.player == byPlayer && p.type == ChessPieceType.knight) {
          return true;
        }
      }
    }

    const diagDirs = [Point(-1, -1), Point(-1, 1), Point(1, -1), Point(1, 1)];
    for (final d in diagDirs) {
      int nr = r + d.x;
      int nc = c + d.y;
      while (isInBounds(nr, nc)) {
        final p = grid[nr][nc];
        if (p != null) {
          if (p.player == byPlayer && (p.type == ChessPieceType.bishop || p.type == ChessPieceType.queen)) {
            return true;
          }
          break;
        }
        nr += d.x;
        nc += d.y;
      }
    }

    const orthoDirs = [Point(-1, 0), Point(1, 0), Point(0, -1), Point(0, 1)];
    for (final d in orthoDirs) {
      int nr = r + d.x;
      int nc = c + d.y;
      while (isInBounds(nr, nc)) {
        final p = grid[nr][nc];
        if (p != null) {
          if (p.player == byPlayer && (p.type == ChessPieceType.rook || p.type == ChessPieceType.queen)) {
            return true;
          }
          break;
        }
        nr += d.x;
        nc += d.y;
      }
    }

    const kingDeltas = [
      Point(-1, -1), Point(-1, 0), Point(-1, 1),
      Point(0, -1), Point(0, 1),
      Point(1, -1), Point(1, 0), Point(1, 1),
    ];
    for (final d in kingDeltas) {
      final nr = r + d.x;
      final nc = c + d.y;
      if (isInBounds(nr, nc)) {
        final p = grid[nr][nc];
        if (p != null && p.player == byPlayer && p.type == ChessPieceType.king) {
          return true;
        }
      }
    }

    return false;
  }

  bool isKingInCheck(int player) {
    final kingPos = findKing(player);
    if (kingPos == null) return true;
    final oppPlayer = player == 1 ? 2 : 1;
    return isSquareAttacked(kingPos.x, kingPos.y, oppPlayer);
  }

  List<ChessMove> getLegalMoves(int r, int c) {
    final piece = getPiece(r, c);
    if (piece == null || piece.player != currentTurn) return [];

    final pseudo = getPseudoLegalMoves(r, c);
    final legal = <ChessMove>[];

    for (final move in pseudo) {
      final sim = clone();
      sim.applyMoveSim(move);
      if (!sim.isKingInCheck(piece.player)) {
        legal.add(move);
      }
    }

    return legal;
  }

  List<ChessMove> getAllLegalMoves(int player) {
    final moves = <ChessMove>[];
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (grid[r][c]?.player == player) {
          moves.addAll(getLegalMoves(r, c));
        }
      }
    }
    return moves;
  }

  void applyMoveSim(ChessMove move) {
    final piece = grid[move.fromRow][move.fromCol]!;
    grid[move.fromRow][move.fromCol] = null;

    if (move.isCastling) {
      if (move.toCol == 6) {
        final rook = grid[move.toRow][7]!;
        grid[move.toRow][7] = null;
        grid[move.toRow][5] = rook;
      } else if (move.toCol == 2) {
        final rook = grid[move.toRow][0]!;
        grid[move.toRow][0] = null;
        grid[move.toRow][3] = rook;
      }
    } else if (move.isEnPassant) {
      final capturedPawnRow = move.fromRow;
      grid[capturedPawnRow][move.toCol] = null;
    }

    if (move.promotionType != null) {
      grid[move.toRow][move.toCol] = ChessPiece(player: piece.player, type: move.promotionType!, hasMoved: true);
    } else {
      grid[move.toRow][move.toCol] = piece.copyWith(hasMoved: true);
    }
  }

  bool makeMove(ChessMove move) {
    if (isGameOver) return false;

    final piece = grid[move.fromRow][move.fromCol];
    if (piece == null || piece.player != currentTurn) return false;

    grid[move.fromRow][move.fromCol] = null;

    if (move.isEnPassant) {
      final capRow = move.fromRow;
      final capPiece = grid[capRow][move.toCol];
      if (capPiece != null) {
        if (currentTurn == 1) {
          capturedByWhite.add(capPiece);
        } else {
          capturedByBlack.add(capPiece);
        }
        grid[capRow][move.toCol] = null;
      }
    } else {
      final target = grid[move.toRow][move.toCol];
      if (target != null) {
        if (currentTurn == 1) {
          capturedByWhite.add(target);
        } else {
          capturedByBlack.add(target);
        }
      }
    }

    if (move.isCastling) {
      if (move.toCol == 6) {
        final rook = grid[move.toRow][7];
        if (rook != null) {
          grid[move.toRow][7] = null;
          grid[move.toRow][5] = rook.copyWith(hasMoved: true);
        }
      } else if (move.toCol == 2) {
        final rook = grid[move.toRow][0];
        if (rook != null) {
          grid[move.toRow][0] = null;
          grid[move.toRow][3] = rook.copyWith(hasMoved: true);
        }
      }
    }

    if (move.promotionType != null) {
      grid[move.toRow][move.toCol] = ChessPiece(
        player: piece.player,
        type: move.promotionType!,
        hasMoved: true,
      );
    } else {
      grid[move.toRow][move.toCol] = piece.copyWith(hasMoved: true);
    }

    if (piece.type == ChessPieceType.pawn && (move.toRow - move.fromRow).abs() == 2) {
      enPassantTarget = Point((move.fromRow + move.toRow) ~/ 2, move.fromCol);
    } else {
      enPassantTarget = null;
    }

    moveHistory.add(move);

    if (piece.type == ChessPieceType.pawn || move.isCapture) {
      halfmoveClock = 0;
    } else {
      halfmoveClock++;
    }

    currentTurn = currentTurn == 1 ? 2 : 1;

    final oppMoves = getAllLegalMoves(currentTurn);
    if (oppMoves.isEmpty) {
      isGameOver = true;
      if (isKingInCheck(currentTurn)) {
        winner = currentTurn == 1 ? 2 : 1;
        gameOverReason = 'Checkmate! ${winner == 1 ? "White" : "Black"} wins.';
      } else {
        isDraw = true;
        winner = null;
        gameOverReason = 'Draw by Stalemate.';
      }
    }

    return true;
  }

  bool isInsufficientMaterial() {
    final activePieces = <ChessPiece>[];
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        final p = grid[r][c];
        if (p != null) activePieces.add(p);
      }
    }
    if (activePieces.length == 2) {
      return activePieces.every((p) => p.type == ChessPieceType.king);
    }
    if (activePieces.length == 3) {
      final nonKings = activePieces.where((p) => p.type != ChessPieceType.king).toList();
      if (nonKings.length == 1) {
        final t = nonKings.first.type;
        return t == ChessPieceType.knight || t == ChessPieceType.bishop;
      }
    }
    return false;
  }

  bool isDeadlockOrRunAndHide() {
    if (isGameOver) return false;
    if (isInsufficientMaterial()) return true;
    if (halfmoveClock >= 30) return true;
    return false;
  }

  int evaluateBoard(int forPlayer) {
    if (isGameOver) {
      if (winner == forPlayer) return 100000;
      if (winner != null && winner != forPlayer) return -100000;
      return 0;
    }

    int score = 0;
    final oppPlayer = forPlayer == 1 ? 2 : 1;

    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        final p = grid[r][c];
        if (p == null) continue;

        int val = p.baseValue;

        if ((r == 3 || r == 4) && (c == 3 || c == 4)) {
          val += 25;
        } else if ((r >= 2 && r <= 5) && (c >= 2 && c <= 5)) {
          val += 12;
        }

        if (p.type == ChessPieceType.pawn) {
          final adv = p.player == 1 ? (6 - r) : (r - 1);
          val += adv * 8;
        }

        if (p.type == ChessPieceType.knight) {
          if (c == 0 || c == 7 || r == 0 || r == 7) {
            val -= 15;
          }
        }

        if (p.player == forPlayer) {
          score += val;
        } else {
          score -= val;
        }
      }
    }

    final myMoves = getAllLegalMoves(forPlayer).length;
    final oppMoves = getAllLegalMoves(oppPlayer).length;
    score += (myMoves - oppMoves) * 4;

    return score;
  }

  int _minimax({
    required ChessBoard board,
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
      if (board.isKingInCheck(currentPlayer)) {
        return isMaximizing ? -100000 + depth : 100000 - depth;
      }
      return 0;
    }

    legalMoves.sort((a, b) {
      if (a.isCapture != b.isCapture) return a.isCapture ? -1 : 1;
      if (a.promotionType != null && b.promotionType == null) return -1;
      return 0;
    });

    if (isMaximizing) {
      int maxEval = -999999;
      for (final move in legalMoves) {
        final nextBoard = board.clone();
        nextBoard.makeMove(move);
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

  ChessMove? getAiMove(ChessDifficulty difficulty) {
    if (isGameOver) return null;

    final legalMoves = getAllLegalMoves(currentTurn);
    if (legalMoves.isEmpty) return null;

    if (difficulty == ChessDifficulty.easy) {
      final captures = legalMoves.where((m) => m.isCapture).toList();
      final pool = captures.isNotEmpty && Random().nextBool() ? captures : legalMoves;
      return pool[Random().nextInt(pool.length)];
    }

    final depth = difficulty == ChessDifficulty.hard ? 3 : 2;

    legalMoves.sort((a, b) {
      if (a.isCapture != b.isCapture) return a.isCapture ? -1 : 1;
      if (a.promotionType != null && b.promotionType == null) return -1;
      return 0;
    });

    ChessMove bestMove = legalMoves.first;
    int bestScore = -999999;

    for (final move in legalMoves) {
      final nextBoard = clone();
      nextBoard.makeMove(move);
      final score = _minimax(
        board: nextBoard,
        depth: depth - 1,
        alpha: -999999,
        beta: 999999,
        isMaximizing: false,
        aiPlayer: currentTurn,
      );

      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }

    return bestMove;
  }
}
