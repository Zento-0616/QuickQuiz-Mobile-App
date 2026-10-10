import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../services/local_storage_service.dart';

/// Premium animated Splash screen featuring a Gemini-style dancing aurora background,
/// concentric splash ripple shockwaves, an orbital celestial halo, a glossy 3D polished
/// glass logo with specular light sweep, smooth percentage loading progress bar,
/// and dynamic status micro-copy. Runs for 5-6 seconds (default 5.5s) to deliver an
/// immersive, mesmerizing loading effect.
class SplashView extends StatefulWidget {
  final Duration minDuration;

  const SplashView({
    super.key,
    this.minDuration = const Duration(milliseconds: 5500),
  });

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> with TickerProviderStateMixin {
  // Breathing and glow animation for logo
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _glowAnim;

  // Concentric splash ripple shockwave effect
  late final AnimationController _rippleController;

  // Orbiting celestial halo ring around the emblem
  late final AnimationController _orbitController;

  // Controller for continuous Gemini aurora dancing background
  late final AnimationController _auroraController;

  // Controller for glossy specular light sweep across the logo
  late final AnimationController _glossShimmerController;

  // Smooth progress bar animation over the 5-6 second duration
  late final AnimationController _progressController;
  late final Animation<double> _progressAnim;

  String _statusText = 'Initializing QuickQuiz...';

  @override
  void initState() {
    super.initState();

    // 1. Immediately dismiss OS native splash on first frame (< 1 second)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });

    // 2. Breathing / scale animation for logo
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowAnim = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 3. Concentric splash shockwave ripple controller (emanates every 2.4s)
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // 4. Orbiting halo particle ring around emblem (rotates smoothly every 3.8s)
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    )..repeat();

    // 5. Gemini dancing aurora background controller (continuous looping flow)
    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    )..repeat();

    // 6. Glossy specular light sweep shimmer controller (sweeps every 2.4s)
    _glossShimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // 7. Smooth progress bar animation over the 5-6s loading duration
    _progressController = AnimationController(
      vsync: this,
      duration: widget.minDuration,
    );

    _progressAnim = _progressController;

    // Dynamic staged micro-copy mapped continuously to progress
    _progressController.addListener(_onProgressUpdated);
    _progressController.forward();

