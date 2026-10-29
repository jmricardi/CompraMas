import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../viewmodels/shopping_list_viewmodel.dart';
import '../../../models/shopping_list_model.dart';
import '../../components/app_header_top_bar.dart';
import '../../components/glass_card.dart';
import 'active_list_screen.dart';
import 'active_shopping_session_screen.dart';
import 'widgets/quote_list_view.dart';

class ShoppingListsScreen extends StatefulWidget {
  const ShoppingListsScreen({super.key});

  @override
  State<ShoppingListsScreen> createState() => _ShoppingListsScreenState();
}

class _ShoppingListsScreenState extends State<ShoppingListsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ShoppingListViewModel>().loadAllLists();
    });
  }

  void _showCreateListDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Nueva Lista de Compras'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ej. Compra semanal, Asado, etc.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final name = textController.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(dialogCtx).pop();
                final id = await context
                    .read<ShoppingListViewModel>()
                    .createList(name);
                if (!mounted) return;
                _navigateToList(id, name);
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  void _navigateToList(int listId, String listName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActiveListScreen(
          listId: listId,
          listName: listName,
        ),
      ),
    );
  }

  void _confirmDeleteList(int listId, String listName) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Eliminar Lista'),
        content: Text('¿Estás seguro de que deseas eliminar "$listName"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () {
              Navigator.of(dCtx).pop();
              context.read<ShoppingListViewModel>().deleteList(listId);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _startShoppingForList(ShoppingListEntity list) async {
    final items = await context.read<ShoppingListViewModel>().getItemsForList(list.id);
    if (!mounted) return;

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La lista no tiene productos. Agrega algunos antes de ir a comprar.')),
      );
      return;
    }

    String selectedSuper = 'Coto';
    final customCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Seleccionar Supermercado'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Elige dónde vas a realizar la compra de "${list.name}":',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedSuper,
                  decoration: const InputDecoration(
                    labelText: 'Supermercado',
                    border: OutlineInputBorder(),
                  ),
                  items: ActiveShoppingSessionScreen.availableChains.map((chain) {
                    return DropdownMenuItem(value: chain, child: Text(chain));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedSuper = val);
                    }
                  },
                ),
                if (selectedSuper == 'Otro comercio') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: customCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del comercio',
                      hintText: 'Ej. Supermercado local, Almacén',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dCtx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.shopping_cart_checkout),
              label: const Text('Comenzar'),
              onPressed: () {
                String finalSuper = selectedSuper;
                if (selectedSuper == 'Otro comercio' && customCtrl.text.trim().isNotEmpty) {
                  finalSuper = customCtrl.text.trim();
                }
                Navigator.of(dCtx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ActiveShoppingSessionScreen(
                      originalListId: list.id,
                      listName: list.name,
                      initialSupermarket: finalSuper,
                      initialItems: items,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ShoppingListViewModel viewModel,
  ) {
    final theme = Theme.of(context);
    return PreferredSize(
      preferredSize: const Size.fromHeight(126),
      child: Column(
        children: [
          const AppHeaderTopBar(title: 'Listas de Compra'),
          Container(
            color: theme.cardColor,
            child: TabBar(
              labelColor: theme.primaryColor,
              indicatorColor: theme.primaryColor,
              unselectedLabelColor: Colors.grey.shade600,
              tabs: [
                Tab(
                  icon: const Icon(Icons.format_list_bulleted, size: 20),
                  text: 'Listas (${viewModel.activeLists.length})',
                ),
                const Tab(
                  icon: Icon(Icons.calculate_outlined, size: 20),
                  text: 'Cotizar',
                ),
                Tab(
                  icon: const Icon(Icons.history, size: 20),
                  text: 'Historial (${viewModel.purchaseHistory.length})',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ShoppingListViewModel>();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: _buildAppBar(context, viewModel),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showCreateListDialog,
          icon: const Icon(Icons.add_shopping_cart),
          label: const Text('Nueva Lista'),
        ),
        body: viewModel.isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _ActiveListsView(
                    lists: viewModel.activeLists,
                    onCreate: _showCreateListDialog,
                    onNavigate: _navigateToList,
                    onStartShopping: _startShoppingForList,
                    onDelete: (id) {
                      final list = viewModel.activeLists.firstWhere((l) => l.id == id);
                      _confirmDeleteList(id, list.name);
                    },
                  ),
                  QuoteListView(
                    lists: viewModel.activeLists,
                  ),
                  _PurchaseHistoryView(
                    history: viewModel.purchaseHistory,
                    onDelete: (id) {
                      final hist = viewModel.purchaseHistory.firstWhere((l) => l.id == id);
                      _confirmDeleteList(id, hist.supermarket ?? hist.name);
                    },
                  ),
                ],
              ),
      ),
    );
  }
}

class _ActiveListsView extends StatelessWidget {
  final List<ShoppingListEntity> lists;
  final VoidCallback onCreate;
  final void Function(int id, String name) onNavigate;
  final void Function(ShoppingListEntity list) onStartShopping;
  final void Function(int id) onDelete;

  const _ActiveListsView({
    required this.lists,
    required this.onCreate,
    required this.onNavigate,
    required this.onStartShopping,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (lists.isEmpty) {
      return _EmptyListsView(onCreate: onCreate);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: lists.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final list = lists[index];
        return _ShoppingListTile(
          list: list,
          onTap: () => onNavigate(list.id, list.name),
          onStartShopping: () => onStartShopping(list),
          onDelete: () => onDelete(list.id),
        );
      },
    );
  }
}

class _PurchaseHistoryView extends StatelessWidget {
  final List<ShoppingListEntity> history;
  final void Function(int id) onDelete;

  const _PurchaseHistoryView({
    required this.history,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_toggle_off, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Sin historial de compras',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Cuando cierres una lista de compras, se guardará aquí con el supermercado, artículos y total gastado.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final list = history[index];
        return _ClosedPurchaseTile(
          list: list,
          onDelete: () => onDelete(list.id),
        );
      },
    );
  }
}

class _ClosedPurchaseTile extends StatelessWidget {
  final ShoppingListEntity list;
  final VoidCallback onDelete;

  const _ClosedPurchaseTile({
    required this.list,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd/MM/yyyy HH:mm')
        .format(DateTime.fromMillisecondsSinceEpoch(list.timestamp));

    return GlassCard(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long, color: Colors.green, size: 22),
          ),
          title: Text(
            list.supermarket ?? list.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                'Fecha: $dateStr',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (list.supermarket != null)
                Text(
                  'Lista: ${list.name}',
                  style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '\$${list.totalCost.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 18),
                onPressed: onDelete,
              ),
            ],
          ),
          children: [
            FutureBuilder<List<ShoppingListItemEntity>>(
              future: context.read<ShoppingListViewModel>().getItemsForList(list.id),
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Sin artículos registrados', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 8),
                  itemBuilder: (ctx, idx) {
                    final it = items[idx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '• ${it.name} (${it.quantity} ${it.unit})',
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '\$${(it.price * it.quantity).toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyListsView extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyListsView({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shopping_bag_outlined, size: 72, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No tienes listas de compras activas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Crea una lista para planificar tus compras y comparar precios automáticamente.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Crear Primera Lista'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShoppingListTile extends StatelessWidget {
  final ShoppingListEntity list;
  final VoidCallback onTap;
  final VoidCallback onStartShopping;
  final VoidCallback onDelete;

  const _ShoppingListTile({
    required this.list,
    required this.onTap,
    required this.onStartShopping,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd/MM/yyyy HH:mm')
        .format(DateTime.fromMillisecondsSinceEpoch(list.timestamp));

    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_cart,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  list.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  dateStr,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${list.totalCost.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_checkout, color: Colors.teal),
                tooltip: 'Hacer compra con esta lista',
                onPressed: onStartShopping,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                tooltip: 'Eliminar lista',
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
