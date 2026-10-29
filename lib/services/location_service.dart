import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Evita volver a disparar el diálogo nativo del sistema si el usuario ya lo rechazó en esta sesión
  static bool _permissionPromptedThisSession = false;

  static Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (_permissionPromptedThisSession) {
          // El usuario ya decidió en esta sesión; no volver a interrumpir con el popup
          return null;
        }
        _permissionPromptedThisSession = true;
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // 1. Intentar recuperar de inmediato la última ubicación conocida (0ms de latencia)
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          return lastKnown;
        }
      } catch (_) {}

      // 2. Si no hay última posición previa, solicitar posición actual con timeout ágil de 2 segundos
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 2),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  static double calculateDistanceMeters(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }
}