    // 8. App initialization and navigation after 5-6s loading effect
    _initializeApp();
  }

  void _onProgressUpdated() {
    final p = _progressController.value;
    String newStatus;
    if (p < 0.20) {
      newStatus = 'Initializing QuickQuiz...';
    } else if (p < 0.42) {
      newStatus = 'Warming up AI engine & study modules...';
    } else if (p < 0.65) {
      newStatus = 'Preparing smart flashcards & quizzes...';
    } else if (p < 0.85) {
      newStatus = 'Personalizing your knowledge path...';
    } else if (p < 0.96) {
      newStatus = 'Optimizing offline study resources...';
    } else {
      newStatus = 'Ready to learn! Launching...';
    }

    if (newStatus != _statusText && mounted) {
      setState(() {
        _statusText = newStatus;
      });
    }
  }

  Future<void> _initializeApp() async {
    final minTimer = Future.delayed(widget.minDuration);

    String targetRoute = AppRoutes.home;
    try {
      final localStorage = LocalStorageService();
      final onboardingComplete = await localStorage.getOnboardingComplete();
      if (!onboardingComplete) {
        targetRoute = AppRoutes.onboarding;
      }
    } catch (e) {
      debugPrint('Error reading onboarding status in SplashView: $e');
    }

    // Wait until at least 5-6 seconds (widget.minDuration) have elapsed
    await minTimer;

    if (mounted) {
      context.go(targetRoute);
    }
  }

  @override
  void dispose() {
    _progressController.removeListener(_onProgressUpdated);
    _pulseController.dispose();
    _rippleController.dispose();
    _orbitController.dispose();
    _auroraController.dispose();
    _glossShimmerController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09061A),
      body: Stack(
        children: [
          // 1. Dancing Aurora Background (Gemini Fluid Aurora Borealis)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _auroraController,
              builder: (context, _) {
                return CustomPaint(
                  painter: GeminiAuroraPainter(
                    animationValue: _auroraController.value,
                  ),
                );
              },
            ),
          ),

          // 2. Subtle Star & Aurora Sparkle Dust Overlay
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _auroraController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _AuroraSparklePainter(
                    progress: _auroraController.value,
                  ),
                );
              },
            ),
          ),

          // 3. Main Centered Content
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),

                    // Animated Logo Centerpiece with Concentric Splash Ripples,
                    // Orbital Halo, Glossy 3D Effect & Glowing Aura
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Splash Effect: Expanding Concentric Shockwave Ripples
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: _rippleController,
                              builder: (context, _) {
                                return CustomPaint(
                                  painter: _AuraRipplePainter(
                                    animationValue: _rippleController.value,
                                  ),
                                );
                              },
                            ),
                          ),

                          // Orbital Celestial Ring with rotating spark
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: _orbitController,
                              builder: (context, _) {
                                return CustomPaint(
                                  painter: _OrbitalHaloPainter(
                                    progress: _orbitController.value,
                                  ),
                                );
                              },
                            ),
                          ),

                          // Animated Logo Emblem with Glossy 3D Effect & Glowing Aura
                          AnimatedBuilder(
                            animation: Listenable.merge([
                              _pulseController,
                              _glossShimmerController,
                            ]),
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _scaleAnim.value,
                                child: Container(
                                  width: 136,
                                  height: 136,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      // Outer celestial cyan glow
                                      BoxShadow(
                                        color: const Color(0xFF00F2FE)
                                            .withValues(alpha: _glowAnim.value * 0.45),
                                        blurRadius: 42,
                                        spreadRadius: 8,
                                      ),
                                      // Vibrant violet / purple aurora reflection
                                      BoxShadow(
                                        color: const Color(0xFF8B5CF6)
                                            .withValues(alpha: _glowAnim.value * 0.65),
                                        blurRadius: 30,
                                        spreadRadius: 4,
                                      ),
                                      // Inner ambient depth shadow
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.45),
                                        blurRadius: 18,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    clipBehavior: Clip.antiAlias,
                                    children: [
                                      // Base QuickQuiz circular emblem
                                      ClipOval(
                                        child: Image.asset(
                                          'assets/icons/quickquiz_logo.png',
                                          width: 136,
                                          height: 136,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            color: const Color(0xFF7B3FF2),
                                            child: const Icon(
                                              Icons.auto_awesome_rounded,
                                              size: 64,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Glossy Effect 1: Curved Glass Dome Specular Highlight
                                      Positioned(
                                        top: 2,
                                        left: 12,
                                        right: 12,
                                        height: 60,
                                        child: ClipRRect(
                                          borderRadius: const BorderRadius.vertical(
                                            top: Radius.circular(66),
                                            bottom: Radius.elliptical(54, 28),
                                          ),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.white.withValues(alpha: 0.55),
                                                  Colors.white.withValues(alpha: 0.18),
                                                  Colors.white.withValues(alpha: 0.0),
                                                ],
                                                stops: const [0.0, 0.45, 1.0],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Glossy Effect 2: Animated Specular Light Sweep Shimmer
                                      Positioned.fill(
                                        child: ClipOval(
                                          child: LayoutBuilder(
                                            builder: (context, constraints) {
                                              final shimmerProgress = _glossShimmerController.value;
                                              final shimmerOffset = shimmerProgress * 3.2 - 1.2;
                                              return Container(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment(shimmerOffset - 0.5, -1.0),
                                                    end: Alignment(shimmerOffset + 0.5, 1.0),
                                                    colors: [
                                                      Colors.transparent,
                                                      Colors.white.withValues(alpha: 0.0),
                                                      Colors.white.withValues(alpha: 0.35),
                                                      Colors.white.withValues(alpha: 0.65),
                                                      Colors.white.withValues(alpha: 0.35),
                                                      Colors.white.withValues(alpha: 0.0),
                                                      Colors.transparent,
                                                    ],
                                                    stops: const [0.0, 0.35, 0.47, 0.5, 0.53, 0.65, 1.0],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),

                                      // Glossy Effect 3: Polished Glass Rim / Beveled Ring Lighting
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white.withValues(alpha: 0.42),
                                              width: 2.2,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Glossy Effect 4: Bottom Ambient Reflective Rim
                                      Positioned(
                                        bottom: 4,
                                        left: 24,
                                        right: 24,
                                        height: 20,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(20),
                                            gradient: RadialGradient(
                                              colors: [
                                                const Color(0xFF00F2FE).withValues(alpha: 0.35),
                                                Colors.transparent,
                                              ],
                                              radius: 0.85,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Brand Typography
                    const Text(
                      'QuickQuiz',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        shadows: [
                          Shadow(
                            color: Color(0xFF8B5CF6),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Text(
                        'AI-POWERED EXAM PREPARATION',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.2,
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Progress Header: Section Name & Real-Time Percentage
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF00F2FE),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xFF00F2FE),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'PREPARING ENVIRONMENT',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          AnimatedBuilder(
                            animation: _progressAnim,
                            builder: (context, _) {
                              final pct = (_progressAnim.value * 100).clamp(0, 100).toInt();
                              return Text(
                                '$pct%',
                                style: const TextStyle(
                                  color: Color(0xFF00F2FE),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Animated Progress Loading Bar with Vibrant Gradient
                    AnimatedBuilder(
                      animation: _progressAnim,
                      builder: (context, _) {
                        final progress = _progressAnim.value.clamp(0.0, 1.0);
                        return Container(
                          width: double.infinity,
                          height: 7,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                              width: 0.8,
                            ),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF00F2FE), // Cyan highlight
                                    Color(0xFF7B3FF2), // Violet
                                    Color(0xFFA855F7), // Purple
                                    Color(0xFFEC4899), // Neon pink
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00F2FE).withValues(alpha: 0.65),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFFEC4899).withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Dynamic Status Micro-copy with Smooth Animated Transitions
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, 0.35),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            )),
                            child: child,
                          ),
                        );
                      },
                      child: Text(
                        _statusText,
                        key: ValueKey<String>(_statusText),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter rendering concentric splash ripple shockwaves expanding from the logo
class _AuraRipplePainter extends CustomPainter {
  final double animationValue;

  _AuraRipplePainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.32; // ~70px
    final maxExpansion = size.width * 0.18; // expands outward

    // 3 staggered concentric ripples
    for (int i = 0; i < 3; i++) {
      final waveProgress = (animationValue + (i / 3.0)) % 1.0;
      final currentRadius = baseRadius + (waveProgress * maxExpansion);
      final opacity = (1.0 - waveProgress).clamp(0.0, 1.0);
      final alpha = (opacity * 0.45 * sin(waveProgress * pi)).clamp(0.0, 1.0);

      if (alpha > 0.01) {
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2 * (1.0 - waveProgress * 0.5)
          ..shader = RadialGradient(
            colors: [
              i % 2 == 0
                  ? const Color(0xFF00F2FE).withValues(alpha: alpha)
                  : const Color(0xFF8B5CF6).withValues(alpha: alpha),
              const Color(0xFFEC4899).withValues(alpha: alpha * 0.6),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: currentRadius));

        canvas.drawCircle(center, currentRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AuraRipplePainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}

/// Rotating orbital halo ring with energetic satellite spark
class _OrbitalHaloPainter extends CustomPainter {
  final double progress;

  _OrbitalHaloPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.40;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final angle = progress * 2 * pi;

    final sweepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..shader = SweepGradient(
        startAngle: 0.0,
        endAngle: 2 * pi,
        transform: GradientRotation(angle),
        colors: [
          Colors.transparent,
          const Color(0xFF00F2FE).withValues(alpha: 0.05),
          const Color(0xFF8B5CF6).withValues(alpha: 0.45),
          const Color(0xFFEC4899).withValues(alpha: 0.65),
          const Color(0xFF00F2FE).withValues(alpha: 0.85),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 0.70, 0.88, 0.96, 1.0],
      ).createShader(rect);

    canvas.drawCircle(center, radius, sweepPaint);

    // Orbiting satellite spark
    final sparkX = center.dx + radius * cos(angle);
    final sparkY = center.dy + radius * sin(angle);
    final sparkPaint = Paint()
      ..color = const Color(0xFF00F2FE)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset(sparkX, sparkY), 3.0, sparkPaint);

    final sparkCorePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(sparkX, sparkY), 1.5, sparkCorePaint);
  }

  @override
  bool shouldRepaint(covariant _OrbitalHaloPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Custom painter rendering Gemini's fluid, waving aurora borealis colors
class GeminiAuroraPainter extends CustomPainter {
  final double animationValue;

  GeminiAuroraPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. Deep space night sky backdrop
    final basePaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF0A061C), // Deep midnight space
          Color(0xFF0D122E), // Rich cosmic blue-navy
          Color(0xFF140828), // Deep nebula violet
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect);
    canvas.drawRect(rect, basePaint);

    final t = animationValue * 2 * pi;

    // Aurora Blob 1: Cosmic Sapphire Blue (swirls top-left towards center)
    final dx1 = size.width * (0.35 + 0.25 * sin(t));
    final dy1 = size.height * (0.28 + 0.16 * cos(t * 0.8));
    final r1 = size.width * 0.65;
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF2563EB).withValues(alpha: 0.55),
          const Color(0xFF3B82F6).withValues(alpha: 0.22),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(dx1, dy1), radius: r1));
    canvas.drawCircle(Offset(dx1, dy1), r1, paint1);

    // Aurora Blob 2: Glowing Cyan / Celestial Teal (Gemini's electric cyan spark)
    final dx2 = size.width * (0.65 + 0.22 * cos(t * 1.2));
    final dy2 = size.height * (0.44 + 0.20 * sin(t * 0.9));
    final r2 = size.width * 0.55;
    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF00F2FE).withValues(alpha: 0.52),
          const Color(0xFF06B6D4).withValues(alpha: 0.22),
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(dx2, dy2), radius: r2));
    canvas.drawCircle(Offset(dx2, dy2), r2, paint2);

    // Aurora Blob 3: Vibrant Violet / Purple Plasma (dances bottom-left)
    final dx3 = size.width * (0.30 + 0.28 * sin(t * 0.7 + 1.2));
    final dy3 = size.height * (0.68 + 0.18 * cos(t * 1.1 + 0.4));
    final r3 = size.width * 0.70;
    final paint3 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF7C3AED).withValues(alpha: 0.58),
          const Color(0xFF9333EA).withValues(alpha: 0.25),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(dx3, dy3), radius: r3));
    canvas.drawCircle(Offset(dx3, dy3), r3, paint3);

    // Aurora Blob 4: Radiant Neon Pink / Magenta (vivid Gemini accent at top-right)
    final dx4 = size.width * (0.72 + 0.20 * sin(t * 1.3 + 2.0));
    final dy4 = size.height * (0.24 + 0.14 * sin(t * 0.6 + 1.5));
    final r4 = size.width * 0.50;
    final paint4 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFEC4899).withValues(alpha: 0.48),
          const Color(0xFFF43F5E).withValues(alpha: 0.16),
          Colors.transparent,
        ],
        stops: const [0.0, 0.42, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(dx4, dy4), radius: r4));
    canvas.drawCircle(Offset(dx4, dy4), r4, paint4);

    // 2. Fluid Dancing Aurora Wave Ribbon sweeping across the canvas
    final wavePath = Path();
    final waveY = size.height * (0.42 + 0.08 * sin(t));
    wavePath.moveTo(0, waveY);
    wavePath.cubicTo(
      size.width * 0.32,
      waveY - 70 * cos(t * 0.9),
      size.width * 0.68,
      waveY + 70 * sin(t * 0.9),
      size.width,
      waveY,
    );
    wavePath.lineTo(size.width, size.height);
    wavePath.lineTo(0, size.height);
    wavePath.close();

    final wavePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF00F2FE).withValues(alpha: 0.14),
          const Color(0xFFA855F7).withValues(alpha: 0.16),
          const Color(0xFF2563EB).withValues(alpha: 0.08),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawPath(wavePath, wavePaint);
  }

  @override
  bool shouldRepaint(covariant GeminiAuroraPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}

