import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/discount_model.dart';
import '../../../viewmodels/discount_viewmodel.dart';
import '../../components/ads/compramas_banner_ad.dart';
import 'widgets/discount_card.dart';
import 'widgets/discount_form_sheet.dart';

/// Pantalla dedicada a "Descuentos y Promociones" (Bancos y Medios de Pago).
///
/// Diseño Bento/Claymorphism sin pestañas rígidas:
/// - Feed directo de promociones registradas.
/// - Botón flotante para registrar nuevas promociones.
/// - Espacio inferior ampliado (al menos 2 tarjetas de producto) para evitar
///   solapamiento con el banner publicitario inferior.
class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DiscountViewModel>().loadDiscounts();
    });
  }

  void _openDiscountForm([DiscountEntity? discount]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DiscountFormSheet(
        initialDiscount: discount,
        onSave: (savedDiscount) async {
          final vm = context.read<DiscountViewModel>();
          if (savedDiscount.id == 0) {
            await vm.addDiscount(savedDiscount);
          } else {
            await vm.updateDiscount(savedDiscount);
          }
        },
      ),
    );
  }

  void _confirmDelete(DiscountEntity discount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Descuento'),
        content: Text(
          '¿Estás seguro de que deseas eliminar la promoción de "${discount.supermarketName}" (${discount.percentage.round()}% OFF)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<DiscountViewModel>().deleteDiscount(discount.id);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DiscountViewModel>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openDiscountForm(),
        backgroundColor: const Color(0xFFF43F5E),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Nueva Promo',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            // 1. Cabecera limpia estilo Bento
            _buildHeader(context, isDark, viewModel.discounts.length),

            // 2. Feed de Promociones con espacio inferior (al menos 2 tarjetas)
            Expanded(
              child: viewModel.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : viewModel.discounts.isEmpty
                      ? _EmptyPromotionsView(onAdd: () => _openDiscountForm())
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 260),
                          itemCount: viewModel.discounts.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final discount = viewModel.discounts[index];
                            return DiscountCard(
                              discount: discount,
                              onToggleActive: (val) {
                                viewModel.toggleDiscountActive(discount.id, val);
                              },
                              onEdit: () => _openDiscountForm(discount),
                              onDelete: () => _confirmDelete(discount),
                            );
                          },
                        ),
            ),

            // 3. Banner publicitario responsivo
            const CompraMasBannerAd(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, int count) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Volver',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Descuentos',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF43F5E).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFF43F5E),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Tarjetas, bancos y billeteras virtuales',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.6)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPromotionsView extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyPromotionsView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF43F5E).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.credit_card_off_rounded,
                size: 56,
                color: Color(0xFFF43F5E),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No hay promociones guardadas',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Registrá tus promociones por día, banco y medio de pago (débito, crédito, MODO, Cuenta DNI) para ver tus precios con descuento aplicados automáticamente.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.35, fontSize: 13),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF43F5E),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar Primera Promo'),
            ),
          ],
        ),
      ),
    );
  }
}
