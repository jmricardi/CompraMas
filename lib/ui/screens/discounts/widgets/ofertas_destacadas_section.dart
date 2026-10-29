import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../../models/oferta_semanal_model.dart';

class OfertasDestacadasSection extends StatelessWidget {
  final List<OfertaSemanalModel> ofertas;
  final bool isLoading;
  final String cadenaSeleccionada;
  final List<String> cadenasDisponibles;
  final ValueChanged<String> onCadenaChanged;
  final bool showCadenaFilter;

  const OfertasDestacadasSection({
    super.key,
    required this.ofertas,
    this.isLoading = false,
    required this.cadenaSeleccionada,
    required this.cadenasDisponibles,
    required this.onCadenaChanged,
    this.showCadenaFilter = false,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'es_AR', symbol: r'$', decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título de la sección
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department, color: Colors.deepOrange, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Ofertas de la semana',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (!isLoading && ofertas.isNotEmpty)
                Text(
                  '${ofertas.length} ofertas',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ),

        // Filtro de cadenas (Chips horizontales si está habilitado)
        if (showCadenaFilter && cadenasDisponibles.length > 1)
          SizedBox(
            height: 38,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: cadenasDisponibles.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final c = cadenasDisponibles[index];
                final isSelected = c == cadenaSeleccionada;
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
                  onSelected: (_) => onCadenaChanged(c),
                );
              },
            ),
          ),

        const SizedBox(height: 12),

        // Contenido de ofertas
        if (isLoading)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (ofertas.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    'No hay ofertas registradas para $cadenaSeleccionada',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: ofertas.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final oferta = ofertas[index];
              return _OfertaCard(
                oferta: oferta,
                currencyFormatter: currencyFormatter,
              );
            },
          ),
      ],
    );
  }
}

class _OfertaCard extends StatelessWidget {
  final OfertaSemanalModel oferta;
  final NumberFormat currencyFormatter;

  const _OfertaCard({
    required this.oferta,
    required this.currencyFormatter,
  });

  void _mostrarDetalleOferta(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _OfertaDetalleDialog(
        oferta: oferta,
        currencyFormatter: currencyFormatter,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _mostrarDetalleOferta(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildRecorteThumbnail(),
            const SizedBox(width: 12),
            Expanded(child: _buildProductInfo()),
            const SizedBox(width: 8),
            _buildPriceColumn(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecorteThumbnail() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 70,
        height: 70,
        color: Colors.grey.shade100,
        child: (oferta.imagenRecorteUrl != null && oferta.imagenRecorteUrl!.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: oferta.imagenRecorteUrl!,
                fit: BoxFit.contain,
                placeholder: (_, _) => const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (_, _, _) => const Icon(Icons.shopping_bag_outlined, color: Colors.grey),
              )
            : const Icon(Icons.shopping_bag_outlined, color: Colors.grey),
      ),
    );
  }

  Widget _buildProductInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                oferta.cadena,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
            if (oferta.numeroPagina != null) ...[
              const SizedBox(width: 6),
              Text(
                'Pág. ${oferta.numeroPagina}',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          oferta.titulo,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        if (oferta.presentacion != null && oferta.presentacion!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            oferta.presentacion!,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ],
    );
  }

  Widget _buildPriceColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (oferta.descuentoPorcentaje != null && oferta.descuentoPorcentaje! > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red.shade600,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '-${oferta.descuentoPorcentaje}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        Text(
          currencyFormatter.format(oferta.precioOferta),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        if (oferta.precioAnterior != null && oferta.precioAnterior! > oferta.precioOferta)
          Text(
            currencyFormatter.format(oferta.precioAnterior),
            style: TextStyle(
              fontSize: 11,
              decoration: TextDecoration.lineThrough,
              color: Colors.grey.shade500,
            ),
          ),
      ],
    );
  }
}

class _OfertaDetalleDialog extends StatelessWidget {
  final OfertaSemanalModel oferta;
  final NumberFormat currencyFormatter;

  const _OfertaDetalleDialog({
    required this.oferta,
    required this.currencyFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final badgeLabel = oferta.cadena +
        (oferta.numeroPagina != null ? ' • Pág. ${oferta.numeroPagina}' : '');
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text(
                    badgeLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            if (oferta.imagenRecorteUrl != null && oferta.imagenRecorteUrl!.isNotEmpty)
              SizedBox(
                height: 250,
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: CachedNetworkImage(
                    imageUrl: oferta.imagenRecorteUrl!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              oferta.titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            if (oferta.presentacion != null && oferta.presentacion!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                oferta.presentacion!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
            const SizedBox(height: 12),
            _buildPricesRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildPricesRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          currencyFormatter.format(oferta.precioOferta),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.green,
          ),
        ),
        if (oferta.precioAnterior != null && oferta.precioAnterior! > oferta.precioOferta) ...[
          const SizedBox(width: 10),
          Text(
            currencyFormatter.format(oferta.precioAnterior),
            style: TextStyle(
              fontSize: 14,
              decoration: TextDecoration.lineThrough,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ],
    );
  }
}
