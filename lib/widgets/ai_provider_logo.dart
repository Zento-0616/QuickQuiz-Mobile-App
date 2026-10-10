import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Renders authentic vector-drawn logos for Google Gemini, OpenAI (ChatGPT), and DeepSeek.
class AiProviderLogo extends StatelessWidget {
  final AiProvider provider;
  final double size;
  final bool showBackground;

  const AiProviderLogo({
    super.key,
    required this.provider,
    this.size = 28,
    this.showBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget iconWidget;
    Color bgFill;
    Color borderColor;

    switch (provider) {
      case AiProvider.gemini:
        iconWidget = CustomPaint(
          size: Size(size, size),
          painter: _GeminiLogoPainter(),
        );
        bgFill = const Color(0xFF1E1B4B).withValues(alpha: 0.08);
        borderColor = const Color(0xFF6366F1).withValues(alpha: 0.25);
        break;

      case AiProvider.openAi:
        iconWidget = CustomPaint(
          size: Size(size, size),
          painter: _OpenAiLogoPainter(),
        );
        bgFill = const Color(0xFF10A37F).withValues(alpha: 0.1);
        borderColor = const Color(0xFF10A37F).withValues(alpha: 0.3);
        break;

      case AiProvider.deepSeek:
        iconWidget = CustomPaint(
          size: Size(size, size),
          painter: _DeepSeekLogoPainter(),
        );
        bgFill = const Color(0xFF0284C7).withValues(alpha: 0.1);
        borderColor = const Color(0xFF0284C7).withValues(alpha: 0.3);
        break;

      case AiProvider.grok:
        iconWidget = CustomPaint(
          size: Size(size, size),
          painter: _GrokLogoPainter(),
        );
        bgFill = const Color(0xFF334155).withValues(alpha: 0.15);
        borderColor = const Color(0xFF94A3B8).withValues(alpha: 0.35);
        break;

      case AiProvider.groq:
        iconWidget = CustomPaint(
          size: Size(size, size),
          painter: _GroqLogoPainter(),
        );
        bgFill = const Color(0xFFF55036).withValues(alpha: 0.12);
        borderColor = const Color(0xFFF55036).withValues(alpha: 0.4);
        break;

      case AiProvider.anthropic:
        iconWidget = CustomPaint(
          size: Size(size, size),
          painter: _AnthropicLogoPainter(),
        );
        bgFill = const Color(0xFFD97757).withValues(alpha: 0.12);
        borderColor = const Color(0xFFD97757).withValues(alpha: 0.4);
        break;
    }

    if (!showBackground) {
      return SizedBox(width: size, height: size, child: iconWidget);
    }

    return Container(
      width: size * 1.5,
      height: size * 1.5,
      decoration: BoxDecoration(
        color: bgFill,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: SizedBox(
          width: size,
          height: size,
          child: iconWidget,
        ),
      ),
    );
  }
}

/// Official Google Gemini 4-pointed sparkle gradient vector painter
class _GeminiLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    final rect = Rect.fromLTWH(0, 0, w, h);
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF38BDF8), // Cyan
          Color(0xFF4F46E5), // Indigo
          Color(0xFF9333EA), // Violet
          Color(0xFFEC4899), // Pink
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Curved 4-pointed Gemini star
    final path = Path();
    path.moveTo(center.dx, 0);
    path.quadraticBezierTo(center.dx, center.dy, w, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, h);
    path.quadraticBezierTo(center.dx, center.dy, 0, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, 0);
    path.close();

    canvas.drawPath(path, paint);

    // Inner bright center glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.85),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: w * 0.25))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, w * 0.25, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official OpenAI rosette / spiral geometric vector painter
class _OpenAiLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w * 0.44;

    final paint = Paint()
      ..color = const Color(0xFF10A37F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    // 6-petaled interlocking OpenAI knot
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60) * math.pi / 180;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);

      final path = Path();
      path.moveTo(0, -radius * 0.95);
      path.lineTo(radius * 0.45, -radius * 0.65);
      path.quadraticBezierTo(
        radius * 0.85,
        -radius * 0.35,
        radius * 0.8,
        0,
      );
      path.lineTo(radius * 0.5, radius * 0.15);

      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official DeepSeek whale / oceanic fin vector painter
