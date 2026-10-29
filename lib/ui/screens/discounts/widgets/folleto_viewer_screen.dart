import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../models/folleto_model.dart';
import '../../../../models/oferta_semanal_model.dart';
import '../../../../services/folletos_service.dart';

class FolletoViewerScreen extends StatefulWidget {
  final FolletoModel folleto;
  final int initialPage;

  const FolletoViewerScreen({
    super.key,
    required this.folleto,
    this.initialPage = 0,
  });

  @override
  State<FolletoViewerScreen> createState() => _FolletoViewerScreenState();
}

class _FolletoViewerScreenState extends State<FolletoViewerScreen> {
  final FolletosService _folletosService = FolletosService();
  late final PageController _pageController;
  final TransformationController _transController = TransformationController();
  final NumberFormat _currencyFmt = NumberFormat.currency(
    locale: 'es_AR',
    symbol: r'$',
    decimalDigits: 0,
  );

  List<OfertaSemanalModel> _ofertas = [];
  bool _isLoadingOfertas = true;
  bool _showGridMode = false;
  int _currentSlide = 0;
  bool _isZoomed = false;

  List<String> get _imagePages {
    // Si la página es un PDF (como los de Vital), usar la portada para la previsualización visual
    final validImages = widget.folleto.paginasUrls
        .where((u) => !u.toLowerCase().endsWith('.pdf'))
        .toList();

    if (validImages.isNotEmpty) {
      return validImages;
    }
    if (widget.folleto.portadaUrl.isNotEmpty &&
        !widget.folleto.portadaUrl.toLowerCase().endsWith('.pdf')) {
      return [widget.folleto.portadaUrl];
    }
    return [];
  }

  bool get _isPdfCatalog =>
      widget.folleto.paginasUrls.any((u) => u.toLowerCase().endsWith('.pdf')) ||
      widget.folleto.portadaUrl.toLowerCase().endsWith('.pdf');

  int get _totalSlides => _imagePages.length;

  @override
  void initState() {
    super.initState();
    _currentSlide = widget.initialPage;
    _pageController = PageController(initialPage: _currentSlide);
    _transController.addListener(_handleTransformationChange);
    _cargarOfertasDelFolleto();
  }

  void _handleTransformationChange() {
    final scale = _transController.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.05;
    if (zoomed != _isZoomed) {
      setState(() {
        _isZoomed = zoomed;
      });
    }
  }

  Future<void> _cargarOfertasDelFolleto() async {
    setState(() => _isLoadingOfertas = true);
    var list = await _folletosService.getOfertasPorFolleto(widget.folleto.id);
    if (list.isEmpty) {
      list = await _folletosService.getOfertasSemanales(
        cadena: widget.folleto.cadena,
        limit: 80,
      );
    }
    if (!mounted) return;
    setState(() {
      _ofertas = list;
      _isLoadingOfertas = false;
    });
  }

  @override
  void dispose() {
    _transController.removeListener(_handleTransformationChange);
    _pageController.dispose();
    _transController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transController.value = Matrix4.identity();
    if (_isZoomed) {
      setState(() => _isZoomed = false);
    }
  }

  void _goToSlide(int slide) {
    if (slide >= 0 && slide < _totalSlides) {
      _resetZoom();
      _pageController.animateToPage(
        slide,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: _isLoadingOfertas
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF10B981)),
              )
            : (_showGridMode ? _buildOffersListView() : _buildMagazineSwipeView()),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final vigencia = widget.folleto.fechaHasta != null
        ? ' • Hasta ${widget.folleto.fechaHasta!.day.toString().padLeft(2, '0')}/${widget.folleto.fechaHasta!.month.toString().padLeft(2, '0')}'
        : '';

