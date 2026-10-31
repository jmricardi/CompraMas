import 'dart:math' as math;
import 'package:flutter/material.dart';

// ============================================================================
// 1. LUPA 3D INFLADA CON LENTE BRILLANTE / TRANSLÚCIDA (HERO)
// ============================================================================

class Clay3DMagnifierIcon extends StatelessWidget {
  final double size;

  const Clay3DMagnifierIcon({super.key, this.size = 56.0});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _Clay3DMagnifierPainter(),
    );
  }
}

class _Clay3DMagnifierPainter extends CustomPainter {
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

    // 2. Sombra suave bajo el aro de la lente
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

    // Brillo superior del aro
    final rimHighlight = Paint()
      ..shader = const SweepGradient(
        colors: [
          Colors.white,
          Colors.transparent,
          Colors.transparent,
          Colors.white,
        ],
        stops: [0.0, 0.3, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.04;
    canvas.drawCircle(center, radius + (w * 0.03), rimHighlight);

    // 4. Lente de cristal translúcida y brillante
    final lensRect = Rect.fromCircle(center: center, radius: radius * 0.82);

    final glassGradient = RadialGradient(
      center: const Alignment(-0.35, -0.35),
      radius: 0.85,
      colors: [
        Colors.white.withValues(alpha: 0.65),
        const Color(0xFF38BDF8).withValues(alpha: 0.28),
        const Color(0xFF0284C7).withValues(alpha: 0.12),
      ],
      stops: const [0.0, 0.55, 1.0],
    );
    canvas.drawOval(lensRect, Paint()..shader = glassGradient.createShader(lensRect));

    // Reflejo curvo especular sobre el cristal (crescent glass shine)
    final shinePath = Path()
      ..addArc(
        Rect.fromCircle(center: center, radius: radius * 0.68),
        -math.pi * 0.85,
        math.pi * 0.55,
      );
    final shinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.06
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.75);
    canvas.drawPath(shinePath, shinePaint);

    // Pequeño destello estelar secundario
    canvas.drawCircle(
      center + Offset(-radius * 0.35, -radius * 0.35),
      w * 0.04,
      Paint()..color = Colors.white.withValues(alpha: 0.90),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// 2. LIBRETA 3D CON INDICADOR DE ÍTEMS (SUPERMERCADO)
// ============================================================================

class Clay3DNotepadIcon extends StatefulWidget {
  final double size;
  final int itemCount;

  const Clay3DNotepadIcon({
    super.key,
    this.size = 52.0,
    this.itemCount = 0,
  });

  @override
  State<Clay3DNotepadIcon> createState() => _Clay3DNotepadIconState();
}

class _Clay3DNotepadIconState extends State<Clay3DNotepadIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    // Animación suave de flotación vertical y sutil respiración
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        final floatY = math.sin(_animController.value * math.pi) * 3.5;
        final tilt = (math.sin(_animController.value * math.pi * 2) * 0.04);
        return Transform.translate(
          offset: Offset(0, -floatY),
          child: Transform.rotate(
            angle: tilt,
            child: CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _Clay3DNotepadPainter(itemCount: widget.itemCount),
            ),
          ),
        );
      },
    );
  }
}

class _Clay3DNotepadPainter extends CustomPainter {
  final int itemCount;

