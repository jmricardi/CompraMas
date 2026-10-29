import 'package:flutter/material.dart';

class SearchAreaPillButton extends StatelessWidget {
  final bool isRefreshing;
  final VoidCallback onRefresh;

  const SearchAreaPillButton({
    super.key,
    required this.isRefreshing,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Material(
        elevation: 3,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(24),
        color: theme.colorScheme.surface.withValues(alpha: 0.95),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: isRefreshing ? null : onRefresh,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isRefreshing)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  )
                else
                  Icon(
                    Icons.refresh,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                const SizedBox(width: 8),
                Text(
                  isRefreshing ? 'Actualizando área...' : 'Buscar en esta zona',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FuelTypeFilterChips extends StatelessWidget {
  final List<String> fuelTypes;
  final String selected;
  final ValueChanged<String> onSelected;

  const FuelTypeFilterChips({
    super.key,
    required this.fuelTypes,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: fuelTypes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final type = fuelTypes[index];
          final isSelected = type == selected;
          return FilterChip(
            showCheckmark: false,
            label: Text(
              type,
              style: TextStyle(
                color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
              ),
            ),
            selected: isSelected,
            onSelected: (_) => onSelected(type),
            backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.95),
            selectedColor: theme.colorScheme.primary,
            side: BorderSide(
              color: isSelected ? theme.colorScheme.primary : Colors.grey.shade400,
              width: isSelected ? 1.5 : 1.0,
            ),
            elevation: isSelected ? 3 : 1,
            shadowColor: Colors.black26,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }
}

class MapControlButtons extends StatelessWidget {
  final VoidCallback onLocation;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const MapControlButtons({
    super.key,
    required this.onLocation,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: 'map_location',
          tooltip: 'Mi ubicación',
          onPressed: onLocation,
          child: const Icon(Icons.my_location),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: 'map_zoom_in',
          tooltip: 'Acercar',
          onPressed: onZoomIn,
          child: const Icon(Icons.add),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: 'map_zoom_out',
          tooltip: 'Alejar',
          onPressed: onZoomOut,
          child: const Icon(Icons.remove),
        ),
      ],
    );
  }
}

