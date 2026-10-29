import 'package:flutter/material.dart';

/// Ícono 3D de Tarjeta de Descuentos / Promociones en estética Claymorphism.
class Clay3DDiscountCardIcon extends StatelessWidget {
  final double size;

  const Clay3DDiscountCardIcon({super.key, this.size = 54.0});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _Clay3DDiscountCardPainter(),
    );
  }
}

class _Clay3DDiscountCardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Sombra proyectada
    final shadowRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.12, h * 0.22, w * 0.76, h * 0.56),
      const Radius.circular(16),
    );
    canvas.drawRRect(
      shadowRRect,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Cuerpo de la tarjeta 3D de arcilla (Magenta / Rosa fucsia)
    final cardRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.10, h * 0.18, w * 0.80, h * 0.58),
      const Radius.circular(16),
    );

    final cardPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFB7185),
          Color(0xFFE11D48),
          Color(0xFF881337),
        ],
      ).createShader(cardRRect.outerRect);
    canvas.drawRRect(cardRRect, cardPaint);

    // Bisel brillante superior
    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.03
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white70, Colors.transparent],
      ).createShader(cardRRect.outerRect);
    canvas.drawRRect(cardRRect, highlightPaint);

    // Chip dorado táctil
    final chipRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.20, h * 0.32, w * 0.20, h * 0.16),
      const Radius.circular(5),
    );
    final chipPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFDE68A), Color(0xFFF59E0B), Color(0xFFB45309)],
      ).createShader(chipRRect.outerRect);
    canvas.drawRRect(chipRRect, chipPaint);

    // Símbolo de porcentaje '%' o líneas de tarjeta en relieve suave
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.40)
      ..strokeWidth = w * 0.045
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(w * 0.46, h * 0.40), Offset(w * 0.78, h * 0.40), linePaint);
    canvas.drawLine(Offset(w * 0.20, h * 0.58), Offset(w * 0.60, h * 0.58), linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
