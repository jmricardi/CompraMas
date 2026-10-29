import 'package:flutter/material.dart';
import 'home/bento_home_screen.dart';

/// Pantalla Principal sin barra inferior rígida: Tablero interactivo Bento Grid
/// con estética 3D Claymorphism y física de rebote elástico.
class MainScaffoldScreen extends StatelessWidget {
  const MainScaffoldScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const BentoHomeScreen();
  }
}
