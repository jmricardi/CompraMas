import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../models/product_model.dart';
import '../../../../models/quote_model.dart';
import '../../../../models/shopping_list_model.dart';
import '../../../../services/shopping_list_quote_service.dart';
import '../../../../services/location_service.dart';
import '../../../../services/settings_service.dart';
import '../../../../utils/format_utils.dart';
import '../../../../viewmodels/discount_viewmodel.dart';
import '../../../../viewmodels/shopping_list_viewmodel.dart';
import '../../../components/glass_card.dart';

class QuoteListView extends StatefulWidget {
  final List<ShoppingListEntity> lists;

  const QuoteListView({super.key, required this.lists});

  @override
  State<QuoteListView> createState() => _QuoteListViewState();
}

class _QuoteListViewState extends State<QuoteListView> {
  final ShoppingListQuoteService _quoteService = ShoppingListQuoteService();

  int? _selectedListId;
  bool _includePhysical = true;
  bool _includeOnline = true;
  bool _applyDiscounts = true;
  bool _includeShipping = true;
  bool _splitPurchase = true;
  final double _shippingFee = 3000.0;

  bool _isQuoting = false;
  FullQuoteBundle? _quoteBundle;

  @override
  void initState() {
    super.initState();
    if (widget.lists.isNotEmpty) {
      _selectedListId = widget.lists.first.id;
    }
  }

