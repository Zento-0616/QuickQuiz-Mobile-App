import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../models/chess_game_model.dart';
import '../../models/user_model.dart';
import '../../services/game_session_service.dart';
import '../../services/head_to_head_service.dart';
import '../../services/reward_effect_service.dart';
import '../../services/social_service.dart';
import '../../utils/toast_helper.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/sign_in_required_dialog.dart';

class ChessGameView extends StatefulWidget {
  const ChessGameView({super.key});

  @override
  State<ChessGameView> createState() => _ChessGameViewState();
}

class _ChessGameViewState extends State<ChessGameView> with SingleTickerProviderStateMixin {
  final ChessBoard _board = ChessBoard();
  ChessMode _gameMode = ChessMode.vsAi;
  ChessDifficulty _aiDifficulty = ChessDifficulty.medium;

  // Head-to-Head win/loss record
  HeadToHeadRecord? _h2hRecord;

  // Lobby State
  bool _hasGameStarted = false;
  int _pvpSubMode = 0; // 0 = Find Online Match, 1 = Invite Scholar, 2 = Pass & Play
  bool _isSearchingMatch = false;
  UserModel? _matchedScholar;
  List<UserModel> _availableScholars = [];
  String _scholarSearchQuery = '';

  Point<int>? _selectedTile;
  List<ChessMove> _currentLegalMoves = [];
  bool _isAiThinking = false;
  String? _statusBannerText;
  bool _hasPromptedDeadlock = false;
  int _deadlockCooldownMoveCount = 0;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthViewModel>();
      if (auth.isGuest) {
        showSignInRequiredDialog(context);
        if (mounted) context.pop();
        return;
      }
      _loadCommunityScholars();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadCommunityScholars() async {
    try {
      final user = context.read<AuthViewModel>().currentUser;
      final scholars = await SocialService().getActiveCommunityScholars(
        limit: 25,
        excludeUserId: user?.uid,
      );
      if (mounted) {
        setState(() => _availableScholars = scholars);
      }
    } catch (_) {}
  }

  Future<void> _loadHeadToHead() async {
    final auth = context.read<AuthViewModel>();
    final user = auth.currentUser;
    if (user == null) return;

    final String oppUid;
    final String oppName;

    if (_gameMode == ChessMode.vsAi) {
      oppUid = 'chess_ai_${_aiDifficulty.name}';
      oppName = 'AI Bot (${_aiDifficulty.name.toUpperCase()})';
    } else {
      oppUid = _matchedScholar?.uid ?? 'guest_chess_player';
      oppName = _matchedScholar?.effectiveNickname ?? 'Player 2';
    }

    try {
      final record = await HeadToHeadService().getRecord(
        userId: user.uid,
        opponentId: oppUid,
        opponentName: oppName,
      );
      if (mounted) setState(() => _h2hRecord = record);
    } catch (_) {}
  }

