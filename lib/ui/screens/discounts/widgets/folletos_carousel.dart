import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../models/folleto_model.dart';
import 'folleto_viewer_screen.dart';

class FolletosCarousel extends StatelessWidget {
  final List<FolletoModel> folletos;
  final bool isLoading;
  final VoidCallback? onRefresh;

  const FolletosCarousel({
    super.key,
    required this.folletos,
    this.isLoading = false,
    this.onRefresh,
  });

  void _abrirVisor(BuildContext context, FolletoModel folleto) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FolletoViewerScreen(folleto: folleto),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Filtrar folletos cuya fecha ya expiró estrictamente (antes del inicio de hoy)
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final folletosVigentes = folletos.where((f) {
      if (f.fechaHasta == null) return true;
      return !f.fechaHasta!.isBefore(inicioHoy);
    }).toList();

    if (folletosVigentes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_stories, color: Theme.of(context).primaryColor, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'Folletos de la Semana',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Text(
                '${folletosVigentes.length}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            scrollDirection: Axis.horizontal,
            itemCount: folletosVigentes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final folleto = folletosVigentes[index];
              return _FolletoCard(
                folleto: folleto,
                onTap: () => _abrirVisor(context, folleto),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FolletoCard extends StatelessWidget {
  final FolletoModel folleto;
  final VoidCallback onTap;

  const _FolletoCard({
    required this.folleto,
    required this.onTap,
  });

  String _formatearVigencia() {
    final DateTime targetDate;
    if (folleto.fechaHasta != null) {
      targetDate = folleto.fechaHasta!;
    } else {
      // Si no tiene fecha_hasta definida, calcular el próximo domingo de la semana en curso
      final now = DateTime.now();
      final daysUntilSunday = DateTime.sunday - now.weekday;
      targetDate = now.add(Duration(days: daysUntilSunday >= 0 ? daysUntilSunday : 7));
    }
    final dia = targetDate.day.toString().padLeft(2, '0');
    final mes = targetDate.month.toString().padLeft(2, '0');
    return 'Hasta $dia/$mes';
  }

  Color _obtenerColorCadena(String cadena) {
    switch (cadena.toLowerCase()) {
      case 'coto':
        return Colors.red.shade700;
      case 'carrefour':
        return Colors.blue.shade700;
      case 'jumbo':
      case 'disco':
      case 'vea':
        return Colors.green.shade700;
      case 'makro':
        return Colors.red.shade900;
      case 'maxiconsumo':
        return Colors.orange.shade800;
      case 'diarco':
        return Colors.deepOrange.shade700;
      case 'vital':
        return Colors.blue.shade900;
      default:
        return Colors.indigo.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorBadge = _obtenerColorCadena(folleto.cadena);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Portada WebP desde Supabase Storage
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: folleto.portadaUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade100,
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                    // Badge Cadena y Badge Bancario
                    Positioned(
                      top: 8,
                      left: 8,
                      right: 8,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: colorBadge,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 4),
                              ],
                            ),
                            child: Text(
                              folleto.cadena,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (folleto.esBancario)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black26, blurRadius: 4),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.credit_card_rounded, color: Colors.white, size: 11),
                                  SizedBox(width: 3),
                                  Text(
                                    'Promos',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
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
              // Metadata compacta: solo vigencia para maximizar el espacio de la imagen
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 11, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _formatearVigencia(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(Icons.touch_app_outlined, size: 13, color: Theme.of(context).primaryColor),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
