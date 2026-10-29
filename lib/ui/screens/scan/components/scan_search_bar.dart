import 'package:flutter/material.dart';

/// Barra de búsqueda personalizada con soporte para navegación hacia atrás,
/// limpieza de texto y escaneo directo por cámara.
class ScanSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSuccess;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onBackToSearch;
  final VoidCallback onClear;
  final VoidCallback onScanner;
  final VoidCallback? onBackToHome;

  const ScanSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isSuccess,
    required this.onChanged,
    required this.onSubmitted,
    required this.onBackToSearch,
    required this.onClear,
    required this.onScanner,
    this.onBackToHome,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: focusNode.hasFocus
                ? theme.colorScheme.primary
                : const Color(0xFFE2E8F0),
            width: focusNode.hasFocus ? 1.8 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            if (isSuccess)
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                color: theme.colorScheme.primary,
                tooltip: 'Volver a la búsqueda',
                splashRadius: 20,
                onPressed: onBackToSearch,
              )
            else if (onBackToHome != null)
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                color: theme.colorScheme.primary,
                tooltip: 'Volver al inicio',
                splashRadius: 20,
                onPressed: onBackToHome,
              )
            else ...[
              const SizedBox(width: 12),
              Icon(Icons.search, color: theme.colorScheme.primary, size: 24),
            ],
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  hintText: 'Buscar por producto, marca o código...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF94A3B8),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                onChanged: onChanged,
                onSubmitted: onSubmitted,
              ),
            ),
            if (controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                splashRadius: 18,
                onPressed: onClear,
              ),
            Container(
              height: 24,
              width: 1,
              color: const Color(0xFFE2E8F0),
              margin: const EdgeInsets.symmetric(horizontal: 2),
            ),
            IconButton(
              icon: Icon(Icons.qr_code_scanner, color: theme.colorScheme.primary),
              tooltip: 'Escanear código de barras',
              splashRadius: 20,
              onPressed: onScanner,
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}
