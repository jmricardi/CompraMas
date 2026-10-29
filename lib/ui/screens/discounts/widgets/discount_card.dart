import 'package:flutter/material.dart';
import '../../../../models/discount_model.dart';
import '../../../components/glass_card.dart';

class DiscountCard extends StatelessWidget {
  final DiscountEntity discount;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const DiscountCard({
    super.key,
    required this.discount,
    required this.onToggleActive,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appliesToday = discount.appliesToday();
    final isInactive = !discount.isActive;

    return Opacity(
      opacity: isInactive ? 0.6 : 1.0,
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila superior: Banco/Medio + Badge % OFF + Switch Activo
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: isInactive ? Colors.grey : const Color(0xFF059669),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${discount.percentage.round()}% OFF',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          discount.bank.isNotEmpty ? discount.bank : discount.paymentMethod,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isInactive ? Colors.grey : theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (discount.bank.isNotEmpty)
                          Text(
                            discount.paymentMethod,
                            style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                          ),
                      ],
                    ),
                  ),
                  Transform.scale(
                    scale: 0.85,
                    child: Switch.adaptive(
                      value: discount.isActive,
                      activeTrackColor: const Color(0xFF059669),
                      onChanged: onToggleActive,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Fila de condiciones (Comercio y Día)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _InfoChip(
                    icon: Icons.storefront_outlined,
                    label: discount.supermarketName,
                    color: Colors.blue.shade700,
                    bgColor: Colors.blue.shade50,
                  ),
                  _InfoChip(
                    icon: Icons.calendar_today_outlined,
                    label: discount.isRecurring
                        ? discount.dayOfWeek
                        : (discount.validDate != null ? 'Vence: ${discount.validDate}' : 'Única vez'),
                    color: appliesToday ? Colors.green.shade800 : Colors.indigo.shade700,
                    bgColor: appliesToday ? Colors.green.shade50 : Colors.indigo.shade50,
                    badgeText: appliesToday ? '¡Hoy!' : null,
                  ),
                  if (discount.minAmount > 0)
                    _InfoChip(
                      icon: Icons.shopping_basket_outlined,
                      label: 'Mín: \$${discount.minAmount.toStringAsFixed(0)}',
                      color: Colors.amber.shade900,
                      bgColor: Colors.amber.shade50,
                    ),
                  if (discount.maxCap > 0)
                    _InfoChip(
                      icon: Icons.vertical_align_top_outlined,
                      label: 'Tope: \$${discount.maxCap.toStringAsFixed(0)}',
                      color: Colors.teal.shade900,
                      bgColor: Colors.teal.shade50,
                    ),
                ],
              ),
              const SizedBox(height: 6),

              // Botones de acción inferiores
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Editar', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                    label: const Text('Eliminar', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final String? badgeText;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          if (badgeText != null) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badgeText!,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
