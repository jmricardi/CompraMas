import 'package:flutter/material.dart';
import '../../../../models/shopping_list_model.dart';
import '../../../components/glass_card.dart';

class ShoppingItemRow extends StatelessWidget {
  final ShoppingListItemEntity item;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ShoppingItemRow({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final subtotal = item.price * item.quantity;
    final isSelected = item.isPurchased;
    final theme = Theme.of(context);

    return Opacity(
      opacity: isSelected ? 1.0 : 0.55,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (_) => onToggle(),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        decoration: isSelected ? null : TextDecoration.lineThrough,
                        color: isSelected ? null : Colors.grey,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${item.quantity} ${item.unit} x \$${item.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isSelected ? Colors.blueGrey : Colors.grey,
                          ),
                        ),
                        if (!isSelected) ...[
                          const SizedBox(width: 6),
                          const Text(
                            '(No suma)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.redAccent,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Suma parcial destacada
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${subtotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? theme.colorScheme.primary : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tocar para editar',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                tooltip: 'Eliminar producto',
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
