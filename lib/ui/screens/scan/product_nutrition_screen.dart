import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/product_model.dart';
import '../../../utils/image_url_helper.dart';
import '../../../services/locale_service.dart';
import '../../components/app_header_top_bar.dart';
import '../../components/glass_card.dart';
import '../../components/carrefour_image_cropper.dart';
import 'score_explanation_sheet.dart';
import 'components/product_header_card.dart';
import 'widgets/collapsible_nutrition_table.dart';
import 'widgets/octagon_seal_badge.dart';

class ProductNutritionScreen extends StatelessWidget {
  final OffProduct product;

  static const TextStyle _sectionHeaderTitleStyle = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.bold,
    color: Color(0xFF0F172A),
    letterSpacing: -0.2,
  );

  const ProductNutritionScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPad = (screenWidth * 0.04).clamp(12.0, 24.0);

    return Scaffold(
      appBar: AppHeaderTopBar(
        title: 'Información Nutricional',
        leading: BackButton(
          color: Colors.white,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: horizontalPad, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProductHeader(context),
              const SizedBox(height: 16),
              ProductNutritionContent(product: product),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductHeader(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final imgDim = (screenWidth * 0.17).clamp(56.0, 76.0);

    return GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (product.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CarrefourImageCropper(
                imageUrl: product.imageUrl,
                fillWidth: true,
                child: CachedNetworkImage(
                  imageUrl: ImageUrlHelper.getOptimizedImageUrl(product.imageUrl, targetWidth: 160),
                  width: imgDim,
                  height: imgDim,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  errorWidget: (_, _, _) => const Icon(Icons.image_not_supported, size: 36),
                ),
              ),
            ),
            SizedBox(width: (screenWidth * 0.035).clamp(10.0, 16.0)),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.productName ?? 'Producto sin nombre',
                  style: _sectionHeaderTitleStyle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (product.brands != null && product.brands!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    product.brands!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (product.quantity != null && product.quantity!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Contenido neto: ${product.quantity}',
                    style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                  ),
                ],
                if (product.barcode != null && product.barcode!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  BarcodeBadge(
                    barcode: product.barcode!,
                    isProxy: product.isProxy,
                    proxyProductName: product.proxyProductName,
                    proxyBarcode: product.proxyBarcode,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProductNutritionContent extends StatelessWidget {
  final OffProduct product;

  static const TextStyle _sectionHeaderTitleStyle = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.bold,
    color: Color(0xFF0F172A),
    letterSpacing: -0.2,
  );

  const ProductNutritionContent({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildNutritionalFactsTable(context),
        const SizedBox(height: 16),
        _buildOfficialScoresCard(context),
        const SizedBox(height: 16),
        _buildWarningSealsSection(context),
      ],
    );
  }

  Widget _buildOfficialScoresCard(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: _buildNutriScoreSvg(context)),
          const SizedBox(width: 4),
          Expanded(child: _buildNovaSvg(context)),
          const SizedBox(width: 4),
          Expanded(child: _buildEcoScoreSvg(context)),
        ],
      ),
    );
  }

  Widget _buildNutriScoreSvg(BuildContext context) {
    final grade = (product.nutriscoreGrade ?? '').toLowerCase();
    String assetPath;
    if (['a', 'b', 'c', 'd', 'e'].contains(grade)) {
      assetPath = 'assets/icons/nutriscore/nutriscore-$grade.svg';
    } else {
      assetPath = 'assets/icons/nutriscore/nutriscore-unknown.svg';
    }

    return InkWell(
      onTap: () => ScoreExplanationSheet.show(
        context,
        ScoreExplanationData.forNutriScore(product),
      ),
      borderRadius: BorderRadius.circular(8),
      child: SvgPicture.asset(
        assetPath,
        height: 74,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => const SizedBox(height: 74),
      ),
    );
  }

  Widget _buildNovaSvg(BuildContext context) {
    final group = product.novaGroup;
    final hasNova = group != null && group >= 1 && group <= 4;
    final assetPath = hasNova
        ? 'assets/icons/nova/NOVA_group_$group.svg'
        : null;

    return InkWell(
      onTap: () => ScoreExplanationSheet.show(
        context,
        ScoreExplanationData.forNova(product),
      ),
      borderRadius: BorderRadius.circular(8),
      child: assetPath != null
          ? SvgPicture.asset(
              assetPath,
              height: 74,
              fit: BoxFit.contain,
              placeholderBuilder: (_) => const SizedBox(height: 74),
            )
          : Container(
              height: 74,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('N/D', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
    );
  }

  Widget _buildEcoScoreSvg(BuildContext context) {
    final grade = (product.ecoscoreGrade ?? '').toLowerCase();
    String assetPath;
    if (['a', 'b', 'c', 'd', 'e'].contains(grade)) {
      assetPath = 'assets/icons/greenscore/green-score-$grade.svg';
    } else {
      assetPath = 'assets/icons/greenscore/green-score-unknown.svg';
    }

    return InkWell(
      onTap: () => ScoreExplanationSheet.show(
        context,
        ScoreExplanationData.forEcoScore(product),
      ),
      borderRadius: BorderRadius.circular(8),
      child: SvgPicture.asset(
        assetPath,
        height: 74,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => const SizedBox(height: 74),
      ),
    );
  }

  static String cleanIngredientsText(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    var text = raw;

    // Eliminar leyendas de advertencia de alérgenos que ya se muestran en la sección de alérgenos
    final allergenPhrasesRegex = RegExp(
      r'[\(\[]?\s*(?:contiene|puede contener|alérgenos|trazas de)?\s*(?:derivados\s+de(?:l)?\s+)?(?:trigo|soja|gluten)[\)\]]?\.?',
      caseSensitive: false,
    );

    text = text.replaceAll(allergenPhrasesRegex, '');

    // Limpieza de puntuación y espaciado residual
    text = text
        .replaceAll(RegExp(r'\s*,\s*,'), ',')
        .replaceAll(RegExp(r'\s*;\s*;'), ';')
        .replaceAll(RegExp(r'\s*\.\s*\.'), '.')
        .replaceAll(RegExp(r',\s*\.'), '.')
        .replaceAll(RegExp(r'^\s*[,;.-]\s*'), '')
        .replaceAll(RegExp(r'\s*[,;]\s*$'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    return text;
  }

  Widget _buildNutritionalFactsTable(BuildContext context) {
    final n = product.nutriments;
    final cleanedIngredients = cleanIngredientsText(product.ingredientsText);
    final hasIngredients = cleanedIngredients.isNotEmpty;

    final facts = <MapEntry<String, String>>[
      if (n?.energyKcal != null) MapEntry('Valor energético', '${n!.energyKcal!.toStringAsFixed(0)} kcal'),
      if (n?.carbohydrates != null) MapEntry('Carbohidratos', '${n!.carbohydrates!.toStringAsFixed(1)} g'),
      if (n?.sugars != null) MapEntry('Azúcares totales', '${n!.sugars!.toStringAsFixed(1)} g'),
      if (n?.proteins != null) MapEntry('Proteínas', '${n!.proteins!.toStringAsFixed(1)} g'),
      if (n?.fat != null) MapEntry('Grasas totales', '${n!.fat!.toStringAsFixed(1)} g'),
      if (n?.saturatedFat != null) MapEntry('Grasas saturadas', '${n!.saturatedFat!.toStringAsFixed(1)} g'),
      if (n?.salt != null) MapEntry('Sodio / Sal', '${n!.salt!.toStringAsFixed(2)} g'),
    ];

    if (facts.isEmpty && !hasIngredients) return const SizedBox.shrink();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasIngredients) ...[
            _buildIngredientsSection(cleanedIngredients),
            if (facts.isNotEmpty) const Divider(height: 24, color: Color(0xFFE2E8F0)),
          ],
          if (facts.isNotEmpty) CollapsibleNutritionTable(facts: facts),
        ],
      ),
    );
  }

  Widget _buildIngredientsSection(String cleanedIngredients) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.menu_book_outlined, size: 18, color: Color(0xFF0D9488)),
            SizedBox(width: 8),
            Text(
              'Ingredientes',
              style: _sectionHeaderTitleStyle,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          cleanedIngredients,
          style: const TextStyle(
            fontSize: 12,
            height: 1.4,
            color: Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  List<String> _resolveWarningSeals() {
    final rawLabels = product.labelsTags;
    final seen = <String>{};
    final result = <String>[];

    void addSeal(String rawTag) {
      final displayText = _getSealDisplayText(rawTag).trim();
      if (displayText.isEmpty) return;
      // Deduplicación estricta por el texto final visible para evitar repeticiones
      if (!seen.contains(displayText)) {
        seen.add(displayText);
        result.add(displayText);
      }
    }

    for (final tag in rawLabels) {
      if (OctagonSealBadge.isSystemNameTag(tag)) {
        continue;
      }
      addSeal(tag);
    }

    final nutriments = product.nutriments;
    if (nutriments != null) {
      if ((nutriments.sugars ?? 0) >= 10.0) {
        addSeal('es:exceso-en-azucares');
      }
      if ((nutriments.salt ?? 0) >= 1.0) {
        addSeal('es:exceso-en-sodio');
      }
      if ((nutriments.saturatedFat ?? 0) >= 4.0) {
        addSeal('es:exceso-en-grasas-saturadas');
      }
      if ((nutriments.fat ?? 0) >= 12.0) {
        addSeal('es:exceso-en-grasas-totales');
      }
    }

    return result;
  }

  Widget _buildWarningSealsSection(BuildContext context) {
    final locale = context.watch<LocaleService>();
    final seals = _resolveWarningSeals();
    final allergens = product.allergensTags.toSet().toList();
    final isNaturalOrExempt = product.isExemptLaw27642 || (seals.isEmpty && product.novaGroup == 1);

    if (seals.isEmpty && allergens.isEmpty && !isNaturalOrExempt) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sellos y Advertencias',
            style: _sectionHeaderTitleStyle,
          ),
          const SizedBox(height: 10),
          if (isNaturalOrExempt && seals.isEmpty)
            _buildExemptNaturalCard()
          else
            ...seals.map((displayText) => _buildSealCard(displayText)),
          if (allergens.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Alérgenos Declarados',
              style: _sectionHeaderTitleStyle,
            ),
            const SizedBox(height: 10),
            ...allergens.map((all) => _buildAllergenCard(locale.formatAllergen(all))),
          ],
        ],
      ),
    );
  }

  Widget _buildExemptNaturalCard() {
    final refText = product.referenceSource != null
        ? 'Exento Ley 27.642 • ${product.referenceSource}'
        : 'Alimento sin procesar o de 1 solo ingrediente (Exento Ley 27.642)';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFF059669),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Alimento natural sin sellos de advertencia',
                  style: TextStyle(
                    color: Color(0xFF065F46),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  refText,
                  style: const TextStyle(
                    color: Color(0xFF047857),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSealCard(String displayText) {
    final isOctagon = displayText.startsWith('EXCESO EN');
    final isWarning = displayText.contains('NO RECOMENDABLE') || displayText.contains('EVITAR EN NIÑOS');
    final isSinTacc = displayText.contains('T.A.C.C.');

    Color cardBg;
    Color textColor;
    Color borderColor;
    Widget leadingWidget;

    if (isOctagon) {
      cardBg = const Color(0xFF0F172A);
      textColor = Colors.white;
      borderColor = const Color(0xFF1E293B);
      leadingWidget = Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: const Center(
          child: Text(
            '!',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ),
      );
    } else if (isWarning) {
      cardBg = const Color(0xFFFFFBEB);
      textColor = const Color(0xFF92400E);
      borderColor = const Color(0xFFF59E0B);
      leadingWidget = Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Center(
          child: Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
        ),
      );
    } else if (isSinTacc) {
      cardBg = const Color(0xFFF0FDF4);
      textColor = const Color(0xFF166534);
      borderColor = const Color(0xFF22C55E);
      leadingWidget = Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF22C55E),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Center(
          child: Icon(Icons.verified_rounded, color: Colors.white, size: 18),
        ),
      );
    } else {
      cardBg = const Color(0xFFF8FAFC);
      textColor = const Color(0xFF1E293B);
      borderColor = const Color(0xFFCBD5E1);
      leadingWidget = const Icon(Icons.info_outline, color: Color(0xFF64748B), size: 24);
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          leadingWidget,
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              displayText,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: textColor,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllergenCard(String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDBA74), width: 1.2),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded, size: 18, color: Color(0xFFEA580C)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13.0,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9A3412),
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSealDisplayText(String rawTag) {
    final clean = rawTag.toLowerCase().replaceAll(RegExp(r'^(es:|en:|fr:)'), '');
    if (clean.contains('azucar') || clean.contains('sugar')) {
      return 'EXCESO EN AZÚCARES';
    }
    if (clean.contains('sodio') || clean.contains('sodium') || clean.contains('salt')) {
      return 'EXCESO EN SODIO';
    }
    if (clean.contains('grasas-saturadas') || clean.contains('saturated-fat')) {
      return 'EXCESO EN GRASAS SATURADAS';
    }
    if (clean.contains('grasas-totales') || clean.contains('grasas') || clean.contains('fat')) {
      return 'EXCESO EN GRASAS TOTALES';
    }
    if (clean.contains('caloria') || clean.contains('calorie') || clean.contains('energy')) {
      return 'EXCESO EN CALORÍAS';
    }
    if (clean.contains('edulcorante') || clean.contains('sweetener')) {
      return 'CONTIENE EDULCORANTES - NO RECOMENDABLE EN NIÑOS/AS';
    }
    if (clean.contains('cafeina') || clean.contains('caffeine')) {
      return 'CONTIENE CAFEÍNA - EVITAR EN NIÑOS/AS';
    }
    if (clean.contains('tacc') || clean.contains('gluten')) {
      return 'SIN T.A.C.C.';
    }
    return clean.replaceAll('-', ' ').toUpperCase();
  }
}
