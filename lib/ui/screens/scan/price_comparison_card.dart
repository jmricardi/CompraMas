import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/product_model.dart';
import '../../../utils/image_url_helper.dart';
import '../../../services/locale_service.dart';
import '../../components/glass_card.dart';

class PriceComparisonCard extends StatelessWidget {
  final List<SupermarketPriceInfo> prices;
  final double searchRadiusKm;
  final int totalPricesCount;
  final bool hasLocation;

  const PriceComparisonCard({
    super.key,
    required this.prices,
    required this.searchRadiusKm,
    this.totalPricesCount = 0,
    this.hasLocation = true,
  });

  String get _formattedRadius {
    return searchRadiusKm % 1 == 0
        ? '${searchRadiusKm.toInt()} km'
        : '${searchRadiusKm.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final hasFallback = prices.isNotEmpty && prices.first.isFallbackSuggested;
    final fallbackItem = hasFallback ? prices.first : null;
    final bestPriceItem = prices.isNotEmpty ? prices.first : null;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          if (hasFallback && fallbackItem != null) ...[
            const SizedBox(height: 10),
            _buildFallbackNotice(context, fallbackItem),
          ],
          const SizedBox(height: 12),
          if (bestPriceItem != null) ...[
            _buildBestPriceBanner(context, bestPriceItem),
            const SizedBox(height: 14),
          ],
          if (prices.isEmpty)
            _buildEmptyState(context)
          else
            _buildPriceList(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final locale = context.watch<LocaleService>();
    final primary = Theme.of(context).colorScheme.primary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.storefront, color: primary),
            const SizedBox(width: 8),
            Text(
              locale.t('price_comparison'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        if (hasLocation)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.radar, size: 14, color: primary),
                const SizedBox(width: 4),
                Text(
                  _formattedRadius,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFallbackNotice(
    BuildContext context,
    SupermarketPriceInfo fallbackItem,
  ) {
    final locale = context.watch<LocaleService>();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade700, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: Colors.amber.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locale.t('fallback_notice_title'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
                Text(
                  '${fallbackItem.matchedProductName ?? ''} (EAN: ${fallbackItem.currentProductId ?? ''})',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBestPriceBanner(
    BuildContext context,
    SupermarketPriceInfo bestItem,
  ) {
    final locale = context.watch<LocaleService>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade600, width: 1.2),
      ),
      child: Row(
        children: [
          if (bestItem.logoUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: ImageUrlHelper.getOptimizedImageUrl(bestItem.logoUrl, targetWidth: 100),
                width: 32,
                height: 32,
                fit: BoxFit.contain,
                placeholder: (_, _) => const SizedBox(width: 32, height: 32),
                errorWidget: (_, _, _) => Container(
                  padding: const EdgeInsets.all(7),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.star, color: Colors.white, size: 18),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.star, color: Colors.white, size: 18),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${locale.t('best_price_in_radius')} ($_formattedRadius)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: Colors.green.shade900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  bestItem.supermarketName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${bestItem.price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
              if (bestItem.distanceMeters != null)
                Text(
                  bestItem.formattedDistance,
                  style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final locale = context.watch<LocaleService>();
    final outsideCount = totalPricesCount - prices.length;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_off_outlined,
                  size: 20, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  locale.t('no_prices_in_radius', [_formattedRadius]),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          if (outsideCount > 0) ...[
            const SizedBox(height: 6),
            Text(
              locale.t('prices_outside_radius', [outsideCount]),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              locale.t('adjust_radius_hint'),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceList(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: prices.length,
      separatorBuilder: (_, _) => const Divider(height: 16),
      itemBuilder: (context, index) {
        return _PriceRowItem(
          item: prices[index],
          isCheapest: index == 0,
        );
      },
    );
  }
}

class _PriceRowItem extends StatelessWidget {
  final SupermarketPriceInfo item;
  final bool isCheapest;

  const _PriceRowItem({
    required this.item,
    required this.isCheapest,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleService>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      item.supermarketName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isCheapest) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        locale.t('best_price'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (item.address != null || item.locality != null)
                Text(
                  [item.address, item.locality]
                      .where((s) => s != null && s.isNotEmpty)
                      .join(' - '),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${item.price.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isCheapest ? Colors.green[700] : null,
              ),
            ),
            if (item.distanceMeters != null)
              Text(
                item.formattedDistance,
                style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
          ],
        ),
      ],
    );
  }
}
