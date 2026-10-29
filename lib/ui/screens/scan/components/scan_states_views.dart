import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:compramas/services/locale_service.dart';
import 'package:compramas/viewmodels/scanner_viewmodel.dart';

class SearchIdleView extends StatelessWidget {
  final VoidCallback onScan;
  final VoidCallback? onVoiceSearch;
  final ValueChanged<String> onQuickSearch;

  const SearchIdleView({
    super.key,
    required this.onScan,
    this.onVoiceSearch,
    required this.onQuickSearch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_rounded,
                size: 50,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Encuentra el Mejor Precio',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Usa la barra superior para escribir el nombre, hablar por micrófono o escanear con la cámara.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScanLoadingView extends StatelessWidget {
  const ScanLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleService>();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            locale.t('scan_loading'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class ScanErrorView extends StatelessWidget {
  final String errorMessage;
  final String? barcode;
  final VoidCallback onRetry;

  const ScanErrorView({
    super.key,
    required this.errorMessage,
    required this.barcode,
    required this.onRetry,
  });

  Future<void> _pickAndUploadImage(BuildContext context) async {
    final locale = context.read<LocaleService>();
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    if (!context.mounted) return;
    final vm = context.read<ScannerViewModel>();
    final ok = await vm.uploadProductImage(File(image.path));

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? locale.t('photo_success') : locale.t('photo_error')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleService>();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              locale.t('product_not_found'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            if (barcode != null) ...[
              const SizedBox(height: 12),
              Chip(label: Text('Código: $barcode')),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(locale.t('retry')),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () => _pickAndUploadImage(context),
                  icon: const Icon(Icons.add_a_photo),
                  label: Text(locale.t('add_photo')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

