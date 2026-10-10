import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../app/routes.dart';
import '../models/game_match_model.dart';
import '../services/game_session_service.dart';
import '../viewmodels/auth_viewmodel.dart';

class GameInvitationOverlay extends StatefulWidget {
  final Widget child;
  final GameSessionService? sessionService;
  final GoRouter? router;

  const GameInvitationOverlay({
    super.key,
    required this.child,
    this.sessionService,
    this.router,
  });

  @override
  State<GameInvitationOverlay> createState() => _GameInvitationOverlayState();
}

class _GameInvitationOverlayState extends State<GameInvitationOverlay> {
  late final GameSessionService _service;
  StreamSubscription<List<GameMatchModel>>? _challengesSub;
  GameMatchModel? _currentChallenge;
  String? _lastUserId;
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    _service = widget.sessionService ?? GameSessionService();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted) {
        try {
          context.read<AuthViewModel>().refreshHeartbeat();
        } catch (_) {}
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthViewModel>();
    final user = auth.currentUser;
    final uid = user?.uid;

    if (user?.isInMatch == true && _currentChallenge != null) {
      _currentChallenge = null;
    }

    if (uid != _lastUserId) {
      _lastUserId = uid;
      _challengesSub?.cancel();
      _currentChallenge = null;

      if (uid != null && uid.isNotEmpty) {
        try {
          context.read<AuthViewModel>().refreshHeartbeat();
        } catch (_) {}
        _challengesSub = _service.streamIncomingChallenges(uid).listen((challenges) {
          if (!mounted) return;
          final isInMatch = context.read<AuthViewModel>().currentUser?.isInMatch ?? false;
          final validDirectInvites = challenges
              .where((c) => c.isDirectInvite && c.status == GameMatchStatus.pending)
              .toList();
          setState(() {
            if (validDirectInvites.isNotEmpty && !isInMatch) {
              _currentChallenge = validDirectInvites.first;
            } else {
              _currentChallenge = null;
            }
          });
        });
      }
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _challengesSub?.cancel();
    super.dispose();
  }

  Future<void> _handleAccept(GameMatchModel match) async {
    final updatedMatch = match.copyWith(status: GameMatchStatus.playing);
    setState(() => _currentChallenge = null);

    try {
      await _service.respondToChallenge(matchId: match.id, accept: true);
    } catch (_) {}

    final route = match.gameType == 'chess' ? AppRoutes.chess : AppRoutes.dama;
    _navigateToMatch(route, updatedMatch);
  }

  void _navigateToMatch(String route, GameMatchModel match) {
    if (widget.router != null) {
      widget.router!.push(route, extra: match);
      return;
    }

    final navContext = rootNavigatorKey.currentContext;
    if (navContext != null) {
      try {
        GoRouter.of(navContext).push(route, extra: match);
        return;
      } catch (_) {}
    }

    if (mounted) {
      try {
        context.push(route, extra: match);
      } catch (_) {}
    }
  }

  Future<void> _handleDecline(GameMatchModel match) async {
    setState(() => _currentChallenge = null);
    try {
      await _service.respondToChallenge(matchId: match.id, accept: false);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final hasChallenge = _currentChallenge != null;

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            offset: hasChallenge ? Offset.zero : const Offset(0, -1.2),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: hasChallenge ? 1.0 : 0.0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: hasChallenge
                      ? _buildNotificationBar(context, _currentChallenge!)
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationBar(BuildContext context, GameMatchModel challenge) {
    final isDama = challenge.gameType == 'dama';
    final gameLabel = isDama ? 'Dama' : 'Chess';

    return Material(
      color: Colors.transparent,
      elevation: 12,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF06B6D4).withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF06B6D4).withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  '⚔️',
                  style: TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06B6D4).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$gameLabel Match',
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Live Invitation',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      children: [
                        TextSpan(
                          text: challenge.hostName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF38BDF8),
                          ),
                        ),
                        const TextSpan(text: ' challenged you to play!'),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => _handleDecline(challenge),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Text(
                      'Decline',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                InkWell(
                  onTap: () => _handleAccept(challenge),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Accept',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
