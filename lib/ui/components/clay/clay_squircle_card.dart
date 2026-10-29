import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Contenedor táctil con estética Claymorphism 3D y física de rebote elástico.
///
/// Características:
/// - Doble sombra suave (sombra exterior difusa + brillo superior claro).
/// - Gradiente sutil que simula volumen cóncavo/convexo de arcilla o goma mate.
/// - Bordes redondeados pronunciados (squircles con radio de 28 a 34 px).
/// - Reacción háptica e inmersiva al toque: se hunde al presionar y rebota con inercia elástica.
class ClaySquircleCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color baseColor;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;
  final Color? accentColor;
  final bool animateOnPress;

  const ClaySquircleCard({
    super.key,
    required this.child,
    this.onTap,
    this.baseColor = const Color(0xFFF1F5F9),
    this.borderRadius = 30.0,
    this.padding = const EdgeInsets.all(20.0),
    this.width,
    this.height,
    this.accentColor,
    this.animateOnPress = true,
  });

  @override
  State<ClaySquircleCard> createState() => _ClaySquircleCardState();
}

class _ClaySquircleCardState extends State<ClaySquircleCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _depthAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      reverseDuration: const Duration(milliseconds: 450),
    );

    // Animación de escala: se comprime ligeramente (0.95) y rebota con curva elástica
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.948).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: Curves.easeInOutQuad,
        reverseCurve: Curves.elasticOut,
      ),
    );

    // Animación de profundidad: simula hundimiento en la arcilla
    _depthAnimation = Tween<double>(begin: 1.0, end: 0.35).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: Curves.easeInOutQuad,
        reverseCurve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (!widget.animateOnPress || widget.onTap == null) return;
    HapticFeedback.lightImpact();
    _pressController.forward();
  }

  void _handleTapUp(TapUpDetails _) {
    if (!widget.animateOnPress || widget.onTap == null) return;
    _pressController.reverse();
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    if (!widget.animateOnPress || widget.onTap == null) return;
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = widget.baseColor;

    return AnimatedBuilder(
      animation: _pressController,
      builder: (context, child) {
        final depth = _depthAnimation.value;
        final scale = _scaleAnimation.value;

        // Sombras dinámicas moduladas por la presión
        final darkShadowColor = isDark
            ? Colors.black.withValues(alpha: 0.45 * depth)
            : const Color(0xFF0F172A).withValues(alpha: 0.12 * depth);

        final lightHighlightColor = isDark
            ? Colors.white.withValues(alpha: 0.08 * depth)
            : Colors.white.withValues(alpha: 0.85 * depth);

        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: widget.width,
              height: widget.height,
              padding: widget.padding,
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(base, Colors.white, isDark ? 0.06 : 0.45)!,
                    Color.lerp(base, Colors.black, isDark ? 0.20 : 0.04)!,
                  ],
                ),
                boxShadow: [
                  // Sombra difusa inferior derecha (volumen 3D)
                  BoxShadow(
                    color: darkShadowColor,
                    offset: Offset(7.0 * depth, 9.0 * depth),
                    blurRadius: 18.0 * depth + 4.0,
                    spreadRadius: 1.0,
                  ),
                  // Brillo superior izquierdo (bisel especular de arcilla)
                  BoxShadow(
                    color: lightHighlightColor,
                    offset: Offset(-5.0 * depth, -5.0 * depth),
                    blurRadius: 14.0 * depth + 2.0,
                    spreadRadius: 1.0,
                  ),
                  if (widget.accentColor != null)
                    BoxShadow(
                      color: widget.accentColor!.withValues(alpha: 0.15 * depth),
                      offset: Offset(0, 8.0 * depth),
                      blurRadius: 16.0 * depth,
                    ),
                ],
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : Colors.white.withValues(alpha: 0.70),
                  width: 1.5,
                ),
              ),
              child: widget.child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
