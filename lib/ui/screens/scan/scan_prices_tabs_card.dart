import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/product_model.dart';
import '../../../services/settings_service.dart';
import '../../../viewmodels/discount_viewmodel.dart';
import '../../../utils/format_utils.dart';
import '../../../utils/image_url_helper.dart';
import '../../components/glass_card.dart';
import 'widgets/price_item_tile.dart';

class ScanPricesTabsCard extends StatefulWidget {
  final List<SupermarketPriceInfo> topCheapestPrices;
  final List<SupermarketPriceInfo> onlinePrices;
  final List<SupermarketPriceInfo> wholesalePrices;
  final List<SupermarketPriceInfo> nearestPrices;
  final List<SupermarketChainFilter> availableSupermarketChains;
  final List<SupermarketChainFilter> Function(int tabIndex)? chainsForTab;
  final List<String> availableSupermarkets;
  final Set<String> selectedSupermarkets;
  final ValueChanged<String> onToggleSupermarket;
  final List<String> availableBrands;
  final Set<String> selectedBrands;
  final ValueChanged<String> onToggleBrand;
  final double searchRadiusKm;
  final ValueChanged<double>? onRadiusChanged;
  final bool hasLocation;
  final double Function(double price) calculateDifferencePercentage;

  const ScanPricesTabsCard({
    super.key,
    required this.topCheapestPrices,
    this.onlinePrices = const [],
    this.wholesalePrices = const [],
    required this.nearestPrices,
    this.availableSupermarketChains = const [],
    this.chainsForTab,
    this.availableSupermarkets = const ['Todos'],
    this.selectedSupermarkets = const {},
    required this.onToggleSupermarket,
    required this.availableBrands,
    this.selectedBrands = const {},
    required this.onToggleBrand,
    required this.searchRadiusKm,
    this.onRadiusChanged,
    required this.hasLocation,
    required this.calculateDifferencePercentage,
  });

  @override
  State<ScanPricesTabsCard> createState() => _ScanPricesTabsCardState();
}

