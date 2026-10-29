import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../config/app_config.dart';

class GeminiVoiceService {
  final AudioRecorder _recorder = AudioRecorder();
  final http.Client _httpClient = http.Client();
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  /// Inicia la grabación del micrófono.
  Future<bool> startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        debugPrint('[GeminiVoiceService] Permiso de micrófono denegado');
        return false;
      }

      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/voice_search_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 16000,
        ),
        path: filePath,
      );
      _isRecording = true;
      return true;
    } catch (e) {
      debugPrint('[GeminiVoiceService] Error iniciando grabación: $e');
      _isRecording = false;
      return false;
    }
  }

  /// Detiene la grabación y envía el audio a Google AI Studio (Gemini)
  /// para transcribir el número de código de barras o el nombre del producto.
  Future<String?> stopAndTranscribe() async {
    try {
      if (!_isRecording) return null;
      final path = await _recorder.stop();
      _isRecording = false;

      if (path == null) return null;
      final file = File(path);
      if (!await file.exists() || await file.length() < 400) {
        debugPrint('[GeminiVoiceService] Archivo de audio inexistente o demasiado breve');
        return null;
      }

      final bytes = await file.readAsBytes();
      final base64Audio = base64Encode(bytes);

      // Limpieza del archivo temporal
      unawaited(file.delete().catchError((_) => file));

      return await _transcribeWithGemini(base64Audio, mimeType: 'audio/m4a');
    } catch (e) {
      debugPrint('[GeminiVoiceService] Error al transcribir: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Cancela la grabación sin procesar
  Future<void> cancelRecording() async {
    try {
      if (_isRecording) {
        final path = await _recorder.stop();
        _isRecording = false;
        if (path != null) {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }
    } catch (_) {
      _isRecording = false;
    }
  }

  Future<String?> _transcribeWithGemini(
    String base64Audio, {
    String mimeType = 'audio/m4a',
  }) async {
    var apiKey = AppConfig.geminiApiKey;
    if (apiKey.isEmpty) {
      await AppConfig.loadConfig();
      apiKey = AppConfig.geminiApiKey;
    }
    if (apiKey.isEmpty) {
      debugPrint('[GeminiVoiceService] GEMINI_API_KEY no configurada');
      return null;
    }

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
    );

    const prompt = '''
Transcribe con exactitud el audio del usuario para el buscador de productos de supermercado en Argentina:
1. Si el usuario dice dígitos o números (ej: "siete siete nueve cero...", "dos cero cero cero..."), conviértelos a una secuencia numérica continua sin espacios ni guiones (ej: "7790895000997").
2. Si el usuario dice el nombre de un producto, marca o variedad (ej: "leche entera la serenísima", "kiwi por kilo", "arroz lucchetti"), transcribe el nombre limpio y claro.
3. Devuelve ÚNICAMENTE el texto o número transcrito. No agregues comillas, explicaciones ni puntos finales.
''';

    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Audio,
              }
            },
            {
              'text': prompt,
            }
          ]
        }
      ]
    });

    final res = await _httpClient.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: requestBody,
    ).timeout(const Duration(seconds: 12));

    if (res.statusCode == 200) {
      final jsonRes =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final candidates = jsonRes['candidates'] as List<dynamic>?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates.first['content'] as Map<String, dynamic>?;
        final parts = content?['parts'] as List<dynamic>?;
        if (parts != null && parts.isNotEmpty) {
          final text = parts.first['text']?.toString().trim() ?? '';
          return _cleanTranscription(text);
        }
      }
    } else {
      debugPrint(
          '[GeminiVoiceService] Error API Gemini: ${res.statusCode} ${res.body}');
    }
    return null;
  }

  String _cleanTranscription(String raw) {
    var text = raw.trim();
    if ((text.startsWith('"') && text.endsWith('"')) ||
        (text.startsWith("'") && text.endsWith("'"))) {
      text = text.substring(1, text.length - 1).trim();
    }
    if (text.endsWith('.')) {
      text = text.substring(0, text.length - 1).trim();
    }
    return text;
  }

  void dispose() {
    _recorder.dispose();
  }
}
