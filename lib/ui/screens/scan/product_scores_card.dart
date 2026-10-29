import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/product_model.dart';
import '../../../services/locale_service.dart';

export 'widgets/product_labels_and_allergens_card.dart';

/// Tarjeta modular de tres estados para Nutri-Score, NOVA y Eco-Score
class ProductScoresCard extends StatelessWidget {
  final String nutriScore; // 'A', 'B', 'C', 'D', 'E'
  final int novaGroup;     // 1, 2, 3, 4
  final String ecoScore;   // 'A', 'B', 'C', 'D', 'E'

  const ProductScoresCard({
    super.key,
    required this.nutriScore,
    required this.novaGroup,
    required this.ecoScore,
  });

  factory ProductScoresCard.fromProduct(OffProduct product) {
    return ProductScoresCard(
      nutriScore: (product.nutriscoreGrade ?? '?').toUpperCase(),
      novaGroup: product.novaGroup ?? 0,
      ecoScore: (product.ecoscoreGrade ?? '?').toUpperCase(),
    );
  }

  Color _getNutriScoreColor(String score) {
    switch (score.toUpperCase()) {
      case 'A': return const Color(0xFF038141);
      case 'B': return const Color(0xFF85BB2F);
      case 'C': return const Color(0xFFFECB02);
      case 'D': return const Color(0xFFEE8100);
      case 'E': return const Color(0xFFE63E11);
      default: return Colors.grey.shade400;
    }
  }

  Color _getNovaColor(int group) {
    switch (group) {
      case 1: return const Color(0xFF00AA6C);
      case 2: return const Color(0xFFFFB703);
      case 3: return const Color(0xFFFB8500);
      case 4: return const Color(0xFFD90429);
      default: return Colors.grey.shade400;
    }
  }

  Color _getEcoScoreColor(String score) {
    switch (score.toUpperCase()) {
      case 'A': return const Color(0xFF1E8F4E);
      case 'B': return const Color(0xFF2ECC71);
      case 'C': return const Color(0xFFFFCC00);
      case 'D': return const Color(0xFFFF7B00);
      case 'E': return const Color(0xFFD32F2F);
      default: return Colors.grey.shade400;
    }
  }

  String _getNovaDescription(int group, LocaleService locale) {
    switch (group) {
      case 1: return 'No procesado';
      case 2: return 'Ingrediente culinario';
      case 3: return 'Procesado';
      case 4: return 'Ultraprocesado';
      default: return 'No disponible';
    }
  }

  String _getNutriScoreSubtitle(String score) {
    final clean = score.toUpperCase();
    if (clean == 'A' || clean == 'B') return 'Excelente';
    if (clean == 'C') return 'Aceptable';
    if (clean == 'D') return 'Moderado';
    if (clean == 'E') return 'Bajo';
    return 'No disponible';
  }

  String _getEcoScoreSubtitle(String score) {
    final clean = score.toUpperCase();
    if (clean == 'A' || clean == 'B') return 'Sostenible';
    if (clean == 'C') return 'Moderado';
    if (clean == 'D' || clean == 'E') return 'Alto impacto';
    return 'No disponible';
  }

  @override
  Widget build(BuildContext context) {
    if (nutriScore == '?' && novaGroup == 0 && ecoScore == '?') {
      return const SizedBox.shrink();
    }

    final locale = context.watch<LocaleService>();

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PERFIL DEL PRODUCTO',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: Colors.black54,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ScoreItem(
                  title: 'Nutri-Score',
                  badgeText: nutriScore == '?' ? '-' : nutriScore.toUpperCase(),
                  subtitle: _getNutriScoreSubtitle(nutriScore),
                  badgeColor: _getNutriScoreColor(nutriScore),
                  icon: Icons.restaurant_outlined,
                  onTap: () => _showDetailSheet(
                    context,
                    'Nutri-Score',
                    'Calidad nutricional global de los alimentos, de la A (más saludable) a la E (menos saludable).',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ScoreItem(
                  title: 'NOVA',
                  badgeText: novaGroup == 0 ? '-' : '$novaGroup',
                  subtitle: _getNovaDescription(novaGroup, locale),
                  badgeColor: _getNovaColor(novaGroup),
                  icon: Icons.layers_outlined,
                  onTap: () => _showDetailSheet(
                    context,
                    'Clasificación NOVA',
                    'Grado de procesamiento industrial: 1 (alimento natural/mínimamente procesado) hasta 4 (ultraprocesado).',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ScoreItem(
                  title: 'Eco-Score',
                  badgeText: ecoScore == '?' ? '-' : ecoScore.toUpperCase(),
                  subtitle: _getEcoScoreSubtitle(ecoScore),
                  badgeColor: _getEcoScoreColor(ecoScore),
                  icon: Icons.eco_outlined,
                  onTap: () => _showDetailSheet(
                    context,
                    'Eco-Score',
                    'Impacto ecológico y huella de carbono a lo largo del ciclo de vida del producto (A a E).',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDetailSheet(BuildContext context, String title, String description) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.black87),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Entendido'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreItem extends StatelessWidget {
  final String title;
  final String badgeText;
  final String subtitle;
  final Color badgeColor;
  final IconData icon;
  final VoidCallback? onTap;

  const _ScoreItem({
    required this.title,
    required this.badgeText,
    required this.subtitle,
    required this.badgeColor,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: badgeColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: badgeColor),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badgeText,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: Colors.black87.withValues(alpha: 0.75),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