  _Clay3DNotepadPainter({required this.itemCount});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Sombra proyectada
    final shadowRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.16, h * 0.18, w * 0.68, h * 0.72),
      const Radius.circular(16),
    );
    canvas.drawRRect(
      shadowRRect,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // 1. Tapa trasera de arcilla (Ámbar suave)
    final backRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.14, h * 0.14, w * 0.72, h * 0.74),
      const Radius.circular(16),
    );
    final backPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFDE68A), Color(0xFFF59E0B), Color(0xFFD97706)],
      ).createShader(backRRect.outerRect);
    canvas.drawRRect(backRRect, backPaint);

    // 2. Hoja frontal blanca/crema de arcilla
    final sheetRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.18, h * 0.22, w * 0.64, h * 0.64),
      const Radius.circular(12),
    );
    final sheetPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, Color(0xFFFEF3C7), Color(0xFFFDE68A)],
      ).createShader(sheetRRect.outerRect);
    canvas.drawRRect(sheetRRect, sheetPaint);

    // 3. Renglones / Checkmarks táctiles
    final linePaint = Paint()
      ..color = const Color(0xFFD97706).withValues(alpha: 0.45)
      ..strokeWidth = w * 0.038
      ..strokeCap = StrokeCap.round;

    final checkPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..strokeWidth = w * 0.045
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Fila 1 (Checked)
    canvas.drawLine(Offset(w * 0.38, h * 0.38), Offset(w * 0.72, h * 0.38), linePaint);
    final checkPath1 = Path()
      ..moveTo(w * 0.24, h * 0.38)
      ..lineTo(w * 0.28, h * 0.42)
      ..lineTo(w * 0.34, h * 0.34);
    canvas.drawPath(checkPath1, checkPaint);

    // Fila 2
    canvas.drawLine(Offset(w * 0.38, h * 0.52), Offset(w * 0.70, h * 0.52), linePaint);
    final checkPath2 = Path()
      ..moveTo(w * 0.24, h * 0.52)
      ..lineTo(w * 0.28, h * 0.56)
      ..lineTo(w * 0.34, h * 0.48);
    canvas.drawPath(checkPath2, checkPaint);

    // Fila 3
    canvas.drawLine(Offset(w * 0.26, h * 0.66), Offset(w * 0.65, h * 0.66), linePaint);

    // 4. Espiral superior de arcilla (3 anillas redondeadas)
    final ringPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFE2E8F0), Color(0xFF94A3B8), Color(0xFF475569)],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..strokeWidth = w * 0.075
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 3; i++) {
      final rx = w * (0.30 + (i * 0.20));
      canvas.drawLine(Offset(rx, h * 0.10), Offset(rx, h * 0.22), ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _Clay3DNotepadPainter oldDelegate) =>
      oldDelegate.itemCount != itemCount;
}

// ============================================================================
// 3. ETIQUETA COLGANTE 3D ANIMADA (DESCUENTOS / OFERTAS)
// ============================================================================

class Clay3DHangingTagIcon extends StatefulWidget {
  final double size;

  const Clay3DHangingTagIcon({super.key, this.size = 52.0});

  @override
  State<Clay3DHangingTagIcon> createState() => _Clay3DHangingTagIconState();
}

class _Clay3DHangingTagIconState extends State<Clay3DHangingTagIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _swingController;

  @override
  void initState() {
    super.initState();
    // Oscilación de péndulo relajada y continua
    _swingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _swingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _swingController,
      builder: (context, _) {
        // Balanceo armónico de ±11 grados
        final angle = (math.sin(_swingController.value * math.pi * 2) * 0.18);

        return Transform.rotate(
          angle: angle,
          alignment: const Alignment(0.0, -0.85),
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _Clay3DTagPainter(),
          ),
        );
      },
    );
  }
}

