import 'package:flutter/material.dart';
import '../../../../models/shopping_assistant_model.dart';
import '../../../components/optimized_network_image.dart';

/// Resultado confirmado por el usuario en el diálogo de producto del Asistente
class ConfirmedProductDialogData {
  final String ean;
  final String name;
  final String brand;
  final String content;
  final double price;
  final int quantity;
  final String? imageUrl;
  final String source;

  const ConfirmedProductDialogData({
    required this.ean,
    required this.name,
    required this.brand,
    required this.content,
    required this.price,
    required this.quantity,
    this.imageUrl,
    required this.source,
  });
}

/// Diálogo interactivo Claymorphic que muestra Producto, Marca, Contenido, Precio editable
/// y Selector de Cantidad (+ / -), con botones Tilde (Confirmar) y Cruz (Cancelar).
class AssistantProductConfirmationDialog extends StatefulWidget {
  final AssistantProductLookupResult lookupResult;
  final int initialQuantity;
  final bool isEditingExisting;

  const AssistantProductConfirmationDialog({
    super.key,
    required this.lookupResult,
    this.initialQuantity = 1,
    this.isEditingExisting = false,
  });

  static Future<ConfirmedProductDialogData?> show(
    BuildContext context, {
    required AssistantProductLookupResult lookupResult,
    int initialQuantity = 1,
    bool isEditingExisting = false,
  }) {
    return showDialog<ConfirmedProductDialogData>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AssistantProductConfirmationDialog(
        lookupResult: lookupResult,
        initialQuantity: initialQuantity,
        isEditingExisting: isEditingExisting,
      ),
    );
  }

  @override
  State<AssistantProductConfirmationDialog> createState() =>
      _AssistantProductConfirmationDialogState();
}

class _AssistantProductConfirmationDialogState
    extends State<AssistantProductConfirmationDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _contentCtrl;
  late final TextEditingController _priceCtrl;
  late int _quantity;

  @override
  void initState() {
    super.initState();
    final r = widget.lookupResult;
    _nameCtrl = TextEditingController(text: r.name);
    _brandCtrl = TextEditingController(text: r.brand);
    _contentCtrl = TextEditingController(
      text: r.content.isNotEmpty ? r.content : '1 un',
    );
    _priceCtrl = TextEditingController(
      text: r.price > 0 ? r.price.toStringAsFixed(2) : '',
    );
    _quantity = widget.initialQuantity > 0 ? widget.initialQuantity : 1;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _contentCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _handleConfirm() {
    final name = _nameCtrl.text.trim();
    final effectiveName = name.isNotEmpty
        ? name
        : (widget.lookupResult.ean.isNotEmpty
            ? 'Producto ${widget.lookupResult.ean}'
            : 'Producto');
    final parsedPrice =
        double.tryParse(_priceCtrl.text.replaceAll(',', '.').trim()) ?? 0.0;

    Navigator.of(context).pop(
      ConfirmedProductDialogData(
        ean: widget.lookupResult.ean,
        name: effectiveName,
        brand: _brandCtrl.text.trim(),
        content: _contentCtrl.text.trim().isNotEmpty
            ? _contentCtrl.text.trim()
            : '1 un',
        price: parsedPrice >= 0 ? parsedPrice : 0.0,
        quantity: _quantity,
        imageUrl: widget.lookupResult.imageUrl,
        source: widget.lookupResult.source,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDialogHeader(isDark),
            const SizedBox(height: 12),
            _buildSourceBadge(),
            const SizedBox(height: 14),
            _buildProductIdentityFields(isDark),
            const SizedBox(height: 14),
            _buildPriceAndQuantityRow(isDark),
            const SizedBox(height: 20),
            _buildConfirmCancelButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader(bool isDark) {
    final img = widget.lookupResult.imageUrl;
    return Row(
      children: [
        if (img != null && img.isNotEmpty) ...[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            clipBehavior: Clip.antiAlias,
            child: OptimizedNetworkImage(
              imageUrl: img,
              width: 52,
              height: 52,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isEditingExisting
                    ? 'Editar Producto'
                    : 'Confirmar Producto',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              if (widget.lookupResult.ean.isNotEmpty)
                Text(
                  'EAN: ${widget.lookupResult.ean}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSourceBadge() {
    final src = widget.lookupResult.source;
    final isVtex = src == 'vtex_ingested';
    final isSupabase = src == 'supabase';

    final Color bgColor = isVtex
        ? const Color(0xFF0EA5E9).withValues(alpha: 0.12)
        : (isSupabase
            ? const Color(0xFF10B981).withValues(alpha: 0.12)
            : const Color(0xFFF59E0B).withValues(alpha: 0.12));

    final Color fgColor = isVtex
        ? const Color(0xFF0284C7)
        : (isSupabase ? const Color(0xFF059669) : const Color(0xFFD97706));

    final String label = isVtex
        ? 'Obtenido de VTEX · Incorporado a Supabase'
        : (isSupabase
            ? 'Producto verificado en base Supabase'
            : 'Completar datos de góndola manualmente');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            isVtex
                ? Icons.cloud_upload_rounded
                : (isSupabase ? Icons.verified_rounded : Icons.edit_note_rounded),
            size: 16,
            color: fgColor,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: fgColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductIdentityFields(bool isDark) {
    return Column(
      children: [
        TextField(
          controller: _nameCtrl,
          autofocus: widget.lookupResult.name.isEmpty,
          decoration: InputDecoration(
            labelText: 'Producto',
            hintText: 'Ej. Leche Entera Clásica',
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _brandCtrl,
                decoration: InputDecoration(
                  labelText: 'Marca',
                  hintText: 'Ej. La Serenísima',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _contentCtrl,
                decoration: InputDecoration(
                  labelText: 'Contenido',
                  hintText: 'Ej. 1 L / 500 g',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceAndQuantityRow(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextField(
            controller: _priceCtrl,
            autofocus: widget.lookupResult.name.isNotEmpty,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            decoration: InputDecoration(
              labelText: 'Precio unitario (\$)',
              prefixText: '\$ ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _buildQuantityStepper(isDark),
      ],
    );
  }

  Widget _buildQuantityStepper(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperIconButton(
            icon: Icons.remove_rounded,
            onTap: () {
              if (_quantity > 1) {
                setState(() => _quantity--);
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Cant.',
                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                ),
                Text(
                  '$_quantity',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          _StepperIconButton(
            icon: Icons.add_rounded,
            onTap: () => setState(() => _quantity++),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmCancelButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(null),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.close_rounded, size: 22),
            label: const Text(
              'Cancelar',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: _handleConfirm,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.check_rounded, size: 22),
            label: const Text(
              'Confirmar',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _StepperIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StepperIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFF0D9488).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF0D9488)),
      ),
    );
  }
}
