import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../viewmodels/shopping_list_viewmodel.dart';
import '../../../models/shopping_list_model.dart';
import '../scan/scanner_view.dart';
import '../../components/app_header_top_bar.dart';
import 'widgets/shopping_item_row.dart';
import 'widgets/edit_item_dialog.dart';
import 'widgets/list_summary_footer.dart';
import 'active_shopping_session_screen.dart';

class ActiveListScreen extends StatefulWidget {
  final int listId;
  final String listName;

  const ActiveListScreen({
    super.key,
    required this.listId,
    required this.listName,
  });

  @override
  State<ActiveListScreen> createState() => _ActiveListScreenState();
}

class _ActiveListScreenState extends State<ActiveListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ShoppingListViewModel>().loadItemsForList(widget.listId);
    });
  }

  void _showAddItemDialog({String? initialBarcode, String? initialName, double? initialPrice}) {
    showDialog(
      context: context,
      builder: (_) => _AddItemDialog(
        listId: widget.listId,
        initialBarcode: initialBarcode,
        initialName: initialName,
        initialPrice: initialPrice,
      ),
    );
  }

  void _openDirectScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScannerView(
          onBarcodeScanned: (scannedBarcode) async {
            final vm = context.read<ShoppingListViewModel>();
            String? prodName;
            double? estPrice;

            final prod = await vm.findProductByBarcode(scannedBarcode);
            if (prod != null) {
              prodName = prod['productos_descripcion'] as String?;
              final price = await vm.getEstimatedPrice(prod['id_producto'].toString());
              if (price != null && price > 0) {
                estPrice = price;
              }
            }

            if (estPrice == null || estPrice == 0.0) {
              final lp = await vm.getLastPurchase(scannedBarcode, widget.listId);
              if (lp != null) {
                estPrice = lp.price;
              }
            }

            if (!mounted) return;
            _showAddItemDialog(
              initialBarcode: scannedBarcode,
              initialName: prodName,
              initialPrice: estPrice,
            );
          },
        ),
      ),
    );
  }

  void _showEditItemDialog(ShoppingListItemEntity item) {
    showDialog(
      context: context,
      builder: (_) => EditItemDialog(
        item: item,
        onSave: (updated) {
          context.read<ShoppingListViewModel>().updateItem(updated);
        },
      ),
    );
  }

  void _confirmDeleteItem(ShoppingListItemEntity item) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Eliminar Producto'),
        content: Text('¿Deseas eliminar "${item.name}" de la lista?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () {
              Navigator.of(dCtx).pop();
              context.read<ShoppingListViewModel>().deleteItem(item.id, widget.listId);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _saveList() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Lista guardada y actualizada correctamente.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _startShoppingSession(List<ShoppingListItemEntity> items) {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un producto a la lista antes de comprar.')),
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
                const Text(
                  'Elige dónde vas a realizar la compra para registrar los precios reales y el ticket en tu Historial:',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
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
                      originalListId: widget.listId,
                      listName: widget.listName,
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

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ShoppingListViewModel>();
    final items = viewModel.currentItems;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(108),
        child: Column(
          children: [
            AppHeaderTopBar(
              title: widget.listName,
              leading: BackButton(
                color: Colors.white,
                onPressed: () => Navigator.of(context).pop(),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                  tooltip: 'Escanear producto',
                  onPressed: _openDirectScanner,
                ),
              ],
            ),
            // Menú superior bajo el encabezado con flecha de volver, disco de guardar e iniciar compra
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              color: theme.cardColor,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Volver',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.save),
                    tooltip: 'Guardar lista',
                    onPressed: _saveList,
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.shopping_cart_checkout, size: 18),
                    label: const Text('Hacer Compra'),
                    onPressed: () => _startShoppingSession(items),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddItemDialog(),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: ListSummaryFooter(
        viewModel: viewModel,
        listId: widget.listId,
      ),
      body: items.isEmpty
          ? const Center(
              child: Text(
                'No hay productos en esta lista.\nAgrega uno con el botón + o el escáner.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                return ShoppingItemRow(
                  item: item,
                  onToggle: () => viewModel.toggleItemPurchased(item),
                  onEdit: () => _showEditItemDialog(item),
                  onDelete: () => _confirmDeleteItem(item),
                );
              },
            ),
    );
  }
}

class _AddItemDialog extends StatefulWidget {
  final int listId;
  final String? initialBarcode;
  final String? initialName;
  final double? initialPrice;

