import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'main_scaffold_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    PaintingBinding.instance.imageCache.evict(const AssetImage('assets/images/compramas_background.png'));
    _startTimer();
  }

  Future<void> _requestInitialPermissions() async {
    try {
      // 1. Permiso de ubicación inicial
      final locStatus = await Geolocator.checkPermission();
      if (locStatus == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (_) {}
  }

  void _startTimer() async {
    debugPrint('[SplashScreen] Solicitando permisos iniciales...');
    await Future.wait([
      _requestInitialPermissions(),
      Future.delayed(const Duration(seconds: 2)),
    ]);
    debugPrint('[SplashScreen] Temporizador finalizado. mounted=$mounted');
    if (!mounted) return;

    try {
      debugPrint('[SplashScreen] Navegando hacia MainScaffoldScreen...');
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const MainScaffoldScreen(),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
      debugPrint('[SplashScreen] Navegación ejecutada con éxito.');
    } catch (e, stack) {
      debugPrint('[SplashScreen] Error durante la navegación: $e\n$stack');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Imagen oficial de fondo de CompraMas (nueva versión)
          Positioned.fill(
            child: Image.asset(
              'assets/images/compramas_background.png',
              key: const ValueKey('splash_compramas_background_v9'),
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (_, _, _) => const ColoredBox(color: Colors.white),
            ),
          ),
          // 2. Contenido principal en primer plano
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/icons/icono_app.png',
                      width: 108,
                      height: 108,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.shopping_cart,
                        size: 96,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'CompraMas',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Precios, nutrición y ahorro inteligente',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