class _ScanPricesTabsCardState extends State<ScanPricesTabsCard>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Map<int, int> _visibleCounts = {0: 5, 1: 5, 2: 5, 3: 5};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void didUpdateWidget(covariant ScanPricesTabsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchRadiusKm != widget.searchRadiusKm ||
        oldWidget.topCheapestPrices != widget.topCheapestPrices ||
        oldWidget.nearestPrices != widget.nearestPrices ||
        oldWidget.onlinePrices != widget.onlinePrices ||
        oldWidget.wholesalePrices != widget.wholesalePrices) {
      _visibleCounts[0] = 5;
      _visibleCounts[1] = 5;
      _visibleCounts[2] = 5;
      _visibleCounts[3] = 5;
    }
  }

  void _onTabChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  String get _formattedRadius =>
      AppFormatters.distance(widget.searchRadiusKm * 1000);

  Future<void> _launchDirections(SupermarketPriceInfo item) async {
    if (item.productUrl != null && item.productUrl!.isNotEmpty) {
      final uri = Uri.tryParse(item.productUrl!);
      if (uri != null) {
        try {
          final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (ok) return;
        } catch (_) {}
      }
    }

    if (item.isVirtualStore) {
      final webUrl = _resolveStoreWebUrl(item);
      if (webUrl != null) {
        final uri = Uri.parse(webUrl);
        try {
          final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (ok) return;
        } catch (_) {}
      }
      return;
    }

    final lat = item.latitude;
    final lon = item.longitude;
    final storeName = item.chainName ?? item.supermarketName;
    final hasAddress = item.address != null && item.address!.trim().isNotEmpty;
    final fullQuery = [storeName, item.address, item.locality]
        .where((s) => s != null && s.trim().isNotEmpty)
        .join(', ');

    final isWalking = item.distanceMeters != null && item.distanceMeters! < 2000;
    final navMode = isWalking ? 'w' : 'd';
    final travelMode = isWalking ? 'walking' : 'driving';

    if (hasAddress) {
      final navQueryUri = Uri.parse(
        'google.navigation:q=${Uri.encodeComponent(fullQuery)}&mode=$navMode',
      );
      try {
        final ok = await launchUrl(navQueryUri, mode: LaunchMode.externalApplication);
        if (ok) return;
      } catch (_) {}

      final dirAddressUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(fullQuery)}&travelmode=$travelMode',
      );
      try {
        final ok = await launchUrl(dirAddressUri, mode: LaunchMode.externalApplication);
        if (ok) return;
      } catch (_) {}
    }

    if (lat != null && lon != null) {
      final navUri = Uri.parse('google.navigation:q=$lat,$lon&mode=$navMode');
      try {
        final ok = await launchUrl(navUri, mode: LaunchMode.externalApplication);
        if (ok) return;
      } catch (_) {}

      final dirUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=$travelMode',
      );
      try {
        final ok = await launchUrl(dirUri, mode: LaunchMode.externalApplication);
        if (ok) return;
      } catch (_) {}

      try {
        await launchUrl(dirUri, mode: LaunchMode.platformDefault);
      } catch (_) {}
      return;
    }

    if (fullQuery.isNotEmpty) {
      final searchUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(fullQuery)}',
      );
      try {
        final ok = await launchUrl(searchUri, mode: LaunchMode.externalApplication);
        if (!ok) {
          await launchUrl(searchUri, mode: LaunchMode.platformDefault);
        }
      } catch (_) {}
    }
  }

  String? _resolveStoreWebUrl(SupermarketPriceInfo item) {
    final addr = item.address?.trim() ?? '';
    if (addr.startsWith('http://') || addr.startsWith('https://')) {
      return addr;
    }
    final urlMatch = RegExp(r'https?://[^\s,]+').firstMatch(addr);
    if (urlMatch != null) {
      return urlMatch.group(0);
    }
    final chain = (item.chainName ?? item.supermarketName).toLowerCase();
    if (chain.contains('anonima')) return 'https://supermercado.laanonimaonline.com';
    if (chain.contains('dia')) return 'https://diaonline.supermercadosdia.com.ar';
    if (chain.contains('coto')) return 'https://www.cotodigital3.com.ar';
    if (chain.contains('carrefour')) return 'https://www.carrefour.com.ar';
    if (chain.contains('jumbo')) return 'https://www.jumbo.com.ar';
    if (chain.contains('disco')) return 'https://www.disco.com.ar';
    if (chain.contains('vea')) return 'https://www.vea.com.ar';
    if (chain.contains('chango') || chain.contains('walmart') || chain.contains('mas online')) {
      return 'https://www.masonline.com.ar';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderControls(primary),
                _buildPriceStatsOverview(primary),
                const SizedBox(height: 6),
                _buildTabBar(primary),
                if (_chainsList.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildFilterLabel('Cadenas con inventario:'),
                  const SizedBox(height: 6),
                  _buildSupermarketSelector(primary),
                ],
                if (widget.availableBrands.length > 2) ...[
                  const SizedBox(height: 8),
                  _buildFilterLabel('Marcas equivalentes:'),
                  const SizedBox(height: 4),
                  _buildBrandSelector(primary),
                ],
                const SizedBox(height: 12),
                _buildTabView(),
              ],
            ),
          ),
          Positioned(
            top: -7,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Text(
                'Precios',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceStatsOverview(Color primary) {
    final all = [
      ...widget.topCheapestPrices,
      ...widget.nearestPrices,
      ...widget.onlinePrices,
    ];
    final validPrices = all.map((p) => p.effectivePrice).where((pr) => pr > 0).toList();
    if (validPrices.isEmpty) return const SizedBox.shrink();

    final minPrice = validPrices.reduce((a, b) => a < b ? a : b);
    final maxPrice = validPrices.reduce((a, b) => a > b ? a : b);
    final avgPrice = validPrices.reduce((a, b) => a + b) / validPrices.length;

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatSegment('Más bajo', AppFormatters.currency(minPrice), const Color(0xFF059669)),
          Container(width: 1, height: 26, color: const Color(0xFFCBD5E1)),
          _buildStatSegment('Promedio', AppFormatters.currency(avgPrice), const Color(0xFF1E293B)),
          Container(width: 1, height: 26, color: const Color(0xFFCBD5E1)),
          _buildStatSegment('Más alto', AppFormatters.currency(maxPrice), const Color(0xFFE11D48)),
        ],
      ),
    );
  }

  Widget _buildStatSegment(String label, String value, Color valueColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
            color: valueColor,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderControls(Color primary) {
    final settings = context.watch<SettingsService>();
    final isPromosOn = settings.showPromotionalPrices;
    final hasRightControls = widget.hasLocation || _tabController.index == 2;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              settings.setShowPromotionalPrices(!isPromosOn);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isPromosOn
                    ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isPromosOn
                      ? const Color(0xFF16A34A).withValues(alpha: 0.5)
                      : Colors.grey.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPromosOn ? Icons.local_offer : Icons.local_offer_outlined,
                    size: 13,
                    color: isPromosOn ? const Color(0xFF16A34A) : Colors.grey[700],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isPromosOn ? 'Promos ACTIVAS' : 'Promos OFF',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isPromosOn ? const Color(0xFF16A34A) : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (hasRightControls)
          _tabController.index == 2
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_shipping_outlined, size: 13, color: Color(0xFF2563EB)),
                      SizedBox(width: 4),
                      Text(
                        'Reparto / Envíos',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                )
              : Material(
                  color: Colors.transparent,
                  child: Tooltip(
                    message: 'Modificar radio de búsqueda',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showRadiusSelector(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.radar, size: 13, color: primary),
                            const SizedBox(width: 4),
                            Text(
                              _formattedRadius,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: primary,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(Icons.tune, size: 11, color: primary),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
        else
          const SizedBox.shrink(),
      ],
    );
  }

  void _showRadiusSelector(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _RadiusSelectorSheet(
        initialRadius: widget.searchRadiusKm,
        onRadiusChanged: (val) => widget.onRadiusChanged?.call(val),
      ),
    );
  }

  Widget _buildFilterLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.blueGrey,
      ),
    );
  }

  List<SupermarketChainFilter> get _chainsList {
    if (widget.chainsForTab != null) {
      return widget.chainsForTab!(_tabController.index);
    }
    if (widget.availableSupermarketChains.isNotEmpty) {
      return widget.availableSupermarketChains;
    }
    final List<SupermarketChainFilter> fallback = [];
    for (final chain in widget.availableSupermarkets) {
      if (chain.toLowerCase() == 'todos') continue;
      fallback.add(SupermarketChainFilter(
        chainName: chain,
        logoUrl: _findLogoForChain(chain),
      ));
    }
    return fallback;
  }

  String? _findLogoForChain(String chain) {
    if (chain.toLowerCase() == 'todos') return null;
    final all = [...widget.topCheapestPrices, ...widget.nearestPrices];
    for (final p in all) {
      final name = p.chainName ?? p.supermarketName;
      if (name.toLowerCase() == chain.toLowerCase() && p.logoUrl != null) {
        return p.logoUrl;
      }
    }
    return null;
  }

  Widget _buildSupermarketSelector(Color primary) {
    final chains = _chainsList;
    if (chains.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chains.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            final isAllSelected = widget.selectedSupermarkets.isEmpty;
            return _buildAllChainsIconCard(isAllSelected, primary);
          }
          final chain = chains[index - 1];
          final isSelected = widget.selectedSupermarkets.contains(chain.chainName);
          return _buildChainLogoCard(chain, isSelected, primary);
        },
      ),
    );
  }

  Widget _buildAllChainsIconCard(bool isSelected, Color primary) {
    return Tooltip(
      message: 'Todos los supermercados',
      triggerMode: TooltipTriggerMode.tap,
      preferBelow: false,
      waitDuration: Duration.zero,
      child: InkWell(
        onTap: () => widget.onToggleSupermarket('Todos'),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: isSelected ? primary.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? primary : const Color(0xFFE2E8F0),
              width: isSelected ? 2.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Icon(
            Icons.storefront,
            size: 24,
            color: isSelected ? primary : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildChainLogoCard(
    SupermarketChainFilter chain,
    bool isSelected,
    Color primary,
  ) {
    final effectiveLogo = chain.effectiveLogoUrl;

    return Tooltip(
      message: chain.chainName,
      triggerMode: TooltipTriggerMode.tap,
      preferBelow: false,
      waitDuration: Duration.zero,
      child: InkWell(
        onTap: () => widget.onToggleSupermarket(chain.chainName),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 52,
          height: 52,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? primary : const Color(0xFFE2E8F0),
              width: isSelected ? 2.5 : 1.0,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: primary.withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: effectiveLogo != null
                    ? CachedNetworkImage(
                        imageUrl: ImageUrlHelper.getOptimizedImageUrl(effectiveLogo, targetWidth: 120),
                        fit: BoxFit.contain,
                        placeholder: (_, _) => const Center(
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (_, _, _) => _buildFallbackInitial(chain.chainName),
                      )
                    : _buildFallbackInitial(chain.chainName),
              ),
              if (chain.isOnline)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: _buildOnlineGlobeBadge(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineGlobeBadge() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF2563EB),
          width: 1.2,
        ),
      ),
      child: const Icon(
        Icons.public,
        size: 10,
        color: Color(0xFF2563EB),
      ),
    );
  }

  Widget _buildFallbackInitial(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'S';
    return Container(
      color: const Color(0xFFF1F5F9),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF334155),
        ),
      ),
    );
  }

  Widget _buildBrandSelector(Color primary) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widget.availableBrands.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final brand = widget.availableBrands[index];
          final isAll = brand.toLowerCase() == 'todas';
          final isSelected = isAll
              ? widget.selectedBrands.isEmpty
              : widget.selectedBrands.contains(brand);
          return FilterChip(
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            label: Text(
              brand,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : null,
              ),
            ),
            selected: isSelected,
            selectedColor: primary,
            onSelected: (_) => widget.onToggleBrand(brand),
          );
        },
      ),
    );
  }

  Widget _buildTabBar(Color primary) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: primary,
          borderRadius: BorderRadius.circular(8),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: primary,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        tabs: const [
          Tab(height: 32, text: 'Precio'),
          Tab(height: 32, text: 'Cercanía'),
          Tab(height: 32, text: 'Online'),
          Tab(height: 32, text: 'Mayorista'),
        ],
      ),
    );
  }

  Widget _buildTabView() {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        return IndexedStack(
          index: _tabController.index,
          children: [
            _buildCheapestTab(),
            _buildNearestTab(),
            _buildOnlineTab(),
            _buildWholesaleTab(),
          ],
        );
      },
    );
  }

  Widget _buildPriceList(
    List<SupermarketPriceInfo> list,
    int tabIndex, {
    bool isNearest = false,
  }) {
    if (list.isEmpty) {
      switch (tabIndex) {
        case 2:
          return _buildEmptyState('No se encontraron comercios online disponibles para este producto.');
        case 3:
          return _buildEmptyState('No se encontraron comercios mayoristas disponibles para este producto.');
        default:
          return _buildEmptyState('No hay precios dentro del radio definido.');
      }
    }

    final maxVisible = _visibleCounts[tabIndex] ?? 5;
    final visibleItems = list.take(maxVisible).toList();
    final hasMore = list.length > maxVisible;

    final settings = context.watch<SettingsService>();
    final discountVm = context.watch<DiscountViewModel>();
    final isPromosOn = settings.showPromotionalPrices;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visibleItems.length,
          separatorBuilder: (_, _) => const Divider(height: 12),
          itemBuilder: (context, index) {
            final item = visibleItems[index];
            final appliedDiscount = isPromosOn
                ? discountVm.findBestDiscountForSupermarket(
                    item.chainName ?? item.supermarketName,
                    item.effectivePrice,
                  )
                : null;

            if (isNearest) {
              final diffPercent = widget.calculateDifferencePercentage(item.effectivePrice);
              return PriceItemTile(
                item: item,
                diffPercentage: diffPercent,
                isTopCheapest: diffPercent == 0.0,
                onTap: () => _launchDirections(item),
                appliedDiscount: appliedDiscount,
              );
            }
            return PriceItemTile(
              item: item,
              rankBadge: '#${index + 1}',
              isTopCheapest: index == 0,
              onTap: () => _launchDirections(item),
              appliedDiscount: appliedDiscount,
            );
          },
        ),
        if (hasMore) ...[
          const SizedBox(height: 14),
          _buildLoadMoreButton(
            onTap: () {
              setState(() {
                _visibleCounts[tabIndex] = maxVisible + 5;
              });
            },
            remainingCount: list.length - maxVisible,
          ),
        ],
      ],
    );
  }

  Widget _buildLoadMoreButton({
    required VoidCallback onTap,
    required int remainingCount,
  }) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: primary.withValues(alpha: 0.25),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.expand_more_rounded, size: 20, color: primary),
              const SizedBox(width: 8),
              Text(
                'Ver 5 precios más',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: primary,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWholesaleTab() => _buildPriceList(widget.wholesalePrices, 3);

  Widget _buildOnlineTab() => _buildPriceList(widget.onlinePrices, 2);

  Widget _buildCheapestTab() => _buildPriceList(widget.topCheapestPrices, 0);

  Widget _buildNearestTab() => _buildPriceList(widget.nearestPrices, 1, isNearest: true);

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.location_off_outlined, size: 28, color: Colors.orange),
            const SizedBox(height: 6),
            Text(
              message,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _RadiusSelectorSheet extends StatefulWidget {
  final double initialRadius;
  final ValueChanged<double> onRadiusChanged;

  const _RadiusSelectorSheet({
    required this.initialRadius,
    required this.onRadiusChanged,
  });

  @override
  State<_RadiusSelectorSheet> createState() => _RadiusSelectorSheetState();
}

class _RadiusSelectorSheetState extends State<_RadiusSelectorSheet> {
  late double _currentRadius;

  @override
  void initState() {
    super.initState();
    _currentRadius = widget.initialRadius.clamp(0.5, 15.0);
  }

  void _applyRadius(double radius) {
    setState(() => _currentRadius = radius);
    widget.onRadiusChanged(radius);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHandle(),
            const SizedBox(height: 14),
            _buildHeader(primary),
            const SizedBox(height: 16),
            _buildSlider(primary),
            const SizedBox(height: 12),
            _buildPresets(primary),
            const SizedBox(height: 18),
            _buildApplyButton(primary),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 38,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFCBD5E1),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(Color primary) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.radar, color: primary, size: 22),
            const SizedBox(width: 8),
            const Text(
              'Radio de búsqueda',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            AppFormatters.distance(_currentRadius * 1000),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSlider(Color primary) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: primary,
        thumbColor: primary,
        overlayColor: primary.withValues(alpha: 0.2),
        valueIndicatorColor: primary,
      ),
      child: Slider(
        value: _currentRadius,
        min: 0.5,
        max: 15.0,
        divisions: 29,
        label: AppFormatters.distance(_currentRadius * 1000),
        onChanged: (val) {
          setState(() => _currentRadius = val);
        },
        onChangeEnd: (val) {
          _applyRadius(val);
        },
      ),
    );
  }

  Widget _buildPresets(Color primary) {
    const presets = [0.5, 1.0, 2.0, 3.0, 5.0, 10.0, 15.0];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: presets.map((km) {
        final isSelected = (_currentRadius - km).abs() < 0.1;
        return ChoiceChip(
          label: Text(
            AppFormatters.distance(km * 1000),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF334155),
            ),
          ),
          selected: isSelected,
          selectedColor: primary,
          backgroundColor: const Color(0xFFF1F5F9),
          side: BorderSide(
            color: isSelected ? primary : const Color(0xFFE2E8F0),
          ),
          onSelected: (_) => _applyRadius(km),
        );
      }).toList(),
    );
  }

  Widget _buildApplyButton(Color primary) {
    return ElevatedButton(
      onPressed: () {
        widget.onRadiusChanged(_currentRadius);
        Navigator.of(context).pop();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: const Text(
        'Aplicar radio',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }
}


