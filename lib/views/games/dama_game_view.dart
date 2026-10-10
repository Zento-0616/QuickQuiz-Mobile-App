import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../models/dama_game_model.dart';
import '../../models/game_match_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../services/game_session_service.dart';
import '../../services/head_to_head_service.dart';
import '../../services/reward_effect_service.dart';
import '../../services/social_service.dart';
import '../../utils/toast_helper.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/sign_in_required_dialog.dart';

class DamaGameView extends StatefulWidget {
  final GameMatchModel? initialMatch;
  const DamaGameView({super.key, this.initialMatch});

  @override
  State<DamaGameView> createState() => _DamaGameViewState();
}

class _DamaGameViewState extends State<DamaGameView> with SingleTickerProviderStateMixin {
  final DamaBoard _board = DamaBoard();
  DamaMode _gameMode = DamaMode.vsAi;
  DamaDifficulty _aiDifficulty = DamaDifficulty.medium;

  // Head-to-Head win/loss record against the current opponent
  HeadToHeadRecord? _h2hRecord;

  // Lobby State (Settings screen appears first before playing)
  bool _hasGameStarted = false;
  int _pvpSubMode = 0; // 0 = Find Online Match, 1 = Invite Scholar, 2 = Pass & Play
  bool _isSearchingMatch = false;
  UserModel? _matchedScholar;
  List<UserModel> _availableScholars = [];
  String _scholarSearchQuery = '';
  bool _noOnlineFound = false;

  // Real Online Multiplayer State
  GameMatchModel? _activeMatch;
  StreamSubscription<GameMatchModel?>? _matchSub;
  StreamSubscription<String?>? _ticketSub;
  int _myPlayerNumber = 1; // 1 = White/Light pieces, 2 = Red/Dark pieces
  bool get _isOnlinePvP => _gameMode == DamaMode.pvp && _pvpSubMode != 2 && _activeMatch != null;
  bool get _isBoardFlipped => _isOnlinePvP && _myPlayerNumber == 2;
  bool _isWaitingOpponent = false;
  String? _waitingMessage;
  bool _hasPromptedDrawOffer = false;

  Point<int>? _selectedTile;
  List<DamaMove> _currentLegalMoves = [];
  bool _isAiThinking = false;
  String? _coronationText;
  Timer? _coronationTimer;

