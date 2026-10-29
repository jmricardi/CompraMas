import 'package:compramas/ui/components/glass_card.dart';
import 'package:flutter/material.dart';
import 'package:compramas/models/fuel_model.dart';
import 'package:compramas/services/fuel_service.dart';

class StationMarkerPin extends StatelessWidget {
  final FuelRecord record;
  final bool showPrice;
  final List<FuelSubproductPrice> subproducts;
  final VoidCallback onTap;

  const StationMarkerPin({
    super.key,
    required this.record,
    required this.showPrice,
    this.subproducts = const [],
    required this.onTap,
  });

  Color _getBrandColor(String? brand) {
    final b = (brand ?? '').toUpperCase();
    if (b.contains('YPF')) return const Color(0xFF003399);
    if (b.contains('SHELL')) return const Color(0xFFDD1D21);
    if (b.contains('AXION')) return const Color(0xFF7A1A78);
    if (b.contains('PUMA')) return const Color(0xFF007A33);
    if (b.contains('DAPSA')) return const Color(0xFF002D62);
    if (b.contains('GULF')) return const Color(0xFFFF6600);
    if (b.contains('REFINOR')) return const Color(0xFF00838F);
    if (b.contains('VOY')) return const Color(0xFF43A047);
    return Colors.blueGrey.shade800;
  }

  @override
  Widget build(BuildContext context) {
    final brand = record.empresaBandera ?? record.empresa;
    final brandColor = _getBrandColor(brand);

    if (!showPrice) {
      return _buildCircleMarker(brand);
    }

    if (subproducts.length > 1) {
      return _buildMultiPriceMarker(brand, brandColor);
    }

    return _buildSinglePriceMarker(brand, brandColor);
  }

  Widget _buildCircleMarker(String? brand) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(3),
        child: FuelBrandBadge(brand: brand, size: 36),
      ),
    );
  }

  Widget _buildMultiPriceMarker(String? brand, Color brandColor) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: brandColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FuelBrandBadge(brand: brand, size: 24),
            const SizedBox(width: 4),
            Container(width: 1, height: 26, color: brandColor.withValues(alpha: 0.25)),
            const SizedBox(width: 4),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final sp in subproducts.take(2))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 0.5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${sp.shortLabel}: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 9.5,
                            color: Colors.grey.shade700,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          '\$${sp.price.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 10.5,
                            color: brandColor,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSinglePriceMarker(String? brand, Color brandColor) {
    String label;
    if (subproducts.isNotEmpty) {
      final sp = subproducts.first;
      label = '${sp.shortLabel}: \$${sp.price.toStringAsFixed(0)}';
    } else {
      final isOutdated = FuelService.isPriceOutdated(record.fechaVigencia);
      final hasPrice = record.precio != null && record.precio! > 0 && !isOutdated;
      label = hasPrice ? '\$${record.precio!.toStringAsFixed(0)}' : 'Sin datos';
    }

    final isSinDatos = label == 'Sin datos';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSinDatos ? Colors.grey.shade400 : brandColor,
            width: 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FuelBrandBadge(brand: brand, size: 26),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: isSinDatos ? 11.0 : 11.5,
                color: isSinDatos ? Colors.grey.shade700 : brandColor,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String cleanFuelProductName(String? name) {
  if (name == null || name.trim().isEmpty) return '';
  final lower = name.toLowerCase();
  if (lower.contains('super') || lower.contains('súper')) {
    return 'Nafta Súper';
  }
  if (lower.contains('premium') && (lower.contains('nafta') || (!lower.contains('diesel') && !lower.contains('gasoil')))) {
    return 'Nafta Premium';
  }
  if (lower.contains('grado 3') || lower.contains('infinia diesel') || lower.contains('v-power diesel') || lower.contains('quantium diesel')) {
    return 'Gasoil Grado 3';
  }
  if (lower.contains('grado 2') || lower.contains('diesel 500') || lower.contains('formula diesel') || lower.contains('gasoil') || lower.contains('diesel')) {
    return 'Gasoil Grado 2';
  }
  if (lower.contains('gnc') || lower.contains('gas natural')) {
    return 'GNC';
  }
  return name;
}

class FuelBrandBadge extends StatelessWidget {
  final String? brand;
  final double size;

  const FuelBrandBadge({super.key, this.brand, this.size = 28});

  static String? getBrandAsset(String? brand) {
    final b = (brand ?? '').toUpperCase();
    if (b.contains('YPF')) return 'assets/icons/estaciones/ypf.png';
    if (b.contains('SHELL') || b.contains('RAIZEN')) return 'assets/icons/estaciones/shell.png';
    if (b.contains('AXION') || b.contains('ESSO')) return 'assets/icons/estaciones/axion.png';
    if (b.contains('PUMA') || b.contains('TRAFIGURA')) return 'assets/icons/estaciones/puma.png';
    if (b.contains('GULF')) return 'assets/icons/estaciones/gulf.png';
    if (b.contains('DAPSA')) return 'assets/icons/estaciones/dapsa.png';
    if (b.contains('REFINOR')) return 'assets/icons/estaciones/refinor.png';
    if (b.contains('VOY')) return 'assets/icons/estaciones/voy.png';
    return null; // Bandera blanca u otras marcas sin logo oficial
  }

  Widget _buildGenericPump(double s) {
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade700,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.2),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.local_gas_station,
        color: Colors.white,
        size: s * 0.62,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assetPath = getBrandAsset(brand);
    if (assetPath == null) {
      return _buildGenericPump(size);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ClipOval(
        child: Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildGenericPump(size),
        ),
      ),
    );
  }
}

