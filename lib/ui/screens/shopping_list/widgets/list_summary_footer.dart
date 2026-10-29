import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../viewmodels/shopping_list_viewmodel.dart';
import '../../../../viewmodels/discount_viewmodel.dart';

class ListSummaryFooter extends StatelessWidget {
  final ShoppingListViewModel viewModel;
  final int listId;

  const ListSummaryFooter({
    super.key,
    required this.viewModel,
    required this.listId,
  });

  void _showDiscountConfigSheet(BuildContext context) {
    final discountVm = context.read<DiscountViewModel>();
    final activeDiscounts = discountVm.getActiveDiscountsForToday();

    final pctCtrl = TextEditingController(
      text: viewModel.discountPercentage > 0
          ? viewModel.discountPercentage.toStringAsFixed(0)
          : '',
    );
    final capCtrl = TextEditingController(
      text: viewModel.discountCap > 0
          ? viewModel.discountCap.toStringAsFixed(0)
          : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Descuento o Promoción',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Ingresa el porcentaje de reintegro de tu banco/tarjeta y el tope máximo si corresponde.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              if (activeDiscounts.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Tus promociones guardadas para hoy:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: activeDiscounts.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final d = activeDiscounts[i];
                      return ActionChip(
                        avatar: const Icon(Icons.local_offer, size: 14, color: Colors.teal),
                        label: Text(
                          '${d.supermarketName}: ${d.percentage.toStringAsFixed(0)}% (${d.bankOrMethod})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        onPressed: () {
                          pctCtrl.text = d.percentage.toStringAsFixed(0);
                          capCtrl.text = d.maxCap > 0 ? d.maxCap.toStringAsFixed(0) : '';
                        },
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: pctCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Descuento (%)',
                        hintText: 'Ej. 15, 20',
                        suffixText: '%',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: capCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Tope máx. (\$)',
                        hintText: 'Opcional (0=sin tope)',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [10, 15, 20, 25, 30].map((pct) {
                  return ActionChip(
                    label: Text('$pct%'),
                    onPressed: () {
                      pctCtrl.text = pct.toString();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (viewModel.discountPercentage > 0 || viewModel.discountCap > 0)
                    TextButton(
                      onPressed: () {
                        viewModel.updateDiscounts(
                          listId: listId,
                          discountPercentage: 0.0,
                          discountCap: 0.0,
                        );
                        Navigator.of(sheetCtx).pop();
                      },
                      child: const Text('Quitar descuento', style: TextStyle(color: Colors.red)),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      final pct = double.tryParse(pctCtrl.text.trim()) ?? 0.0;
                      final cap = double.tryParse(capCtrl.text.trim()) ?? 0.0;
                      viewModel.updateDiscounts(
                        listId: listId,
                        discountPercentage: pct > 0 ? pct : 0.0,
                        discountCap: cap > 0 ? cap : 0.0,
                      );
                      Navigator.of(sheetCtx).pop();
                    },
                    child: const Text('Guardar'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = viewModel.currentSubtotal;
    final discount = viewModel.currentDiscount;
    final totalFinal = viewModel.currentFinalTotal;
    final selectedCount = viewModel.selectedItemCount;
    final totalCount = viewModel.currentItems.length;
    final hasDiscount = viewModel.discountPercentage > 0;
    final isCapReached = hasDiscount &&
        viewModel.discountCap > 0 &&
        (subtotal * (viewModel.discountPercentage / 100.0)) >= viewModel.discountCap;

    final discountVm = context.watch<DiscountViewModel>();
    final activeDiscountsToday = discountVm.getActiveDiscountsForToday();

    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, -3),
            blurRadius: 10,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Línea 1: Subtotal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal ($selectedCount de $totalCount art.)',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.blueGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '\$${subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Línea 2: Descuento configurable
            InkWell(
              onTap: () => _showDiscountConfigSheet(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.discount_outlined,
                          size: 16,
                          color: hasDiscount
                              ? Colors.teal
                              : (activeDiscountsToday.isNotEmpty ? Colors.teal : Colors.grey),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          hasDiscount
                              ? 'Descuento (${viewModel.discountPercentage.toStringAsFixed(0)}%${viewModel.discountCap > 0 ? " · Tope \$${viewModel.discountCap.toStringAsFixed(0)}" : ""})'
                              : activeDiscountsToday.isNotEmpty
                                  ? 'Cargar Descuento (${activeDiscountsToday.length} hoy)'
                                  : 'Cargar Descuento / Tope',
                          style: TextStyle(
                            fontSize: 13,
                            color: hasDiscount
                                ? Colors.teal
                                : (activeDiscountsToday.isNotEmpty ? Colors.teal : theme.colorScheme.primary),
                            fontWeight: FontWeight.w500,
                            decoration: hasDiscount ? null : TextDecoration.underline,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.edit_outlined,
                          size: 14,
                          color: hasDiscount
                              ? Colors.teal
                              : (activeDiscountsToday.isNotEmpty ? Colors.teal : theme.colorScheme.primary),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isCapReached)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Text(
                              '(Tope)',
                              style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                            ),
                          ),
                        Text(
                          hasDiscount
                              ? '-\$${discount.toStringAsFixed(2)}'
                              : '\$0.00',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: hasDiscount ? Colors.green.shade700 : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 14),

            // Línea 3: Total Final
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Final',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '\$${totalFinal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
