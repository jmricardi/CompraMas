import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerView extends StatefulWidget {
  final void Function(String barcode) onBarcodeScanned;
  final VoidCallback? onOpenSearchModal;

  const ScannerView({
    super.key,
    required this.onBarcodeScanned,
    this.onOpenSearchModal,
  });

  @override
  State<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<ScannerView> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
    ],
  );

  bool _isScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_isScanned) return;
    final barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.isNotEmpty) {
        _isScanned = true;
        widget.onBarcodeScanned(rawValue);
        Navigator.of(context).pop();
        break;
      }
    }
  }

  void _showManualEntryDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Ingresar código manual'),
        content: TextField(
          controller: textController,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Ej. 7791813434412',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final code = textController.text.trim();
              if (code.isNotEmpty) {
                Navigator.of(dialogCtx).pop();
                widget.onBarcodeScanned(code);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Buscar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear Código de Barras'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcode,
          ),
          // Marco guía visual
          Center(
            child: Container(
              width: 280,
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent, width: 2.5),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // Botón flotante para cerrar el escáner y abrir la búsqueda por palabra / variedad
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Cerrar escáner',
                    ),
                  ),
                  const Spacer(),
                  if (widget.onOpenSearchModal != null)
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onOpenSearchModal!();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: const Icon(Icons.search_rounded, size: 18),
                      label: const Text(
                        'Buscar sin código',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Botón inferior para entrada manual de código
          Positioned(
            bottom: 36,
            left: 24,
            right: 24,
            child: FilledButton.tonalIcon(
              onPressed: () {
                if (widget.onOpenSearchModal != null) {
                  Navigator.of(context).pop();
                  widget.onOpenSearchModal!();
                } else {
                  _showManualEntryDialog();
                }
              },
              icon: Icon(widget.onOpenSearchModal != null ? Icons.manage_search_rounded : Icons.keyboard),
              label: Text(widget.onOpenSearchModal != null
                  ? 'Buscar por palabra, variedad o peso'
                  : 'Ingresar código manualmente'),
            ),
          ),
        ],
      ),
    );
  }
}
