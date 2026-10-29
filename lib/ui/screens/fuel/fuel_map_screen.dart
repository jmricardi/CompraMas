import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../viewmodels/fuel_viewmodel.dart';
import '../../../models/fuel_model.dart';
import '../../../services/fuel_service.dart';
import '../../../services/location_service.dart';
import '../../components/app_header_top_bar.dart';
import 'components/fuel_map_controls.dart';
import 'components/fuel_station_markers.dart';

class FuelMapScreen extends StatefulWidget {
  const FuelMapScreen({super.key});

  @override
  State<FuelMapScreen> createState() => _FuelMapScreenState();
}

class _FuelMapScreenState extends State<FuelMapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final LatLng _defaultCenter = const LatLng(-34.6037, -58.3816); // Obelisco, CABA
  String _selectedFuelType = 'Todos';
  double _currentZoom = 13.0;
  final List<String> _fuelTypes = [
    'Todos',
    'Nafta',
    'Gasoil',
    'GNC',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
      _showPriceUpdateNoticeDialog();
    });
  }

  void _showPriceUpdateNoticeDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.info_outline, color: Colors.amber.shade900, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Aviso sobre la actualización de precios',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tras la derogación de la normativa que obligaba a las estaciones a declarar sus precios al Estado (Res. 717/2025), el 75% de las bocas de expendio del país (3.697 estaciones) llevan más de 6 meses sin asentar modificaciones en el registro nacional de Energía.',
                style: TextStyle(fontSize: 13.5, height: 1.45),
              ),
              SizedBox(height: 12),
              Text(
                'Al no existir canales oficiales alternativos para relevar esta información de forma directa, solo mostramos el valor en aquellas estaciones que continúan reportando sus datos. Para el resto, se indicará «Sin datos» con el fin de evitar información errónea o desactualizada.',
                style: TextStyle(fontSize: 13.5, height: 1.45),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _animatedMapMove(LatLng destLocation, double destZoom, [double? destRotation]) {
    final camera = _mapController.camera;
    final latTween = Tween<double>(begin: camera.center.latitude, end: destLocation.latitude);
    final lngTween = Tween<double>(begin: camera.center.longitude, end: destLocation.longitude);
    final zoomTween = Tween<double>(begin: camera.zoom, end: destZoom);
    final rotationTween = Tween<double>(
      begin: camera.rotation,
      end: destRotation ?? camera.rotation,
    );

    final controller = AnimationController(
      duration: const Duration(milliseconds: 320),
      vsync: this,
    );
    final animation = CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn);

    controller.addListener(() {
      _mapController.moveAndRotate(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
        rotationTween.evaluate(animation),
      );
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  Future<void> _loadInitialData() async {
    try {
      final pos = await LocationService.getCurrentLocation();
      if (!mounted) return;
      if (pos != null) {
        _animatedMapMove(LatLng(pos.latitude, pos.longitude), 13.5, 0.0);
        context.read<FuelViewModel>().loadFuelPrices(
          latitude: pos.latitude,
          longitude: pos.longitude,
          radiusKm: 15.0,
        );
        return;
      }
    } catch (_) {}

    if (!mounted) return;
    context.read<FuelViewModel>().loadFuelPrices(
      latitude: _defaultCenter.latitude,
      longitude: _defaultCenter.longitude,
      radiusKm: 15.0,
    );
  }

  Future<void> _centerOnUserLocation() async {
    final pos = await LocationService.getCurrentLocation();
    if (!mounted) return;

    if (pos != null) {
      _animatedMapMove(LatLng(pos.latitude, pos.longitude), 14.0, 0.0);
      context.read<FuelViewModel>().loadFuelPrices(
        latitude: pos.latitude,
        longitude: pos.longitude,
        radiusKm: 15.0,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo obtener la ubicación GPS actual.'),
        ),
      );
    }
  }

  void _zoomIn() {
    final camera = _mapController.camera;
    final targetZoom = (camera.zoom + 1.0).clamp(3.0, 18.0);
    _animatedMapMove(camera.center, targetZoom, camera.rotation);
  }

  void _zoomOut() {
    final camera = _mapController.camera;
    final targetZoom = (camera.zoom - 1.0).clamp(3.0, 18.0);
    _animatedMapMove(camera.center, targetZoom, camera.rotation);
  }

  Future<void> _refreshCurrentArea() async {
    final camera = _mapController.camera;
    final center = camera.center;
    final bounds = camera.visibleBounds;

    final distMeters = LocationService.calculateDistanceMeters(
      center.latitude,
      center.longitude,
      bounds.northEast.latitude,
      bounds.northEast.longitude,
    );

    final radiusKm = (distMeters / 1000.0).clamp(2.0, 35.0);

    if (!mounted) return;
    await context.read<FuelViewModel>().loadFuelPrices(
      latitude: center.latitude,
      longitude: center.longitude,
      radiusKm: radiusKm,
      productFilter: null,
    );
  }

  static List<FuelSubproductPrice> _getSubproductsForRecord(
    FuelRecord record,
    String category,
  ) {
    if (category == 'Todos') return const [];
    if (FuelService.isPriceOutdated(record.fechaVigencia)) return const [];
    final List<FuelSubproductPrice> list = [];
    final items = record.preciosDisponibles;

    if (category == 'Nafta') {
      final superItem = items.where((p) {
        final prod = p.producto.toLowerCase();
        return (prod.contains('súper') || prod.contains('super')) &&
            !prod.contains('diesel') &&
            !prod.contains('gasoil') &&
            !prod.contains('gnc');
      }).firstOrNull;
      if (superItem != null && superItem.precio > 0) {
        list.add(FuelSubproductPrice(
          label: 'Nafta Súper',
          shortLabel: 'Súper',
          price: superItem.precio,
        ));
      }

      final premItem = items.where((p) {
        final prod = p.producto.toLowerCase();
        return (prod.contains('premium') ||
                prod.contains('infinia') ||
                prod.contains('v-power') ||
                prod.contains('quantium') ||
                prod.contains('grado 3')) &&
            !prod.contains('diesel') &&
            !prod.contains('gasoil') &&
            !prod.contains('gnc');
      }).firstOrNull;
      if (premItem != null && premItem.precio > 0) {
        list.add(FuelSubproductPrice(
          label: 'Nafta Premium',
          shortLabel: 'Prem',
          price: premItem.precio,
        ));
      }

      if (list.isEmpty && record.precio != null && record.precio! > 0) {
        final prod = (record.producto ?? '').toLowerCase();
        if (_matchesCategory(prod, 'Nafta')) {
          final isPrem = prod.contains('premium') ||
              prod.contains('infinia') ||
              prod.contains('v-power') ||
              prod.contains('quantium') ||
              prod.contains('grado 3');
          list.add(FuelSubproductPrice(
            label: isPrem ? 'Nafta Premium' : 'Nafta Súper',
            shortLabel: isPrem ? 'Prem' : 'Súper',
            price: record.precio!,
          ));
        }
      }
    } else if (category == 'Gasoil') {
      final g2Item = items.where((p) {
        final prod = p.producto.toLowerCase();
        return prod.contains('grado 2') ||
            prod.contains('diesel 500') ||
            prod.contains('formula diesel') ||
            (prod.contains('gasoil') &&
                !prod.contains('grado 3') &&
                !prod.contains('premium') &&
                !prod.contains('infinia') &&
                !prod.contains('v-power'));
      }).firstOrNull;
      if (g2Item != null && g2Item.precio > 0) {
        list.add(FuelSubproductPrice(
          label: 'Gasoil Grado 2',
          shortLabel: 'Grado 2',
          price: g2Item.precio,
        ));
      }

      final g3Item = items.where((p) {
        final prod = p.producto.toLowerCase();
        return prod.contains('grado 3') ||
            prod.contains('infinia diesel') ||
            prod.contains('v-power diesel') ||
            prod.contains('quantium diesel') ||
            ((prod.contains('gasoil') || prod.contains('diesel')) &&
                (prod.contains('premium') ||
                    prod.contains('infinia') ||
                    prod.contains('v-power') ||
                    prod.contains('grado 3')));
      }).firstOrNull;
      if (g3Item != null && g3Item.precio > 0) {
        list.add(FuelSubproductPrice(
          label: 'Gasoil Grado 3',
          shortLabel: 'Grado 3',
          price: g3Item.precio,
        ));
      }

      if (list.isEmpty && record.precio != null && record.precio! > 0) {
        final prod = (record.producto ?? '').toLowerCase();
        if (_matchesCategory(prod, 'Gasoil')) {
          final isG3 = prod.contains('grado 3') ||
              prod.contains('infinia') ||
              prod.contains('v-power') ||
              prod.contains('premium');
          list.add(FuelSubproductPrice(
            label: isG3 ? 'Gasoil Grado 3' : 'Gasoil Grado 2',
            shortLabel: isG3 ? 'Grado 3' : 'Grado 2',
            price: record.precio!,
          ));
        }
      }
    } else if (category == 'GNC') {
      final gncItem = items
          .where((p) => p.producto.toLowerCase().contains('gnc'))
          .firstOrNull;
      if (gncItem != null && gncItem.precio > 0) {
        list.add(FuelSubproductPrice(
          label: 'GNC',
          shortLabel: 'GNC',
          price: gncItem.precio,
        ));
      } else if (record.precio != null &&
          record.precio! > 0 &&
          (record.producto ?? '').toLowerCase().contains('gnc')) {
        list.add(FuelSubproductPrice(
          label: 'GNC',
          shortLabel: 'GNC',
          price: record.precio!,
        ));
      }
    }

    return list;
  }

  static bool _matchesCategory(String? productName, String category) {
    if (productName == null) return false;
    final prod = productName.toLowerCase();
    if (category == 'Nafta') {
      return (prod.contains('nafta') || prod.contains('súper') || prod.contains('super') || prod.contains('premium')) &&
          !prod.contains('diesel') &&
          !prod.contains('gasoil') &&
          !prod.contains('gnc');
    } else if (category == 'Gasoil') {
      return (prod.contains('gasoil') || prod.contains('diesel') || prod.contains('grado 2') || prod.contains('grado 3')) &&
          !prod.contains('nafta') &&
          !prod.contains('gnc');
    } else if (category == 'GNC') {
      return prod.contains('gnc') || prod.contains('gas natural');
    }
    return false;
  }

  List<FuelRecord> _filterRecords(List<FuelRecord> all) {
    if (_selectedFuelType == 'Todos') {
      final Map<String, FuelRecord> unique = {};
      for (final r in all) {
        final key = '${r.idEmpresa ?? r.id}_${r.latitud}_${r.longitud}';
        if (!unique.containsKey(key)) {
          unique[key] = r;
        }
      }
      return unique.values.toList();
    }

    final List<FuelRecord> matched = [];
    final Set<String> seenStations = {};

    for (final r in all) {
      final key = '${r.idEmpresa ?? r.id}_${r.latitud}_${r.longitud}';
      if (seenStations.contains(key)) continue;

      // Si la estación solo vende GNC y filtramos Nafta o Gasoil, omitirla
      if (_selectedFuelType != 'GNC' && _isExclusivelyGnc(r)) {
        continue;
      }

      // Si filtramos GNC y la estación tiene productos explícitos cargados que demuestran que no tiene GNC
      if (_selectedFuelType == 'GNC' && _hasPricesButNoGnc(r)) {
        continue;
      }

      seenStations.add(key);
      matched.add(r);
    }

    return matched;
  }

  bool _isExclusivelyGnc(FuelRecord r) {
    final validPrices = r.preciosDisponibles.where((p) => p.precio > 0).toList();
    if (validPrices.isNotEmpty) {
      return validPrices.every((p) => p.producto.toLowerCase().contains('gnc'));
    }
    final emp = (r.empresa ?? '').toLowerCase();
    final bandera = (r.empresaBandera ?? '').toLowerCase();
    final prod = (r.producto ?? '').toLowerCase();
    if (prod.isNotEmpty) {
      return prod.contains('gnc') && !prod.contains('nafta') && !prod.contains('gasoil') && !prod.contains('diesel');
    }
    return emp.contains('gnc') || bandera.contains('gnc');
  }

  bool _hasPricesButNoGnc(FuelRecord r) {
    final validPrices = r.preciosDisponibles.where((p) => p.precio > 0).toList();
    if (validPrices.isNotEmpty) {
      return !validPrices.any((p) => p.producto.toLowerCase().contains('gnc'));
    }
    final prod = (r.producto ?? '').toLowerCase();
    if (prod.isNotEmpty && !prod.contains('gnc')) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<FuelViewModel>();
    final filtered = _filterRecords(viewModel.records);
    final isInitialLoading = viewModel.status == FuelStatus.loading && viewModel.records.isEmpty;
    final isRefreshing = viewModel.status == FuelStatus.loading && viewModel.records.isNotEmpty;
    final hasMap = viewModel.status == FuelStatus.success || viewModel.records.isNotEmpty;

    return Scaffold(
      appBar: AppHeaderTopBar(
        title: 'Combustibles en Surtidor',
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            tooltip: 'Aviso de precios',
            onPressed: _showPriceUpdateNoticeDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (isInitialLoading)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando estaciones de OpenStreetMap y precios oficiales...'),
                ],
              ),
            )
          else if (viewModel.status == FuelStatus.error && viewModel.records.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    viewModel.errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => viewModel.loadFuelPrices(),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          else if (hasMap)
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _defaultCenter,
                initialZoom: 13.0,
                onPositionChanged: (camera, hasGesture) {
                  if ((camera.zoom - _currentZoom).abs() > 0.15) {
                    setState(() {
                      _currentZoom = camera.zoom;
                    });
                  }
                },
                onTap: (_, _) => viewModel.selectStation(null),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom |
                      InteractiveFlag.drag |
                      InteractiveFlag.doubleTapZoom |
                      InteractiveFlag.scrollWheelZoom |
                      InteractiveFlag.flingAnimation,
                ),
              ),
              children: [
                // Capa base OpenStreetMap oficial estándar (sin requerimiento de API Key)
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'dev.arandulabs.compramas',
                  maxZoom: 19,
                ),
                // Capa de marcadores de estaciones con logo y precios de subproductos (siempre horizontales con rotate: true)
                MarkerLayer(
                  rotate: true,
                  markers: filtered.map((record) {
                    final isFuelFilterActive = _selectedFuelType != 'Todos';
                    final subproducts = isFuelFilterActive
                        ? _getSubproductsForRecord(record, _selectedFuelType)
                        : const <FuelSubproductPrice>[];
                    final hasMulti = subproducts.length > 1;

                    // Escala moderada de zoom para agrandar precios cuando se acerca el mapa
                    final zoomScale = (1.0 + (_currentZoom - 13.0) * 0.10).clamp(0.85, 1.45);
                    final baseWidth = !isFuelFilterActive ? 42.0 : (hasMulti ? 132.0 : 116.0);
                    final baseHeight = !isFuelFilterActive ? 42.0 : (hasMulti ? 44.0 : 38.0);

                    return Marker(
                      point: LatLng(record.latitud!, record.longitud!),
                      width: baseWidth * zoomScale,
                      height: baseHeight * zoomScale,
                      rotate: true,
                      child: Transform.scale(
                        scale: zoomScale,
                        alignment: Alignment.center,
                        child: StationMarkerPin(
                          record: record,
                          showPrice: isFuelFilterActive,
                          subproducts: subproducts,
                          onTap: () => viewModel.selectStation(record),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                // Atribución de OpenStreetMap (requerida por licencia ODbL)
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      '© OpenStreetMap contributors',
                      onTap: () {},
                    ),
                  ],
                ),
              ],
            ),
          // Selector horizontal de tipo de combustible
          if (hasMap)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: FuelTypeFilterChips(
                fuelTypes: _fuelTypes,
                selected: _selectedFuelType,
                onSelected: (val) => setState(() => _selectedFuelType = val),
              ),
            ),
          // Botón flotante para refrescar / buscar en el área visible actual
          if (hasMap)
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: SearchAreaPillButton(
                isRefreshing: isRefreshing,
                onRefresh: _refreshCurrentArea,
              ),
            ),
          // Botones de control del mapa (Mi ubicación, Zoom +, Zoom -)
          if (hasMap)
            Positioned(
              top: 116,
              right: 14,
              child: MapControlButtons(
                onLocation: _centerOnUserLocation,
                onZoomIn: _zoomIn,
                onZoomOut: _zoomOut,
              ),
            ),
          // Ficha de detalle de la estación seleccionada
          if (viewModel.selectedStation != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: StationDetailCard(
                station: viewModel.selectedStation!,
                onClose: () => viewModel.selectStation(null),
              ),
            ),
        ],
      ),
    );
  }
}