class StationDetailCard extends StatelessWidget {
  final FuelRecord station;
  final VoidCallback onClose;

  const StationDetailCard({super.key, required this.station, required this.onClose});

  DateTime? _extractLatestDate(FuelRecord station) {
    DateTime? maxDate;
    void check(String? raw) {
      if (raw == null || raw.trim().isEmpty) return;
      DateTime? d;
      final clean = raw.trim();
      try {
        d = DateTime.parse(clean.replaceFirst(' ', 'T'));
      } catch (_) {
        final parts = clean.split(' ')[0].split('/');
        if (parts.length == 3) {
          final day = int.tryParse(parts[0]);
          final month = int.tryParse(parts[1]);
          final year = int.tryParse(parts[2]);
          if (day != null && month != null && year != null) {
            d = DateTime(year, month, day);
          }
        }
      }
      if (d != null) {
        if (maxDate == null || d.isAfter(maxDate!)) {
          maxDate = d;
        }
      }
    }

    check(station.fechaVigencia);
    for (final item in station.preciosDisponibles) {
      check(item.fechaVigencia);
    }
    return maxDate;
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Sin datos';
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    if (dt.hour != 0 || dt.minute != 0) {
      final hour = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$min hs';
    }
    return '$day/$month/$year';
  }

  Widget _buildHeader(BuildContext context, String title) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FuelBrandBadge(
          brand: station.empresaBandera ?? station.empresa,
          size: 38,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (station.distanciaKm != null)
                Text(
                  'A ${station.distanciaKm!.toStringAsFixed(1)} km de distancia',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 20),
          onPressed: onClose,
        ),
      ],
    );
  }

  Widget _buildAddress() {
    if (station.direccion == null) return const SizedBox.shrink();
    return Text(
      '${station.direccion}, ${station.localidad ?? ''}',
      style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
    );
  }

  Widget _buildPricesList(BuildContext context, List<FuelPriceItem> sortedPrices, bool isStationOutdated) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 180),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: sortedPrices.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final item = sortedPrices[index];
          final isSelected = station.producto != null &&
              item.producto.toLowerCase() == station.producto!.toLowerCase();
          final isItemOutdated = isStationOutdated ||
              FuelService.isPriceOutdated(item.fechaVigencia) ||
              item.precio <= 0;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.7)
                  : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5)
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    cleanFuelProductName(item.producto),
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  isItemOutdated
                      ? 'Sin datos'
                      : '\$${item.precio.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isItemOutdated ? 13 : 15,
                    color: isItemOutdated
                        ? Colors.grey.shade600
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSinglePrice(BuildContext context, bool isStationOutdated) {
    final isOutdated = isStationOutdated || station.precio == null || station.precio! <= 0;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            cleanFuelProductName(station.producto).isNotEmpty
                ? cleanFuelProductName(station.producto)
                : (station.producto ?? 'Combustible'),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          Text(
            isOutdated ? 'Sin datos' : '\$${station.precio!.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isOutdated ? 14 : 18,
              color: isOutdated
                  ? Colors.grey.shade600
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final latestDate = _extractLatestDate(station);
    final hasDate = latestDate != null;
    final dateStr = _formatDate(latestDate);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        Divider(
          height: 1,
          thickness: 0.8,
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 13,
                  color: Colors.blueGrey.shade600,
                ),
                const SizedBox(width: 5),
                Text(
                  'Última actualización:',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.blueGrey.shade600,
                  ),
                ),
              ],
            ),
            Text(
              dateStr,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: hasDate
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = station.empresaBandera ?? station.empresa ?? 'Estación de Servicio';
    final isStationOutdated = FuelService.isPriceOutdated(station.fechaVigencia);
    final sortedPrices = _sortFuelPrices(station.preciosDisponibles);
    final hasMultiplePrices = sortedPrices.isNotEmpty;

    return GlassCard(
      backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context, title),
          _buildAddress(),
          const SizedBox(height: 10),
          if (hasMultiplePrices)
            _buildPricesList(context, sortedPrices, isStationOutdated)
          else
            _buildSinglePrice(context, isStationOutdated),
          _buildFooter(context),
        ],
      ),
    );
  }
}

List<FuelPriceItem> _sortFuelPrices(List<FuelPriceItem> items) {
  int getCategoryPriority(String name) {
    final p = name.toLowerCase();
    // 1. Nafta Súper
    if (p.contains('súper') || p.contains('super')) return 1;
    // 2. Nafta Premium / Otras naftas
    if (p.contains('premium') || p.contains('infinia') || p.contains('nafta')) return 2;
    // 3. GNC
    if (p.contains('gnc')) return 3;
    // 4. Gasoil Grado 2 / Diesel común
    if (p.contains('grado 2') || (p.contains('gasoil') && !p.contains('grado 3')) || p.contains('diesel 500')) return 4;
    // 5. Gasoil Grado 3 / Diesel premium
    if (p.contains('grado 3') || p.contains('diesel') || p.contains('gasoil')) return 5;
    // 6. Otros
    return 6;
  }

  final list = List<FuelPriceItem>.from(items);
  list.sort((a, b) {
    final prioA = getCategoryPriority(a.producto);
    final prioB = getCategoryPriority(b.producto);
    if (prioA != prioB) return prioA.compareTo(prioB);
    return a.producto.compareTo(b.producto);
  });
  return list;
}