  @override
  void didUpdateWidget(covariant QuoteListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedListId == null && widget.lists.isNotEmpty) {
      _selectedListId = widget.lists.first.id;
    }
  }

  Future<void> _runQuote() async {
    if (_selectedListId == null) return;
    final list = widget.lists.where((l) => l.id == _selectedListId).firstOrNull;
    if (list == null) return;

    setState(() => _isQuoting = true);

    try {
      final items = await context.read<ShoppingListViewModel>().getItemsForList(list.id);
      if (!mounted) return;

      final settings = context.read<SettingsService>();
      final userLocation = await LocationService.getCurrentLocation();
      if (!mounted) return;

      final discounts = context.read<DiscountViewModel>().discounts;
      final bundle = await _quoteService.quoteList(
        list: list,
        items: items,
        userDiscounts: discounts,
        userLocation: userLocation,
        radiusKm: settings.searchRadiusKm,
        postalCode: settings.postalCode,
        includePhysical: _includePhysical,
        includeOnline: _includeOnline,
        applyDiscounts: _applyDiscounts,
        onlineShippingFee: _includeShipping ? _shippingFee : 0.0,
        splitPurchaseEnabled: _splitPurchase,
      );

      if (!mounted) return;
      setState(() {
        _quoteBundle = bundle;
        _isQuoting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isQuoting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lists.isEmpty) {
      return const _EmptyListsForQuote();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildListSelector(),
        const SizedBox(height: 12),
        _buildConfigSection(),
        const SizedBox(height: 14),
        _buildQuoteButton(),
        const SizedBox(height: 18),
        if (_isQuoting)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_quoteBundle != null) ...[
          if (_splitPurchase && _quoteBundle!.splitQuote != null) ...[
            _SplitQuoteCard(split: _quoteBundle!.splitQuote!),
            const SizedBox(height: 16),
          ],
          _buildSingleQuotesHeader(),
          const SizedBox(height: 8),
          ..._quoteBundle!.singleStoreQuotes.map((q) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SingleQuoteCard(quote: q, isBest: q == _quoteBundle!.singleStoreQuotes.first),
              )),
        ],
      ],
    );
  }

  Widget _buildListSelector() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Seleccionar lista a cotizar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: _selectedListId,
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: widget.lists.map((l) {
              return DropdownMenuItem<int>(
                value: l.id,
                child: Text(l.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedListId = val;
                _quoteBundle = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildConfigSection() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Opciones de cotización', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('Físicos'),
                avatar: const Icon(Icons.store, size: 16),
                selected: _includePhysical,
                onSelected: (val) => setState(() => _includePhysical = val),
              ),
              FilterChip(
                label: const Text('Online'),
                avatar: const Icon(Icons.shopping_cart_outlined, size: 16),
                selected: _includeOnline,
                onSelected: (val) => setState(() => _includeOnline = val),
              ),
              FilterChip(
                label: const Text('Promos Bancarias'),
                avatar: const Icon(Icons.credit_card, size: 16),
                selected: _applyDiscounts,
                onSelected: (val) => setState(() => _applyDiscounts = val),
              ),
              FilterChip(
                label: Text('Envío online (${AppFormatters.currency(_shippingFee)})'),
                avatar: const Icon(Icons.local_shipping_outlined, size: 16),
                selected: _includeShipping,
                onSelected: (val) => setState(() => _includeShipping = val),
              ),
              FilterChip(
                label: const Text('Dividir compra inteligente'),
                avatar: const Icon(Icons.call_split, size: 16),
                selected: _splitPurchase,
                onSelected: (val) => setState(() => _splitPurchase = val),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteButton() {
    return SizedBox(
      height: 48,
      child: FilledButton.icon(
        onPressed: _runQuote,
        icon: const Icon(Icons.calculate),
        label: const Text('Cotizar Lista de Precios', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSingleQuotesHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Cotización por Supermercado',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        Text(
          '${_quoteBundle?.singleStoreQuotes.length ?? 0} comercios',
          style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
        ),
      ],
    );
  }
}

class _EmptyListsForQuote extends StatelessWidget {
  const _EmptyListsForQuote();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.request_quote_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No hay listas para cotizar',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Crea una lista en la pestaña Listas y agrega productos para cotizar sus precios en múltiples supermercados.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _SingleQuoteCard extends StatelessWidget {
  final SingleStoreQuote quote;
  final bool isBest;

  const _SingleQuoteCard({required this.quote, required this.isBest});

  Widget _buildStoreLogo() {
    final logoUrl = SupermarketPriceInfo.buildLogoUrl(chainName: quote.chainName);
    if (logoUrl == null) {
      return const Icon(Icons.storefront, size: 28, color: Colors.blueGrey);
    }
    return CachedNetworkImage(
      imageUrl: logoUrl,
      width: 36,
      height: 36,
      fit: BoxFit.contain,
      memCacheWidth: 80,
      placeholder: (_, _) => const SizedBox(width: 36, height: 36),
      errorWidget: (_, _, _) => const Icon(Icons.storefront, size: 28, color: Colors.blueGrey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          leading: _buildStoreLogo(),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  quote.supermarket,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isBest)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Más económico', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 3),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: quote.isOnline ? Colors.purple.shade50 : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      quote.isOnline ? 'Online' : 'Físico',
                      style: TextStyle(fontSize: 10, color: quote.isOnline ? Colors.purple.shade700 : Colors.blue.shade700, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${quote.itemsFoundCount}/${quote.totalItemsCount} productos',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              if (quote.discountSavings > 0 && quote.appliedDiscountTag != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Ahorro: -${AppFormatters.currency(quote.discountSavings)} (${quote.appliedDiscountTag})',
                    style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.w600),
                  ),
                ),
              if (quote.shippingFee > 0)
                Text(
                  'Envío: +${AppFormatters.currency(quote.shippingFee)}',
                  style: const TextStyle(fontSize: 10.5, color: Colors.blueGrey),
                ),
            ],
          ),
          trailing: Text(
            AppFormatters.currency(quote.finalTotal),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: isBest ? Colors.green.shade700 : theme.colorScheme.onSurface,
            ),
          ),
          children: [
            const Divider(height: 8),
            ...quote.items.map((it) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${it.productName} (${it.quantity} ${it.unit})',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        AppFormatters.currency(it.subtotal),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _SplitQuoteCard extends StatelessWidget {
  final SplitQuoteResult split;

  const _SplitQuoteCard({required this.split});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        border: Border.all(color: const Color(0xFF10B981), width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.call_split, color: Color(0xFF047857), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Compra Dividida Óptima',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF065F46)),
                    ),
                    Text(
                      'Ahorrá ${AppFormatters.currency(split.totalSavingsVsSingle)} (${split.savingsPercentage.toStringAsFixed(0)}% menos)',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF047857), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Text(
                AppFormatters.currency(split.combinedTotal),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF065F46)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Dividiendo tu compra entre ${split.storeGroups.length} supermercados obtienes el precio más económico para cada producto:',
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF064E3B)),
          ),
          const Divider(height: 16, color: Color(0xFFA7F3D0)),
          ...split.storeGroups.map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('• ${g.supermarket} (${g.items.length} productos)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF065F46))),
                        Text(AppFormatters.currency(g.total),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF065F46))),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 2),
                      child: Text(
                        g.items.map((i) => '${i.productName} (${AppFormatters.currency(i.subtotal)})').join(', '),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF047857)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
