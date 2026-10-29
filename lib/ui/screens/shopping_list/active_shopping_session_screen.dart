import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/shopping_list_model.dart';
import '../../../viewmodels/shopping_list_viewmodel.dart';
import '../../components/glass_card.dart';
import '../scan/scanner_view.dart';

class ActiveShoppingSessionScreen extends StatefulWidget {
  final int originalListId;
  final String listName;
  final String initialSupermarket;
  final List<ShoppingListItemEntity> initialItems;

  static const List<String> availableChains = [
    'Coto',
    'Carrefour',
    'Día',
    'ChangoMás',
    'Jumbo',
    'Disco',
    'Vea',
    'Vital',
    'Maxiconsumo',
    'Makro',
    'Yaguar',
    'La Anónima',
    'Cooperativa Obrera',
    'Otro comercio',
  ];

  const ActiveShoppingSessionScreen({
    super.key,
    required this.originalListId,
    required this.listName,
    required this.initialSupermarket,
    required this.initialItems,
  });

  @override
  State<ActiveShoppingSessionScreen> createState() => _ActiveShoppingSessionScreenState();
}

class _ActiveShoppingSessionScreenState extends State<ActiveShoppingSessionScreen> {
  late String _supermarket;
  late List<_ShoppingSessionItem> _sessionItems;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _supermarket = widget.initialSupermarket.trim().isEmpty ? 'Supermercado' : widget.initialSupermarket;
    _sessionItems = widget.initialItems
        .map((it) => _ShoppingSessionItem(
              barcode: it.barcode,
              name: it.name,
              quantity: it.quantity > 0 ? it.quantity : 1.0,
              unit: it.unit,
              price: it.price,
              isPurchased: false,
            ))
        .toList();
  }

  double get _currentTotal {
    double total = 0.0;
    for (final it in _sessionItems) {
      if (it.isPurchased) {
        total += it.price * it.quantity;
      }
    }
    return total;
  }

  int get _purchasedCount => _sessionItems.where((it) => it.isPurchased).length;

  void _changeSupermarketDialog() {
    showDialog(
      context: context,
      builder: (dCtx) => SimpleDialog(
        title: const Text('Cambiar Supermercado'),
        children: ActiveShoppingSessionScreen.availableChains.map((chain) {
          return SimpleDialogOption(
            onPressed: () {
              Navigator.pop(dCtx);
              if (chain == 'Otro comercio') {
                _promptCustomSupermarket();
              } else {
                setState(() => _supermarket = chain);
              }
            },
            child: Text(chain, style: const TextStyle(fontSize: 15)),
          );
        }).toList(),
      ),
    );
  }

  void _promptCustomSupermarket() {
    final ctrl = TextEditingController(text: _supermarket);
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Nombre del Comercio'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ej. Almacén Don Juan, Autoservicio Sol',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                setState(() => _supermarket = val);
              }
              Navigator.pop(dCtx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _editItemPriceAndQty(_ShoppingSessionItem item) {
    final priceCtrl = TextEditingController(
      text: item.price > 0 ? item.price.toStringAsFixed(2) : '',
    );
    final qtyCtrl = TextEditingController(text: item.quantity.toString());

    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Precio de Góndola (\$)',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Cantidad (${item.unit})',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final newPrice = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? item.price;
              final newQty = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? item.quantity;
              setState(() {
                item.price = newPrice > 0 ? newPrice : item.price;
                item.quantity = newQty > 0 ? newQty : item.quantity;
                item.isPurchased = true;
              });
              Navigator.pop(dCtx);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _openScannerForNewItem() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScannerView(
          onBarcodeScanned: (scannedBarcode) async {
            final vm = context.read<ShoppingListViewModel>();
            String? prodName;
            double estPrice = 0.0;

            final prod = await vm.findProductByBarcode(scannedBarcode);
            if (prod != null) {
              prodName = prod['productos_descripcion'] as String?;
              final price = await vm.getEstimatedPrice(prod['id_producto'].toString());
              if (price != null && price > 0) {
                estPrice = price;
              }
            }

            if (!mounted) return;
            _addNewItemDialog(
              barcode: scannedBarcode,
              initialName: prodName,
              initialPrice: estPrice,
            );
          },
        ),
      ),
    );
  }

  void _addNewItemDialog({String? barcode, String? initialName, double? initialPrice}) {
    final nameCtrl = TextEditingController(text: initialName ?? '');
    final priceCtrl = TextEditingController(
      text: (initialPrice != null && initialPrice > 0) ? initialPrice.toStringAsFixed(2) : '',
    );
    final qtyCtrl = TextEditingController(text: '1.0');

    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Agregar Artículo a la Compra'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: initialName == null || initialName.isEmpty,
                decoration: const InputDecoration(
                  labelText: 'Descripción del Producto',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Precio (\$)',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Cantidad',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                final price = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0.0;
                final qty = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 1.0;
                setState(() {
                  _sessionItems.insert(
                    0,
                    _ShoppingSessionItem(
                      barcode: barcode,
                      name: name,
                      quantity: qty > 0 ? qty : 1.0,
                      price: price,
                      isPurchased: true,
                    ),
                  );
                });
              }
              Navigator.pop(dCtx);
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  Future<void> _finalizePurchase() async {
    final purchasedItems = _sessionItems.where((it) => it.isPurchased).toList();
    if (purchasedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No has marcado ningún artículo como comprado.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Finalizar Compra'),
        content: Text(
          'Se guardará la compra de ${purchasedItems.length} artículos en $_supermarket por un total de \$${_currentTotal.toStringAsFixed(2)} en tu Historial.\n\nTu lista "${widget.listName}" original se mantendrá guardada para futuras compras.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Seguir comprando')),
          FilledButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('Confirmar y Guardar')),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final vm = context.read<ShoppingListViewModel>();
      final entityItems = purchasedItems
          .map((it) => ShoppingListItemEntity(
                listId: widget.originalListId,
                barcode: it.barcode,
                name: it.name,
                quantity: it.quantity,
                unit: it.unit,
                price: it.price,
                isPurchased: true,
              ))
          .toList();

      await vm.completePurchase(
        originalListId: widget.originalListId,
        listName: widget.listName,
        supermarket: _supermarket,
        purchasedItems: entityItems,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Compra guardada con éxito en el Historial! (\$${_currentTotal.toStringAsFixed(2)})'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar la compra: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Comprando: ${widget.listName}', style: const TextStyle(fontSize: 16)),
            InkWell(
              onTap: _changeSupermarketDialog,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _supermarket,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primaryContainer,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, size: 16),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Escanear producto imprevisto',
            onPressed: _openScannerForNewItem,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Agregar producto manual',
            onPressed: () => _addNewItemDialog(),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Comprados: $_purchasedCount de ${_sessionItems.length}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '\$${_currentTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _isSaving ? null : _finalizePurchase,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: const Text('Finalizar Compra'),
              ),
            ],
          ),
        ),
      ),
      body: _sessionItems.isEmpty
          ? const Center(
              child: Text('No hay productos en esta lista para comprar.'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _sessionItems.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = _sessionItems[index];
                final subtotal = item.price * item.quantity;

                return GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Checkbox(
                      value: item.isPurchased,
                      onChanged: (checked) {
                        if (checked == true && item.price == 0.0) {
                          _editItemPriceAndQty(item);
                        } else {
                          setState(() => item.isPurchased = checked ?? false);
                        }
                      },
                    ),
                    title: Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        decoration: item.isPurchased ? null : TextDecoration.none,
                      ),
                    ),
                    subtitle: Text(
                      '${item.quantity} ${item.unit} x \$${item.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: item.isPurchased ? Colors.blueGrey : Colors.grey,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '\$${subtotal.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: item.isPurchased ? theme.colorScheme.primary : Colors.grey,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Editar precio / cantidad',
                          onPressed: () => _editItemPriceAndQty(item),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _ShoppingSessionItem {
  final String? barcode;
  final String name;
  double quantity;
  final String unit;
  double price;
  bool isPurchased;

  _ShoppingSessionItem({
    this.barcode,
    required this.name,
    required this.quantity,
    this.unit = 'un',
    required this.price,
    required this.isPurchased,
  });
}
