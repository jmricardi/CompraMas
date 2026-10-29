import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Lupa 3D interactiva de arcilla inflada con lente brillante,
/// flotación senoidal continua y barrido de luz (efecto Lottie nativo).
class AnimatedClayMagnifierIcon extends StatefulWidget {
  final double size;

  const AnimatedClayMagnifierIcon({super.key, this.size = 68.0});

  @override
  State<AnimatedClayMagnifierIcon> createState() =>
      _AnimatedClayMagnifierIconState();
}

class _AnimatedClayMagnifierIconState extends State<AnimatedClayMagnifierIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * 2 * math.pi;
        final floatY = math.sin(t) * 3.0;
        final tilt = math.cos(t * 0.8) * 0.05;
        final sweep = _controller.value;

        return Transform.translate(
          offset: Offset(0, floatY),
          child: Transform.rotate(
            angle: tilt,
            child: CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _AnimatedClayMagnifierPainter(sweepProgress: sweep),
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedClayMagnifierPainter extends CustomPainter {
  final double sweepProgress;

  _AnimatedClayMagnifierPainter({required this.sweepProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final center = Offset(w * 0.42, h * 0.42);
    final radius = w * 0.32;

    // 1. Mango de arcilla 3D (diagonal)
    final handlePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFDBA74),
          Color(0xFFEA580C),
          Color(0xFF9A3412),
        ],
      ).createShader(Rect.fromLTWH(w * 0.60, h * 0.60, w * 0.35, h * 0.35))
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * 0.16
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(w * 0.62, h * 0.62),
      Offset(w * 0.88, h * 0.88),
      handlePaint,
    );

    // Conector metálico / bisel
    final connectorPaint = Paint()
      ..color = const Color(0xFFFDE68A)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * 0.13
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(w * 0.58, h * 0.58),
      Offset(w * 0.66, h * 0.66),
      connectorPaint,
    );

    // 2. Sombra difusa bajo la lente
    canvas.drawCircle(
      center + const Offset(4, 6),
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // 3. Aro inflado de arcilla (Toroide 3D)
    final rimPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.4),
        radius: 0.9,
        colors: const [
          Color(0xFF6EE7B7),
          Color(0xFF10B981),
          Color(0xFF047857),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.14;

    canvas.drawCircle(center, radius, rimPaint);

    // 4. Lente translúcida
    final lensPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.25, -0.25),
        radius: 0.95,
        colors: [
          Colors.white.withValues(alpha: 0.65),
          const Color(0xFFA7F3D0).withValues(alpha: 0.35),
          const Color(0xFF047857).withValues(alpha: 0.20),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.85))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.85, lensPaint);

    // 5. Destello y barrido de luz dinámico (animación continua)
    final sweepAngle = (sweepProgress * 2 * math.pi) - math.pi;
    final shinePos = Offset(
      center.dx + (math.cos(sweepAngle) * radius * 0.45),
      center.dy + (math.sin(sweepAngle) * radius * 0.45),
    );

    canvas.drawCircle(
      shinePos,
      w * 0.05,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Arco de brillo superior de cristal
    final shinePath = Path()
      ..addArc(
        Rect.fromCircle(center: center, radius: radius * 0.68),
        -math.pi * 0.85,
        math.pi * 0.55,
      );
    final shinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.055
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.80);
    canvas.drawPath(shinePath, shinePaint);
  }

  @override
  bool shouldRepaint(covariant _AnimatedClayMagnifierPainter oldDelegate) =>
      oldDelegate.sweepProgress != sweepProgress;
}
