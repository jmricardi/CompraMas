import 'package:flutter/material.dart';
import '../../../models/product_model.dart';

class ScoreExplanationData {
  final String title;
  final String subtitle;
  final String currentBadge;
  final Color currentBadgeColor;
  final String currentValueTitle;
  final String currentValueDescription;
  final List<ScoreScaleItem> scale;
  final String methodology;

  const ScoreExplanationData({
    required this.title,
    required this.subtitle,
    required this.currentBadge,
    required this.currentBadgeColor,
    required this.currentValueTitle,
    required this.currentValueDescription,
    required this.scale,
    required this.methodology,
  });

  factory ScoreExplanationData.forNutriScore(OffProduct product) {
    final grade = (product.nutriscoreGrade ?? '').toUpperCase();
    final hasGrade = ['A', 'B', 'C', 'D', 'E'].contains(grade);

    final values = {
      'A': ('Calidad Nutricional Muy Buena', 'Alimento con excelente balance nutricional: rico en fibra y proteínas, y bajo en azúcares, grasas saturadas y sodio.', const Color(0xFF038141)),
      'B': ('Calidad Nutricional Buena', 'Alimento con buen perfil nutricional, recomendable para consumo habitual.', const Color(0xFF85BB2F)),
      'C': ('Calidad Nutricional Media', 'Alimento con balance aceptable de nutrientes. Consumo regular moderado.', const Color(0xFFFECB02)),
      'D': ('Calidad Nutricional Baja', 'Contiene proporciones más altas de azúcares, sal o grasas saturadas. Consumir con moderación.', const Color(0xFFEE8100)),
      'E': ('Calidad Nutricional Muy Baja', 'Alimento muy denso en calorías, grasas saturadas o sodio. Limitar su consumo.', const Color(0xFFE63E11)),
    };

    final currentInfo = values[grade] ?? (
      'Sin Calificación Nutri-Score',
      'No se dispone de la información nutricional completa en la base de datos para calcular el puntaje.',
      Colors.blueGrey,
    );

    return ScoreExplanationData(
      title: 'Nutri-Score',
      subtitle: 'Calidad nutricional global de los alimentos',
      currentBadge: hasGrade ? grade : 'N/D',
      currentBadgeColor: currentInfo.$3,
      currentValueTitle: currentInfo.$1,
      currentValueDescription: currentInfo.$2,
      methodology: 'El Nutri-Score es un logotipo nutricional oficial basado en una escala de 5 letras (A a E) y colores. Evalúa los nutrientes favorables (fibras, proteínas, frutas y legumbres) frente a los que conviene limitar (calorías, azúcares, sal y grasas saturadas) por cada 100g de producto.',
      scale: [
        ScoreScaleItem(label: 'A', title: 'Muy favorable', description: 'Excelente calidad nutricional', color: const Color(0xFF038141), isSelected: grade == 'A'),
        ScoreScaleItem(label: 'B', title: 'Favorable', description: 'Buena calidad nutricional', color: const Color(0xFF85BB2F), isSelected: grade == 'B'),
        ScoreScaleItem(label: 'C', title: 'Medio', description: 'Calidad nutricional aceptable', color: const Color(0xFFFECB02), isSelected: grade == 'C'),
        ScoreScaleItem(label: 'D', title: 'Bajo', description: 'Menor calidad nutricional', color: const Color(0xFFEE8100), isSelected: grade == 'D'),
        ScoreScaleItem(label: 'E', title: 'Muy bajo', description: 'Baja calidad nutricional', color: const Color(0xFFE63E11), isSelected: grade == 'E'),
      ],
    );
  }

  factory ScoreExplanationData.forNova(OffProduct product) {
    final group = product.novaGroup;
    final hasGroup = group != null && group >= 1 && group <= 4;

    final values = {
      1: ('Grupo 1 — Alimento no procesado o mínimamente procesado', 'Alimento en su estado natural o con procesos simples (limpieza, congelación, secado) sin agregado de sustancias industriales.', const Color(0xFF00AA6C)),
      2: ('Grupo 2 — Ingrediente culinario procesado', 'Sustancia extraída directamente de alimentos o de la naturaleza para cocinar y sazonar (aceites, sal, azúcar, manteca).', const Color(0xFFFFB703)),
      3: ('Grupo 3 — Alimento procesado', 'Productos elaborados agregando sal, azúcar u otras sustancias del Grupo 2 a alimentos del Grupo 1 (conservas, quesos, panes artesanales).', const Color(0xFFFB8500)),
      4: ('Grupo 4 — Producto ultraprocesado', 'Formulaciones industriales fabricadas a partir de sustancias derivadas de alimentos con aditivos, colorantes, saborizantes y emulsionantes.', const Color(0xFFD90429)),
    };

    final currentInfo = values[group] ?? (
      'Sin Clasificación NOVA',
      'No hay suficiente información sobre la lista de ingredientes para determinar el nivel de procesamiento industrial.',
      Colors.blueGrey,
    );

    return ScoreExplanationData(
      title: 'Clasificación NOVA',
      subtitle: 'Nivel y propósito del procesamiento industrial de alimentos',
      currentBadge: hasGroup ? '$group' : 'N/D',
      currentBadgeColor: currentInfo.$3,
      currentValueTitle: currentInfo.$1,
      currentValueDescription: currentInfo.$2,
      methodology: 'El sistema NOVA, desarrollado por la Universidad de São Paulo y adoptado por la OMS/OPS, clasifica a los alimentos según el grado de procesamiento al que han sido sometidos en su fabricación, alertando sobre el consumo excesivo de ultraprocesados.',
      scale: [
        ScoreScaleItem(label: '1', title: 'No procesado', description: 'Frutas, verduras, carnes, leche y granos enteros', color: const Color(0xFF00AA6C), isSelected: group == 1),
        ScoreScaleItem(label: '2', title: 'Ingrediente culinario', description: 'Aceites, vinagre, manteca, azúcar y sal', color: const Color(0xFFFFB703), isSelected: group == 2),
        ScoreScaleItem(label: '3', title: 'Procesado', description: 'Conservas de verduras/pescado, quesos simples', color: const Color(0xFFFB8500), isSelected: group == 3),
        ScoreScaleItem(label: '4', title: 'Ultraprocesado', description: 'Golosinas, snacks, gaseosas y aditivos sintéticos', color: const Color(0xFFD90429), isSelected: group == 4),
      ],
    );
  }

