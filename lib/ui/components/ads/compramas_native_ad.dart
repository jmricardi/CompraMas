import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart' as ul;
import '../../../core/services/ad_manager.dart';
import '../../../models/house_ad_model.dart';

enum CompraMasNativeAdType { compact, feed, mrec }

class CompraMasNativeAd extends StatefulWidget {
  final CompraMasNativeAdType type;
  final bool allowHouseFallback;

  const CompraMasNativeAd({
    super.key,
    this.type = CompraMasNativeAdType.feed,
    this.allowHouseFallback = true,
  });

  @override
  State<CompraMasNativeAd> createState() => _CompraMasNativeAdState();
}

class _CompraMasNativeAdState extends State<CompraMasNativeAd>
    with AutomaticKeepAliveClientMixin {
  bool _useHouseAd = false;
  bool _useNativeAdView = false;
  bool _initialLoadStarted = false;
  HouseAd? _selectedHouseAd;

  @override
  bool get wantKeepAlive => _useNativeAdView;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialLoadStarted) {
      _initialLoadStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _evaluateAndLoad();
      });
    }
  }

  void _evaluateAndLoad() {
    final adManager = AdManager.instance;
    if (!adManager.showAds || !adManager.showNativeAds) {
      return;
    }

    // 1. Decisión por ratio de anuncios de la casa
    final randomVal = (DateTime.now().millisecondsSinceEpoch % 100) / 100.0;
    if (widget.allowHouseFallback && randomVal < adManager.houseNativeRatio) {
      final houseAd = adManager.getRandomHouseNativeAd();
      if (houseAd != null) {
        setState(() {
          _selectedHouseAd = houseAd;
          _useHouseAd = true;
          _useNativeAdView = false;
        });
        return;
      }
    }

    // 2. Intentar anuncio nativo de la red (Meta / Yandex)
    setState(() {
      _useNativeAdView = true;
      _useHouseAd = false;
    });
    updateKeepAlive();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final adManager = AdManager.instance;
    if (!adManager.showAds || !adManager.showNativeAds) {
      return const SizedBox.shrink();
    }

    if (_useHouseAd && _selectedHouseAd != null) {
      return _buildHouseAdCard(_selectedHouseAd!);
    }

    if (_useNativeAdView) {
      return _buildPlatformNativeAd();
    }

    return const SizedBox.shrink();
  }

  Widget _buildPlatformNativeAd() {
    final isCompact = widget.type == CompraMasNativeAdType.compact;
    final viewType = isCompact ? 'compact' : 'media_only';
    final height = isCompact ? 104.0 : 250.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: AndroidView(
            viewType: 'dev.arandulabs.compramas/native_ad_view',
            creationParams: {'type': viewType},
            creationParamsCodec: const StandardMessageCodec(),
          ),
        ),
      ),
    );
  }

  Widget _buildHouseAdCard(HouseAd ad) {
    final isCompact = widget.type == CompraMasNativeAdType.compact;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _openAdUrl(ad.actionUrl),
          child: isCompact ? _buildCompactContent(ad) : _buildFeedContent(ad),
        ),
      ),
    );
  }

  Widget _buildCompactContent(HouseAd ad) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          if (ad.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: ad.imageUrl,
                width: 70,
                height: 70,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const Icon(Icons.campaign, size: 36),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  ad.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _openAdUrl(ad.actionUrl),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(ad.ctaText, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedContent(HouseAd ad) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (ad.imageUrl.isNotEmpty)
          CachedNetworkImage(
            imageUrl: ad.imageUrl,
            width: double.infinity,
            height: 140,
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => const SizedBox(
              height: 80,
              child: Center(child: Icon(Icons.campaign, size: 40)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                ad.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _openAdUrl(ad.actionUrl),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(ad.ctaText),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.amber.shade700,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'PROMO',
        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