/// Floating subtle aurora star sparkles
class _AuroraSparklePainter extends CustomPainter {
  final double progress;

  _AuroraSparklePainter({required this.progress});

  static final List<Offset> _fixedStars = [
    const Offset(0.12, 0.16),
    const Offset(0.82, 0.20),
    const Offset(0.24, 0.38),
    const Offset(0.78, 0.54),
    const Offset(0.16, 0.68),
    const Offset(0.86, 0.74),
    const Offset(0.48, 0.12),
    const Offset(0.65, 0.88),
    const Offset(0.34, 0.84),
    const Offset(0.88, 0.36),
    const Offset(0.08, 0.48),
    const Offset(0.55, 0.32),
    const Offset(0.38, 0.22),
    const Offset(0.70, 0.72),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < _fixedStars.length; i++) {
      final s = _fixedStars[i];
      final phase = (progress * 2 * pi) + (i * 0.7);
      final alpha = (0.2 + 0.5 * sin(phase).abs()).clamp(0.0, 1.0);
      final radius = 1.0 + 1.3 * sin(phase).abs();

      final paint = Paint()
        ..color = (i % 3 == 0
                ? const Color(0xFF00F2FE)
                : (i % 3 == 1 ? const Color(0xFFEC4899) : const Color(0xFFA855F7)))
            .withValues(alpha: alpha);

      canvas.drawCircle(
        Offset(s.dx * size.width, s.dy * size.height),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraSparklePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