  late AnimationController _pulseController;
  DamaMove? _lastMove;
  bool _hasPromptedDeadlock = false;
  int _deadlockCooldownMoveCount = 0;
  bool _resultRecorded = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    if (widget.initialMatch != null) {
      _gameMode = DamaMode.pvp;
      _pvpSubMode = 0;
      _activeMatch = widget.initialMatch;
      _hasGameStarted = true;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthViewModel>();
      if (auth.isGuest) {
        showSignInRequiredDialog(context);
        if (mounted) context.pop();
        return;
      }

      if (widget.initialMatch != null) {
        _applyInitialMatch(widget.initialMatch!);
      }

      _loadCommunityScholars();
    });
  }

  @override
  void didUpdateWidget(DamaGameView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialMatch != null &&
        widget.initialMatch?.id != oldWidget.initialMatch?.id) {
      _applyInitialMatch(widget.initialMatch!);
    }
  }

  void _applyInitialMatch(GameMatchModel match) {
    final auth = context.read<AuthViewModel>();
    final currentUid = auth.currentUser?.uid;

    setState(() {
      _gameMode = DamaMode.pvp;
      _pvpSubMode = 0;
      _activeMatch = match;
      _hasGameStarted = true;
      _isSearchingMatch = false;
      _isWaitingOpponent = false;
      _waitingMessage = null;
      _resultRecorded = false;
      _board.reset();
      _selectedTile = null;
      _currentLegalMoves = [];
      _lastMove = null;

      if (currentUid == match.hostId) {
        _myPlayerNumber = 1;
        _matchedScholar = UserModel(
          uid: match.opponentId,
          name: match.opponentName,
          email: '',
          nickname: match.opponentName,
          photoUrl: match.opponentAvatar,
          level: match.opponentLevel,
          createdAt: DateTime.now(),
        );
      } else {
        _myPlayerNumber = 2;
        _matchedScholar = UserModel(
          uid: match.hostId,
          name: match.hostName,
          email: '',
          nickname: match.hostName,
          photoUrl: match.hostAvatar,
          level: match.hostLevel,
          createdAt: DateTime.now(),
        );
      }
    });

    try {
      auth.setInMatchStatus(true);
    } catch (_) {}

    _hydrateOpponentProfile(_matchedScholar?.uid);
    _subscribeToMatch(match.id);
  }

  Future<void> _hydrateOpponentProfile(String? opponentUid) async {
    if (opponentUid == null || opponentUid.isEmpty) return;
    try {
      final cached = _availableScholars.where((s) => s.uid == opponentUid).firstOrNull;
      if (cached != null && mounted) {
        setState(() => _matchedScholar = cached);
        return;
      }
      final profile = await FirestoreService().getUserProfile(opponentUid);
      if (profile != null && mounted) {
        setState(() => _matchedScholar = profile);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _matchSub?.cancel();
    _ticketSub?.cancel();
    _pulseController.dispose();
    _coronationTimer?.cancel();
    super.dispose();
  }

  void _subscribeToMatch(String matchId) {
    _matchSub?.cancel();
    _matchSub = GameSessionService().streamMatch(matchId).listen((match) {
      if (!mounted || match == null) return;
      _activeMatch = match;

      // Handle match declined
      if (match.status == GameMatchStatus.declined) {
        if (_isWaitingOpponent) {
          setState(() {
            _isWaitingOpponent = false;
            _waitingMessage = null;
            _isSearchingMatch = false;
          });
          showWarningToast(context, '${match.opponentName} declined the match.');
        }
        return;
      }

      // Handle match cancelled
      if (match.status == GameMatchStatus.cancelled) {
        if (_hasGameStarted && !_board.isGameOver) {
          showWarningToast(context, 'Opponent left the match.');
        }
        return;
      }

      // Handle match accepted / started
      if ((_isWaitingOpponent || !_hasGameStarted) &&
          (match.status == GameMatchStatus.playing || match.status == GameMatchStatus.accepted)) {
        setState(() {
          _isWaitingOpponent = false;
          _waitingMessage = null;
          _isSearchingMatch = false;
          _hasGameStarted = true;
        });
        showSuccessToast(context, '🎮 Live match started with ${_matchedScholar?.effectiveNickname ?? "opponent"}!');
      }

      // Handle Remote Moves
      if (match.lastMove != null) {
        final lastMoveMap = match.lastMove!;
        final byPlayer = (lastMoveMap['byPlayer'] as num?)?.toInt() ?? 0;

        if (byPlayer != _myPlayerNumber && byPlayer != 0) {
          final fromRow = (lastMoveMap['fromRow'] as num).toInt();
          final fromCol = (lastMoveMap['fromCol'] as num).toInt();
          final toRow = (lastMoveMap['toRow'] as num).toInt();
          final toCol = (lastMoveMap['toCol'] as num).toInt();

          final isAlreadyApplied = _lastMove != null &&
              _lastMove!.fromRow == fromRow &&
              _lastMove!.fromCol == fromCol &&
              _lastMove!.toRow == toRow &&
              _lastMove!.toCol == toCol;

          if (!isAlreadyApplied) {
            final rawCaptures = lastMoveMap['capturedTiles'] as List? ?? const [];
            final captured = rawCaptures
                .map((c) => Point((c['x'] as num).toInt(), (c['y'] as num).toInt()))
                .toList();
            final becameKing = lastMoveMap['becameKing'] as bool? ?? false;

            final remoteMove = DamaMove(
              fromRow: fromRow,
              fromCol: fromCol,
              toRow: toRow,
              toCol: toCol,
              capturedTiles: captured,
              becameKing: becameKing,
            );

            _executeRemoteMove(remoteMove, becameKing);
          }
        }
      }

      // Handle Incoming Draw Offer
      final currentUid = context.read<AuthViewModel>().currentUser?.uid;
      if (match.drawOfferedBy != null &&
          match.drawOfferedBy != currentUid &&
          !_hasPromptedDrawOffer &&
          !_board.isGameOver) {
        _hasPromptedDrawOffer = true;
        _showIncomingDrawOfferDialog(match);
      }

      // Handle Remote Game Over (e.g. Resignation or Draw)
      if (match.isGameOver && !_board.isGameOver) {
        setState(() {
          _board.isGameOver = true;
          _board.isDraw = match.isDraw;
          if (match.isDraw) {
            _board.winner = null;
          } else {
            _board.winner = match.winnerId == currentUid ? _myPlayerNumber : (_myPlayerNumber == 1 ? 2 : 1);
          }
        });
        _showGameOverDialog();
      }
    });
  }

  void _executeRemoteMove(DamaMove move, bool becameKing) {
    final moveMade = _board.makeMove(move);
    if (!moveMade) return;

    setState(() {
      _lastMove = move;
      _selectedTile = null;
      _currentLegalMoves = [];
    });

    if (becameKing) {
      _triggerCoronationEffect();
    }

    if (_board.isGameOver) {
      _showGameOverDialog();
    }
  }

  Future<void> _loadCommunityScholars() async {
    try {
      final user = context.read<AuthViewModel>().currentUser;
      final scholars = await SocialService().getActiveOnlineScholars(
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

    final String opponentUid;
    final String opponentName;

    if (_gameMode == DamaMode.vsAi) {
      opponentUid = 'ai_bot_${_aiDifficulty.name}';
      opponentName = 'AI Bot (${_aiDifficulty.name.toUpperCase()})';
    } else {
      opponentUid = _matchedScholar?.uid ?? 'guest_player_2';
      opponentName = _matchedScholar?.effectiveNickname ?? 'Player 2';
    }

    try {
      final record = await HeadToHeadService().getRecord(
        userId: user.uid,
        opponentId: opponentUid,
        opponentName: opponentName,
      );
      if (mounted) {
        setState(() => _h2hRecord = record);
      }
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
      _noOnlineFound = false;
      _isWaitingOpponent = true;
      _waitingMessage = 'Searching for another player in matchmaking queue...';
    });

    try {
      // 1. Enter matchmaking queue to find an instant waiting match
      final instantMatch = await GameSessionService().enterMatchmaking(
        user: user,
        gameType: 'dama',
      );

      if (instantMatch != null) {
        // Paired with someone who was already in queue!
        setState(() {
          _isSearchingMatch = false;
          _isWaitingOpponent = false;
          _waitingMessage = null;
          _activeMatch = instantMatch;
          _myPlayerNumber = 2; // Joined existing host
          _resultRecorded = false;
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
        _hydrateOpponentProfile(instantMatch.hostId);
        _subscribeToMatch(instantMatch.id);
        _startGame();
        if (mounted) {
          showSuccessToast(context, '🎯 Matched with ${instantMatch.hostName}!');
        }
        return;
      }

      // 2. No instant match: wait in pure matchmaking queue for another player to search
      setState(() {
        _waitingMessage = 'In matchmaking queue... Waiting for another player searching for a match.';
      });
      _ticketSub?.cancel();
      _ticketSub = GameSessionService().streamMatchmakingTicket(user.uid).listen((matchId) async {
        if (matchId != null && mounted) {
          _ticketSub?.cancel();
          final match = await GameSessionService().streamMatch(matchId).first;
          if (match != null && mounted) {
            setState(() {
              _isSearchingMatch = false;
              _isWaitingOpponent = false;
              _waitingMessage = null;
              _activeMatch = match;
              _myPlayerNumber = 1;
              _resultRecorded = false;
              _matchedScholar = UserModel(
                uid: match.opponentId,
                name: match.opponentName,
                email: '',
                nickname: match.opponentName,
                photoUrl: match.opponentAvatar,
                level: match.opponentLevel,
                createdAt: DateTime.now(),
              );
            });
            _hydrateOpponentProfile(match.opponentId);
            _subscribeToMatch(match.id);
            _startGame();
            showSuccessToast(context, '🎯 Match found: ${match.opponentName}!');
          }
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSearchingMatch = false;
          _isWaitingOpponent = false;
          _waitingMessage = null;
          _noOnlineFound = true;
        });
      }
    }
  }

  Future<void> _sendInviteChallenge(UserModel scholar) async {
    final auth = context.read<AuthViewModel>();
    final user = auth.currentUser;
    if (user == null || user.isGuest) {
      showSignInRequiredDialog(context);
      return;
    }

    if (scholar.isInMatch) {
      showWarningToast(context, '${scholar.effectiveNickname} is currently playing in another match.');
      return;
    }

    try {
      final challenge = await GameSessionService().sendChallenge(
        host: user,
        opponent: scholar,
        gameType: 'dama',
      );

      setState(() {
        _activeMatch = challenge;
        _myPlayerNumber = 1; // Host (White)
        _matchedScholar = scholar;
        _isWaitingOpponent = true;
        _waitingMessage = 'Challenge sent to ${scholar.effectiveNickname}! Waiting for response...';
      });

      _subscribeToMatch(challenge.id);
      if (mounted) {
        showSuccessToast(context, '⚔️ Challenge sent to ${scholar.effectiveNickname}!');
      }
    } catch (e) {
      if (mounted) {
        showWarningToast(context, 'Could not send challenge: $e');
      }
    }
  }

  Future<void> _cancelWaiting() async {
    final user = context.read<AuthViewModel>().currentUser;
    if (user != null) {
      await GameSessionService().leaveMatchmaking(user.uid);
    }
    if (_activeMatch != null && _activeMatch!.status == GameMatchStatus.pending) {
      await GameSessionService().cancelChallenge(_activeMatch!.id);
    }
    _ticketSub?.cancel();
    _matchSub?.cancel();
    setState(() {
      _isSearchingMatch = false;
      _isWaitingOpponent = false;
      _waitingMessage = null;
      _activeMatch = null;
    });
  }

  void _startGame() {
    setState(() {
      _board.reset();
      _selectedTile = null;
      _currentLegalMoves = [];
      _hasGameStarted = true;
      _resultRecorded = false;
    });
    _loadHeadToHead();
    try {
      context.read<AuthViewModel>().setInMatchStatus(true);
    } catch (_) {}
  }

  void _onTileTap(int r, int c) {
    if (_board.isGameOver || _isAiThinking) return;

    // If mid-chain jump is active, player MUST continue capturing with that specific piece
    if (_board.multiCapturePiece != null) {
      final matchedMove = _currentLegalMoves.firstWhere(
        (m) => m.toRow == r && m.toCol == c,
        orElse: () => const DamaMove(fromRow: -1, fromCol: -1, toRow: -1, toCol: -1),
      );

      if (matchedMove.fromRow != -1) {
        _executeMove(matchedMove);
      } else {
        showWarningToast(context, 'Chained jump active! Tap a highlighted green square to continue capturing.');
      }
      return;
    }

    // Normal piece selection
    final piece = _board.getPiece(r, c);
    if (piece != null && piece.player == _board.currentTurn) {
      if (_isOnlinePvP && piece.player != _myPlayerNumber) {
        showWarningToast(
          context,
          'Waiting for ${_matchedScholar?.effectiveNickname ?? "opponent"}\'s turn...',
        );
        return;
      }
      if (_gameMode == DamaMode.vsAi && _board.currentTurn == 2) {
        return;
      }
      setState(() {
        _selectedTile = Point(r, c);
        _currentLegalMoves = _board.getLegalMoves(r, c);
      });
      return;
    }

    // Destination tap
    if (_selectedTile != null) {
      final matchedMove = _currentLegalMoves.firstWhere(
        (m) => m.toRow == r && m.toCol == c,
        orElse: () => const DamaMove(fromRow: -1, fromCol: -1, toRow: -1, toCol: -1),
      );

      if (matchedMove.fromRow != -1) {
        _executeMove(matchedMove);
      } else {
        setState(() {
          _selectedTile = null;
          _currentLegalMoves = [];
        });
      }
    }
  }

  DamaDifficulty get _effectiveOpponentDifficulty {
    if (_gameMode == DamaMode.vsAi) return _aiDifficulty;
    if (_matchedScholar != null) {
      if (_matchedScholar!.level >= 10) return DamaDifficulty.hard;
      if (_matchedScholar!.level >= 4) return DamaDifficulty.medium;
      return DamaDifficulty.easy;
    }
    return DamaDifficulty.medium;
  }

  void _executeMove(DamaMove move) {
    final becameKing = move.becameKing;
    final moveMade = _board.makeMove(move);

    if (!moveMade) {
      setState(() {
        _selectedTile = null;
        _currentLegalMoves = [];
      });
      return;
    }

    setState(() {
      _lastMove = move;
      if (_board.multiCapturePiece != null) {
        // Continue chained jump
        _selectedTile = _board.multiCapturePiece;
        _currentLegalMoves = _board.getLegalMoves(
          _board.multiCapturePiece!.x,
          _board.multiCapturePiece!.y,
        );
      } else {
        _selectedTile = null;
        _currentLegalMoves = [];
      }
    });

    if (becameKing) {
      _triggerCoronationEffect();
    }

    if (_board.isGameOver) {
      _showGameOverDialog();
    }

    // Broadcast move to remote opponent if in live online PvP match
    if (_isOnlinePvP && _activeMatch != null) {
      final auth = context.read<AuthViewModel>();
      final myUid = auth.currentUser?.uid ?? '';
      final opponentUid = _matchedScholar?.uid;

      String? winnerId;
      if (_board.isGameOver) {
        if (_board.isDraw) {
          winnerId = 'draw';
        } else {
          winnerId = _board.winner == _myPlayerNumber ? myUid : opponentUid;
        }
      }

      GameSessionService().sendMove(
        matchId: _activeMatch!.id,
        moveData: {
          'fromRow': move.fromRow,
          'fromCol': move.fromCol,
          'toRow': move.toRow,
          'toCol': move.toCol,
          'capturedTiles': move.capturedTiles.map((p) => {'x': p.x, 'y': p.y}).toList(),
          'becameKing': becameKing,
          'byPlayer': _myPlayerNumber,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
        nextTurn: _board.currentTurn,
        isGameOver: _board.isGameOver,
        winnerId: winnerId,
        isDraw: _board.isDraw,
      );
    }

    if (_board.isGameOver) {
      return;
    }

    // Deadlock / "Run & Hide" impossible to beat check
    if (!_board.isGameOver &&
        _board.isRunAndHideDeadlock() &&
        (!_hasPromptedDeadlock || _board.moveHistory.length >= _deadlockCooldownMoveCount)) {
      _hasPromptedDeadlock = true;
      _deadlockCooldownMoveCount = _board.moveHistory.length + 14;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_board.isGameOver) {
          _showDeadlockDrawDialog();
        }
      });
    }

    // STRICT: Only trigger AI moves if in vsAi mode! Never in PvP!
    if (_gameMode == DamaMode.vsAi && _board.currentTurn == 2) {
      _triggerAiMove();
    }
  }

  void _showIncomingDrawOfferDialog(GameMatchModel match) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.handshake_rounded, color: Color(0xFF38BDF8), size: 24),
            SizedBox(width: 8),
            Text('Draw Offered', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ],
        ),
        content: Text(
          '${_matchedScholar?.effectiveNickname ?? "Your opponent"} has offered a peaceful draw. Accept or continue playing?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: const Text('Decline', style: TextStyle(color: Colors.redAccent)),
            onPressed: () {
              Navigator.pop(ctx);
              _hasPromptedDrawOffer = false;
              GameSessionService().respondToDraw(matchId: match.id, accept: false);
              showWarningToast(context, 'Draw offer declined.');
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Accept Draw', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            onPressed: () {
              Navigator.pop(ctx);
              _hasPromptedDrawOffer = false;
              GameSessionService().respondToDraw(matchId: match.id, accept: true);
              setState(() {
                _board.isGameOver = true;
                _board.isDraw = true;
                _board.winner = null;
              });
              _showGameOverDialog();
            },
          ),
        ],
      ),
    );
  }

  void _handleOfferOrDeclareDraw() {
    if (_isOnlinePvP && _activeMatch != null) {
      final user = context.read<AuthViewModel>().currentUser;
      if (user != null) {
        GameSessionService().offerDraw(
          matchId: _activeMatch!.id,
          fromUserId: user.uid,
        );
        showSuccessToast(context, 'Draw offer sent to ${_matchedScholar?.effectiveNickname ?? "opponent"}');
      }
    } else {
      setState(() {
        _board.isGameOver = true;
        _board.isDraw = true;
        _board.winner = null;
      });
      _showGameOverDialog();
    }
  }

  void _handleResign() {
    if (_isOnlinePvP && _activeMatch != null) {
      final user = context.read<AuthViewModel>().currentUser;
      final opponentUid = _matchedScholar?.uid ?? '';
      if (user != null) {
        GameSessionService().resignMatch(
          matchId: _activeMatch!.id,
          winnerUserId: opponentUid,
        );
      }
      setState(() {
        _board.isGameOver = true;
        _board.winner = _myPlayerNumber == 1 ? 2 : 1;
      });
      _showGameOverDialog();
    } else {
      setState(() {
        _board.isGameOver = true;
        _board.winner = _board.currentTurn == 1 ? 2 : 1;
      });
      _showGameOverDialog();
    }
  }

  void _triggerCoronationEffect() {
    _coronationTimer?.cancel();
    setState(() => _coronationText = '👑 DAMA PROMOTED!');
    _coronationTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _coronationText = null);
    });
  }

  void _triggerAiMove() {
    if (_board.isGameOver) {
      _showGameOverDialog();
      return;
    }

    setState(() => _isAiThinking = true);

    // Short 500ms delay if chained combo so steps are fluid yet distinct
    final delayMs = _board.multiCapturePiece != null ? 500 : 700;

    Future.delayed(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      try {
        final aiMove = _board.getAiMove(_effectiveOpponentDifficulty);
        if (aiMove != null) {
          _executeMove(aiMove);
        } else {
          if (_board.isGameOver) {
            _showGameOverDialog();
          }
        }
      } catch (e) {
        debugPrint('AI move error: $e');
      } finally {
        if (mounted) {
          setState(() => _isAiThinking = false);
        }
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
              'The match has entered an evasive stalemate with no captures. Would you like to declare a peaceful draw or continue playing?',
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
              _handleOfferOrDeclareDraw();
            },
          ),
        ],
      ),
    );
  }

  void _showGameOverDialog() {
    final winner = _board.winner;
    final isP1Winner = winner == 1;

    // Record win / loss / draw result
    if (!_resultRecorded) {
      _resultRecorded = true;
      try {
        final auth = context.read<AuthViewModel>();
        final isWin = _board.isDraw ? false : (_myPlayerNumber == winner);
        if (_board.isDraw) {
          auth.recordDamaMatchResult(isWin: false, isDraw: true);
        } else {
          auth.recordDamaMatchResult(isWin: isWin, isDraw: false);
        }

        // Record persistent Head-to-Head score
        final user = auth.currentUser;
        if (user != null) {
          final oppUid = _gameMode == DamaMode.vsAi
              ? 'ai_bot_${_aiDifficulty.name}'
              : (_matchedScholar?.uid ?? 'guest_player_2');
          final oppName = _gameMode == DamaMode.vsAi
              ? 'AI Bot (${_aiDifficulty.name.toUpperCase()})'
              : (_matchedScholar?.effectiveNickname ?? 'Player 2');

          HeadToHeadService().recordMatchOutcome(
            userId: user.uid,
            opponentId: oppUid,
            opponentName: oppName,
            isWin: isWin,
            isDraw: _board.isDraw,
          ).then((rec) {
            if (mounted) setState(() => _h2hRecord = rec);
          });
        }
      } catch (e) {
        debugPrint('Error recording Dama result: $e');
      }
    }

    if (isP1Winner) {
      RewardEffectService().showCelebration(
        context,
        RewardCelebrationPayload(
          id: 'dama_victory_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Victory!',
          rewardText: '👑 Champion',
          subtitle: 'Brilliant tactical play on the Checkers board!',
          icon: Icons.military_tech_rounded,
          badgeColor: const Color(0xFF38BDF8),
        ),
      );
    }

    String winnerTitle;
    if (_board.isDraw) {
      winnerTitle = '🤝 Match Drawn! (Peaceful Deadlock)';
    } else if (_gameMode == DamaMode.vsAi) {
      winnerTitle = isP1Winner ? '🎉 Victory! You Won!' : '⚔️ Defeat! AI Bot Won!';
    } else {
      final p2Name = _matchedScholar?.effectiveNickname ?? 'Player 2 (Rose)';
      winnerTitle = isP1Winner ? '🏆 Player 1 (Blue) Wins!' : '🏆 $p2Name Wins!';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          winnerTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 54),
            const SizedBox(height: 12),
            const Text(
              'Casual Brain Training Match\n0 EXP Awarded (Only Tournaments Award EXP)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 14),
            Text(
              'Final Captures: Blue ${_board.capturedByP1} - Rose ${_board.capturedByP2}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            if (_h2hRecord != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sports_score_rounded, color: Color(0xFFF59E0B), size: 15),
                        SizedBox(width: 5),
                        Text(
                          'LIFETIME HEAD-TO-HEAD SCORE',
                          style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w900, fontSize: 10.5, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You ${_h2hRecord!.wins}  -  ${_h2hRecord!.losses}  ${_h2hRecord!.opponentName}${_h2hRecord!.draws > 0 ? " (${_h2hRecord!.draws} D)" : ""}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Back to Lobby', style: TextStyle(color: Colors.white60)),
            onPressed: () {
              Navigator.pop(ctx);
              try {
                context.read<AuthViewModel>().setInMatchStatus(false);
              } catch (_) {}
              setState(() {
                _hasGameStarted = false;
                _activeMatch = null;
              });
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.replay_rounded, size: 18),
            label: const Text('Play Again', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _board.reset();
                _selectedTile = null;
                _currentLegalMoves = [];
                _lastMove = null;
                _hasPromptedDeadlock = false;
                _deadlockCooldownMoveCount = 0;
                _resultRecorded = false;
              });
              try {
                context.read<AuthViewModel>().setInMatchStatus(true);
              } catch (_) {}
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleBackOrQuit(BuildContext context) async {
    if (!_hasGameStarted || _board.isGameOver) {
      if (_hasGameStarted) {
        try {
          context.read<AuthViewModel>().setInMatchStatus(false);
        } catch (_) {}
        setState(() {
          _hasGameStarted = false;
          _activeMatch = null;
        });
      } else {
        if (context.canPop()) {
          context.pop();
        }
      }
      return;
    }

    final shouldQuit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Quit Active Match?',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          _isOnlinePvP
              ? 'You have an active online match against ${_matchedScholar?.effectiveNickname ?? "your opponent"}. Leaving now will forfeit the game and count as a loss.\n\nDo you want to quit or continue playing?'
              : 'Your match is currently in progress. Quitting will count as an abandoned loss.\n\nDo you want to quit or continue playing?',
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Continue Playing', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Quit & Forfeit', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (shouldQuit == true && mounted) {
      _executeQuitOrForfeit();
    }
  }

  void _executeQuitOrForfeit() {
    final auth = context.read<AuthViewModel>();

    // Forfeit online match if active
    if (_isOnlinePvP && _activeMatch != null) {
      final user = auth.currentUser;
      final opponentUid = _matchedScholar?.uid ?? '';
      if (user != null) {
        try {
          GameSessionService().resignMatch(
            matchId: _activeMatch!.id,
            winnerUserId: opponentUid,
          );
        } catch (_) {}
      }
    }

    if (!_resultRecorded) {
      _resultRecorded = true;
      try {
        auth.recordDamaMatchResult(isWin: false, isDraw: false);

        final user = auth.currentUser;
        if (user != null) {
          final oppUid = _gameMode == DamaMode.vsAi
              ? 'ai_bot_${_aiDifficulty.name}'
              : (_matchedScholar?.uid ?? 'guest_player_2');
          final oppName = _gameMode == DamaMode.vsAi
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
      } catch (_) {}
    }

    try {
      auth.setInMatchStatus(false);
    } catch (_) {}

    _matchSub?.cancel();
    _ticketSub?.cancel();

    setState(() {
      _hasGameStarted = false;
      _activeMatch = null;
      _isSearchingMatch = false;
      _isWaitingOpponent = false;
      _waitingMessage = null;
      _board.reset();
    });

    if (mounted) {
      showWarningToast(context, 'You quit and forfeited the match.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasGameStarted || _board.isGameOver,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackOrQuit(context);
      },
      child: !_hasGameStarted ? _buildLobbyScreen(context) : _buildBoardScreen(context),
    );
  }

  // ===================================================================
  // SCREEN 1: PRE-GAME LOBBY / SETTINGS FIRST
  // ===================================================================

  Widget _buildLobbyScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.grid_4x4_rounded, color: Color(0xFFF59E0B), size: 22),
            SizedBox(width: 8),
            Text('Scholar Dama Arena', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
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
              tooltip: 'Back to Games',
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.games);
                }
              },
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Hero Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF18181B), Color(0xFF27272A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_moon_rounded, color: Color(0xFFF59E0B), size: 14),
                            SizedBox(width: 5),
                            Text('8x8 CLASSIC CHECKERS', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w900, fontSize: 10.5)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('0 EXP • Casual Play', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 10)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Scholar Dama: Match Setup',
                    style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Strategic board battle. Forward steps, flying king promotions, and multi-jump captures. Choose your battle mode to start!',
                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Mode Selector Tabs: vs AI Bot | PvP
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() => _gameMode = DamaMode.vsAi),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _gameMode == DamaMode.vsAi ? const Color(0xFF6366F1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.smart_toy_rounded, size: 18, color: _gameMode == DamaMode.vsAi ? Colors.white : Colors.white60),
                            const SizedBox(width: 6),
                            Text('vs AI Bot', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _gameMode == DamaMode.vsAi ? Colors.white : Colors.white60)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() => _gameMode = DamaMode.pvp),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _gameMode == DamaMode.pvp ? const Color(0xFFF59E0B) : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_alt_rounded, size: 18, color: _gameMode == DamaMode.pvp ? Colors.black : Colors.white60),
                            const SizedBox(width: 6),
                            Text('Player vs Player (PvP)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _gameMode == DamaMode.pvp ? Colors.black : Colors.white60)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Mode Content: AI Settings vs PvP Settings
            if (_gameMode == DamaMode.vsAi) ...[
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select AI Bot Difficulty', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildDifficultyChip('Novice', DamaDifficulty.easy),
              const SizedBox(width: 8),
              _buildDifficultyChip('Scholar', DamaDifficulty.medium),
              const SizedBox(width: 8),
              _buildDifficultyChip('Grandmaster', DamaDifficulty.hard),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF818CF8), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _aiDifficulty == DamaDifficulty.easy
                        ? 'Novice Bot: Plays casual defensive moves with occasional slip-ups.'
                        : (_aiDifficulty == DamaDifficulty.medium
                            ? 'Scholar Bot: Evaluates captures, balances board position, and promotes kings.'
                            : 'Grandmaster Bot: Deep search with multi-jump prioritization and flying king control.'),
                    style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Start Match Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  Widget _buildPvpSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Choose PvP Matchmaking Mode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 12),

          // 3 PvP Pills
          Row(
            children: [
              Expanded(
                child: _buildPvpPill('Find Match', 0, Icons.wifi_tethering_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPvpPill('Invite', 1, Icons.send_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPvpPill('Pass & Play', 2, Icons.phone_android_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sub-Mode 0: Find Online Match (Centered & Online-Only)
          if (_pvpSubMode == 0) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1E293B).withValues(alpha: 0.6),
                    const Color(0xFF0F172A).withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.25)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (_isSearchingMatch || _isWaitingOpponent) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _waitingMessage ?? 'Searching for Online Scholars...',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Live queue matchmaking active',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Cancel Matchmaking', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: _cancelWaiting,
                    ),
                  ] else if (_matchedScholar != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.green, size: 14),
                          SizedBox(width: 5),
                          Text(
                            'ONLINE OPPONENT FOUND',
                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 10.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFFF59E0B),
                      child: Text(
                        _matchedScholar!.effectiveNickname.isNotEmpty ? _matchedScholar!.effectiveNickname[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 20),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _matchedScholar!.effectiveNickname,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Level ${_matchedScholar!.level} • ${_matchedScholar!.winRate}% Win Rate • 🟢 Online Now',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Find Another Online Opponent', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: _triggerOnlineMatchmaking,
                    ),
                  ] else if (_noOnlineFound) ...[
                    const Icon(Icons.wifi_off_rounded, color: Color(0xFFF59E0B), size: 40),
                    const SizedBox(height: 12),
                    const Text(
                      'No Matching Scholars in Queue Right Now',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Matchmaking only pairs with scholars currently searching in the queue. You can search again, send a direct invite to a friend, or play vs AI Bot!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.3),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Search Again', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          onPressed: _triggerOnlineMatchmaking,
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.smart_toy_rounded, size: 16),
                          label: const Text('Play vs AI Bot', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          onPressed: () => setState(() => _gameMode = DamaMode.vsAi),
                        ),
                      ],
                    ),
                  ] else ...[
                    const Icon(Icons.wifi_tethering_rounded, color: Color(0xFFF59E0B), size: 40),
                    const SizedBox(height: 12),
                    const Text(
                      'Ready for Live Online Matchmaking?',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Pairs you strictly with another player searching in the matchmaking queue.\nNo notifications are sent to uninvolved scholars.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.search_rounded, size: 18),
                      label: const Text('Find Online Opponent', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                      onPressed: _triggerOnlineMatchmaking,
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Sub-Mode 1: Invite a Scholar
          if (_pvpSubMode == 1) ...[
            TextField(
              onChanged: (val) => setState(() => _scholarSearchQuery = val.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search scholar to invite...',
                hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Colors.grey),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              child: _availableScholars.isEmpty
                  ? const Center(child: Text('No other active scholars online right now.', style: TextStyle(color: Colors.grey, fontSize: 12)))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _availableScholars.where((s) => _scholarSearchQuery.isEmpty || s.effectiveNickname.toLowerCase().contains(_scholarSearchQuery)).length,
                      itemBuilder: (ctx, idx) {
                        final list = _availableScholars.where((s) => _scholarSearchQuery.isEmpty || s.effectiveNickname.toLowerCase().contains(_scholarSearchQuery)).toList();
                        final s = list[idx];
                        final isInvited = _matchedScholar?.uid == s.uid;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isInvited ? const Color(0xFFF59E0B).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isInvited ? const Color(0xFFF59E0B) : Colors.transparent),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: const Color(0xFFF59E0B),
                                child: Text(s.effectiveNickname.isNotEmpty ? s.effectiveNickname[0].toUpperCase() : '?', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.effectiveNickname, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                    Text('Level ${s.level}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isInvited ? Colors.green : const Color(0xFFF59E0B),
                                  foregroundColor: Colors.black,
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                ),
                                onPressed: _isWaitingOpponent ? null : () => _sendInviteChallenge(s),
                                child: Text(
                                  isInvited ? (_isWaitingOpponent ? 'Waiting...' : 'Invited') : 'Invite',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            if (_isWaitingOpponent && _matchedScholar != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFF59E0B)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _waitingMessage ?? 'Waiting for ${_matchedScholar!.effectiveNickname} to respond...',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: _cancelWaiting,
                      child: const Text('Cancel', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ],

          // Sub-Mode 2: Pass & Play
          if (_pvpSubMode == 2) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.phone_android_rounded, color: Color(0xFFF59E0B), size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Pass & Play: Take turns on the same device.\nPlayer 1 controls Blue, Player 2 controls Rose.',
                      style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Start PvP Battle Button (Only needed for Pass & Play or direct start)
          if (_pvpSubMode == 2)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.sports_esports_rounded, size: 22),
                label: const Text(
                  'Start Pass & Play Match',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
                onPressed: _startGame,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDifficultyChip(String label, DamaDifficulty difficulty) {
    final isSelected = _aiDifficulty == difficulty;
    return Expanded(
      child: ChoiceChip(
        label: Center(child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500))),
        selected: isSelected,
        onSelected: (val) {
          if (val) setState(() => _aiDifficulty = difficulty);
        },
      ),
    );
  }

  Widget _buildPvpPill(String label, int index, IconData icon) {
    final isSelected = _pvpSubMode == index;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _pvpSubMode = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF59E0B).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? const Color(0xFFF59E0B) : Colors.transparent),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: isSelected ? const Color(0xFFF59E0B) : Colors.white60),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: isSelected ? const Color(0xFFF59E0B) : Colors.white70, fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  // SCREEN 2: INTERACTIVE 8x8 DAMA CHECKERBOARD
  // ===================================================================

  Widget _buildBoardScreen(BuildContext context) {
    final user = context.watch<AuthViewModel>().currentUser;
    final userNick = user?.effectiveNickname ?? 'Scholar';
    final String p1Name;
    final String p2Name;

    if (_gameMode == DamaMode.vsAi) {
      p1Name = '$userNick (You)';
      p2Name = 'AI Scholar Bot (${_aiDifficulty.name.toUpperCase()})';
    } else if (_isOnlinePvP) {
      if (_myPlayerNumber == 1) {
        p1Name = '$userNick (You)';
        p2Name = _activeMatch?.opponentName ?? _matchedScholar?.effectiveNickname ?? 'Opponent';
      } else {
        p1Name = _activeMatch?.hostName ?? _matchedScholar?.effectiveNickname ?? 'Host';
        p2Name = '$userNick (You)';
      }
    } else {
      p1Name = '$userNick (Player 1)';
      p2Name = _matchedScholar?.effectiveNickname ?? 'Player 2';
    }

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
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
              onPressed: () => _handleBackOrQuit(context),
            ),
          ),
        ),
        title: Row(
          children: [
            const Icon(Icons.grid_4x4_rounded, color: Color(0xFFF59E0B), size: 20),
            const SizedBox(width: 8),
            Text(_gameMode == DamaMode.vsAi ? 'vs AI Scholar Bot' : 'Scholar Dama PvP', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Lobby & Settings',
            onPressed: () {
              if (!_board.isGameOver) {
                _handleBackOrQuit(context);
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
                _lastMove = null;
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
            // Top Status & Rules Pill
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _gameMode == DamaMode.vsAi ? '🤖 VS AI (${_aiDifficulty.name.toUpperCase()})' : '👥 PVP BATTLE',
                      style: const TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const Spacer(),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined, color: Colors.amber, size: 14),
                      SizedBox(width: 4),
                      Text('0 EXP (Casual Play)', style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),

            // Head-to-Head Score Bar
            if (_h2hRecord != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      const Color(0xFF6366F1).withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.sports_score_rounded, color: Color(0xFFF59E0B), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'H2H Score: You ${_h2hRecord!.wins} - ${_h2hRecord!.losses} ${_h2hRecord!.opponentName}${_h2hRecord!.draws > 0 ? " (${_h2hRecord!.draws} D)" : ""}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),

            // Top Tray (Always the Opponent / AI)
            _buildPlayerTray(
              playerNumber: _isBoardFlipped ? 1 : 2,
              name: _isBoardFlipped ? p1Name : p2Name,
              capturedCount: _isBoardFlipped ? _board.capturedByP1 : _board.capturedByP2,
              isTurn: _isBoardFlipped ? _board.currentTurn == 1 : _board.currentTurn == 2,
              isAi: !_isBoardFlipped && _gameMode == DamaMode.vsAi,
              isThinking: _isAiThinking && (_isBoardFlipped ? _board.currentTurn == 1 : _board.currentTurn == 2),
            ),

            // Fixed-height status slot to prevent board resizing / zooming when thinking or chaining
            SizedBox(
              height: 28,
              child: Center(
                child: _coronationText != null
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.amber),
                        ),
                        child: Text(
                          _coronationText!,
                          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                      )
                    : (_board.multiCapturePiece != null
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF10B981)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bolt_rounded, color: Color(0xFF10B981), size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  _board.currentTurn == _myPlayerNumber
                                      ? 'CHAINED JUMP! Continue capturing'
                                      : 'Combo: Continuing capture sequence...',
                                  style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 11),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink()),
              ),
            ),

            // 8x8 Board Container
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: _buildCheckerboard(),
                  ),
                ),
              ),
            ),

            // Bottom Tray (Always the User / You)
            _buildPlayerTray(
              playerNumber: _isBoardFlipped ? 2 : 1,
              name: _isBoardFlipped ? p2Name : p1Name,
              capturedCount: _isBoardFlipped ? _board.capturedByP2 : _board.capturedByP1,
              isTurn: _isBoardFlipped ? _board.currentTurn == 2 : _board.currentTurn == 1,
              isAi: false,
              isThinking: false,
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
                    onPressed: _handleOfferOrDeclareDraw,
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                    icon: const Icon(Icons.flag_outlined, size: 16),
                    label: const Text('Resign', style: TextStyle(fontSize: 12)),
                    onPressed: _handleResign,
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
    required int capturedCount,
    required bool isTurn,
    required bool isAi,
    bool isThinking = false,
  }) {
    final isP1 = playerNumber == 1;
    final color = isP1 ? const Color(0xFF38BDF8) : const Color(0xFFF43F5E);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isTurn ? color.withValues(alpha: 0.15) : const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isTurn ? color : Colors.white12, width: isTurn ? 1.5 : 1),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: color,
            child: Icon(isAi ? Icons.smart_toy_rounded : Icons.person_rounded, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: TextStyle(color: isTurn ? Colors.white : Colors.white70, fontWeight: FontWeight.w800, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isThinking)
            Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 9,
                    height: 9,
                    child: CircularProgressIndicator(strokeWidth: 1.8, color: color),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'THINKING',
                    style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 0.5),
                  ),
                ],
              ),
            )
          else if (isTurn)
            Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
              child: const Text('TURN', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 9)),
            ),
          Text(
            'Captured: $capturedCount',
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckerboard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: DamaBoard.size,
          ),
          itemCount: DamaBoard.size * DamaBoard.size,
          itemBuilder: (context, index) {
            final screenRow = index ~/ DamaBoard.size;
            final screenCol = index % DamaBoard.size;
            // Map screen coordinates according to player POV perspective
            final r = _isBoardFlipped ? (DamaBoard.size - 1 - screenRow) : screenRow;
            final c = _isBoardFlipped ? (DamaBoard.size - 1 - screenCol) : screenCol;
            final isDark = _board.isDarkTile(r, c);
            final piece = _board.getPiece(r, c);
            final isSelected = _selectedTile != null && _selectedTile!.x == r && _selectedTile!.y == c;
            final isLegalDest = _currentLegalMoves.any((m) => m.toRow == r && m.toCol == c);
            // Highlight ONLY the destination square where the piece moved to (no glow on source square)
            final isLastMoveTile = _lastMove != null &&
                _lastMove!.toRow == r &&
                _lastMove!.toCol == c;

            return GestureDetector(
              onTap: () => _onTileTap(r, c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: isDark
                      ? (isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF1E293B))
                      : const Color(0xFF0F172A),
                  border: isSelected
                      ? Border.all(color: const Color(0xFF38BDF8), width: 2.5)
                      : (isLegalDest
                          ? Border.all(color: const Color(0xFF10B981), width: 1.5)
                          : null),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Moving box glowing light effect (Target / Destination square ONLY)
                    if (isLastMoveTile && !isSelected)
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, _) {
                            final pulse = _pulseController.value;
                            const glowColor = Color(0xFF38BDF8);

                            return Container(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment.center,
                                  radius: 0.85,
                                  colors: [
                                    glowColor.withValues(alpha: 0.45 + 0.18 * pulse),
                                    glowColor.withValues(alpha: 0.18 + 0.10 * pulse),
                                    Colors.transparent,
                                  ],
                                ),
                                border: Border.all(
                                  color: glowColor.withValues(alpha: 0.65 + 0.35 * pulse),
                                  width: 2.2,
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

                    if (isLegalDest)
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (piece != null)
                      _buildPieceWidget(piece),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPieceWidget(DamaPiece piece) {
    final isP1 = piece.player == 1;
    final pieceColor = isP1 ? const Color(0xFF38BDF8) : const Color(0xFFF43F5E);
    final innerColor = isP1 ? const Color(0xFF0284C7) : const Color(0xFFE11D48);

    return LayoutBuilder(
      builder: (context, constraints) {
        final diameter = constraints.maxWidth * 0.78;
        return Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [pieceColor, innerColor],
              center: const Alignment(-0.2, -0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: pieceColor.withValues(alpha: 0.45),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.8),
              width: 1.5,
            ),
          ),
          child: Center(
            child: piece.isKing
                ? const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 20)
                : Container(
                    width: diameter * 0.4,
                    height: diameter * 0.4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
                    ),
                  ),
          ),
        );
      },
    );
  }
}
