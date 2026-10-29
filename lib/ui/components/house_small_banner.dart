import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/ad_manager.dart';
import '../../models/house_ad_model.dart';
import 'glass_card.dart';

/// Formato 1: Banner Contenedor Estilo Precios (House Ads Small Banner).
///
/// Se adapta al ancho del contenedor de precios (`GlassCard`), luciendo integrado
/// en la pantalla con badge distintivo "AD", creatividad, textos y botón CTA.
class HouseSmallBanner extends StatelessWidget {
  final HouseAd? customAd;
  final VoidCallback? onAdClicked;

  const HouseSmallBanner({
    super.key,
    this.customAd,
    this.onAdClicked,
  });

  Future<void> _handleAdTap(BuildContext context, HouseAd ad) async {
    onAdClicked?.call();
    if (ad.actionUrl.isEmpty) return;

    final uri = Uri.tryParse(ad.actionUrl);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        // Ignorar excepciones al intentar lanzar URLs externas no soportadas
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = AdManager.instance;
    final locale = Localizations.maybeLocaleOf(context);
    final ad = customAd ??
        manager.getRandomHouseBannerAd(
          language: locale?.languageCode,
          country: locale?.countryCode,
        );

    if (ad == null) {
      return const SizedBox.shrink();
    }

    final primary = Theme.of(context).colorScheme.primary;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: InkWell(
        onTap: () => _handleAdTap(context, ad),
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              _buildAdThumbnail(ad, primary),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAdDetails(ad),
              ),
              const SizedBox(width: 8),
              _buildCtaButton(ad, primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdThumbnail(HouseAd ad, Color primary) {
    final thumbUrl = ad.iconUrl ?? ad.imageUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 44,
        height: 44,
        child: thumbUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: thumbUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  color: const Color(0xFFF1F5F9),
                  child: const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: (_, _, _) => _buildFallbackThumbnail(primary),
              )
            : _buildFallbackThumbnail(primary),
      ),
    );
  }

  Widget _buildFallbackThumbnail(Color primary) {
    return Container(
      color: primary.withValues(alpha: 0.1),
      child: Icon(Icons.campaign_rounded, size: 24, color: primary),
    );
  }

  Widget _buildAdDetails(HouseAd ad) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            _buildAdBadge(),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                ad.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.0,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          ad.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11.0,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildAdBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF94A3B8), width: 0.8),
      ),
      child: const Text(
        'AD',
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          color: Color(0xFF334155),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCtaButton(HouseAd ad, Color primary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        ad.ctaText,
        maxLines: 1,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}
