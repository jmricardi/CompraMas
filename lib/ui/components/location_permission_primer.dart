import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'clay/clay_squircle_card.dart';

/// Diálogo personalizado (Pre-Permission Primer) para solicitar ubicación con estética Claymorphism.
/// Android exige que el cuadro de diálogo final sea el nativo del sistema operativo (por seguridad de Android).
/// Sin embargo, la mejor práctica de UX es presentar previamente esta pantalla personalizada
/// que explica al usuario con amabilidad y transparencia por qué la app necesita la ubicación.
class LocationPermissionPrimerDialog extends StatelessWidget {
  const LocationPermissionPrimerDialog({super.key});

  static Future<bool> checkAndRequestLocation(BuildContext context) async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        return true;
      }
      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      if (!context.mounted) return false;

      // Mostrar pantalla explicativa personalizada antes del diálogo del sistema
      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (_) => const LocationPermissionPrimerDialog(),
      );

      if (accepted == true) {
        permission = await Geolocator.requestPermission();
        return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ClaySquircleCard(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        borderRadius: 32.0,
        baseColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF),
        animateOnPress: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícono 3D de ubicación en arcilla esmeralda
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(-0.35, -0.35),
                  colors: [
                    Color(0xFF6EE7B7),
                    Color(0xFF10B981),
                    Color(0xFF047857),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.location_on_rounded,
                size: 42,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Ubicación para Ahorrar',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'CompraMas compara precios reales de los supermercados y estaciones de combustible más cercanos a ti para que nunca pagues de más.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Ahora no',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text(
                      'Activar Ubicación',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
