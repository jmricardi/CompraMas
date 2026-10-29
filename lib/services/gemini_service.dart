import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/product_model.dart';

class GeminiService {
  final http.Client _client;

  GeminiService({http.Client? client}) : _client = client ?? http.Client();

  Future<String> fetchHealthierAlternatives(
    OffProduct product, {
    String targetLanguage = 'Español',
  }) async {
    final apiKey = AppConfig.geminiApiKey;
    if (apiKey.isEmpty || apiKey == 'MY_GEMINI_API_KEY') {
      return targetLanguage == 'English'
          ? 'Configure your GEMINI_API_KEY in Settings to get AI recommendations.'
          : targetLanguage == 'Português'
              ? 'Configure sua GEMINI_API_KEY nas Configurações para obter recomendações de IA.'
              : targetLanguage == "Avañe'ẽ"
                  ? 'Emohenda ne GEMINI_API_KEY Ajustes-pe rehupyty haguã marandu IA rupive.'
                  : 'Configura tu GEMINI_API_KEY en los Ajustes o en config.json para recibir sugerencias saludables y análisis con IA.';
    }

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
    );

    final langInstruction = switch (targetLanguage) {
      'English' => 'Write your response in friendly English.',
      'Português' => 'Escreva sua resposta em português amigável.',
      "Avañe'ẽ" => "Ehai ne mbohovái avañe'ẽme (Guarani) térã joparápe.",
      _ => 'Escribe una respuesta concisa, práctica y en español rioplatense amigable.',
    };

    final prompt = '''
You are an expert nutritional advisor. Analyze the following supermarket food product and suggest 2 or 3 healthier and accessible alternatives:
- Name: ${product.productName ?? 'Unknown'}
- Brand: ${product.brands ?? 'Unknown'}
- Net quantity: ${product.quantity ?? 'Unknown'}
- NOVA Group (processing): ${product.novaGroup ?? 'Unknown'}
- Eco-Score: ${product.ecoscoreGrade?.toUpperCase() ?? 'Unknown'}
- Ingredients: ${product.ingredientsText ?? 'Not detailed'}
- Nutri-Score: ${product.nutriscoreGrade?.toUpperCase() ?? 'Not specified'}
- Calories (100g): ${product.nutriments?.energyKcal ?? 'N/D'} kcal
- Sugars (100g): ${product.nutriments?.sugars ?? 'N/D'} g
- Saturated Fat: ${product.nutriments?.saturatedFat ?? 'N/D'} g
- Sodium/Salt: ${product.nutriments?.salt ?? 'N/D'} g

$langInstruction
''';

    final body = json.encode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ]
    });

    try {
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final candidates = data['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            return parts[0]['text'] as String? ?? 'No se recibieron sugerencias.';
          }
        }
        return 'No se pudo generar una alternativa en este momento.';
      } else {
        return 'No se pudieron obtener alternativas (${response.statusCode}).';
      }
    } catch (e) {
      return 'Error al conectar con el servicio de IA: $e';
    }
  }
}
