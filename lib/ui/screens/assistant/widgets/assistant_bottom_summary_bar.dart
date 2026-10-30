import 'package:flutter/material.dart';
import '../../../../models/shopping_assistant_model.dart';
import '../../../../utils/format_utils.dart';

/// Barra persistente al pie del Asistente de Compras con:
/// - Subtotal
/// - Línea de Descuentos (configurable al pulsar)
/// - Total en tipografía destacada de alto contraste
/// - Acciones: "Guardar como Lista" y "Finalizar Compra"
class AssistantBottomSummaryBar extends StatelessWidget {
  final double subtotal;
  final double discountAmount;
  final double discountPercentage;
  final double finalTotal;
  final int totalArticles;
  final bool hasItems;
  final bool isProcessing;
  final VoidCallback onTapConfigureDiscount;
  final VoidCallback onSaveAsList;
  final VoidCallback onFinalizePurchase;

  const AssistantBottomSummaryBar({
    super.key,
    required this.subtotal,
    required this.discountAmount,
    required this.discountPercentage,
    required this.finalTotal,
    required this.totalArticles,
    required this.hasItems,
    required this.isProcessing,
    required this.onTapConfigureDiscount,
    required this.onSaveAsList,
    required this.onFinalizePurchase,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSubtotalRow(isDark),
          const SizedBox(height: 4),
          _buildDiscountRow(isDark),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),
          _buildTotalRow(isDark),
          const SizedBox(height: 12),
          _buildActionButtons(isDark),
        ],
      ),
    );
  }

  Widget _buildSubtotalRow(bool isDark) {
    final articlesLabel =
        totalArticles == 1 ? '1 artículo' : '$totalArticles artículos';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Subtotal ($articlesLabel)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
        ),
        Text(
          AppFormatters.currency(subtotal),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildDiscountRow(bool isDark) {
    final pctBadge = discountPercentage > 0
        ? ' (${discountPercentage.toStringAsFixed(0)}%)'
        : '';
    return InkWell(
      onTap: onTapConfigureDiscount,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_offer_outlined,
                  size: 14,
                  color: Color(0xFF10B981),
                ),
                const SizedBox(width: 4),
                Text(
                  'Descuentos$pctBadge',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Editar',
                  style: TextStyle(
                    fontSize: 11,
                    decoration: TextDecoration.underline,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            Text(
              discountAmount > 0
                  ? '- ${AppFormatters.currency(discountAmount)}'
                  : AppFormatters.currency(0),
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF10B981),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'TOTAL A PAGAR',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        Text(
          AppFormatters.currency(finalTotal),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isDark) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: OutlinedButton.icon(
            onPressed: (!hasItems || isProcessing) ? null : onSaveAsList,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0D9488),
              side: BorderSide(
                color: hasItems
                    ? const Color(0xFF0D9488)
                    : Colors.grey.withValues(alpha: 0.3),
                width: 1.4,
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.playlist_add_check_rounded, size: 19),
            label: const Text(
              'Guardar Lista',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 6,
          child: FilledButton.icon(
            onPressed: (!hasItems || isProcessing) ? null : onFinalizePurchase,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.shopping_cart_checkout_rounded, size: 19),
            label: const Text(
              'Finalizar Compra',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

/// Diálogo para configurar el descuento de la compra actual (% con tope o monto fijo)
class AssistantDiscountDialog extends StatefulWidget {
  final double initialPercentage;
  final double initialCap;
  final double initialManualAmount;

  const AssistantDiscountDialog({
    super.key,
    required this.initialPercentage,
    required this.initialCap,
    required this.initialManualAmount,
  });

  @override
  State<AssistantDiscountDialog> createState() =>
      _AssistantDiscountDialogState();
}

class _AssistantDiscountDialogState extends State<AssistantDiscountDialog> {
  late final TextEditingController _pctCtrl;
  late final TextEditingController _capCtrl;
  late final TextEditingController _fixedCtrl;

  @override
  void initState() {
    super.initState();
    _pctCtrl = TextEditingController(
      text: widget.initialPercentage > 0
          ? widget.initialPercentage.toStringAsFixed(0)
          : '',
    );
    _capCtrl = TextEditingController(
      text: widget.initialCap > 0 ? widget.initialCap.toStringAsFixed(0) : '',
    );
    _fixedCtrl = TextEditingController(
      text: widget.initialManualAmount > 0
          ? widget.initialManualAmount.toStringAsFixed(2)
          : '',
    );
  }

  @override
  void dispose() {
    _pctCtrl.dispose();
    _capCtrl.dispose();
    _fixedCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text(
        'Configurar Descuentos',
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _pctCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Porcentaje de descuento (%)',
                hintText: 'Ej. 20',
                suffixText: '%',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _capCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Tope de reintegro (\$ opcional)',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _fixedCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Descuento fijo adicional (\$)',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop({
              'pct': 0.0,
              'cap': 0.0,
              'fixed': 0.0,
            });
          },
          child: const Text('Limpiar'),
        ),
        FilledButton(
          onPressed: () {
            final pct =
                double.tryParse(_pctCtrl.text.replaceAll(',', '.')) ?? 0.0;
            final cap =
                double.tryParse(_capCtrl.text.replaceAll(',', '.')) ?? 0.0;
            final fixed =
                double.tryParse(_fixedCtrl.text.replaceAll(',', '.')) ?? 0.0;
            Navigator.of(context).pop({
              'pct': pct,
              'cap': cap,
              'fixed': fixed,
            });
          },
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}

/// Diálogo de éxito al finalizar la compra mostrando el ticket guardado en Historial
class AssistantPurchaseTicketDialog extends StatelessWidget {
  final CompletedPurchaseTicket ticket;

  const AssistantPurchaseTicketDialog({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    final d = ticket.timestamp;
    final dateFormatted =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      title: const Row(
        children: [
          Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 28),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '¡Compra Guardada!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ticket.storeName,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            Text(
              'Fecha: $dateFormatted',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const Divider(height: 18),
            ...ticket.items.map(
              (it) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${it.quantity}x ${it.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppFormatters.currency(it.subtotal),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 18),
            _ticketLine('Subtotal', AppFormatters.currency(ticket.subtotal)),
            if (ticket.discountAmount > 0)
              _ticketLine(
                'Descuentos',
                '- ${AppFormatters.currency(ticket.discountAmount)}',
              ),
            const SizedBox(height: 4),
            _ticketLine(
              'Total Pagado',
              AppFormatters.currency(ticket.finalTotal),
              isBold: true,
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Aceptar'),
        ),
      ],
    );
  }

  Widget _ticketLine(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 13,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