  Future<void> _triggerOnlineMatchmaking() async {
    final auth = context.read<AuthViewModel>();
    final user = auth.currentUser;
    if (user == null || user.isGuest) {
      showSignInRequiredDialog(context);
      return;
    }

    setState(() {
      _isSearchingMatch = true;
      _matchedScholar = null;
    });

    try {
      final instantMatch = await GameSessionService().enterMatchmaking(
        user: user,
        gameType: 'chess',
      );

      if (instantMatch != null) {
        setState(() {
          _isSearchingMatch = false;
          _matchedScholar = UserModel(
            uid: instantMatch.hostId,
            name: instantMatch.hostName,
            email: '',
            nickname: instantMatch.hostName,
            photoUrl: instantMatch.hostAvatar,
            level: instantMatch.hostLevel,
            createdAt: DateTime.now(),
          );
        });
        _startGame();
        if (mounted) {
          showSuccessToast(context, '🎯 Matched with ${instantMatch.hostName}!');
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isSearchingMatch = true;
        });
        showInfoToast(context, 'In matchmaking queue... Waiting for another player searching for chess.');
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSearchingMatch = false;
        });
      }
    }
  }

  Future<void> _handleBackOrQuit() async {
    if (!_hasGameStarted || _board.isGameOver) {
      setState(() => _hasGameStarted = false);
      return;
    }

    final shouldQuit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Leave Match?',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Text(
          'Your chess match is currently in progress. Quitting will count as a forfeit loss.\n\nDo you want to quit or continue playing?',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Continue Playing', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(dialogCtx, false),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Quit & Forfeit', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(dialogCtx, true),
          ),
        ],
      ),
    );

    if (shouldQuit != true || !mounted) return;

    final auth = context.read<AuthViewModel>();
    final user = auth.currentUser;
    if (user != null) {
      final oppUid = _gameMode == ChessMode.vsAi
          ? 'chess_ai_${_aiDifficulty.name}'
          : (_matchedScholar?.uid ?? 'guest_chess_player');
      final oppName = _gameMode == ChessMode.vsAi
          ? 'AI Bot (${_aiDifficulty.name.toUpperCase()})'
          : (_matchedScholar?.effectiveNickname ?? 'Player 2');

      HeadToHeadService().recordMatchOutcome(
        userId: user.uid,
        opponentId: oppUid,
        opponentName: oppName,
        isWin: false,
        isDraw: false,
      ).then((rec) {
        if (mounted) setState(() => _h2hRecord = rec);
      });
    }
    setState(() {
      _hasGameStarted = false;
      _board.reset();
    });
    showWarningToast(context, 'You quit and forfeited the match.');
  }

  void _startGame() {
    setState(() {
      _board.reset();
      _selectedTile = null;
      _currentLegalMoves = [];
      _hasGameStarted = true;
      _statusBannerText = null;
    });
    _loadHeadToHead();
  }

  void _onTileTap(int r, int c) {
    if (_board.isGameOver || _isAiThinking) return;

    final isSimulatedOpponent = _gameMode == ChessMode.vsAi || (_gameMode == ChessMode.pvp && _pvpSubMode != 2);

    // If waiting for opponent turn in simulated/AI modes
    if (isSimulatedOpponent && _board.currentTurn != 1) return;

    // Check if tapped a legal move for selected tile
    final matchedMove = _currentLegalMoves.firstWhere(
      (m) => m.toRow == r && m.toCol == c,
      orElse: () => const ChessMove(fromRow: -1, fromCol: -1, toRow: -1, toCol: -1),
    );

    if (matchedMove.fromRow != -1) {
      // Check if move requires pawn promotion selection
      final piece = _board.getPiece(matchedMove.fromRow, matchedMove.fromCol);
      final isPromoRow = (piece?.player == 1 && r == 0) || (piece?.player == 2 && r == 7);
      if (piece?.type == ChessPieceType.pawn && isPromoRow) {
        _showPromotionDialog(matchedMove);
      } else {
        _executeMove(matchedMove);
      }
      return;
    }

    // Select piece if it belongs to current player
    final piece = _board.getPiece(r, c);
    if (piece != null && piece.player == _board.currentTurn) {
      setState(() {
        _selectedTile = Point(r, c);
        _currentLegalMoves = _board.getLegalMoves(r, c);
      });
    } else {
      setState(() {
        _selectedTile = null;
        _currentLegalMoves = [];
      });
    }
  }

  void _showPromotionDialog(ChessMove baseMove) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
        ),
        title: const Row(
          children: [
            Icon(Icons.military_tech_rounded, color: Colors.amber, size: 24),
            SizedBox(width: 8),
            Text('Pawn Promotion', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select a piece to promote your pawn:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPromoCard(ctx, baseMove, ChessPieceType.queen, '♕', 'Queen', '9 pts', const Color(0xFF818CF8)),
                _buildPromoCard(ctx, baseMove, ChessPieceType.rook, '♖', 'Rook', '5 pts', const Color(0xFF38BDF8)),
                _buildPromoCard(ctx, baseMove, ChessPieceType.bishop, '♗', 'Bishop', '3 pts', const Color(0xFF34D399)),
                _buildPromoCard(ctx, baseMove, ChessPieceType.knight, '♘', 'Knight', '3 pts', const Color(0xFFFBBF24)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoCard(
    BuildContext ctx,
    ChessMove baseMove,
    ChessPieceType type,
    String symbol,
    String label,
    String pts,
    Color accent,
  ) {
    return InkWell(
      onTap: () {
        Navigator.pop(ctx);
        final promoMove = ChessMove(
          fromRow: baseMove.fromRow,
          fromCol: baseMove.fromCol,
          toRow: baseMove.toRow,
          toCol: baseMove.toCol,
          capturedType: baseMove.capturedType,
          promotionType: type,
        );
        _executeMove(promoMove);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.2),
        ),
        child: Column(
          children: [
            Text(symbol, style: TextStyle(fontSize: 28, color: accent)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
            Text(pts, style: TextStyle(color: accent, fontSize: 9.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  void _executeMove(ChessMove move) {
    setState(() {
      _board.makeMove(move);
      _selectedTile = null;
      _currentLegalMoves = [];
    });

    if (_board.isGameOver) {
      _handleGameOver();
      return;
    }

    if (_board.isKingInCheck(_board.currentTurn)) {
      setState(() {
        _statusBannerText = '⚠️ CHECK! ${_board.currentTurn == 1 ? "White" : "Black"} King under attack!';
      });
    } else {
      setState(() => _statusBannerText = null);
    }

    // Deadlock / "Run & Hide" impossible to beat check
    if (!_board.isGameOver &&
        _board.isDeadlockOrRunAndHide() &&
        (!_hasPromptedDeadlock || _board.moveHistory.length >= _deadlockCooldownMoveCount)) {
      _hasPromptedDeadlock = true;
      _deadlockCooldownMoveCount = _board.moveHistory.length + 14;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_board.isGameOver) {
          _showDeadlockDrawDialog();
        }
      });
    }

    // Trigger AI / Simulated Opponent Turn if needed
    final isSimulatedOpponent = _gameMode == ChessMode.vsAi || (_gameMode == ChessMode.pvp && _pvpSubMode != 2);
    if (isSimulatedOpponent && _board.currentTurn == 2 && !_board.isGameOver) {
      _triggerAiTurn();
    }
  }

  void _triggerAiTurn() {
    setState(() => _isAiThinking = true);

    final difficulty = _effectiveOpponentDifficulty;

    Timer(const Duration(milliseconds: 650), () {
      if (!mounted || _board.isGameOver) return;

      final aiMove = _board.getAiMove(difficulty);
      if (aiMove != null) {
        _executeMove(aiMove);
      }

      if (mounted) {
        setState(() => _isAiThinking = false);
      }
    });
  }

  void _showDeadlockDrawDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.handshake_outlined, color: Color(0xFF38BDF8), size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Draw or Continue?',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unbeatable Loop Detected ("Run & Hide")',
              style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13),
            ),
            SizedBox(height: 8),
            Text(
              'The match has reached an evasive deadlock with no material progress or captures. Would you like to declare a peaceful draw or continue playing?',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Continue Playing', style: TextStyle(color: Colors.white60, fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Declare Draw', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _board.isGameOver = true;
                _board.isDraw = true;
                _board.gameOverReason = 'Match drawn by mutual agreement (run & hide deadlock).';
              });
              _handleGameOver();
            },
          ),
        ],
      ),
    );
  }

  ChessDifficulty get _effectiveOpponentDifficulty {
    if (_gameMode == ChessMode.vsAi) return _aiDifficulty;
    if (_matchedScholar != null) {
      if (_matchedScholar!.level >= 10) return ChessDifficulty.hard;
      if (_matchedScholar!.level >= 4) return ChessDifficulty.medium;
      return ChessDifficulty.easy;
    }
    return ChessDifficulty.medium;
  }

  void _handleGameOver() {
    final didWin = _board.winner == 1;
    final isDraw = _board.isDraw;

    final auth = context.read<AuthViewModel>();
    final user = auth.currentUser;
    if (user != null) {
      final oppUid = _gameMode == ChessMode.vsAi
          ? 'chess_ai_${_aiDifficulty.name}'
          : (_matchedScholar?.uid ?? 'guest_chess_player');
      final oppName = _gameMode == ChessMode.vsAi
          ? 'AI Bot (${_aiDifficulty.name.toUpperCase()})'
          : (_matchedScholar?.effectiveNickname ?? 'Player 2');

      HeadToHeadService().recordMatchOutcome(
        userId: user.uid,
        opponentId: oppUid,
        opponentName: oppName,
        isWin: didWin,
        isDraw: isDraw,
      ).then((rec) {
        if (mounted) setState(() => _h2hRecord = rec);
      });
    }

    if (didWin) {
      final rewardService = RewardEffectService();
      rewardService.showCelebration(
        context,
        RewardCelebrationPayload(
          id: 'chess_victory_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Checkmate! Grandmaster Victory!',
          rewardText: '+200 EXP',
          subtitle: 'You mastered the 8x8 tactical chess battlefield',
          type: RewardType.xp,
          icon: Icons.military_tech_rounded,
          badgeColor: Colors.amber,
        ),
      );
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: (didWin ? Colors.amber : (isDraw ? const Color(0xFF38BDF8) : Colors.redAccent))
                .withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isDraw ? Colors.blue : (didWin ? Colors.amber : Colors.redAccent)).withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isDraw ? Icons.handshake_rounded : (didWin ? Icons.emoji_events_rounded : Icons.flag_rounded),
                color: isDraw ? Colors.blue : (didWin ? Colors.amber : Colors.redAccent),
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              isDraw ? 'Game Drawn' : (didWin ? 'Victory!' : 'Defeat'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _board.gameOverReason ??
                  (isDraw
                      ? 'Draw by Stalemate.'
                      : (_board.winner == 1 ? 'White won by checkmate!' : 'Black won by checkmate!')),
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Total Moves Played: ${_board.moveHistory.length}',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            if (_h2hRecord != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('LIFETIME HEAD-TO-HEAD SCORE', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)),
                    const SizedBox(height: 3),
                    Text(
                      'You ${_h2hRecord!.wins}  -  ${_h2hRecord!.losses}  ${_h2hRecord!.opponentName}${_h2hRecord!.draws > 0 ? " (${_h2hRecord!.draws} D)" : ""}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _hasGameStarted = false);
            },
            child: const Text('Return to Lobby', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startGame();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Play Again', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  int _calculateMaterialAdvantage(int player) {
    int whiteScore = 0;
    for (final p in _board.capturedByWhite) {
      whiteScore += _piecePointValue(p.type);
    }
    int blackScore = 0;
    for (final p in _board.capturedByBlack) {
      blackScore += _piecePointValue(p.type);
    }
    return player == 1 ? (whiteScore - blackScore) : (blackScore - whiteScore);
  }

  int _piecePointValue(ChessPieceType type) {
    switch (type) {
      case ChessPieceType.pawn:
        return 1;
      case ChessPieceType.knight:
        return 3;
      case ChessPieceType.bishop:
        return 3;
      case ChessPieceType.rook:
        return 5;
      case ChessPieceType.queen:
        return 9;
      case ChessPieceType.king:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasGameStarted || _board.isGameOver,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackOrQuit();
      },
      child: !_hasGameStarted ? _buildLobbyScreen() : _buildChessboardScreen(),
    );
  }

  // ==========================================
  // SCREEN 1: MODERN LOBBY & MATCH SETUP
  // ==========================================
  Widget _buildLobbyScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1120),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.shield_moon_rounded, color: Color(0xFF38BDF8), size: 20),
            SizedBox(width: 8),
            Text('Scholar Chess Arena', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(AppRoutes.games),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Top Hero Banner
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF312E81)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF818CF8).withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt_rounded, color: Color(0xFF38BDF8), size: 14),
                            SizedBox(width: 4),
                            Text('CHESS ARENA', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w900, fontSize: 11)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('FIDE 8x8 Rules', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 10)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Scholar Chess Arena',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Grandmaster tactical chess with legal engine, castling, en-passant, pawn promotion, and smart Minimax AI.',
                    style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Mode Selector Tabs: vs AI Bot | PvP
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _gameMode = ChessMode.vsAi),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _gameMode == ChessMode.vsAi ? const Color(0xFF6366F1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _gameMode == ChessMode.vsAi
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.smart_toy_rounded, size: 18, color: _gameMode == ChessMode.vsAi ? Colors.white : Colors.white60),
                            const SizedBox(width: 6),
                            Text('vs AI Bot', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _gameMode == ChessMode.vsAi ? Colors.white : Colors.white60)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _gameMode = ChessMode.pvp),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _gameMode == ChessMode.pvp ? const Color(0xFFF59E0B) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _gameMode == ChessMode.pvp
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_alt_rounded, size: 18, color: _gameMode == ChessMode.pvp ? Colors.black : Colors.white60),
                            const SizedBox(width: 6),
                            Text('PvP Match', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _gameMode == ChessMode.pvp ? Colors.black : Colors.white60)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_gameMode == ChessMode.vsAi) ...[
              _buildAiSettingsCard(),
            ] else ...[
              _buildPvpSettingsCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAiSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select AI Engine Level', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildDifficultyChip('Novice', ChessDifficulty.easy, const Color(0xFF10B981)),
              const SizedBox(width: 8),
              _buildDifficultyChip('Scholar', ChessDifficulty.medium, const Color(0xFF38BDF8)),
              const SizedBox(width: 8),
              _buildDifficultyChip('Grandmaster', ChessDifficulty.hard, const Color(0xFFEC4899)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(
              _aiDifficulty == ChessDifficulty.easy
                  ? '• Novice: Fast, warm-up play style. Evaluates immediate captures and piece trades.'
                  : (_aiDifficulty == ChessDifficulty.medium
                      ? '• Scholar: 2-ply Minimax engine. Evaluates captures, central control, and tactical piece development.'
                      : '• Grandmaster: 3-ply Minimax lookahead with Alpha-Beta pruning, king safety heuristics, and piece-square evaluation tables.'),
              style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.45),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              label: const Text('Start Match vs AI Bot', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              onPressed: _startGame,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyChip(String label, ChessDifficulty diff, Color accent) {
    final isSelected = _aiDifficulty == diff;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _aiDifficulty = diff),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: isSelected ? accent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? accent : Colors.white.withValues(alpha: 0.1),
              width: isSelected ? 1.6 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPvpSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Choose PvP Match Mode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildPvpPill('Find Match', 0, Icons.radar_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _buildPvpPill('Invite', 1, Icons.send_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _buildPvpPill('Pass & Play', 2, Icons.phone_android_rounded)),
            ],
          ),
          const SizedBox(height: 18),

          // Sub-Mode 0: Find Online Match
          if (_pvpSubMode == 0) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.25)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isSearchingMatch) ...[
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, _) {
                        final val = _pulseController.value;
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 80 + (24 * val),
                              height: 80 + (24 * val),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFF59E0B).withValues(alpha: (1.0 - val) * 0.4),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                              ),
                              child: const Icon(Icons.radar_rounded, color: Color(0xFFF59E0B), size: 28),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Scanning radar for active online scholars...', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                  ] else if (_matchedScholar != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.verified_rounded, color: Colors.greenAccent, size: 36),
                    ),
                    const SizedBox(height: 12),
                    Text('Opponent: ${_matchedScholar!.effectiveNickname}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text('Scholar Level ${_matchedScholar!.level}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _startGame,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Start PvP Match', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ] else ...[
                    const Icon(Icons.wifi_tethering_rounded, color: Color(0xFFF59E0B), size: 40),
                    const SizedBox(height: 10),
                    const Text('Find Online Opponent', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 4),
                    const Text('Connect with real online scholars for a live Chess blitz match.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 12)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.search_rounded, size: 18),
                      label: const Text('Search Online Match', style: TextStyle(fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _triggerOnlineMatchmaking,
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Sub-Mode 1: Invite Scholar
          if (_pvpSubMode == 1) ...[
            TextField(
              onChanged: (val) => setState(() => _scholarSearchQuery = val),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search community scholars...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 18),
                fillColor: Colors.white.withValues(alpha: 0.05),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              child: _availableScholars.isEmpty
                  ? const Center(child: Text('No other scholars found to invite.', style: TextStyle(color: Colors.white38, fontSize: 12)))
                  : ListView.separated(
                      itemCount: _availableScholars.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
                      itemBuilder: (context, idx) {
                        final s = _availableScholars[idx];
                        if (_scholarSearchQuery.isNotEmpty && !s.effectiveNickname.toLowerCase().contains(_scholarSearchQuery.toLowerCase())) {
                          return const SizedBox.shrink();
                        }
                        return ListTile(
                          dense: true,
                          title: Text(s.effectiveNickname, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          subtitle: Text('Level ${s.level}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              setState(() => _matchedScholar = s);
                              showSuccessToast(context, 'Challenge sent to ${s.effectiveNickname}!');
                              _startGame();
                            },
                            child: const Text('Challenge', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                          ),
                        );
                      },
                    ),
            ),
          ],

          // Sub-Mode 2: Pass & Play
          if (_pvpSubMode == 2) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(Icons.phone_android_rounded, color: Color(0xFFF59E0B), size: 36),
                  const SizedBox(height: 10),
                  const Text('Local Pass & Play', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 4),
                  const Text('Play with a friend on this device. White moves first, then hand the device over to Black.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _startGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Start Local 2-Player Game', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPvpPill(String label, int modeIndex, IconData icon) {
    final isSelected = _pvpSubMode == modeIndex;
    return InkWell(
      onTap: () => setState(() => _pvpSubMode = modeIndex),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF59E0B) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.black : Colors.white60),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white60,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SCREEN 2: MODERN INTERACTIVE CHESSBOARD
  // ==========================================
  Widget _buildChessboardScreen() {
    final user = context.watch<AuthViewModel>().currentUser;
    final opponentNick = _gameMode == ChessMode.vsAi
        ? 'AI Scholar Bot (${_aiDifficulty.name.toUpperCase()})'
        : (_matchedScholar?.effectiveNickname ?? (_pvpSubMode == 2 ? 'Player 2 (Black)' : 'Online Scholar'));

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1120),
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              padding: EdgeInsets.zero,
              tooltip: 'Leave Match',
              onPressed: _handleBackOrQuit,
            ),
          ),
        ),
        title: Row(
          children: [
            const Icon(Icons.shield_moon_rounded, color: Color(0xFF38BDF8), size: 20),
            const SizedBox(width: 8),
            Text(
              _gameMode == ChessMode.vsAi ? 'vs AI Scholar Bot' : 'Scholar Chess PvP',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Lobby & Settings',
            onPressed: () {
              if (!_board.isGameOver) {
                _handleBackOrQuit();
              } else {
                setState(() => _hasGameStarted = false);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Restart Board',
            onPressed: () {
              setState(() {
                _board.reset();
                _selectedTile = null;
                _currentLegalMoves = [];
                _statusBannerText = null;
                _hasPromptedDeadlock = false;
                _deadlockCooldownMoveCount = 0;
              });
              showSuccessToast(context, 'Board reset!');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Head-to-Head Score Bar
            if (_h2hRecord != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      const Color(0xFF6366F1).withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.sports_score_rounded, color: Color(0xFF38BDF8), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'H2H Score: You ${_h2hRecord!.wins} - ${_h2hRecord!.losses} ${_h2hRecord!.opponentName}${_h2hRecord!.draws > 0 ? " (${_h2hRecord!.draws} D)" : ""}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            // Status Banner / Check indicator with animated pulse
            if (_statusBannerText != null)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  return Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.2 + 0.15 * _pulseController.value),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.8)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withValues(alpha: 0.3 * _pulseController.value),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _statusBannerText!,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                },
              ),

            // Opponent Tray (Black - Player 2)
            _buildPlayerTray(
              playerNumber: 2,
              name: opponentNick,
              capturedPieces: _board.capturedByBlack,
              isTurn: _board.currentTurn == 2,
              isAi: _gameMode == ChessMode.vsAi,
            ),

            const SizedBox(height: 6),

            // 8x8 Chessboard Chassis
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                      ),
                      border: Border.all(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                        width: 2.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.22),
                          blurRadius: 24,
                          spreadRadius: 1,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.7),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: ChessBoard.size,
                        ),
                        itemCount: ChessBoard.size * ChessBoard.size,
                        itemBuilder: (context, index) {
                          final r = index ~/ ChessBoard.size;
                          final c = index % ChessBoard.size;
                          return _buildChessTile(r, c);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 6),

            // User Tray (White - Player 1)
            _buildPlayerTray(
              playerNumber: 1,
              name: user?.effectiveNickname ?? 'Scholar (White)',
              capturedPieces: _board.capturedByWhite,
              isTurn: _board.currentTurn == 1,
              isAi: false,
            ),

            // Bottom Actions Bar (Move count, Draw, Resign)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Text(
                      'Moves: ${_board.moveHistory.length}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.white70),
                    icon: const Icon(Icons.handshake_outlined, size: 16),
                    label: const Text('Draw', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      setState(() {
                        _board.isGameOver = true;
                        _board.isDraw = true;
                        _board.gameOverReason = 'Draw agreed by players.';
                      });
                      _handleGameOver();
                    },
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                    icon: const Icon(Icons.flag_outlined, size: 16),
                    label: const Text('Resign', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      setState(() {
                        _board.isGameOver = true;
                        _board.winner = 2;
                        _board.gameOverReason = 'White resigned.';
                      });
                      _handleGameOver();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerTray({
    required int playerNumber,
    required String name,
    required List<ChessPiece> capturedPieces,
    required bool isTurn,
    required bool isAi,
  }) {
    final isWhite = playerNumber == 1;
    final advantage = _calculateMaterialAdvantage(playerNumber);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isTurn
              ? [
                  const Color(0xFF1E293B).withValues(alpha: 0.9),
                  const Color(0xFF0F172A).withValues(alpha: 0.8),
                ]
              : [
                  const Color(0xFF0F172A).withValues(alpha: 0.6),
                  const Color(0xFF090D16).withValues(alpha: 0.6),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTurn
              ? (isWhite ? const Color(0xFF38BDF8) : const Color(0xFFA855F7))
              : Colors.white.withValues(alpha: 0.08),
          width: isTurn ? 1.6 : 1.0,
        ),
        boxShadow: isTurn
            ? [
                BoxShadow(
                  color: (isWhite ? const Color(0xFF38BDF8) : const Color(0xFFA855F7)).withValues(alpha: 0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Avatar crown token
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isWhite
                  ? const LinearGradient(colors: [Color(0xFFF1F5F9), Color(0xFFCBD5E1)])
                  : const LinearGradient(colors: [Color(0xFF312E81), Color(0xFF0F172A)]),
              border: Border.all(
                color: isWhite ? Colors.white : const Color(0xFFA855F7),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isWhite ? Colors.white.withValues(alpha: 0.3) : const Color(0xFFA855F7).withValues(alpha: 0.4),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Center(
              child: Text(
                isWhite ? '♔' : '♚',
                style: TextStyle(
                  fontSize: 18,
                  height: 1.0,
                  color: isWhite ? const Color(0xFF0F172A) : Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Player name and status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: TextStyle(
                          color: isTurn ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Active turn indicator badge
                    if (isTurn) ...[
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, _) {
                          final val = _pulseController.value;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isWhite ? const Color(0xFF0284C7) : const Color(0xFF7C3AED))
                                  .withValues(alpha: 0.25 + 0.15 * val),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: (isWhite ? const Color(0xFF38BDF8) : const Color(0xFFA855F7))
                                    .withValues(alpha: 0.7),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isWhite ? const Color(0xFF38BDF8) : const Color(0xFFA855F7),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isWhite ? const Color(0xFF38BDF8) : const Color(0xFFA855F7),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isAiThinking && !isWhite ? 'THINKING' : 'LIVE TURN',
                                  style: TextStyle(
                                    color: isWhite ? const Color(0xFF38BDF8) : const Color(0xFFA855F7),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 9,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),

                // Captured pieces & Material Advantage Badge
                if (capturedPieces.isNotEmpty || advantage > 0) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (capturedPieces.isNotEmpty)
                        Text(
                          capturedPieces.map((p) => p.symbol).join(' '),
                          style: const TextStyle(fontSize: 12.5, color: Colors.white70),
                        ),
                      if (advantage > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            '+$advantage',
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChessTile(int r, int c) {
    final isDarkTile = (r + c) % 2 == 1;
    // Cyber-Scholar Palette: Satin Titanium Slate (light) vs Deep Obsidian Slate (dark)
    final tileColor = isDarkTile ? const Color(0xFF131C2E) : const Color(0xFF2C3C58);

    final piece = _board.getPiece(r, c);
    final isSelected = _selectedTile != null && _selectedTile!.x == r && _selectedTile!.y == c;
    final isLegalMove = _currentLegalMoves.any((m) => m.toRow == r && m.toCol == c);
    final isKingInCheckTile = piece != null && piece.type == ChessPieceType.king && _board.isKingInCheck(piece.player);

    final lastMove = _board.moveHistory.isNotEmpty ? _board.moveHistory.last : null;
    final isLastMoveTile = lastMove != null &&
        ((lastMove.fromRow == r && lastMove.fromCol == c) || (lastMove.toRow == r && lastMove.toCol == c));

    return InkWell(
      onTap: () => _onTileTap(r, c),
      child: Container(
        decoration: BoxDecoration(
          color: tileColor,
          border: isSelected
              ? Border.all(color: const Color(0xFF38BDF8), width: 2.5)
              : (isKingInCheckTile
                  ? Border.all(color: Colors.redAccent, width: 2.5)
                  : null),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Moving box radiant light effect (Source and Destination)
            if (isLastMoveTile && !isSelected)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    final pulse = _pulseController.value;
                    final isDestination = lastMove.toRow == r && lastMove.toCol == c;
                    final glowColor = isDestination ? const Color(0xFF38BDF8) : const Color(0xFF818CF8);

                    return Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 0.85,
                          colors: [
                            glowColor.withValues(alpha: 0.42 + 0.18 * pulse),
                            glowColor.withValues(alpha: 0.18 + 0.10 * pulse),
                            Colors.transparent,
                          ],
                        ),
                        border: Border.all(
                          color: glowColor.withValues(alpha: 0.65 + 0.35 * pulse),
                          width: isDestination ? 2.2 : 1.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: glowColor.withValues(alpha: 0.35 * pulse),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            // Selected tile radiant glow
            if (isSelected)
              Positioned.fill(
                child: Container(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                ),
              ),

            // King in check dramatic red glow
            if (isKingInCheckTile)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        Colors.redAccent.withValues(alpha: 0.8),
                        Colors.redAccent.withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

            // Coordinate labels on edges
            if (c == 0)
              Positioned(
                top: 2,
                left: 3,
                child: Text(
                  '${8 - r}',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ),
            if (r == 7)
              Positioned(
                bottom: 2,
                right: 3,
                child: Text(
                  String.fromCharCode(97 + c),
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ),

            // Piece Widget
            if (piece != null)
              _buildPieceWidget(piece, isSelected: isSelected),

            // Modern Legal Move Indicators
            if (isLegalMove)
              Center(
                child: piece == null
                    ? Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF38BDF8).withValues(alpha: 0.8),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      )
                    : Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFF43F5E), width: 2.6),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF43F5E).withValues(alpha: 0.6),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieceWidget(ChessPiece piece, {bool isSelected = false}) {
    final isWhite = piece.player == 1;

    final pieceWidget = Text(
      piece.symbol,
      style: TextStyle(
        fontSize: 34,
        height: 1.0,
        color: isWhite ? Colors.white : const Color(0xFF0F172A),
        shadows: isWhite
            ? [
                const Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(1.5, 1.8)),
                const Shadow(color: Color(0xFF38BDF8), blurRadius: 6),
              ]
            : [
                const Shadow(color: Colors.white, blurRadius: 2.5, offset: Offset(0.5, 0.5)),
                const Shadow(color: Color(0xFFA855F7), blurRadius: 6),
              ],
      ),
    );

    if (isSelected) {
      return Center(
        child: Transform.scale(
          scale: 1.15,
          child: pieceWidget,
        ),
      );
    }

    return Center(child: pieceWidget);
  }
}
