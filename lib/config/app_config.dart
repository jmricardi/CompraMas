import 'dart:convert';
import 'package:flutter/services.dart';

class AppConfig {
  static String supabaseUrl = 'https://ajrmzynmfmudcrsrcbjo.supabase.co';
  static String supabaseAnonKey = 'sb_publishable_FiWGvC0DR2Caw2tyF77x5Q_K99-0ToK';
  static String geminiApiKey = '';
  static String offBaseUrl = 'https://world.openfoodfacts.org';
  static String fuelBaseUrl = 'https://datos.energia.gob.ar';

  static Future<void> loadConfig() async {
    try {
      final jsonString = await rootBundle.loadString('config.json');
      final data = json.decode(jsonString) as Map<String, dynamic>;
      if (data.containsKey('supabase')) {
        final sb = data['supabase'] as Map<String, dynamic>;
        supabaseUrl = sb['project_url'] ?? supabaseUrl;
        supabaseAnonKey = sb['public_key'] ?? supabaseAnonKey;
      }
      if (data.containsKey('GEMINI_API_KEY')) {
        geminiApiKey = data['GEMINI_API_KEY'] ?? '';
      } else if (data.containsKey('gemini_api_key')) {
        geminiApiKey = data['gemini_api_key'] ?? '';
      }
    } catch (_) {
      // Usar valores por defecto si no se puede leer el archivo
    }
  }
}
