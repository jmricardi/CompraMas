import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Carrito animado con física de fluidos aplicada sobre el PNG existente de CompraMas.
///
/// Implementa:
/// 1. Oscilación senoidal continua de flotación/respiración en reposo.
/// 2. Balanceo elástico (tilt de ±3°) que simula la inercia de productos.
/// 3. Salto periódico regular con física parabólica.
/// 4. Squash & Stretch elástico (compresión al agazaparse e impactar, estiramiento al elevarse).
/// 5. Sombra dinámica de suelo que reacciona reactivamente a la elevación.
class AnimatedPngCart extends StatefulWidget {
  final double size;
  final String imageAsset;
  final bool autoJump;
  final VoidCallback? onTap;

  const AnimatedPngCart({
    super.key,
    this.size = 110.0,
    this.imageAsset = 'assets/icons/icono_app.png',
    this.autoJump = true,
    this.onTap,
  });

  @override
  State<AnimatedPngCart> createState() => _AnimatedPngCartState();
}

class _AnimatedPngCartState extends State<AnimatedPngCart>
    with TickerProviderStateMixin {
  // 1. Controlador de flotación senoidal continua y balanceo
  late final AnimationController _breathController;

  // 2. Controlador de salto parabólico con squash & stretch
  late final AnimationController _jumpController;

  Timer? _autoJumpTimer;

  @override
  void initState() {
    super.initState();

    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _jumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    if (widget.autoJump) {
      // Disparar salto periódico cada 3.2 segundos
      _autoJumpTimer = Timer.periodic(const Duration(milliseconds: 3200), (_) {
        if (!mounted) return;
        if (!_jumpController.isAnimating) {
          _jumpController.forward(from: 0.0);
        }
      });
    }
  }

  @override
  void dispose() {
    _autoJumpTimer?.cancel();
    _breathController.dispose();
    _jumpController.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    if (!_jumpController.isAnimating) {
      _jumpController.forward(from: 0.0);
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final double totalHeight = widget.size * 1.35;
    final double totalWidth = widget.size * 1.25;

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: totalWidth,
        height: totalHeight,
        child: AnimatedBuilder(
          animation: Listenable.merge([_breathController, _jumpController]),
          builder: (context, _) {
            final double breathProgress = _breathController.value;
            final double jumpProgress = _jumpController.value;

            // --- 1. Cinemática de Salto y Squash & Stretch ---
            double jumpOffsetY = 0.0;
            double scaleX = 1.0;
            double scaleY = 1.0;

            if (_jumpController.isAnimating) {
              final double t = jumpProgress;

              if (t < 0.15) {
                // Fase 1: Agazapamiento previo al salto (Squash)
                final double prep = t / 0.15;
                scaleX = 1.0 + (0.15 * prep);
                scaleY = 1.0 - (0.15 * prep);
                jumpOffsetY = 2.0 * prep;
              } else if (t < 0.80) {
                // Fase 2: Ascenso, vértice parabólico y descenso (Stretch en aire)
                final double flight = (t - 0.15) / 0.65;
                // Parábola de altura máxima (hasta -38 px)
                jumpOffsetY = -math.sin(flight * math.pi) * 38.0;

                // Elongación vertical en el aire
                final double stretch = math.sin(flight * math.pi);
                scaleX = 1.0 - (0.10 * stretch);
                scaleY = 1.0 + (0.14 * stretch);
              } else {
                // Fase 3: Impacto contra el suelo y rebote amortiguado (Squash al aterrizar)
                final double landing = (t - 0.80) / 0.20;
                final double rebound = math.sin(landing * math.pi);
                scaleX = 1.0 + (0.16 * rebound);
                scaleY = 1.0 - (0.16 * rebound);
                jumpOffsetY = 1.5 * (1.0 - landing);
              }
            }

            // --- 2. Flotación senoidal y balanceo en reposo ---
            final double breathOffsetY =
                math.sin(breathProgress * 2.0 * math.pi) * 5.0;
            final double tiltAngle =
                math.sin(breathProgress * 2.0 * math.pi) * 0.052; // ±3 grados

            final double effectiveOffsetY = breathOffsetY + jumpOffsetY;

            // --- 3. Dinámica de Sombra de Suelo ---
            // Cuanto más alto salta, la sombra se vuelve más tenue y amplia
            final double normalizedElevation =
                (-jumpOffsetY / 38.0).clamp(0.0, 1.0);
            final double shadowScaleX = 1.0 + (0.25 * normalizedElevation);
            final double shadowOpacity =
                (0.28 - (0.16 * normalizedElevation)).clamp(0.06, 0.35);
            final double shadowBlur = 8.0 + (10.0 * normalizedElevation);

            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // A. Sombra dinámica de suelo
                Positioned(
                  bottom: widget.size * 0.06,
                  child: Transform.scale(
                    scaleX: shadowScaleX * scaleX,
                    child: Container(
                      width: widget.size * 0.72,
                      height: widget.size * 0.16,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.all(
                          Radius.elliptical(
                            widget.size * 0.72,
                            widget.size * 0.16,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: shadowOpacity),
                            blurRadius: shadowBlur,
                            spreadRadius: 2.0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // B. Carrito PNG animado con transformaciones combinadas
                Positioned(
                  bottom: (widget.size * 0.14) - effectiveOffsetY,
                  child: Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.diagonal3Values(scaleX, scaleY, 1.0)
                      ..rotateZ(tiltAngle),
                    child: Image.asset(
                      widget.imageAsset,
                      width: widget.size,
                      height: widget.size,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Image.asset(
                        'assets/icons/logo_transparent.png',
                        width: widget.size,
                        height: widget.size,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.shopping_cart_rounded,
                          size: widget.size * 0.85,
                          color: const Color(0xFF059669),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
