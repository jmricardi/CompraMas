import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/product_model.dart';
import '../../../../services/locale_service.dart';

/// Tarjeta de Sellos de Advertencia (Octógonos), Alérgenos y Sin TACC con iconos claros
class ProductLabelsAndAllergensCard extends StatelessWidget {
  final OffProduct product;

  const ProductLabelsAndAllergensCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final labels = product.labelsTags;
    final allergens = product.allergensTags;

    if (labels.isEmpty && allergens.isEmpty) {
      return const SizedBox.shrink();
    }

    final locale = context.watch<LocaleService>();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: Colors.black87),
              const SizedBox(width: 8),
              Text(
                locale.t('warning_seals'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (labels.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: labels.map((tag) => _buildBadgeForLabel(tag, locale)).toList(),
            ),
          ],
          if (allergens.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.error_outline, size: 16, color: Colors.deepOrange),
                const SizedBox(width: 6),
                Text(
                  locale.t('allergens_title'),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: allergens.map((all) {
                return _AllergenChip(text: locale.formatAllergen(all));
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadgeForLabel(String tag, LocaleService locale) {
    final lower = tag.toLowerCase();
    final formattedText = locale.formatLabel(tag);

    // Sin TACC / Gluten Free
    if (lower.contains('tacc') || lower.contains('gluten')) {
      return _WarningSealBadge(
        label: formattedText,
        icon: Icons.verified_outlined,
        backgroundColor: const Color(0xFF2E7D32),
        textColor: Colors.white,
      );
    }

    // Azúcares
    if (lower.contains('azucar') || lower.contains('sugar')) {
      return _WarningSealBadge(
        label: formattedText,
        icon: Icons.cookie_outlined,
        backgroundColor: const Color(0xFF1A1A1A),
        textColor: Colors.white,
      );
    }

    // Sodio
    if (lower.contains('sodio') || lower.contains('sodium') || lower.contains('sal')) {
      return _WarningSealBadge(
        label: formattedText,
        icon: Icons.grain,
        backgroundColor: const Color(0xFF1A1A1A),
        textColor: Colors.white,
      );
    }

    // Grasas
    if (lower.contains('grasa') || lower.contains('fat')) {
      return _WarningSealBadge(
        label: formattedText,
        icon: Icons.oil_barrel_outlined,
        backgroundColor: const Color(0xFF1A1A1A),
        textColor: Colors.white,
      );
    }

    // Edulcorantes
    if (lower.contains('edulcorante') || lower.contains('sweetener')) {
      return _WarningSealBadge(
        label: formattedText,
        icon: Icons.science_outlined,
        backgroundColor: const Color(0xFFC62828),
        textColor: Colors.white,
      );
    }

    // Cafeína
    if (lower.contains('cafeina') || lower.contains('caffeine')) {
      return _WarningSealBadge(
        label: formattedText,
        icon: Icons.local_cafe_outlined,
        backgroundColor: const Color(0xFF4E342E),
        textColor: Colors.white,
      );
    }

    // Genérico
    final isWarning = lower.contains('exceso') || lower.contains('alto');
    return _WarningSealBadge(
      label: formattedText,
      icon: isWarning ? Icons.warning_amber_rounded : Icons.info_outline,
      backgroundColor: isWarning ? const Color(0xFF1A1A1A) : Colors.grey.shade800,
      textColor: Colors.white,
    );
  }
}

class _WarningSealBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color textColor;

  const _WarningSealBadge({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _AllergenChip extends StatelessWidget {
  final String text;

  const _AllergenChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.deepOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber, size: 12, color: Colors.deepOrange),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.deepOrange,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
