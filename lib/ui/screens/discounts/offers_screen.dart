import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/folleto_model.dart';
import '../../../models/oferta_semanal_model.dart';
import '../../../services/folletos_service.dart';
import '../../components/ads/compramas_banner_ad.dart';
import 'widgets/folletos_carousel.dart';
import 'widgets/ofertas_destacadas_section.dart';

/// Pantalla dedicada a "Ofertas y Folletos".
///
/// Diseño Bento/Claymorphism sin pestañas rígidas:
/// - Filtros de comercio directamente accesibles en la parte superior.
/// - Folletos vigentes de la semana y catálogo de ofertas destacadas.
/// - Espacio final generoso (al menos 2 tarjetas de producto) para evitar
///   solapamiento con el banner publicitario inferior.
class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  final FolletosService _folletosService = FolletosService();

  List<FolletoModel> _folletos = [];
  List<OfertaSemanalModel> _ofertas = [];
  bool _isLoading = true;
  String _cadenaFiltro = 'Todas';
  List<String> _cadenasDisponibles = ['Todas'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _cargarDatos();
    });
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);

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
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onCadenaChanged(String nuevaCadena) async {
    setState(() {
      _cadenaFiltro = nuevaCadena;
      _isLoading = true;
    });

    final ofertas = await _folletosService.getOfertasSemanales(
      cadena: nuevaCadena == 'Todas' ? null : nuevaCadena,
    );

    if (!mounted) return;
    setState(() {
      _ofertas = ofertas;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            // 1. Barra de cabecera limpia estilo Bento (sin TabBar)
            _buildHeader(context, isDark),

            // 2. Filtro directo por comercio/cadena
            _buildCadenaFilterBar(primaryColor),

            // 3. Feed de Folletos y Ofertas con espacio inferior ampliado (al menos 2 tarjetas)
            Expanded(
              child: RefreshIndicator(
                onRefresh: _cargarDatos,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(bottom: 260),
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
                          FolletosCarousel(
                            folletos: folletosFiltrados,
                            isLoading: _isLoading && _folletos.isEmpty,
                            onRefresh: _cargarDatos,
                          ),
                          if (folletosFiltrados.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Divider(height: 24, thickness: 1),
                            ),
                          OfertasDestacadasSection(
                            ofertas: _ofertas,
                            isLoading: _isLoading,
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
            ),

            // 4. Banner Publicitario responsivo (60 dp teléfono / 90 dp tablet)
            const CompraMasBannerAd(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        child: Stack(
          children: [
            // Imagen de fondo header.png
            Positioned.fill(
              child: Image.asset(
                'assets/images/header.png',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1E1B4B), Color(0xFF4338CA)],
                    ),
                  ),
                ),
              ),
            ),
            // Capa oscura translúcida para garantizar legibilidad perfecta
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.45),
                      Colors.black.withValues(alpha: 0.65),
                    ],
                  ),
                ),
              ),
            ),
            // Contenido con letras en fuente blanco
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 14, 16, 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Volver',
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Ofertas y Folletos',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.4,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Catálogos vigentes y precios de la semana',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCadenaFilterBar(Color primaryColor) {
    if (_cadenasDisponibles.length <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 8),
      child: SizedBox(
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
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey.shade800,
                ),
              ),
              selected: isSelected,
              selectedColor: primaryColor,
              backgroundColor: Colors.grey.shade100,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onSelected: (_) => _onCadenaChanged(c),
            );
          },
        ),
      ),
    );
  }
}
