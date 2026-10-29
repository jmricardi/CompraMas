import 'dart:math' as math;
import 'package:flutter/material.dart';

enum SealType {
  sugars,
  sodium,
  totalFats,
  saturatedFats,
  calories,
  sweeteners,
  caffeine,
  sinTacc,
  custom,
}

class OctagonSealBadge extends StatelessWidget {
  final SealType type;
  final String? customText;
  final double size;

  const OctagonSealBadge({
    super.key,
    required this.type,
    this.customText,
    this.size = 78.0,
  });

  factory OctagonSealBadge.fromTag(String rawTag) {
    final clean = rawTag.toLowerCase().replaceAll(RegExp(r'^(es:|en:|fr:)'), '');

    if (clean.contains('azucar') || clean.contains('sugar')) {
      return const OctagonSealBadge(type: SealType.sugars);
    }
    if (clean.contains('sodio') || clean.contains('sodium') || clean.contains('salt')) {
      return const OctagonSealBadge(type: SealType.sodium);
    }
    if (clean.contains('grasas-saturadas') || clean.contains('saturated-fat')) {
      return const OctagonSealBadge(type: SealType.saturatedFats);
    }
    if (clean.contains('grasas-totales') || clean.contains('grasas') || clean.contains('fat')) {
      return const OctagonSealBadge(type: SealType.totalFats);
    }
    if (clean.contains('caloria') || clean.contains('calorie') || clean.contains('energy')) {
      return const OctagonSealBadge(type: SealType.calories);
    }
    if (clean.contains('edulcorante') || clean.contains('sweetener')) {
      return const OctagonSealBadge(type: SealType.sweeteners);
    }
    if (clean.contains('cafeina') || clean.contains('caffeine')) {
      return const OctagonSealBadge(type: SealType.caffeine);
    }
    if (clean.contains('tacc') || clean.contains('gluten')) {
      return const OctagonSealBadge(type: SealType.sinTacc);
    }

    return OctagonSealBadge(
      type: SealType.custom,
      customText: clean.replaceAll('-', ' ').toUpperCase(),
    );
  }

  static bool isSystemNameTag(String tag) {
    final lower = tag.toLowerCase();
    return lower.contains('sistema-de-etiquetado-frontal') ||
        lower.contains('sistema de etiquetado frontal') ||
        lower.contains('etiquetado-frontal') ||
        lower.contains('nutritional-warnings');
  }

  @override
  Widget build(BuildContext context) {
    if (type == SealType.sweeteners || type == SealType.caffeine) {
      return _buildRectangularWarning();
    }
    if (type == SealType.sinTacc) {
      return _buildSinTaccBadge();
    }
    return _buildOctagon();
  }

  Widget _buildOctagon() {
    final (title, subtitle) = _getOctagonTexts();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _OctagonPainter(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'EXCESO EN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  height: 1.0,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                  height: 1.05,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: size * 0.08,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                    height: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  (String, String?) _getOctagonTexts() {
    switch (type) {
      case SealType.sugars:
        return ('AZÚCARES', 'Ministerio de Salud');
      case SealType.sodium:
        return ('SODIO', 'Ministerio de Salud');
      case SealType.totalFats:
        return ('GRASAS\nTOTALES', 'Ministerio de Salud');
      case SealType.saturatedFats:
        return ('GRASAS\nSATURADAS', 'Ministerio de Salud');
      case SealType.calories:
        return ('CALORÍAS', 'Ministerio de Salud');
      case SealType.custom:
        return (customText ?? 'ADVERTENCIA', null);
      default:
        return ('ADVERTENCIA', null);
    }
  }

  Widget _buildRectangularWarning() {
    final isSweetener = type == SealType.sweeteners;
    final primary = isSweetener ? 'CONTIENE EDULCORANTES' : 'CONTIENE CAFEÍNA';
    final secondary = isSweetener
        ? 'NO RECOMENDABLE EN NIÑOS/AS'
        : 'EVITAR EN NIÑOS/AS';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            primary,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            secondary,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9.0,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSinTaccBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF166534), // Verde oscuro oficial
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF22C55E), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, color: Colors.white, size: 16),
          SizedBox(width: 5),
          Text(
            'SIN T.A.C.C.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _OctagonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Factor de corte para un octógono regular (1 / (1 + sqrt(2)) ~ 0.29289)
    final c = w * (1.0 / (1.0 + math.sqrt(2)));

    final path = Path()
      ..moveTo(c, 0)
      ..lineTo(w - c, 0)
      ..lineTo(w, c)
      ..lineTo(w, h - c)
      ..lineTo(w - c, h)
      ..lineTo(c, h)
      ..lineTo(0, h - c)
      ..lineTo(0, c)
      ..close();

    // Fondo negro
    final fillPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Borde blanco interior
    final strokePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
