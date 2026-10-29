import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart' as ul;
import '../../../core/services/ad_manager.dart';
import '../../../models/house_ad_model.dart';

class CompraMasBannerAd extends StatefulWidget {
  final double? widthDp;
  final double? heightDp;
  final bool allowHouseFallback;

  const CompraMasBannerAd({
    super.key,
    this.widthDp,
    this.heightDp,
    this.allowHouseFallback = true,
  });

  /// Calcula la altura responsiva según las reglas de Prisma Noticias:
  /// - Teléfonos (shortestSide < 600 dp): 60.0 dp
  /// - Tablets (shortestSide >= 600 dp): 90.0 dp
  /// - Límite de seguridad: Clampeado a máximo 15% del alto total de pantalla.
  static double getResponsiveHeight(BuildContext context) {
    final mediaQuery = MediaQuery.sizeOf(context);
    final shortestSide = mediaQuery.shortestSide;
    final screenHeight = mediaQuery.height;
    final isTablet = shortestSide >= 600;
    final double targetHeight = isTablet ? 90.0 : 60.0;
    final maxHeight = screenHeight * 0.15;
    return targetHeight > maxHeight ? maxHeight : targetHeight;
  }

  @override
  State<CompraMasBannerAd> createState() => _CompraMasBannerAdState();
}

class _CompraMasBannerAdState extends State<CompraMasBannerAd> {
  bool _useHouseAd = false;
  HouseAd? _selectedHouseAd;

  @override
  void initState() {
    super.initState();
    _checkBannerConfig();
  }

  void _checkBannerConfig() {
    final adManager = AdManager.instance;
    if (!adManager.showAds || !adManager.showBannerAds) return;

    final randomVal = (DateTime.now().millisecondsSinceEpoch % 100) / 100.0;
    if (widget.allowHouseFallback && randomVal < adManager.houseBannerRatio) {
      final houseAd = adManager.getRandomHouseBannerAd();
      if (houseAd != null) {
        setState(() {
          _selectedHouseAd = houseAd;
          _useHouseAd = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final adManager = AdManager.instance;
    if (!adManager.showAds || !adManager.showBannerAds) {
      return const SizedBox.shrink();
    }

    final effectiveHeight = widget.heightDp ?? CompraMasBannerAd.getResponsiveHeight(context);
    final effectiveWidth = widget.widthDp ?? MediaQuery.sizeOf(context).width;

    if (_useHouseAd && _selectedHouseAd != null) {
      return _buildHouseBanner(_selectedHouseAd!, effectiveHeight);
    }

    return Container(
      width: double.infinity,
      height: effectiveHeight,
      alignment: Alignment.center,
      child: AndroidView(
        viewType: 'dev.arandulabs.compramas/inline_banner_view',
        creationParams: {
          'widthDp': effectiveWidth.toInt(),
          'heightDp': effectiveHeight.toInt(),
        },
        creationParamsCodec: const StandardMessageCodec(),
      ),
    );
  }

  Widget _buildHouseBanner(HouseAd ad, double height) {
    return Container(
      width: double.infinity,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF047857),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () => _openAdUrl(ad.actionUrl),
        child: Row(
          children: [
            if (ad.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                child: CachedNetworkImage(
                  imageUrl: ad.imageUrl,
                  height: height,
                  width: height * 1.5,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ad.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    ad.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                ad.ctaText,
                style: const TextStyle(
                  color: Color(0xFF047857),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAdUrl(String url) async {
    if (url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      if (await ul.canLaunchUrl(uri)) {
        await ul.launchUrl(uri, mode: ul.LaunchMode.externalApplication);
      }
    } catch (_) {}
  }
}