  factory ScoreExplanationData.forEcoScore(OffProduct product) {
    final grade = (product.ecoscoreGrade ?? '').toUpperCase();
    final hasGrade = ['A', 'B', 'C', 'D', 'E'].contains(grade);

    final values = {
      'A': ('Impacto Ambiental Muy Bajo', 'Elaborado con procesos sostenibles, baja huella de carbono y envase de alta reciclabilidad.', const Color(0xFF1E8F4E)),
      'B': ('Impacto Ambiental Bajo', 'Buen desempeño ecológico global en producción y distribución.', const Color(0xFF2ECC71)),
      'C': ('Impacto Ambiental Moderado', 'Impacto medio en el consumo de recursos naturales y emisiones de gases de efecto invernadero.', const Color(0xFFFFCC00)),
      'D': ('Impacto Ambiental Elevado', 'Mayor huella de carbono, transporte extenso o envasado poco eficiente.', const Color(0xFFFF7B00)),
      'E': ('Impacto Ambiental Muy Elevado', 'Alto impacto en biodiversidad, uso intensivo de suelo/agua o envases no reciclables.', const Color(0xFFD32F2F)),
    };

    final currentInfo = values[grade] ?? (
      'Sin Calificación Eco-Score',
      'No se dispone de datos de origen de ingredientes o embalaje para calcular la huella ambiental.',
      Colors.blueGrey,
    );

    return ScoreExplanationData(
      title: 'Eco-Score',
      subtitle: 'Impacto ambiental y ecológico del ciclo de vida',
      currentBadge: hasGrade ? grade : 'N/D',
      currentBadgeColor: currentInfo.$3,
      currentValueTitle: currentInfo.$1,
      currentValueDescription: currentInfo.$2,
      methodology: 'El Eco-Score evalúa la huella ecológica de un alimento desde la granja hasta el plato. Utiliza el Análisis de Ciclo de Vida (ACV) de Agribalyse complementado con bonificaciones o penalizaciones por empaque, origen geográfico, producción orgánica y biodiversidad.',
      scale: [
        ScoreScaleItem(label: 'A', title: 'Muy bajo impacto', description: 'Excelente sustentabilidad ambiental', color: const Color(0xFF1E8F4E), isSelected: grade == 'A'),
        ScoreScaleItem(label: 'B', title: 'Bajo impacto', description: 'Buen desempeño ecológico', color: const Color(0xFF2ECC71), isSelected: grade == 'B'),
        ScoreScaleItem(label: 'C', title: 'Impacto moderado', description: 'Huella ambiental intermedia', color: const Color(0xFFFFCC00), isSelected: grade == 'C'),
        ScoreScaleItem(label: 'D', title: 'Alto impacto', description: 'Menor eficiencia ambiental', color: const Color(0xFFFF7B00), isSelected: grade == 'D'),
        ScoreScaleItem(label: 'E', title: 'Muy alto impacto', description: 'Alta emisión y uso intensivo', color: const Color(0xFFD32F2F), isSelected: grade == 'E'),
      ],
    );
  }
}

class ScoreScaleItem {
  final String label;
  final String title;
  final String description;
  final Color color;
  final bool isSelected;

  const ScoreScaleItem({
    required this.label,
    required this.title,
    required this.description,
    required this.color,
    this.isSelected = false,
  });
}

class ScoreExplanationSheet extends StatelessWidget {
  final ScoreExplanationData data;

  const ScoreExplanationSheet({super.key, required this.data});

  static void show(BuildContext context, ScoreExplanationData data) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ScoreExplanationSheet(data: data),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          color: Colors.white,
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDragHandle(),
                const SizedBox(height: 12),
                _buildHeader(),
                const SizedBox(height: 16),
                _buildCurrentValueCard(),
                const SizedBox(height: 18),
                _buildScaleSection(),
                const SizedBox(height: 20),
                _buildCloseButton(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFCBD5E1),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: data.currentBadgeColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            data.currentBadge,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      data.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: data.methodology,
                    triggerMode: TooltipTriggerMode.tap,
                    showDuration: const Duration(seconds: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.white,
                      height: 1.35,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Icon(
                        Icons.help_outline,
                        size: 16,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                data.subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentValueCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: data.currentBadgeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: data.currentBadgeColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: data.currentBadgeColor),
              const SizedBox(width: 6),
              const Text(
                'VALOR DE ESTE PRODUCTO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            data.currentValueTitle,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.currentValueDescription,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScaleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Alcance y Niveles de la Escala',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        ...data.scale.map((item) => _buildScaleRow(item)),
      ],
    );
  }

  Widget _buildScaleRow(ScoreScaleItem item) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: item.isSelected
            ? item.color.withValues(alpha: 0.12)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: item.isSelected ? item.color : const Color(0xFFE2E8F0),
          width: item.isSelected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: item.color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              item.label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: item.isSelected ? FontWeight.bold : FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          if (item.isSelected)
            Icon(Icons.check_circle, color: item.color, size: 18),
        ],
      ),
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF059669),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