class _DeepSeekLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final rect = Rect.fromLTWH(0, 0, w, h);
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF0284C7), // Deep Ocean Blue
          Color(0xFF2563EB), // Vivid Blue
          Color(0xFF1D4ED8), // Deep Blue
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomRight,
      ).createShader(rect)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Graceful leaping whale / fin silhouette
    final path = Path();
    // Start at dorsal fin tip
    path.moveTo(w * 0.48, h * 0.08);
    // Upper back arch down to tail
    path.cubicTo(w * 0.65, h * 0.20, w * 0.88, h * 0.40, w * 0.92, h * 0.72);
    // Tail fluke top
    path.quadraticBezierTo(w * 0.98, h * 0.78, w * 0.96, h * 0.90);
    // Tail notch
    path.quadraticBezierTo(w * 0.86, h * 0.88, w * 0.82, h * 0.76);
    // Lower belly curve
    path.cubicTo(w * 0.60, h * 0.88, w * 0.35, h * 0.90, w * 0.15, h * 0.78);
    // Snout / chin
    path.cubicTo(w * 0.05, h * 0.68, w * 0.08, h * 0.48, w * 0.22, h * 0.38);
    // Up along front edge to dorsal fin
    path.cubicTo(w * 0.32, h * 0.32, w * 0.42, h * 0.22, w * 0.48, h * 0.08);
    path.close();

    canvas.drawPath(path, paint);

    // Eye sparkle
    final eyePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.28, h * 0.52), w * 0.055, eyePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official xAI / Grok dynamic geometric X vector painter
class _GrokLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paintMain = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final paintSlash = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.18
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Primary diagonal line
    canvas.drawLine(
      Offset(w * 0.22, h * 0.82),
      Offset(w * 0.78, h * 0.18),
      paintSlash,
    );

    // Left chevron arm of the X
    final leftArm = Path()
      ..moveTo(w * 0.22, h * 0.18)
      ..lineTo(w * 0.42, h * 0.18)
      ..lineTo(w * 0.58, h * 0.38)
      ..lineTo(w * 0.46, h * 0.48)
      ..close();
    canvas.drawPath(leftArm, paintMain);

    // Right chevron arm of the X
    final rightArm = Path()
      ..moveTo(w * 0.78, h * 0.82)
      ..lineTo(w * 0.58, h * 0.82)
      ..lineTo(w * 0.42, h * 0.62)
      ..lineTo(w * 0.54, h * 0.52)
      ..close();
    canvas.drawPath(rightArm, paintMain);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official Groq warm orange rounded geometric G emblem vector painter
class _GroqLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w * 0.38;

    final strokePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFF55036), Color(0xFFFF7A59)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.18
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Outer G arc from 0.8pi to 2.2pi (roughly 45 deg to 360 deg)
    final arcRect = Rect.fromCircle(center: center, radius: radius);
    final arcPath = Path();
    arcPath.addArc(arcRect, 0.2 * math.pi, 1.65 * math.pi);
    canvas.drawPath(arcPath, strokePaint);

    // Inward horizontal bar of the 'G'
    final barPaint = Paint()
      ..color = const Color(0xFFF55036)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.18
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawLine(
      Offset(center.dx + radius * 0.85, center.dy + radius * 0.15),
      Offset(center.dx + radius * 0.1, center.dy + radius * 0.15),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official Anthropic geometric asterisk / terracotta emblem vector painter
class _AnthropicLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFD97757), Color(0xFFCC785C), Color(0xFFB45309)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * 0.14
      ..isAntiAlias = true;

    // Draw the 6-rayed geometric asterisk mark of Claude / Anthropic
    for (int i = 0; i < 3; i++) {
      final angle = i * (math.pi / 3);
      final dx = math.cos(angle) * (w * 0.38);
      final dy = math.sin(angle) * (h * 0.38);
      canvas.drawLine(
        Offset(center.dx - dx, center.dy - dy),
        Offset(center.dx + dx, center.dy + dy),
        paint,
      );
    }

    // Small warm core
    final corePaint = Paint()
      ..color = const Color(0xFFD97757)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, w * 0.1, corePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

