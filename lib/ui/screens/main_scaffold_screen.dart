import 'package:flutter/material.dart';
import 'scan/scan_screen.dart';
import 'shopping_list/shopping_lists_screen.dart';
import 'discounts/discounts_screen.dart';
import 'fuel/fuel_map_screen.dart';
import 'settings/settings_screen.dart';

class MainScaffoldScreen extends StatefulWidget {
  const MainScaffoldScreen({super.key});

  @override
  State<MainScaffoldScreen> createState() => _MainScaffoldScreenState();
}

class _MainScaffoldScreenState extends State<MainScaffoldScreen> {
  int _currentIndex = 0;
  final Set<int> _loadedTabs = {0};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const ScanScreen(),
          _loadedTabs.contains(1)
              ? const ShoppingListsScreen()
              : const SizedBox.shrink(),
          _loadedTabs.contains(2)
              ? const DiscountsScreen()
              : const SizedBox.shrink(),
          _loadedTabs.contains(3)
              ? const FuelMapScreen()
              : const SizedBox.shrink(),
          _loadedTabs.contains(4)
              ? const SettingsScreen()
              : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
            _loadedTabs.add(index);
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Buscar',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'Lista',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_offer_outlined),
            selectedIcon: Icon(Icons.local_offer),
            label: 'Descuentos',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_gas_station_outlined),
            selectedIcon: Icon(Icons.local_gas_station),
            label: 'Combustible',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}
