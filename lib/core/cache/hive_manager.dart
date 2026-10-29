import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Gestor central de persistencia local ultrarrápido y sin bloqueos con Hive.
/// Reemplaza completamente SharedPreferences con acceso síncrono en memoria (`boxSync`).
class HiveManager {
  static const String _boxName = 'compramas_cache';
  static Box? _box;

  /// Inicializar Hive y abrir la caja principal de CompraMas.
  static Future<void> init([String? customPath]) async {
    if (customPath != null) {
      Hive.init(customPath);
    } else {
      await Hive.initFlutter();
    }
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox(_boxName);
      debugPrint('[HiveManager] Box abierta exitosamente: $_boxName');
    } else {
      _box = Hive.box(_boxName);
    }
  }

  /// Obtener box de manera asíncrona con lazy initialization.
  static Future<Box> get box async {
    if (_box == null || !Hive.isBoxOpen(_boxName)) {
      await init();
    }
    return _box!;
  }

  /// Obtener box de manera síncrona (asume que init() fue llamado en el arranque).
  static Box get boxSync {
    if (_box == null && Hive.isBoxOpen(_boxName)) {
      _box = Hive.box(_boxName);
    }
    if (_box == null) {
      throw StateError('Hive box $_boxName no está abierta. Llama a init() primero.');
    }
    return _box!;
  }

  /// Get genérico asíncrono
  static Future<T?> get<T>(String key) async {
    try {
      final b = await box;
      return b.get(key) as T?;
    } catch (e) {
      debugPrint('[HiveManager] Error al leer $key: $e');
      return null;
    }
  }

  /// Get genérico síncrono (cero overhead de I/O)
  static T? getSync<T>(String key) {
    try {
      if (Hive.isBoxOpen(_boxName)) {
        return boxSync.get(key) as T?;
      }
      return null;
    } catch (e) {
      debugPrint('[HiveManager] Error al leer síncrono $key: $e');
      return null;
    }
  }

  /// Set genérico asíncrono
  static Future<void> set<T>(String key, T value) async {
    try {
      final b = await box;
      await b.put(key, value);
    } catch (e) {
      debugPrint('[HiveManager] Error al guardar $key: $e');
    }
  }

  /// Set genérico síncrono
  static void setSync<T>(String key, T value) {
    try {
      if (Hive.isBoxOpen(_boxName)) {
        boxSync.put(key, value);
      }
    } catch (e) {
      debugPrint('[HiveManager] Error al guardar síncrono $key: $e');
    }
  }

  /// Delete asíncrono
  static Future<void> delete(String key) async {
    try {
      final b = await box;
      await b.delete(key);
    } catch (e) {
      debugPrint('[HiveManager] Error al borrar $key: $e');
    }
  }

  /// Delete síncrono
  static void deleteSync(String key) {
    try {
      if (Hive.isBoxOpen(_boxName)) {
        boxSync.delete(key);
      }
    } catch (e) {
      debugPrint('[HiveManager] Error al borrar síncrono $key: $e');
    }
  }

  /// Limpiar toda la caja
  static Future<void> clear() async {
    try {
      final b = await box;
      await b.clear();
    } catch (e) {
      debugPrint('[HiveManager] Error al limpiar box: $e');
    }
  }

  /// Cantidad de elementos almacenados
  static Future<int> get size async {
    try {
      final b = await box;
      return b.length;
    } catch (e) {
      return 0;
    }
  }
}
