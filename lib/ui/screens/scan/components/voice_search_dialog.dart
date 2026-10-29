import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../services/gemini_voice_service.dart';

class VoiceSearchDialog extends StatefulWidget {
  const VoiceSearchDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VoiceSearchDialog(),
    );
  }

  @override
  State<VoiceSearchDialog> createState() => _VoiceSearchDialogState();
}

class _VoiceSearchDialogState extends State<VoiceSearchDialog>
    with SingleTickerProviderStateMixin {
  final GeminiVoiceService _voiceService = GeminiVoiceService();
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  bool _isRecording = false;
  bool _isProcessing = false;
  String? _statusMessage;
  Timer? _recordTimer;
  int _secondsRecorded = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.22).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _animController.dispose();
    _voiceService.cancelRecording();
    _voiceService.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_isProcessing || _isRecording) return;
    final started = await _voiceService.startRecording();
    if (!mounted) return;

    if (started) {
      setState(() {
        _isRecording = true;
        _secondsRecorded = 0;
        _statusMessage = null;
      });
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() => _secondsRecorded++);
      });
    } else {
      setState(() {
        _statusMessage = 'Permiso de micrófono no otorgado.';
      });
    }
  }

  Future<void> _stopAndSubmit() async {
    if (_isProcessing || !_isRecording) return;
    _recordTimer?.cancel();
    setState(() {
      _isRecording = false;
      _isProcessing = true;
      _statusMessage = 'Buscando producto...';
    });

    final result = await _voiceService.stopAndTranscribe();
    if (!mounted) return;

    if (result != null && result.trim().isNotEmpty) {
      Navigator.of(context).pop(result.trim());
    } else {
      setState(() {
        _isProcessing = false;
        _statusMessage = 'No se detectó tu voz. Toca el micrófono para reintentar.';
      });
    }
  }

  void _onCancel() {
    _recordTimer?.cancel();
    _voiceService.cancelRecording();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra de arrastre
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Título y estado
          Text(
            _isProcessing
                ? 'Procesando tu voz...'
                : (_isRecording ? 'Grabando... Toca para buscar' : 'Toca o mantén presionado para hablar'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),

          // Cronómetro o subtítulo
          if (_isRecording)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '00:${_secondsRecorded.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '• Toca o suelta para enviar',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            )
          else
            Text(
              _statusMessage ?? 'Decí el producto, marca o dictá el código de barras',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: _statusMessage != null && _statusMessage!.contains('No')
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF64748B),
              ),
            ),

          const SizedBox(height: 20),

          // Botón central con interacción flexible (Tap para iniciar/parar o Mantener presionado)
          GestureDetector(
            onTap: () {
              if (_isProcessing) return;
              if (_isRecording) {
                _stopAndSubmit();
              } else {
                _startRecording();
              }
            },
            onLongPressStart: (_) {
              if (_isProcessing || _isRecording) return;
              _startRecording();
            },
            onLongPressEnd: (_) {
              if (_isProcessing || !_isRecording) return;
              _stopAndSubmit();
            },
            child: ScaleTransition(
              scale: _isRecording ? _scaleAnimation : const AlwaysStoppedAnimation(1.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _isRecording
                        ? const [Color(0xFFEF4444), Color(0xFFDC2626)]
                        : const [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isRecording ? const Color(0xFFEF4444) : const Color(0xFF10B981))
                          .withValues(alpha: 0.35),
                      blurRadius: 18,
                      spreadRadius: _isRecording ? 4 : 2,
                    ),
                  ],
                ),
                child: Center(
                  child: _isProcessing
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.8,
                          ),
                        )
                      : Icon(
                          _isRecording ? Icons.mic_rounded : Icons.mic_none_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Botones inferiores
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: _onCancel,
                child: const Text('Cancelar', style: TextStyle(color: Color(0xFF64748B))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