  const _AddItemDialog({
    required this.listId,
    this.initialBarcode,
    this.initialName,
    this.initialPrice,
  });

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  late final TextEditingController _nameCtrl;
  final _qtyCtrl = TextEditingController(text: '1.0');
  late final TextEditingController _priceCtrl;
  late final TextEditingController _barcodeCtrl;
  String _unit = 'un';
  LastPurchaseInfo? _lastPurchase;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName ?? '');
    _priceCtrl = TextEditingController(
      text: widget.initialPrice != null && widget.initialPrice! > 0
          ? widget.initialPrice!.toStringAsFixed(2)
          : '0.00',
    );
    _barcodeCtrl = TextEditingController(text: widget.initialBarcode ?? '');

    if (widget.initialBarcode != null && widget.initialBarcode!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkLastPurchase(widget.initialBarcode!));
    }
  }

  Future<void> _checkLastPurchase(String barcode) async {
    final lp = await context.read<ShoppingListViewModel>().getLastPurchase(barcode, widget.listId);
    if (!mounted) return;
    if (lp != null) {
      setState(() {
        _lastPurchase = lp;
        if (_priceCtrl.text == '0.00' || _priceCtrl.text == '0.0' || _priceCtrl.text.isEmpty) {
          _priceCtrl.text = lp.price.toStringAsFixed(2);
        }
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _barcodeCtrl.dispose();
    super.dispose();
  }

  void _openScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScannerView(
          onBarcodeScanned: (scannedBarcode) async {
            _barcodeCtrl.text = scannedBarcode;
            final vm = context.read<ShoppingListViewModel>();

            // Autocompletar automáticamente el nombre desde el catálogo
            final prod = await vm.findProductByBarcode(scannedBarcode);
            if (prod != null) {
              final desc = prod['productos_descripcion'] as String?;
              if (desc != null && desc.isNotEmpty) {
                _nameCtrl.text = desc;
              }
              final estPrice = await vm.getEstimatedPrice(prod['id_producto'].toString());
              if (estPrice != null && estPrice > 0) {
                _priceCtrl.text = estPrice.toStringAsFixed(2);
              }
            }

            final lp = await vm.getLastPurchase(scannedBarcode, widget.listId);
            if (!mounted) return;
            setState(() {
              _lastPurchase = lp;
              if (lp != null && (_priceCtrl.text == '0.0' || _priceCtrl.text == '0.00' || _priceCtrl.text.isEmpty)) {
                _priceCtrl.text = lp.price.toStringAsFixed(2);
              }
            });
          },
        ),
      ),
    );
  }

  Future<void> _onOptionSelected(Map<String, dynamic> option) async {
    final name = option['productos_descripcion'] as String? ?? '';
    _nameCtrl.text = name;
    final code = option['id_producto']?.toString().trim() ?? '';
    if (code.isNotEmpty) {
      _barcodeCtrl.text = code;
    }
    final vm = context.read<ShoppingListViewModel>();
    final estPrice = await vm.getEstimatedPrice(option['id_producto'].toString());
    if (estPrice != null && estPrice > 0) {
      _priceCtrl.text = estPrice.toStringAsFixed(2);
    }
    if (code.isNotEmpty) {
      final lp = await vm.getLastPurchase(code, widget.listId);
      if (!mounted) return;
      setState(() {
        _lastPurchase = lp;
        if (lp != null) {
          _priceCtrl.text = lp.price.toStringAsFixed(2);
        }
      });
    }
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 1.0;
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0.0;
    final barcode = _barcodeCtrl.text.trim();

    if (name.isNotEmpty) {
      context.read<ShoppingListViewModel>().addItem(
            listId: widget.listId,
            name: name,
            quantity: qty,
            unit: _unit,
            price: price >= 0 ? price : 0.0,
            barcode: barcode.isNotEmpty ? barcode : null,
          );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar Artículo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProductAutocomplete(),
            const SizedBox(height: 12),
            _buildQtyAndUnitRow(),
            const SizedBox(height: 12),
            _buildPriceField(),
            const SizedBox(height: 12),
            _buildBarcodeField(),
            if (_lastPurchase != null) ...[
              const SizedBox(height: 8),
              _buildLastPurchaseNotice(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Agregar'),
        ),
      ],
    );
  }

  Widget _buildProductAutocomplete() {
    return Autocomplete<Map<String, dynamic>>(
      displayStringForOption: (option) => option['productos_descripcion'] as String? ?? '',
      optionsBuilder: (textVal) async {
        if (textVal.text.trim().length < 2) return const [];
        return await context.read<ShoppingListViewModel>().searchCatalogProducts(textVal.text);
      },
      onSelected: _onOptionSelected,
      fieldViewBuilder: (ctx, textEditingController, focusNode, onFieldSubmitted) {
        if (_nameCtrl.text.isNotEmpty && textEditingController.text.isEmpty) {
          textEditingController.text = _nameCtrl.text;
        }
        textEditingController.addListener(() {
          _nameCtrl.text = textEditingController.text;
        });
        return TextField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Nombre del producto',
            hintText: 'Ej. Arroz, Leche...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        );
      },
    );
  }

  Widget _buildQtyAndUnitRow() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: _qtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Cantidad',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            initialValue: _unit,
            items: ['un', 'kg', 'g', 'lt', 'ml', 'pack']
                .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _unit = val);
            },
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceField() {
    return TextField(
      controller: _priceCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Precio unitario estimado (\$)',
        prefixText: '\$ ',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildBarcodeField() {
    return InkWell(
      onTap: _openScanner,
      borderRadius: BorderRadius.circular(4),
      child: IgnorePointer(
        child: TextField(
          controller: _barcodeCtrl,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'Código de barras',
            hintText: 'Tocar para escanear',
            suffixIcon: Icon(Icons.qr_code_scanner, color: Colors.teal),
            border: OutlineInputBorder(),
          ),
        ),
      ),
    );
  }

  Widget _buildLastPurchaseNotice() {
    return Text(
      'Último precio pagado: \$${_lastPurchase!.price.toStringAsFixed(2)} '
      '${_lastPurchase!.supermarket != null ? 'en ${_lastPurchase!.supermarket}' : ''}',
      style: const TextStyle(fontSize: 12, color: Colors.green),
    );
  }
}
