import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/discount_model.dart';
import '../../../models/folleto_model.dart';
import '../../../models/oferta_semanal_model.dart';
import '../../../services/folletos_service.dart';
import '../../../viewmodels/discount_viewmodel.dart';
import '../../components/app_header_top_bar.dart';
import 'widgets/discount_card.dart';
import 'widgets/discount_form_sheet.dart';
import 'widgets/folletos_carousel.dart';
import 'widgets/ofertas_destacadas_section.dart';

class DiscountsScreen extends StatefulWidget {
  const DiscountsScreen({super.key});

  @override
  State<DiscountsScreen> createState() => _DiscountsScreenState();
}

class _DiscountsScreenState extends State<DiscountsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FolletosService _folletosService = FolletosService();

  List<FolletoModel> _folletos = [];
  List<OfertaSemanalModel> _ofertas = [];
  bool _isLoadingOfertas = true;
  String _cadenaFiltro = 'Todas';
  List<String> _cadenasDisponibles = ['Todas'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DiscountViewModel>().loadDiscounts();
      _cargarDatosFolletos();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosFolletos() async {
    setState(() => _isLoadingOfertas = true);

    try {
      final folletosFuture = _folletosService.getFolletosActivos();
      final ofertasFuture = _folletosService.getOfertasSemanales(
        cadena: _cadenaFiltro == 'Todas' ? null : _cadenaFiltro,
      );

      final results = await Future.wait([folletosFuture, ofertasFuture]);
      if (!mounted) return;

      final folletos = results[0] as List<FolletoModel>;
      final ofertas = results[1] as List<OfertaSemanalModel>;

      final Set<String> cadenasSet = {'Todas'};
      for (final f in folletos) {
        cadenasSet.add(f.cadena);
      }
      for (final o in ofertas) {
        cadenasSet.add(o.cadena);
      }

      setState(() {
        _folletos = folletos;
        _ofertas = ofertas;
        _cadenasDisponibles = cadenasSet.toList();
        _isLoadingOfertas = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingOfertas = false);
    }
  }

  Future<void> _onCadenaChanged(String nuevaCadena) async {
    setState(() {
      _cadenaFiltro = nuevaCadena;
      _isLoadingOfertas = true;
    });

    final ofertas = await _folletosService.getOfertasSemanales(
      cadena: nuevaCadena == 'Todas' ? null : nuevaCadena,
    );

    if (!mounted) return;
    setState(() {
      _ofertas = ofertas;
      _isLoadingOfertas = false;
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

  Widget _buildUnifiedCadenaFilter() {
    if (_cadenasDisponibles.length <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Filtrar por comercio:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 38,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _cadenasDisponibles.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final c = _cadenasDisponibles[index];
                final isSelected = c == _cadenaFiltro;
                return ChoiceChip(
                  label: Text(
                    c,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : Colors.grey.shade800,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: Theme.of(context).primaryColor,
                  backgroundColor: Colors.grey.shade100,
                  onSelected: (_) => _onCadenaChanged(c),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DiscountViewModel>();

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(126),
        child: Column(
          children: [
            const AppHeaderTopBar(title: 'Ofertas y Promociones'),
            Container(
              color: Theme.of(context).cardColor,
              child: TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).primaryColor,
                indicatorColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey.shade600,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.auto_stories, size: 20),
                    text: 'Ofertas y Folletos',
                  ),
                  Tab(
                    icon: Icon(Icons.credit_card, size: 20),
                    text: 'Promociones',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: () => _openDiscountForm(),
              icon: const Icon(Icons.add),
              label: const Text('Nueva Promo'),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          // Pestaña 1: Folletos de Supermercados y Ofertas de la Semana
          RefreshIndicator(
            onRefresh: _cargarDatosFolletos,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 40),
              child: Builder(
                builder: (context) {
                  final folletosFiltrados = _cadenaFiltro == 'Todas'
                      ? _folletos
                      : _folletos.where((f) {
                          final fCad = f.cadena.toLowerCase();
                          final fil = _cadenaFiltro.toLowerCase();
                          return fCad.contains(fil) || fil.contains(fCad);
                        }).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildUnifiedCadenaFilter(),
                      const SizedBox(height: 6),
                      FolletosCarousel(
                        folletos: folletosFiltrados,
                        isLoading: _isLoadingOfertas && _folletos.isEmpty,
                        onRefresh: _cargarDatosFolletos,
                      ),
                      if (folletosFiltrados.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Divider(height: 24, thickness: 1),
                        ),
                      OfertasDestacadasSection(
                        ofertas: _ofertas,
                        isLoading: _isLoadingOfertas,
                        cadenaSeleccionada: _cadenaFiltro,
                        cadenasDisponibles: _cadenasDisponibles,
                        onCadenaChanged: _onCadenaChanged,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // Pestaña 2: Mis Promociones Bancarias Guardadas
          viewModel.isLoading
              ? const Center(child: CircularProgressIndicator())
              : viewModel.discounts.isEmpty
                  ? _EmptyDiscountsView(onAdd: () => _openDiscountForm())
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      itemCount: viewModel.discounts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
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
        ],
      ),
    );
  }
}

class _EmptyDiscountsView extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyDiscountsView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.credit_card_off_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No hay promociones guardadas',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Registrá tus promociones por día, banco y medio de pago (débito, crédito, MODO, Cuenta DNI) para ver tus precios con descuento aplicados automáticamente.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.3, fontSize: 13),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Agregar Primera Promo'),
            ),
          ],
        ),
      ),
    );
  }
}