class _Clay3DTagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Cuerda colgante flexible
    final stringPaint = Paint()
      ..color = const Color(0xFFF43F5E).withValues(alpha: 0.6)
      ..strokeWidth = w * 0.05
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final stringPath = Path()
      ..moveTo(w * 0.50, h * 0.04)
      ..quadraticBezierTo(w * 0.44, h * 0.14, w * 0.50, h * 0.24);
    canvas.drawPath(stringPath, stringPaint);

    // 2. Silueta de la etiqueta de arcilla (rombo/hexágono redondeado)
    final tagPath = Path()
      ..moveTo(w * 0.50, h * 0.20) // Agujero superior
      ..lineTo(w * 0.78, h * 0.38)
      ..lineTo(w * 0.78, h * 0.86)
      ..lineTo(w * 0.22, h * 0.86)
      ..lineTo(w * 0.22, h * 0.38)
      ..close();

    // Sombra de la etiqueta
    canvas.drawPath(
      tagPath.shift(const Offset(3, 5)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Cuerpo de arcilla rojo coral suave
    final tagPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFDA4AF), Color(0xFFF43F5E), Color(0xFFBE123C)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(tagPath, tagPaint);

    // Agujero con remache metálico
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.32),
      w * 0.08,
      Paint()..color = const Color(0xFF881337),
    );
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.32),
      w * 0.05,
      Paint()..color = Colors.white,
    );

    // Símbolo de porcentaje '%' en relieve blanco de arcilla
    final textPainter = TextPainter(
      text: TextSpan(
        text: '%',
        style: TextStyle(
          color: Colors.white,
          fontSize: w * 0.38,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(
              color: const Color(0xFF9F1239).withValues(alpha: 0.6),
              offset: const Offset(1, 2),
              blurRadius: 2,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset((w - textPainter.width) * 0.50, h * 0.44),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// 4. SURTIDOR 3D REDONDEADO CON GOTA FLUIDA (COMBUSTIBLE)
// ============================================================================

class Clay3DFuelPumpIcon extends StatefulWidget {
  final double size;

  const Clay3DFuelPumpIcon({super.key, this.size = 52.0});

  @override
  State<Clay3DFuelPumpIcon> createState() => _Clay3DFuelPumpIconState();
}

class _Clay3DFuelPumpIconState extends State<Clay3DFuelPumpIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dripController;

  @override
  void initState() {
    super.initState();
    // Animación fluida de goteo / pulsación viva
    _dripController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat();
  }

  @override
  void dispose() {
    _dripController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _dripController,
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _Clay3DFuelPainter(dripProgress: _dripController.value),
        );
      },
    );
  }
}

class _Clay3DFuelPainter extends CustomPainter {
  final double dripProgress;

  _Clay3DFuelPainter({required this.dripProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Sombra suave del surtidor
    final pumpRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.16, h * 0.18, w * 0.48, h * 0.68),
      const Radius.circular(14),
    );
    canvas.drawRRect(
      pumpRRect.shift(const Offset(3, 5)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // 2. Cuerpo del surtidor de arcilla (Azul cielo suave)
    final pumpPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFBAE6FD), Color(0xFF0284C7), Color(0xFF0369A1)],
      ).createShader(pumpRRect.outerRect);
    canvas.drawRRect(pumpRRect, pumpPaint);

    // Pantalla digital del surtidor
    final screenRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.24, h * 0.28, w * 0.32, h * 0.20),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      screenRRect,
      Paint()..color = const Color(0xFF082F49).withValues(alpha: 0.85),
    );
    // Dígitos verdes fluorescentes simulados
    canvas.drawLine(
      Offset(w * 0.28, h * 0.38),
      Offset(w * 0.46, h * 0.38),
      Paint()
        ..color = const Color(0xFF4ADE80)
        ..strokeWidth = w * 0.04
        ..strokeCap = StrokeCap.round,
    );

    // 3. Manguera flexible redondeada
    final hosePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF334155), Color(0xFF0F172A)],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.07
      ..strokeCap = StrokeCap.round;

    final hosePath = Path()
      ..moveTo(w * 0.64, h * 0.38)
      ..cubicTo(w * 0.88, h * 0.42, w * 0.88, h * 0.65, w * 0.78, h * 0.70);
    canvas.drawPath(hosePath, hosePaint);

    // Pistola / Pico dispensador
    canvas.drawCircle(
      Offset(w * 0.78, h * 0.70),
      w * 0.065,
      Paint()..color = const Color(0xFF0284C7),
    );

    // 4. Gota de combustible fluida animada (con elongación)
    final dropProgress = dripProgress;
    final dropY = h * 0.72 + (dropProgress * h * 0.18);
    final dropAlpha = (1.0 - (dropProgress * 0.65)).clamp(0.0, 1.0);
    final dropScale = (1.0 - (dropProgress * 0.35)).clamp(0.3, 1.0);

    final dropCenter = Offset(w * 0.78, dropY);
    final dropPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        radius: 0.8,
        colors: [
          const Color(0xFF38BDF8).withValues(alpha: dropAlpha),
          const Color(0xFF0284C7).withValues(alpha: dropAlpha),
        ],
      ).createShader(Rect.fromCircle(center: dropCenter, radius: w * 0.07));

    canvas.drawOval(
      Rect.fromCenter(
        center: dropCenter,
        width: w * 0.09 * dropScale,
        height: w * 0.13 * dropScale,
      ),
      dropPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _Clay3DFuelPainter oldDelegate) =>
      oldDelegate.dripProgress != dripProgress;
}

