import 'package:flutter/material.dart';
import '../../../../models/shopping_assistant_model.dart';
import '../../../components/clay/clay_squircle_card.dart';
import '../../../components/optimized_network_image.dart';

/// Cabecera persistente que muestra el comercio seleccionado o un selector horizontal
/// de sucursales cercanas geolocalizadas cuando aún no se eligió comercio.
class AssistantStoreHeaderBanner extends StatelessWidget {
  final NearbyStoreBranch? selectedStore;
  final List<NearbyStoreBranch> nearbyStores;
  final bool isLoading;
  final ValueChanged<NearbyStoreBranch> onSelectStore;
  final VoidCallback onOpenFullSelector;
  final VoidCallback onRefreshGps;

  const AssistantStoreHeaderBanner({
    super.key,
    required this.selectedStore,
    required this.nearbyStores,
    required this.isLoading,
    required this.onSelectStore,
    required this.onOpenFullSelector,
    required this.onRefreshGps,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (selectedStore != null) {
      return _SelectedStoreChipBar(
        store: selectedStore!,
        isDark: isDark,
        onTapChange: onOpenFullSelector,
      );
    }
    return _InitialHorizontalStorePicker(
      stores: nearbyStores,
      isLoading: isLoading,
      isDark: isDark,
      onSelectStore: onSelectStore,
      onOpenCustom: onOpenFullSelector,
      onRefreshGps: onRefreshGps,
    );
  }
}

class _SelectedStoreChipBar extends StatelessWidget {
  final NearbyStoreBranch store;
  final bool isDark;
  final VoidCallback onTapChange;

  const _SelectedStoreChipBar({
    required this.store,
    required this.isDark,
    required this.onTapChange,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ClaySquircleCard(
        baseColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDFA),
        borderRadius: 20,
        accentColor: const Color(0xFF0D9488),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        onTap: onTapChange,
        child: Row(
          children: [
            _StoreLogoAvatar(logoUrl: store.logoUrl, chainName: store.chainName),
            const SizedBox(width: 12),
            Expanded(child: _buildStoreTexts()),
            _buildChangeButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreTexts() {
    final subtitle = store.address?.isNotEmpty == true
        ? '${store.address}${store.formattedDistance.isNotEmpty ? ' · ${store.formattedDistance}' : ''}'
        : store.branchName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          store.chainName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        if (subtitle.isNotEmpty)
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF0F766E),
            ),
          ),
      ],
    );
  }

  Widget _buildChangeButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D9488).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.swap_horiz_rounded, size: 15, color: Color(0xFF0D9488)),
          SizedBox(width: 4),
          Text(
            'Cambiar comercio',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0D9488),
            ),
          ),
        ],
      ),
    );
  }
}

class _InitialHorizontalStorePicker extends StatelessWidget {
  final List<NearbyStoreBranch> stores;
  final bool isLoading;
  final bool isDark;
  final ValueChanged<NearbyStoreBranch> onSelectStore;
  final VoidCallback onOpenCustom;
  final VoidCallback onRefreshGps;

  const _InitialHorizontalStorePicker({
    required this.stores,
    required this.isLoading,
    required this.isDark,
    required this.onSelectStore,
    required this.onOpenCustom,
    required this.onRefreshGps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF14B8A6).withValues(alpha: 0.35),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeaderRow(),
          const SizedBox(height: 10),
          SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: stores.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (ctx, idx) {
                if (idx == stores.length) {
                  return _CustomStoreOptionTile(onTap: onOpenCustom);
                }
                final store = stores[idx];
                return _HorizontalStoreOptionTile(
                  store: store,
                  isDark: isDark,
                  onTap: () => onSelectStore(store),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      children: [
        const Icon(Icons.location_on_rounded, size: 18, color: Color(0xFF0D9488)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '¿En qué comercio estás comprando hoy?',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ),
        if (isLoading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          InkWell(
            onTap: onRefreshGps,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.my_location_rounded, size: 16, color: Color(0xFF0D9488)),
            ),
          ),
      ],
    );
  }
}

class _HorizontalStoreOptionTile extends StatelessWidget {
  final NearbyStoreBranch store;
  final bool isDark;
  final VoidCallback onTap;

