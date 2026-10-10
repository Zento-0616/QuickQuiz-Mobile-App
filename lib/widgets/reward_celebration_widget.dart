import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/reward_effect_service.dart';

void showRewardCelebrationOverlay(
  BuildContext context,
  RewardCelebrationPayload payload,
) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _RewardOverlayContent(
      payload: payload,
      onDismissed: () {
        if (entry.mounted) {
          entry.remove();
        }
      },
    ),
  );

  overlay.insert(entry);
}

class _RewardOverlayContent extends StatefulWidget {
  final RewardCelebrationPayload payload;
  final VoidCallback onDismissed;

  const _RewardOverlayContent({
    required this.payload,
    required this.onDismissed,
  });

  @override
  State<_RewardOverlayContent> createState() => _RewardOverlayContentState();
}

class _RewardOverlayContentState extends State<_RewardOverlayContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _particleAnim;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    _scaleAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.25, curve: Curves.elasticOut),
    );

    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.75, 1.0, curve: Curves.easeIn),
    );

    _particleAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.85, curve: Curves.easeOutCubic),
    );

    final rng = math.Random();
    _particles = List.generate(35, (i) {
      final angle = (rng.nextDouble() * 2 * math.pi);
      final speed = 80.0 + rng.nextDouble() * 180.0;
      final size = 4.0 + rng.nextDouble() * 6.0;
      final color = _pickParticleColor(widget.payload.type, rng);
      final isStar = rng.nextBool();
      return _Particle(
        dx: math.cos(angle) * speed,
        dy: math.sin(angle) * speed - 50.0,
        size: size,
        color: color,
        isStar: isStar,
        rotation: rng.nextDouble() * math.pi,
      );
    });

    _controller.forward().then((_) {
      widget.onDismissed();
    });
  }

  Color _pickParticleColor(RewardType type, math.Random rng) {
    const goldColors = [
      Color(0xFFF59E0B),
      Color(0xFFFBBF24),
      Color(0xFFFCD34D),
      Color(0xFF10B981),
      Color(0xFF38BDF8),
      Color(0xFFA855F7),
    ];
    return goldColors[rng.nextInt(goldColors.length)];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final payload = widget.payload;
    final accentColor = payload.accentColor ?? _defaultAccentColor(payload.type);
    final iconData = payload.customIcon ?? _defaultIcon(payload.type);

    return Positioned.fill(
      child: IgnorePointer(
        child: Material(
          type: MaterialType.transparency,
          child: AnimatedBuilder(
            animation: _controller,
          builder: (context, _) {
            final opacity = (1.0 - _fadeAnim.value).clamp(0.0, 1.0);
            return Opacity(
              opacity: opacity,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Positioned(
                    top: 130,
                    child: CustomPaint(
                      painter: _ConfettiPainter(
                        particles: _particles,
                        progress: _particleAnim.value,
                      ),
                    ),
                  ),

                  Positioned(
                    top: 70,
                    left: 20,
                    right: 20,
                    child: Center(
                      child: Transform.scale(
                        scale: _scaleAnim.value,
                        alignment: Alignment.center,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 380),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF0F172A).withValues(alpha: 0.95),
                                const Color(0xFF1E293B).withValues(alpha: 0.95),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.8),
                              width: 1.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.35),
                                blurRadius: 24,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: accentColor.withValues(alpha: 0.2),
                                  border: Border.all(
                                    color: accentColor.withValues(alpha: 0.6),
                                    width: 1.2,
                                  ),
                                ),
                                child: Icon(iconData, color: accentColor, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      payload.title.toUpperCase(),
                                      style: TextStyle(
                                        color: accentColor,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      payload.rewardText,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        height: 1.15,
                                      ),
                                    ),
                                    if (payload.subtitle != null &&
                                        payload.subtitle!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        payload.subtitle!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        ),
      ),
    );
  }

  Color _defaultAccentColor(RewardType type) {
    switch (type) {
      case RewardType.xp:
        return const Color(0xFFF59E0B);
      case RewardType.coin:
        return const Color(0xFFFBBF24);
      case RewardType.achievement:
        return const Color(0xFFA855F7);
      case RewardType.quizComplete:
        return const Color(0xFF10B981);
    }
  }

  IconData _defaultIcon(RewardType type) {
    switch (type) {
      case RewardType.xp:
        return Icons.star_rounded;
      case RewardType.coin:
        return Icons.monetization_on_rounded;
      case RewardType.achievement:
        return Icons.workspace_premium_rounded;
      case RewardType.quizComplete:
        return Icons.task_alt_rounded;
    }
  }
}

class _Particle {
  final double dx;
  final double dy;
  final double size;
  final Color color;
  final bool isStar;
  final double rotation;

  _Particle({
    required this.dx,
    required this.dy,
    required this.size,
    required this.color,
    required this.isStar,
    required this.rotation,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final currentX = p.dx * progress;
      final currentY = (p.dy * progress) + (90.0 * progress * progress);
      final currentOpacity = (1.0 - progress * 0.7).clamp(0.0, 1.0);

      paint.color = p.color.withValues(alpha: currentOpacity);

      canvas.save();
      canvas.translate(currentX, currentY);
      canvas.rotate(p.rotation + progress * 4);

      if (p.isStar) {
        _drawStar(canvas, p.size, paint);
      } else {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      }
      canvas.restore();
    }
  }

  void _drawStar(Canvas canvas, double size, Paint paint) {
    final path = Path();
    final half = size / 2;
    path.moveTo(0, -half);
    path.lineTo(half * 0.3, -half * 0.3);
    path.lineTo(half, 0);
    path.lineTo(half * 0.3, half * 0.3);
    path.lineTo(0, half);
    path.lineTo(-half * 0.3, half * 0.3);
    path.lineTo(-half, 0);
    path.lineTo(-half * 0.3, -half * 0.3);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
