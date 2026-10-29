import 'package:flutter/material.dart';

class CollapsibleNutritionTable extends StatefulWidget {
  final List<MapEntry<String, String>> facts;

  const CollapsibleNutritionTable({super.key, required this.facts});

  @override
  State<CollapsibleNutritionTable> createState() => _CollapsibleNutritionTableState();
}

class _CollapsibleNutritionTableState extends State<CollapsibleNutritionTable> {
  // Por defecto cerrado según requerimiento
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.table_chart_outlined, size: 18, color: Colors.teal),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Información Nutricional (por 100g / 100ml)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                Icon(
                  _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _buildNutritionTable(widget.facts),
          ),
          secondChild: const SizedBox.shrink(),
          crossFadeState:
              _isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }

  Widget _buildNutritionTable(List<MapEntry<String, String>> facts) {
    // Estilo de rótulo de envases (Nutrition Facts)
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Encabezado característico de envase
          const Text(
            'INFORMACIÓN NUTRICIONAL',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Valores medios por 100g / 100ml',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
          const Divider(thickness: 2.0, color: Color(0xFF0F172A), height: 12),
          Table(
            columnWidths: const {0: FlexColumnWidth(2.2), 1: FlexColumnWidth(1)},
            children: facts.map((entry) {
              final isMainNutrient = entry.key.toLowerCase().contains('energ') ||
                  entry.key.toLowerCase().contains('grasa') ||
                  entry.key.toLowerCase().contains('sodio') ||
                  entry.key.toLowerCase().contains('proteí') ||
                  entry.key.toLowerCase().contains('carbo');

              return TableRow(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1), width: 0.8)),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isMainNutrient ? FontWeight.w800 : FontWeight.w600,
                        letterSpacing: 0.2,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      entry.value,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: Color(0xFF0F172A),
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
