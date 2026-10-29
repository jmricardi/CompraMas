import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../services/settings_service.dart';
import '../../../../utils/product_variety_helper.dart';

/// Barra interactiva de etiquetas (Variedad, Presentación, Marca, Envase)
/// que permite seleccionar y deseleccionar atributos para filtrar sugerencias en vivo.
class ProductAttributeTagsBar extends StatelessWidget {
  final ProductFilterAttributes attributes;
  final String? selectedVariedad;
  final String? selectedPresentacion;
  final String? selectedMarca;
  final String? selectedEnvase;
  final ValueChanged<String> onToggleVariedad;
  final ValueChanged<String> onTogglePresentacion;
  final ValueChanged<String> onToggleMarca;
  final ValueChanged<String> onToggleEnvase;
  final VoidCallback onClearAll;

  const ProductAttributeTagsBar({
    super.key,
    required this.attributes,
    this.selectedVariedad,
    this.selectedPresentacion,
    this.selectedMarca,
    this.selectedEnvase,
    required this.onToggleVariedad,
    required this.onTogglePresentacion,
    required this.onToggleMarca,
    required this.onToggleEnvase,
    required this.onClearAll,
  });

  bool get hasActiveFilter =>
      selectedVariedad != null ||
      selectedPresentacion != null ||
      selectedMarca != null ||
      selectedEnvase != null;

  @override
  Widget build(BuildContext context) {
    if (attributes.isEmpty) return const SizedBox.shrink();

    final settings = context.watch<SettingsService>();
    final showVar = settings.showVariedadTag && attributes.variedades.isNotEmpty;
    final showPres = settings.showPresentacionTag && attributes.presentaciones.isNotEmpty;
    final showMarca = settings.showMarcaTag && attributes.marcas.isNotEmpty;
    final showEnv = settings.showEnvaseTag && attributes.envases.isNotEmpty;

    if (!showVar && !showPres && !showMarca && !showEnv) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final hPad = (screenWidth * 0.032).clamp(10.0, 16.0);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(theme, hPad),
          if (showVar)
            _buildChipsRow(
              items: attributes.variedades,
              selectedValue: selectedVariedad,
              onToggle: onToggleVariedad,
              theme: theme,
              hPad: hPad,
            ),
          if (showPres) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 6, hPad, 2),
              child: Text(
                'Contenido / Cantidad',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            _buildChipsRow(
              items: attributes.presentaciones,
              selectedValue: selectedPresentacion,
              onToggle: onTogglePresentacion,
              theme: theme,
              hPad: hPad,
            ),
          ],
          if (showMarca)
            _buildCategorySection(
              title: 'Marca',
              icon: Icons.storefront_rounded,
              items: attributes.marcas,
              selectedValue: selectedMarca,
              onToggle: onToggleMarca,
              theme: theme,
              hPad: hPad,
            ),
          if (showEnv)
            _buildCategorySection(
              title: 'Envase',
              icon: Icons.inventory_2_outlined,
              items: attributes.envases,
              selectedValue: selectedEnvase,
              onToggle: onToggleEnvase,
              theme: theme,
              hPad: hPad,
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, double hPad) {
    if (!hasActiveFilter) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 2),
      child: Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onTap: onClearAll,
          child: Text(
            'Limpiar filtros',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.error,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChipsRow({
    required List<String> items,
    required String? selectedValue,
    required ValueChanged<String> onToggle,
    required ThemeData theme,
    required double hPad,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 3),
      child: Row(
        children: items.map((val) {
          final isSelected = selectedValue == val;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _buildTagChip(val, isSelected, () => onToggle(val), theme),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategorySection({
    required String title,
    required IconData icon,
    required List<String> items,
    required String? selectedValue,
    required ValueChanged<String> onToggle,
    required ThemeData theme,
    required double hPad,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(left: hPad, right: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 12, color: const Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: items.map((val) {
                  final isSelected = selectedValue == val;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _buildTagChip(val, isSelected, () => onToggle(val), theme),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip(
    String label,
    bool isSelected,
    VoidCallback onTap,
    ThemeData theme,
  ) {
    final Color bgColor = isSelected
        ? const Color(0xFF059669) // Verde esmeralda vivo
        : const Color(0xFF334155); // Fondo pleno pizarra oscuro, alto contraste con blanco

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : Colors.transparent,
            width: isSelected ? 1.5 : 0.0,
          ),
          boxShadow: [
            BoxShadow(
              color: bgColor.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check_rounded, size: 14, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
