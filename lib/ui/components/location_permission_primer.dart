import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'clay/clay_squircle_card.dart';

/// Diálogo unificado (Pre-Permission Primer) para solicitar permisos de
/// Ubicación y Cámara con estética Claymorphism 3D.
///
/// Explica al usuario con transparencia y estética de arcilla suave por qué
/// la app requiere la Ubicación (precios y cercanía de comercios) y la Cámara
/// (escaneo de códigos de barra), antes de presentar los cuadros de diálogo
/// nativos de Android.
class AppPermissionsPrimerDialog extends StatelessWidget {
  final bool needsLocation;
  final bool needsCamera;

  const AppPermissionsPrimerDialog({
    super.key,
    this.needsLocation = true,
    this.needsCamera = true,
  });

  /// Comprueba el estado de permisos y, si falta al menos uno, muestra la
  /// pantalla explicativa antes de solicitar los permisos nativos del sistema.
  static Future<bool> checkAndRequestPermissions(BuildContext context) async {
    try {
      final locStatus = await Permission.location.status;
      final camStatus = await Permission.camera.status;

      final isLocGranted = locStatus.isGranted || locStatus.isLimited;
      final isCamGranted = camStatus.isGranted || camStatus.isLimited;

      // Si ambos permisos ya fueron concedidos, no interrumpir al usuario
      if (isLocGranted && isCamGranted) {
        return true;
      }

      // Si alguno fue denegado permanentemente y el otro ya concedido, omitir
      if (locStatus.isPermanentlyDenied && camStatus.isPermanentlyDenied) {
        return false;
      }

      if (!context.mounted) return false;

      // Mostrar pantalla unificada con estética Claymorphism
      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (_) => AppPermissionsPrimerDialog(
          needsLocation: !isLocGranted && !locStatus.isPermanentlyDenied,
          needsCamera: !isCamGranted && !camStatus.isPermanentlyDenied,
        ),
      );

      if (accepted == true) {
        if (!isLocGranted && !locStatus.isPermanentlyDenied) {
          await Permission.location.request();
        }
        if (!isCamGranted && !camStatus.isPermanentlyDenied) {
          await Permission.camera.request();
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Método retrocompatible con llamadas previas
  static Future<bool> checkAndRequestLocation(BuildContext context) async {
    return checkAndRequestPermissions(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      child: ClaySquircleCard(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
        borderRadius: 32.0,
        baseColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF),
        animateOnPress: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Título principal y subtítulo
            Text(
              'Optimizá tu Ahorro',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Para comparar precios en tiempo real y encontrar las mejores ofertas cerca de ti:',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.65)
                    : const Color(0xFF64748B),
                height: 1.35,
              ),
            ),

            const SizedBox(height: 20),

            // 2. Tarjeta de Ubicación (3D Claymorphic)
            _PermissionFeatureTile(
              isDark: isDark,
              accentGradient: const [
                Color(0xFF34D399),
                Color(0xFF10B981),
                Color(0xFF047857),
              ],
              icon: Icons.location_on_rounded,
              title: 'Ubicación en Tiempo Real',
              description:
                  'Detecta los supermercados, comercios y estaciones de combustible más cercanos con sus mejores precios.',
            ),

            const SizedBox(height: 12),

            // 3. Tarjeta de Cámara (3D Claymorphic)
            _PermissionFeatureTile(
              isDark: isDark,
              accentGradient: const [
                Color(0xFF818CF8),
                Color(0xFF6366F1),
                Color(0xFF4338CA),
              ],
              icon: Icons.qr_code_scanner_rounded,
              title: 'Cámara para Escanear',
              description:
                  'Escanea códigos de barras directamente en la góndola para comparar precios al instante entre cadenas.',
            ),

            const SizedBox(height: 24),

            // 4. Botones de Acción
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Más tarde',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white60
                            : const Color(0xFF64748B),
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
                      elevation: 3,
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text(
                      'Continuar y Activar',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
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

/// Alias para mantener retrocompatibilidad exacta
typedef LocationPermissionPrimerDialog = AppPermissionsPrimerDialog;

class _PermissionFeatureTile extends StatelessWidget {
  final bool isDark;
  final List<Color> accentGradient;
  final IconData icon;
  final String title;
  final String description;

  const _PermissionFeatureTile({
    required this.isDark,
    required this.accentGradient,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ícono 3D inflado de arcilla
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.35),
                colors: accentGradient,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentGradient[1].withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, size: 24, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.65)
                        : const Color(0xFF475569),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
