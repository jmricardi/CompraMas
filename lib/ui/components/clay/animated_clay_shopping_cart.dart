import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Ícono de Carrito de Compras animado con física de fluidos, oscilación elástica
/// y micro-movimientos tipo animación Lottie interactiva.
class AnimatedClayShoppingCart extends StatefulWidget {
  final double size;
  final VoidCallback? onTap;

  const AnimatedClayShoppingCart({
    super.key,
    this.size = 64.0,
    this.onTap,
  });

  @override
  State<AnimatedClayShoppingCart> createState() =>
      _AnimatedClayShoppingCartState();
}

class _AnimatedClayShoppingCartState extends State<AnimatedClayShoppingCart>
    with TickerProviderStateMixin {
  late final AnimationController _idleController;
  late final AnimationController _bounceController;

  @override
  void initState() {
    super.initState();

    // 1. Ciclo continuo de respiración y flotación suave (micro-motions)
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // 2. Rebote elástico e inmersivo al interactuar (fluid spring jump)
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void dispose() {
    _idleController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.mediumImpact();
    _bounceController.forward(from: 0.0);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: Listenable.merge([_idleController, _bounceController]),
        builder: (context, _) {
          final idleProgress = _idleController.value * 2 * math.pi;

          // Micro-movimientos continuos: flotación en Y y leve balanceo en rotación
          final idleY = math.sin(idleProgress) * 3.5;
          final idleAngle = math.sin(idleProgress * 0.7) * 0.04;
          final wheelSpin = math.cos(idleProgress) * 0.25;

          // Física de rebote reactivo (squash & stretch elástico)
          final bVal = _bounceController.value;
          double bounceY = 0.0;
          double scaleX = 1.0;
          double scaleY = 1.0;

          if (bVal > 0) {
            // Curva parabólica ascendente con compresión al aterrizar
            final jumpProgress = math.sin(bVal * math.pi);
            bounceY = -jumpProgress * 14.0;

            if (bVal < 0.2) {
              // Compresión inicial (preparando salto)
              scaleX = 1.08;
              scaleY = 0.92;
            } else if (bVal < 0.6) {
              // Estiramiento en el aire
              scaleX = 0.94;
              scaleY = 1.08;
            } else {
              // Rebote elástico final amortiguado
              final damp = math.exp(-3.5 * (bVal - 0.6)) *
                  math.cos(14.0 * (bVal - 0.6));
              scaleX = 1.0 + (0.12 * damp);
              scaleY = 1.0 - (0.12 * damp);
            }
          }

          return Transform.translate(
            offset: Offset(0, idleY + bounceY),
            child: Transform.rotate(
              angle: idleAngle,
              child: Transform.scale(
                scaleX: scaleX,
                scaleY: scaleY,
                child: CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _ClayShoppingCartPainter(
                    wheelRotation: wheelSpin + (bVal * math.pi * 2),
                    idleProgress: idleProgress,
                    isBouncing: _bounceController.isAnimating,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ClayShoppingCartPainter extends CustomPainter {
  final double wheelRotation;
  final double idleProgress;
  final bool isBouncing;

  _ClayShoppingCartPainter({
    required this.wheelRotation,
    required this.idleProgress,
    required this.isBouncing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Colores Claymorphism (paleta de arcilla verde esmeralda y menta)
    const clayPrimary = Color(0xFF10B981);
    const clayHighlight = Color(0xFF6EE7B7);
    const clayShadow = Color(0xFF047857);
    const clayDark = Color(0xFF064E3B);
    const wheelClay = Color(0xFF0F172A);
    const orangeItem = Color(0xFFF97316);
    const purpleItem = Color(0xFF8B5CF6);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    // 1. Sombra de contacto difusa bajo el carrito
    final shadowRect = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.95),
      width: w * 0.75,
      height: h * 0.12,
    );
    canvas.drawOval(shadowRect, shadowPaint);

    // 2. Productos dentro del canasto con micro-inercia
    final itemWobble = math.sin(idleProgress + 0.8) * 2.0;

    // Ítem 1: Manzana/Fruta redondeada
    final itemPaint1 = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.3, -0.4),
        radius: 0.8,
        colors: [Color(0xFFFDBA74), orangeItem, Color(0xFFC2410C)],
      ).createShader(Rect.fromCircle(
          center: Offset(w * 0.44, h * 0.36 + itemWobble), radius: w * 0.14));
    canvas.drawCircle(
        Offset(w * 0.44, h * 0.36 + itemWobble), w * 0.13, itemPaint1);

    // Ítem 2: Paquete/Caja redondeada
    final itemPaint2 = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFC4B5FD), purpleItem, Color(0xFF5B21B6)],
      ).createShader(Rect.fromLTWH(
          w * 0.52, h * 0.28 - itemWobble, w * 0.22, w * 0.24));
    final itemRRect2 = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.52, h * 0.28 - itemWobble, w * 0.20, w * 0.22),
      const Radius.circular(6),
    );
    canvas.drawRRect(itemRRect2, itemPaint2);

    // 3. Estructura y canasto del Carrito (Cuerpo Clay)
    final cartPath = Path()
      ..moveTo(w * 0.16, h * 0.28) // Manija inicio
      ..lineTo(w * 0.27, h * 0.35)
      ..lineTo(w * 0.34, h * 0.65) // Base trasera
      ..lineTo(w * 0.78, h * 0.65) // Base delantera
      ..lineTo(w * 0.88, h * 0.36) // Frente canasto
      ..lineTo(w * 0.30, h * 0.36); // Borde superior

    final cartStrokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [clayHighlight, clayPrimary, clayShadow],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(cartPath, cartStrokePaint);

    // 4. Malla interior de arcilla translúcida
    final meshPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.032
      ..strokeCap = StrokeCap.round
      ..color = clayDark.withValues(alpha: 0.35);

    // Rejillas horizontales y verticales
    canvas.drawLine(
        Offset(w * 0.33, h * 0.46), Offset(w * 0.84, h * 0.46), meshPaint);
    canvas.drawLine(
        Offset(w * 0.34, h * 0.55), Offset(w * 0.80, h * 0.55), meshPaint);
    canvas.drawLine(
        Offset(w * 0.48, h * 0.37), Offset(w * 0.48, h * 0.64), meshPaint);
    canvas.drawLine(
        Offset(w * 0.64, h * 0.37), Offset(w * 0.64, h * 0.64), meshPaint);

    // 5. Chasis inferior
    final chassisPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.065
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF334155);

    final chassisPath = Path()
      ..moveTo(w * 0.34, h * 0.65)
      ..lineTo(w * 0.40, h * 0.77)
      ..lineTo(w * 0.75, h * 0.77);
    canvas.drawPath(chassisPath, chassisPaint);

    // 6. Ruedas 3D infladas de arcilla con eje rotativo
    _drawClayWheel(canvas, Offset(w * 0.40, h * 0.83), w * 0.10, wheelClay,
        wheelRotation);
    _drawClayWheel(canvas, Offset(w * 0.74, h * 0.83), w * 0.10, wheelClay,
        wheelRotation);
  }

  void _drawClayWheel(
      Canvas canvas, Offset center, double radius, Color color, double angle) {
    // Sombra de rueda
    canvas.drawCircle(
      center + const Offset(1.5, 2.0),
      radius,
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );

    // Cuerpo neumático de goma mate
    final tirePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        radius: 0.9,
        colors: [
          const Color(0xFF64748B),
          color,
          Colors.black,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, tirePaint);

    // Llanta central de arcilla esmeralda
    final rimPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        radius: 0.8,
        colors: const [
          Color(0xFF6EE7B7),
          Color(0xFF10B981),
          Color(0xFF047857),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.55));
    canvas.drawCircle(center, radius * 0.52, rimPaint);

    // Eje con muesca de rotación sutil
    final notchOffset =
        Offset(math.cos(angle) * radius * 0.26, math.sin(angle) * radius * 0.26);
    canvas.drawCircle(
      center + notchOffset,
      radius * 0.12,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant _ClayShoppingCartPainter oldDelegate) => true;
}