  const _HorizontalStoreOptionTile({
    required this.store,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dist = store.formattedDistance;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 155,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            _StoreLogoAvatar(logoUrl: store.logoUrl, chainName: store.chainName, size: 36),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    store.chainName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    dist.isNotEmpty ? dist : store.branchName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0D9488),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomStoreOptionTile extends StatelessWidget {
  final VoidCallback onTap;

  const _CustomStoreOptionTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 135,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0D9488).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.4)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront_rounded, color: Color(0xFF0D9488), size: 22),
            SizedBox(height: 4),
            Text(
              'Otro comercio',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0D9488),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreLogoAvatar extends StatelessWidget {
  final String? logoUrl;
  final String chainName;
  final double size;

  const _StoreLogoAvatar({
    required this.logoUrl,
    required this.chainName,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: logoUrl != null && logoUrl!.isNotEmpty
          ? OptimizedNetworkImage(
              imageUrl: logoUrl!,
              width: size,
              height: size,
              fit: BoxFit.contain,
            )
          : Center(
              child: Text(
                chainName.isNotEmpty ? chainName[0].toUpperCase() : 'S',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0D9488),
                ),
              ),
            ),
    );
  }
}

/// Modal BottomSheet completo para elegir o buscar comercios cercanos o ingresar uno manual
class StoreSelectorSheet extends StatefulWidget {
  final List<NearbyStoreBranch> stores;
  final NearbyStoreBranch? currentStore;
  final ValueChanged<NearbyStoreBranch> onSelected;
  final void Function(String name, String? address) onCustomStoreSubmitted;

  const StoreSelectorSheet({
    super.key,
    required this.stores,
    required this.currentStore,
    required this.onSelected,
    required this.onCustomStoreSubmitted,
  });

  static Future<void> show(
    BuildContext context, {
    required List<NearbyStoreBranch> stores,
    required NearbyStoreBranch? currentStore,
    required ValueChanged<NearbyStoreBranch> onSelected,
    required void Function(String name, String? address) onCustomStoreSubmitted,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StoreSelectorSheet(
        stores: stores,
        currentStore: currentStore,
        onSelected: onSelected,
        onCustomStoreSubmitted: onCustomStoreSubmitted,
      ),
    );
  }

  @override
  State<StoreSelectorSheet> createState() => _StoreSelectorSheetState();
}

class _StoreSelectorSheetState extends State<StoreSelectorSheet> {
  final TextEditingController _customNameCtrl = TextEditingController();
  bool _showCustomInput = false;

  @override
  void dispose() {
    _customNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSheetHandle(),
          const SizedBox(height: 12),
          const Text(
            'Seleccionar Comercio o Sucursal',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Comercios ordenados por cercanía a tu ubicación actual',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),
          if (_showCustomInput) _buildCustomInputSection() else _buildStoreList(),
        ],
      ),
    );
  }

  Widget _buildSheetHandle() {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildStoreList() {
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: widget.stores.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final s = widget.stores[i];
                final isSelected = widget.currentStore?.id == s.id;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  leading: _StoreLogoAvatar(logoUrl: s.logoUrl, chainName: s.chainName),
                  title: Text(
                    s.chainName,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                  ),
                  subtitle: Text(
                    s.address ?? s.branchName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (s.formattedDistance.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            s.formattedDistance,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0D9488),
                            ),
                          ),
                        ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF0D9488)),
                      ],
                    ],
                  ),
                  onTap: () {
                    widget.onSelected(s);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => setState(() => _showCustomInput = true),
            icon: const Icon(Icons.edit_location_alt_rounded),
            label: const Text('Escribir otro comercio manualmente'),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomInputSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _customNameCtrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Nombre del supermercado o comercio',
            hintText: 'Ej. Autoservicio El Sol, Mayorista Local...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => setState(() => _showCustomInput = false),
                child: const Text('Volver a la lista'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  final text = _customNameCtrl.text.trim();
                  if (text.isNotEmpty) {
                    widget.onCustomStoreSubmitted(text, null);
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Confirmar'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
