import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../models/discount_model.dart';
import '../../../../models/product_model.dart';

class DiscountFormSheet extends StatefulWidget {
  final DiscountEntity? initialDiscount;
  final ValueChanged<DiscountEntity> onSave;

  const DiscountFormSheet({
    super.key,
    this.initialDiscount,
    required this.onSave,
  });

  @override
  State<DiscountFormSheet> createState() => _DiscountFormSheetState();
}

class _DiscountFormSheetState extends State<DiscountFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _bankCtrl;
  late TextEditingController _percentCtrl;
  late TextEditingController _capCtrl;
  late TextEditingController _minAmountCtrl;

  final Set<String> _selectedSupermarkets = {};
  final Set<String> _selectedDays = {};
  final Set<String> _selectedPaymentMethods = {};
  final Set<String> _selectedBanks = {};
  late bool _isRecurring;
  String? _validDate;
  late bool _hasCap;
  late bool _hasMinAmount;

  static const List<String> _availableBrands = [
    'Todas',
    'Coto',
    'Carrefour',
    'ChangoMás',
    'Día',
    'Jumbo',
    'Disco',
    'Vea',
    'Maxiconsumo',
    'Vital',
    'Diarco',
    'Makro',
    'La Anónima',
    'Yaguar',
  ];

  static const List<String> _availableDays = [
    'Todos',
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  static const List<String> _paymentMethods = [
    'Tarjeta de Débito',
    'Tarjeta de Crédito',
    'MODO',
    'Cuenta DNI',
    'Billetera Virtual',
    'Efectivo',
    'Otro',
  ];

  static const List<String> _bankSuggestions = [
    'Banco Nación',
    'Santander',
    'Galicia',
    'BBVA',
    'Macro',
    'Banco Provincia',
    'Mercado Pago',
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.initialDiscount;

    _initSupermarkets(d);
    _initDays(d);
    _initPaymentMethods(d);
    _initBanks(d);

    _bankCtrl = TextEditingController();
    _percentCtrl = TextEditingController(
      text: d != null && d.percentage > 0 ? d.percentage.toStringAsFixed(0) : '',
    );
    _capCtrl = TextEditingController(
      text: d != null && d.maxCap > 0 ? d.maxCap.toStringAsFixed(0) : '',
    );
    _minAmountCtrl = TextEditingController(
      text: d != null && d.minAmount > 0 ? d.minAmount.toStringAsFixed(0) : '',
    );

    _isRecurring = d?.isRecurring ?? true;
    _validDate = d?.validDate;
    _hasCap = d != null && d.maxCap > 0;
    _hasMinAmount = d != null && d.minAmount > 0;
  }

  void _initSupermarkets(DiscountEntity? d) {
    final raw = d?.supermarketName.trim() ?? 'Todos';
    if (raw.toLowerCase() == 'todos' || raw.isEmpty) {
      _selectedSupermarkets.add('Todas');
    } else {
      final parts = raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
      _selectedSupermarkets.addAll(parts);
    }
  }

  void _initDays(DiscountEntity? d) {
    final raw = d?.dayOfWeek.trim() ?? 'Todos los días';
    if (raw.toLowerCase().contains('todos') || raw.isEmpty) {
      _selectedDays.add('Todos');
    } else {
      final parts = raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
      _selectedDays.addAll(parts);
    }
  }

  void _initPaymentMethods(DiscountEntity? d) {
    final raw = d?.paymentMethod.trim() ?? 'Tarjeta de Débito';
    if (raw.isEmpty) {
      _selectedPaymentMethods.add('Tarjeta de Débito');
    } else {
      final parts = raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
      _selectedPaymentMethods.addAll(parts);
      if (_selectedPaymentMethods.isEmpty) {
        _selectedPaymentMethods.add('Tarjeta de Débito');
      }
    }
  }

  void _initBanks(DiscountEntity? d) {
    final raw = d?.bank.trim() ?? '';
    if (raw.isNotEmpty) {
      final parts = raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
      _selectedBanks.addAll(parts);
    }
  }

  @override
  void dispose() {
    _bankCtrl.dispose();
    _percentCtrl.dispose();
    _capCtrl.dispose();
    _minAmountCtrl.dispose();
    super.dispose();
  }

  void _toggleBrand(String brand) {
    setState(() {
      if (brand == 'Todas') {
        _selectedSupermarkets.clear();
        _selectedSupermarkets.add('Todas');
        return;
      }
      _selectedSupermarkets.remove('Todas');
      if (_selectedSupermarkets.contains(brand)) {
        _selectedSupermarkets.remove(brand);
        if (_selectedSupermarkets.isEmpty) {
          _selectedSupermarkets.add('Todas');
        }
      } else {
        _selectedSupermarkets.add(brand);
        if (_selectedSupermarkets.length == _availableBrands.length - 1) {
          _selectedSupermarkets.clear();
          _selectedSupermarkets.add('Todas');
        }
      }
    });
  }

  void _toggleDay(String day) {
    setState(() {
      if (day == 'Todos') {
        _selectedDays.clear();
        _selectedDays.add('Todos');
        return;
      }
      _selectedDays.remove('Todos');
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
        if (_selectedDays.isEmpty) {
          _selectedDays.add('Todos');
        }
      } else {
        _selectedDays.add(day);
        if (_selectedDays.length == 7) {
          _selectedDays.clear();
          _selectedDays.add('Todos');
        }
      }
    });
  }

  void _togglePaymentMethod(String method) {
    setState(() {
      if (_selectedPaymentMethods.contains(method)) {
        if (_selectedPaymentMethods.length > 1) {
          _selectedPaymentMethods.remove(method);
        }
      } else {
        _selectedPaymentMethods.add(method);
      }
    });
  }

  void _toggleBank(String bankName) {
    setState(() {
      if (_selectedBanks.contains(bankName)) {
        _selectedBanks.remove(bankName);
      } else {
        _selectedBanks.add(bankName);
      }
    });
  }

  void _addCustomBank() {
    final text = _bankCtrl.text.trim();
    if (text.isEmpty) return;
    final parts = text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
    setState(() {
      _selectedBanks.addAll(parts);
      _bankCtrl.clear();
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _validDate != null ? DateTime.tryParse(_validDate!) ?? now : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _validDate =
            "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final superName = (_selectedSupermarkets.contains('Todas') || _selectedSupermarkets.isEmpty)
        ? 'Todos'
        : _selectedSupermarkets.join(', ');

    final dayStr = (_selectedDays.contains('Todos') || _selectedDays.isEmpty)
        ? 'Todos los días'
        : _selectedDays.join(', ');

    final paymentStr = _selectedPaymentMethods.isEmpty
        ? 'Tarjeta de Débito'
        : _selectedPaymentMethods.join(', ');

    final bankStr = _selectedBanks.join(', ');
    final percent = double.tryParse(_percentCtrl.text.trim()) ?? 0.0;
    final cap = _hasCap ? (double.tryParse(_capCtrl.text.trim()) ?? 0.0) : 0.0;
    final minAmt = _hasMinAmount ? (double.tryParse(_minAmountCtrl.text.trim()) ?? 0.0) : 0.0;

    final discount = DiscountEntity(
      id: widget.initialDiscount?.id ?? 0,
      supermarketName: superName,
      dayOfWeek: dayStr,
      paymentMethod: paymentStr,
      bank: bankStr,
      isRecurring: _isRecurring,
      validDate: !_isRecurring ? _validDate : null,
      percentage: percent,
      maxCap: cap,
      minAmount: minAmt,
      isActive: widget.initialDiscount?.isActive ?? true,
    );

    widget.onSave(discount);
    Navigator.of(context).pop();
  }

  Widget _buildBrandLogo(String brand, bool isSelected, Color primary) {
    if (brand == 'Todas') {
      return Icon(
        Icons.storefront_rounded,
        size: 28,
        color: isSelected ? primary : Colors.grey.shade400,
      );
    }

    final logoUrl = SupermarketPriceInfo.buildLogoUrl(chainName: brand);
    if (logoUrl == null) {
      return Icon(
        Icons.storefront,
        size: 24,
        color: isSelected ? primary : Colors.grey.shade400,
      );
    }

    final image = CachedNetworkImage(
      imageUrl: logoUrl,
      fit: BoxFit.contain,
      memCacheWidth: 120,
      placeholder: (_, _) => Icon(
        Icons.storefront,
        size: 24,
        color: Colors.grey.shade300,
      ),
      errorWidget: (_, _, _) => Icon(
        Icons.storefront,
        size: 24,
        color: isSelected ? primary : Colors.grey.shade400,
      ),
    );

    if (isSelected) {
      return image;
    }
    return Opacity(
      opacity: 0.40,
      child: image,
    );
  }

  Widget _buildBrandCard(String brand, ThemeData theme) {
    final isSelected = _selectedSupermarkets.contains(brand) ||
        (_selectedSupermarkets.contains('Todas') && brand == 'Todas');
    final primary = theme.primaryColor;

    return InkWell(
      onTap: () => _toggleBrand(brand),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 78,
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primary : Colors.grey.shade300,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.18),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(child: _buildBrandLogo(brand, isSelected, primary)),
            const SizedBox(height: 3),
            Text(
              brand,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? primary : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComercioSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Comercio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(
              _selectedSupermarkets.contains('Todas') ? 'Todas las marcas' : '${_selectedSupermarkets.length} seleccionada(s)',
              style: TextStyle(fontSize: 11.5, color: theme.primaryColor, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableBrands.map((b) => _buildBrandCard(b, theme)).toList(),
        ),
      ],
    );
  }

  Widget _buildPercentageField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Porcentaje de Descuento (%)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _percentCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: 'Ej. 20 (para 20% OFF)',
            prefixIcon: Icon(Icons.percent),
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          validator: (val) {
            final n = double.tryParse(val?.trim() ?? '');
            if (n == null || n <= 0 || n > 100) {
              return 'Ingresá un porcentaje válido entre 1 y 100';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPaymentMethodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Medios de Pago (Múltiples)', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              '${_selectedPaymentMethods.length} seleccionado(s)',
              style: const TextStyle(fontSize: 11.5, color: Colors.blueGrey, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _paymentMethods.map((method) {
            final isSelected = _selectedPaymentMethods.contains(method);
            return FilterChip(
              label: Text(method),
              selected: isSelected,
              onSelected: (_) => _togglePaymentMethod(method),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBankField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Bancos / Billeteras (Múltiples)', style: TextStyle(fontWeight: FontWeight.bold)),
            if (_selectedBanks.isNotEmpty)
              Text(
                '${_selectedBanks.length} seleccionado(s)',
                style: const TextStyle(fontSize: 11.5, color: Colors.blueGrey, fontWeight: FontWeight.w600),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _bankSuggestions.map((b) {
            final isSelected = _selectedBanks.contains(b);
            return FilterChip(
              label: Text(b, style: const TextStyle(fontSize: 12)),
              selected: isSelected,
              onSelected: (_) => _toggleBank(b),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _bankCtrl,
                decoration: const InputDecoration(
                  hintText: 'Agregar otro banco o billetera...',
                  prefixIcon: Icon(Icons.account_balance_outlined, size: 20),
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                onSubmitted: (_) => _addCustomBank(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              icon: const Icon(Icons.add),
              tooltip: 'Agregar',
              onPressed: _addCustomBank,
            ),
          ],
        ),
        if (_selectedBanks.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: _selectedBanks.where((b) => !_bankSuggestions.contains(b)).map((b) {
              return Chip(
                label: Text(b, style: const TextStyle(fontSize: 11.5)),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () => setState(() => _selectedBanks.remove(b)),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildDaysSection(ThemeData theme) {
    final primary = theme.primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Tipo de Promoción', style: TextStyle(fontWeight: FontWeight.bold)),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Semanal')),
                ButtonSegment(value: false, label: Text('Única vez')),
              ],
              selected: {_isRecurring},
              onSelectionChanged: (val) => setState(() => _isRecurring = val.first),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_isRecurring) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Días que aplica (Múltiples)', style: TextStyle(fontSize: 13, color: Colors.blueGrey)),
              Text(
                _selectedDays.contains('Todos') ? 'Todos los días' : '${_selectedDays.length} día(s)',
                style: TextStyle(fontSize: 11.5, color: primary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _availableDays.map((day) {
              final isSelected = _selectedDays.contains(day) ||
                  (_selectedDays.contains('Todos') && day == 'Todos');
              return FilterChip(
                label: Text(day),
                selected: isSelected,
                onSelected: (_) => _toggleDay(day),
              );
            }).toList(),
          ),
        ] else ...[
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month),
            label: Text(_validDate != null ? 'Fecha: $_validDate' : 'Seleccionar Fecha Válida'),
          ),
        ],
      ],
    );
  }

  Widget _buildCapAndMinAmountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('¿Tiene tope de reintegro?', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Límite máximo en pesos de ahorro por compra'),
          value: _hasCap,
          onChanged: (val) => setState(() => _hasCap = val),
        ),
        if (_hasCap) ...[
          TextFormField(
            controller: _capCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: 'Ej. 6000',
              prefixText: '\$ ',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            validator: (val) {
              if (_hasCap && (double.tryParse(val?.trim() ?? '') ?? 0) <= 0) {
                return 'Ingresá el monto del tope en pesos';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
        ],
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('¿Exige compra mínima?', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Solo aplica si el ticket supera este monto'),
          value: _hasMinAmount,
          onChanged: (val) => setState(() => _hasMinAmount = val),
        ),
        if (_hasMinAmount) ...[
          TextFormField(
            controller: _minAmountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: 'Ej. 15000',
              prefixText: '\$ ',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            validator: (val) {
              if (_hasMinAmount && (double.tryParse(val?.trim() ?? '') ?? 0) <= 0) {
                return 'Ingresá el monto mínimo en pesos';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.initialDiscount != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Editar Promoción' : 'Nueva Promoción',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildComercioSection(theme),
                    const SizedBox(height: 20),
                    _buildPercentageField(),
                    const SizedBox(height: 18),
                    _buildPaymentMethodSection(),
                    const SizedBox(height: 18),
                    _buildBankField(),
                    const SizedBox(height: 18),
                    _buildDaysSection(theme),
                    const SizedBox(height: 18),
                    _buildCapAndMinAmountSection(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.check),
                    label: Text(isEditing ? 'Guardar Cambios' : 'Crear Promoción'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
