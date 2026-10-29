import 'package:flutter/material.dart';

/// Diálogo modal de confirmación antes de comparar precios de un clúster o producto.
/// Muestra las variables canónicas (Producto, Variedad, Presentación, Categoría)
/// una debajo de la otra (sin mencionar la marca, ya que se compararán todas las marcas),
/// junto a un tilde verde para confirmar o una X roja para anular y volver a buscar.
class ClusterConfirmationDialog extends StatelessWidget {
  final Map<String, dynamic> data;

  const ClusterConfirmationDialog({
    super.key,
    required this.data,
  });

  static Future<bool?> show(BuildContext context, Map<String, dynamic> data) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClusterConfirmationDialog(data: data),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final dialogHInset = (screenWidth * 0.06).clamp(16.0, 32.0);
    final innerHPad = (screenWidth * 0.05).clamp(16.0, 24.0);
    final labelColWidth = (screenWidth * 0.30).clamp(95.0, 130.0);

    final canonical = data['nombre_canonico']?.toString().trim();
    final producto = data['producto']?.toString().trim();
    final prodName = (canonical != null && canonical.isNotEmpty)
        ? canonical
        : ((producto != null && producto.isNotEmpty) ? producto : 'Producto');

    final variedad = data['variedad']?.toString().trim();
    final presentacion = data['presentacion']?.toString().trim();
    final contenido = data['contenido']?.toString().trim();
    final categoria = data['categoria']?.toString().trim();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: theme.colorScheme.surface,
      insetPadding: EdgeInsets.symmetric(horizontal: dialogHInset, vertical: 24),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: innerHPad, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(theme),
            const SizedBox(height: 18),
            _buildVariablesCard(
              theme,
              labelColWidth: labelColWidth,
              producto: prodName,
              variedad: (variedad != null && variedad.isNotEmpty)
                  ? variedad
                  : 'Clásico',
              presentacion: (presentacion != null &&
                      presentacion.isNotEmpty &&
                      presentacion.toLowerCase() != 'estándar' &&
                      presentacion.toLowerCase() != 'estandar')
                  ? presentacion
                  : 'Según envase',
              contenido: (contenido != null && contenido.isNotEmpty)
                  ? contenido
                  : null,
              categoria: (categoria != null && categoria.isNotEmpty)
                  ? categoria
                  : null,
            ),
            const SizedBox(height: 12),
            _buildBrandClarificationNote(theme),
            const SizedBox(height: 22),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.compare_arrows_rounded,
            size: 24,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Confirmar producto',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVariablesCard(
    ThemeData theme, {
    required double labelColWidth,
    required String producto,
    required String variedad,
    required String presentacion,
    String? contenido,
    String? categoria,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          _buildVariableRow('Producto', producto, labelColWidth, isHighlight: true),
          const Divider(height: 16, color: Color(0xFFE2E8F0)),
          _buildVariableRow('Variedad', variedad, labelColWidth),
          const Divider(height: 16, color: Color(0xFFE2E8F0)),
          _buildVariableRow('Presentación', presentacion, labelColWidth),
          if (contenido != null && contenido.isNotEmpty) ...[
            const Divider(height: 16, color: Color(0xFFE2E8F0)),
            _buildVariableRow('Contenido', contenido, labelColWidth),
          ],
          if (categoria != null) ...[
            const Divider(height: 16, color: Color(0xFFE2E8F0)),
            _buildVariableRow('Categoría', categoria, labelColWidth),
          ],
        ],
      ),
    );
  }

  Widget _buildVariableRow(
    String label,
    String value,
    double labelColWidth, {
    bool isHighlight = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: labelColWidth,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
              color:
                  isHighlight ? const Color(0xFF0F172A) : const Color(0xFF334155),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBrandClarificationNote(ThemeData theme) {
    return Row(
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 14,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 6),
        const Expanded(
          child: Text(
            'Se compararán los precios de todas las marcas disponibles.',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Botón Anular con X roja
        InkWell(
          onTap: () => Navigator.of(context).pop(false),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 76,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.close_rounded,
                size: 30,
                color: Color(0xFFEF4444),
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        // Botón Confirmar con Tilde verde
        InkWell(
          onTap: () => Navigator.of(context).pop(true),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 76,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF059669),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF059669).withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.check_rounded,
                size: 32,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