// ============================================================================
// 5. ENGRANAJE 3D DE ARCILLA CON GIRO SUAVE (AJUSTES)
// ============================================================================

class Clay3DGearIcon extends StatefulWidget {
  final double size;

  const Clay3DGearIcon({super.key, this.size = 52.0});

  @override
  State<Clay3DGearIcon> createState() => _Clay3DGearIconState();
}

class _Clay3DGearIconState extends State<Clay3DGearIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    // Giro suave, continuo y relajante (18 segundos por revolución)
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, _) {
        return Transform.rotate(
          angle: _rotationController.value * 2 * math.pi,
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _Clay3DGearPainter(),
          ),
        );
      },
    );
  }
}

class _Clay3DGearPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w * 0.5, h * 0.5);
    final outerR = w * 0.42;
    final innerR = w * 0.32;
    const teethCount = 6;

    // Sombra del engranaje
    canvas.drawCircle(
      center + const Offset(2.5, 4.0),
      outerR,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Trayectoria del engranaje dentado
    final gearPath = Path();
    for (int i = 0; i < teethCount; i++) {
      final angle = (i * 2 * math.pi) / teethCount;
      final nextAngle = ((i + 1) * 2 * math.pi) / teethCount;
      final mid1 = angle + (nextAngle - angle) * 0.28;
      final mid2 = angle + (nextAngle - angle) * 0.72;

      final p1 = Offset(center.dx + innerR * math.cos(angle),
          center.dy + innerR * math.sin(angle));
      final p2 = Offset(center.dx + outerR * math.cos(mid1),
          center.dy + outerR * math.sin(mid1));
      final p3 = Offset(center.dx + outerR * math.cos(mid2),
          center.dy + outerR * math.sin(mid2));
      final p4 = Offset(center.dx + innerR * math.cos(nextAngle),
          center.dy + innerR * math.sin(nextAngle));

      if (i == 0) {
        gearPath.moveTo(p1.dx, p1.dy);
      } else {
        gearPath.lineTo(p1.dx, p1.dy);
      }
      gearPath.lineTo(p2.dx, p2.dy);
      gearPath.lineTo(p3.dx, p3.dy);
      gearPath.lineTo(p4.dx, p4.dy);
    }
    gearPath.close();

    // Cuerpo de arcilla (Lavanda / Pizarra moderno)
    final gearPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        radius: 0.9,
        colors: const [
          Color(0xFFE9D5FF),
          Color(0xFFA855F7),
          Color(0xFF6B21A8),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: outerR));

    canvas.drawPath(gearPath, gearPaint);

    // Orificio central con bisel interno
    canvas.drawCircle(
      center,
      w * 0.16,
      Paint()..color = const Color(0xFF581C87),
    );
    canvas.drawCircle(
      center,
      w * 0.13,
      Paint()..color = const Color(0xFFF1F5F9),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
