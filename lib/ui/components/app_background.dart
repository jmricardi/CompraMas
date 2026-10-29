import 'package:flutter/material.dart';

/// Widget de fondo unificado que envuelve las pantallas de la aplicación
/// con la imagen oficial compramas_background.png.
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: Colors.white,
            child: Image.asset(
              'assets/images/compramas_background.png',
              key: const ValueKey('app_compramas_background_v9'),
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (_, _, _) => const ColoredBox(color: Colors.white),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