    return AppBar(
      backgroundColor: const Color(0xFF0F172A),
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => Navigator.of(context).pop(),
        tooltip: 'Volver',
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.folleto.titulo,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '${widget.folleto.cadena}$vigencia (${_ofertas.length} ofertas)',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
      actions: [
        if (_ofertas.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () => setState(() => _showGridMode = !_showGridMode),
              icon: Icon(
                _showGridMode ? Icons.auto_stories_rounded : Icons.grid_view_rounded,
                size: 16,
                color: const Color(0xFF10B981),
              ),
              label: Text(
                _showGridMode ? 'Ver Páginas' : 'Ver Lista (${_ofertas.length})',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMagazineSwipeView() {
    final total = _totalSlides;
    if (total == 0) {
      final target = widget.folleto.visorUrl ?? widget.folleto.urlOficialCadena;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  size: 56,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.folleto.titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Este catálogo de ${widget.folleto.cadena} se encuentra disponible directamente en el visor digital oficial de la cadena.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  launchUrl(Uri.parse(target), mode: LaunchMode.externalApplication);
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Abrir folleto en línea'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
              ),
              if (_ofertas.isNotEmpty) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => setState(() => _showGridMode = true),
                  icon: const Icon(Icons.list_alt_rounded, size: 18, color: Color(0xFF6EE7B7)),
                  label: Text(
                    'Ver ${_ofertas.length} productos destacados',
                    style: const TextStyle(color: Color(0xFF6EE7B7), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: total,
          physics: _isZoomed
              ? const NeverScrollableScrollPhysics()
              : const PageScrollPhysics(),
          onPageChanged: (idx) {
            _resetZoom();
            setState(() => _currentSlide = idx);
          },
          itemBuilder: (context, index) {
            return _buildFullPageImageSlide(_imagePages[index]);
          },
        ),
        if (total > 1) _buildBottomPaginationBar(total),
      ],
    );
  }

  Widget _buildFullPageImageSlide(String pageUrl) {
    return GestureDetector(
      onDoubleTap: () {
        if (_isZoomed) {
          _resetZoom();
        } else {
          _transController.value = Matrix4.diagonal3Values(2.5, 2.5, 1.0);
        }
      },
      child: InteractiveViewer(
        transformationController: _transController,
        minScale: 1.0,
        maxScale: 4.5,
        clipBehavior: Clip.none,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: pageUrl,
            fit: BoxFit.contain,
            placeholder: (_, _) => const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF10B981),
              ),
            ),
            errorWidget: (_, _, _) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.picture_as_pdf_rounded, size: 54, color: Color(0xFFEF4444)),
                const SizedBox(height: 12),
                Text(
                  _isPdfCatalog ? 'Catálogo completo en PDF' : 'Error al cargar la imagen de página',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tocá abajo para abrir el visor oficial interactivo',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    final target = widget.folleto.visorUrl ?? widget.folleto.urlOficialCadena;
                    launchUrl(Uri.parse(target), mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Abrir catálogo oficial'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOffersListView() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
      itemCount: _ofertas.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final o = _ofertas[index];
        return _FolletoOfferListTile(
          oferta: o,
          currencyFmt: _currencyFmt,
          onTap: () => _showOfferZoomModal(o),
        );
      },
    );
  }

  Widget _buildBottomPaginationBar(int total) {
    return Positioned(
      bottom: 16,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 24),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _currentSlide > 0 ? () => _goToSlide(_currentSlide - 1) : null,
              ),
              const SizedBox(width: 14),
              Text(
                'Página ${_currentSlide + 1} / $total',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 14),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 24),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _currentSlide < total - 1 ? () => _goToSlide(_currentSlide + 1) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOfferZoomModal(OfertaSemanalModel oferta) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
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
                      oferta.cadena,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              if (oferta.imagenRecorteUrl != null && oferta.imagenRecorteUrl!.isNotEmpty)
                SizedBox(
                  height: 260,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _currencyFmt.format(oferta.precioOferta),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF059669),
                    ),
                  ),
                  if (oferta.precioAnterior != null &&
                      oferta.precioAnterior! > oferta.precioOferta) ...[
                    const SizedBox(width: 10),
                    Text(
                      _currencyFmt.format(oferta.precioAnterior),
                      style: const TextStyle(
                        fontSize: 14,
                        decoration: TextDecoration.lineThrough,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _FolletoOfferListTile extends StatelessWidget {
  final OfertaSemanalModel oferta;
  final NumberFormat currencyFmt;
  final VoidCallback onTap;

  const _FolletoOfferListTile({
    required this.oferta,
    required this.currencyFmt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 64,
                height: 64,
                color: const Color(0xFFF1F5F9),
                child: (oferta.imagenRecorteUrl != null && oferta.imagenRecorteUrl!.isNotEmpty)
                    ? CachedNetworkImage(imageUrl: oferta.imagenRecorteUrl!, fit: BoxFit.contain)
                    : const Icon(Icons.shopping_bag_outlined, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    oferta.titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (oferta.presentacion != null && oferta.presentacion!.isNotEmpty)
                    Text(
                      oferta.presentacion!,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
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
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Text(
                  currencyFmt.format(oferta.precioOferta),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF059669),
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
