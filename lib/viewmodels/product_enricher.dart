import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../models/product_model.dart';
import '../../services/open_food_facts_service.dart';
import '../../services/carrefour_catalog_service.dart';
import '../../services/argenfoods_service.dart';
import '../data/repositories/price_repository.dart';
import '../data/repositories/price_search_utils.dart';

/// Servicio encargado del enriquecimiento asíncrono de productos
/// usando Open Food Facts y Carrefour Catalog como respaldo de imágenes/nutrición.
class ProductEnricher {
  final OpenFoodFactsService _offService;
  final PriceRepository _priceRepository;

  ProductEnricher({
    OpenFoodFactsService? offService,
    PriceRepository? priceRepository,
  })  : _offService = offService ?? OpenFoodFactsService(),
        _priceRepository = priceRepository ?? PriceRepository();

  /// Enriquecimiento en segundo plano con Open Food Facts y catálogo oficial de Carrefour.
  Future<void> enrichWithOffData(
    String cleanBarcode, {
    String? sepaImage,
    String? cleanSepaName,
    String? cleanSepaBrand,
    Map<String, dynamic>? primaryData,
    OffProduct? currentProduct,
    required void Function(OffProduct updated) onProductUpdated,
  }) async {
    try {
      // 1. Si es código interno/PLU (balanza, prefijos GS1 20 a 29 o productos_ean == false),
      // omitir OFF por completo y buscar la foto directamente en el supermercado (Carrefour).
      final isLocalEan = CarrefourCatalogService.isInternalOrPluBarcode(cleanBarcode) ||
          primaryData?['productos_ean'] == false ||
          primaryData?['productos_ean']?.toString() == '0';
      if (isLocalEan) {
        debugPrint('ℹ️ Código local/fresco ($cleanBarcode): omitiendo OFF y buscando imagen en supermercado...');
        final crfRes = await CarrefourCatalogService.findProductImage(
          ean: cleanBarcode,
          productTitle: cleanSepaName,
        );

        if (crfRes != null && crfRes.imageUrl != null && crfRes.imageUrl!.isNotEmpty) {
          unawaited(_priceRepository.updateProductImage(cleanBarcode, crfRes.imageUrl!));
          final updated = OffProduct(
            barcode: cleanBarcode,
            productName: cleanSepaName ?? crfRes.productName,
            imageUrl: crfRes.imageUrl,
            brands: cleanSepaBrand ?? crfRes.brand,
            quantity: currentProduct?.quantity ?? primaryData?['contenido_neto']?.toString(),
          );
          onProductUpdated(updated);
        }
        return;
      }

      final offResponse = await _offService.getProduct(cleanBarcode);
      bool offValido = false;
      OffProduct? workingProduct = currentProduct;

      if (offResponse.status == 1 && offResponse.product != null) {
        final p = offResponse.product!;

        // Verificar que no sea un producto incompatible por error de carga en OFF (ej. budín vs kiwi)
        bool isCompat = true;
        if (cleanSepaName != null && cleanSepaName.isNotEmpty && p.productName != null && p.productName!.isNotEmpty) {
          isCompat = PriceSearchUtils.matchesSearchDomain(cleanSepaName, p.productName!);
          if (!isCompat) {
            debugPrint('⚠️ Discrepancia de categoría entre catálogo ($cleanSepaName) y OFF (${p.productName}): se descarta OFF.');
          }
        }

        if (isCompat) {
          offValido = true;
          // Prioridad absoluta a la foto de Open Food Facts para este código de barras
          final offImage = (p.imageUrl != null && p.imageUrl!.isNotEmpty) ? p.imageUrl : null;
          final effectiveImage = offImage ?? sepaImage ?? workingProduct?.imageUrl;

          if (offImage != null) {
            unawaited(_priceRepository.updateProductImage(cleanBarcode, offImage));
          }

          final offNameClean = PriceSearchUtils.cleanProductTitle(p.productName, brand: p.brands);
          final resolvedName = (cleanSepaName != null && cleanSepaName.isNotEmpty)
              ? cleanSepaName
              : (offNameClean.isNotEmpty ? offNameClean : 'Producto sin nombre');

          workingProduct = OffProduct(
            barcode: cleanBarcode,
            productName: resolvedName,
            imageUrl: effectiveImage,
            ingredientsText: p.ingredientsText,
            brands: (cleanSepaBrand != null && cleanSepaBrand.isNotEmpty) ? cleanSepaBrand : p.brands,
            nutriscoreGrade: p.nutriscoreGrade,
            novaGroup: p.novaGroup,
            ecoscoreGrade: p.ecoscoreGrade,
            quantity: workingProduct?.quantity ?? p.quantity ?? primaryData?['contenido_neto']?.toString(),
            allergensTags: p.allergensTags,
            labelsTags: p.labelsTags,
            nutriments: p.nutriments,
          );
          onProductUpdated(workingProduct);

          // Si faltan datos de nutrición o sellos, intentar Nivel 2 (EAN hermano del clúster) y Nivel 3 (Producto + Variedad)
          final lacksNutrition = p.nutriments == null || p.nutriments!.isEmpty;
          final lacksLabels = p.labelsTags.isEmpty;
          if (lacksNutrition || lacksLabels) {
            final fallbackProd = await _findClusterOrGenericNutrition(
              cleanBarcode: cleanBarcode,
              primaryData: primaryData,
              fallbackQueryName: cleanSepaName ?? resolvedName,
            );
            if (fallbackProd != null) {
              final proxyTitle = _formatProxyOriginalName(fallbackProd);
              workingProduct = OffProduct(
                barcode: cleanBarcode,
                productName: resolvedName,
                // Preservar la imagen del producto real; solo usar la del hermano del clúster si no había ninguna
                imageUrl: workingProduct.imageUrl ?? fallbackProd.imageUrl,
                ingredientsText: workingProduct.ingredientsText ?? fallbackProd.ingredientsText,
                brands: workingProduct.brands,
                nutriscoreGrade: workingProduct.nutriscoreGrade ?? fallbackProd.nutriscoreGrade,
                novaGroup: workingProduct.novaGroup ?? fallbackProd.novaGroup,
                ecoscoreGrade: workingProduct.ecoscoreGrade ?? fallbackProd.ecoscoreGrade,
                quantity: workingProduct.quantity ?? fallbackProd.quantity,
                allergensTags: workingProduct.allergensTags.isNotEmpty
                    ? workingProduct.allergensTags
                    : fallbackProd.allergensTags,
                labelsTags: workingProduct.labelsTags.isNotEmpty
                    ? workingProduct.labelsTags
                    : fallbackProd.labelsTags,
                nutriments: (workingProduct.nutriments != null && workingProduct.nutriments!.isNotEmpty)
                    ? workingProduct.nutriments
                    : fallbackProd.nutriments,
                isProxy: true,
                proxyProductName: proxyTitle,
                proxyBarcode: fallbackProd.barcode,
              );
              onProductUpdated(workingProduct);
            }
          }
        }
      }

      // 2. SOLO si NO hay ninguna imagen (ni en OFF, ni en catálogo, ni previa), consultar foto oficial en Carrefour como respaldo.
      final hasImage = workingProduct?.imageUrl != null && workingProduct!.imageUrl!.isNotEmpty;
      if (!hasImage) {
        final crfRes = await CarrefourCatalogService.findProductImage(
          ean: cleanBarcode,
          productTitle: cleanSepaName,
        );
        final stillNoImage = workingProduct?.imageUrl == null || workingProduct!.imageUrl!.isEmpty;
        if (stillNoImage && crfRes != null && crfRes.imageUrl != null && crfRes.imageUrl!.isNotEmpty) {
          unawaited(_priceRepository.updateProductImage(cleanBarcode, crfRes.imageUrl!));
          workingProduct = OffProduct(
            barcode: cleanBarcode,
            productName: workingProduct?.productName ?? cleanSepaName ?? crfRes.productName,
            imageUrl: crfRes.imageUrl,
            brands: workingProduct?.brands ?? cleanSepaBrand ?? crfRes.brand,
            quantity: workingProduct?.quantity ?? primaryData?['contenido_neto']?.toString(),
            ingredientsText: workingProduct?.ingredientsText,
            nutriscoreGrade: workingProduct?.nutriscoreGrade,
            novaGroup: workingProduct?.novaGroup,
            ecoscoreGrade: workingProduct?.ecoscoreGrade,
            allergensTags: workingProduct?.allergensTags ?? const [],
            labelsTags: workingProduct?.labelsTags ?? const [],
            nutriments: workingProduct?.nutriments,
            isProxy: workingProduct?.isProxy ?? false,
            proxyProductName: workingProduct?.proxyProductName,
            proxyBarcode: workingProduct?.proxyBarcode,
          );
          onProductUpdated(workingProduct);
        }
      }

      // 3. Si OFF no fue válido ni devolvió producto para el EAN principal, buscar en hermanos del clúster (Nivel 2) o genérico (Nivel 3)
      if (!offValido && cleanSepaName != null && cleanSepaName.isNotEmpty) {
        final fallbackProd = await _findClusterOrGenericNutrition(
          cleanBarcode: cleanBarcode,
          primaryData: primaryData,
          fallbackQueryName: cleanSepaName,
        );
        if (fallbackProd != null &&
            (fallbackProd.nutriments != null ||
                fallbackProd.labelsTags.isNotEmpty ||
                fallbackProd.nutriscoreGrade != null)) {
          final proxyTitle = _formatProxyOriginalName(fallbackProd);
          workingProduct = OffProduct(
            barcode: cleanBarcode,
            productName: workingProduct?.productName ?? cleanSepaName,
            imageUrl: workingProduct?.imageUrl ?? fallbackProd.imageUrl,
            brands: workingProduct?.brands ?? cleanSepaBrand,
            quantity: workingProduct?.quantity ?? fallbackProd.quantity,
            ingredientsText: fallbackProd.ingredientsText,
            nutriscoreGrade: fallbackProd.nutriscoreGrade,
            novaGroup: fallbackProd.novaGroup,
            ecoscoreGrade: fallbackProd.ecoscoreGrade,
            allergensTags: fallbackProd.allergensTags,
            labelsTags: fallbackProd.labelsTags,
            nutriments: fallbackProd.nutriments,
            isProxy: true,
            proxyProductName: proxyTitle,
            proxyBarcode: fallbackProd.barcode,
          );
          onProductUpdated(workingProduct);
        }
      }

      // 4. Nivel 4: Si aún carece de información nutricional, consultar base oficial ARGENFOODS
      final lacksNutritionAfterOff = workingProduct == null ||
          workingProduct.nutriments == null ||
          workingProduct.nutriments!.isEmpty;
      if (lacksNutritionAfterOff && cleanSepaName != null && cleanSepaName.isNotEmpty) {
        final argenRef = await ArgenfoodsService.findReferenceProduct(
          cleanSepaName,
          barcode: cleanBarcode,
          brand: cleanSepaBrand,
        );
        if (argenRef != null) {
          final argenProxyName = (argenRef.productName != null && argenRef.productName!.trim().isNotEmpty)
              ? '${argenRef.productName!.trim()} (${argenRef.referenceSource ?? "Tabla oficial Argenfoods"})'
              : (argenRef.referenceSource ?? 'Referencia nutricional Argenfoods');
          workingProduct = OffProduct(
            barcode: cleanBarcode,
            productName: workingProduct?.productName ?? argenRef.productName ?? cleanSepaName,
            imageUrl: workingProduct?.imageUrl,
            brands: workingProduct?.brands ?? cleanSepaBrand,
            quantity: workingProduct?.quantity ?? primaryData?['contenido_neto']?.toString(),
            ingredientsText: workingProduct?.ingredientsText ?? argenRef.ingredientsText,
            nutriscoreGrade: workingProduct?.nutriscoreGrade ?? argenRef.nutriscoreGrade,
            novaGroup: workingProduct?.novaGroup ?? argenRef.novaGroup,
            ecoscoreGrade: workingProduct?.ecoscoreGrade ?? argenRef.ecoscoreGrade,
            allergensTags: workingProduct?.allergensTags ?? const [],
            labelsTags: workingProduct?.labelsTags ?? const [],
            nutriments: argenRef.nutriments,
            isExemptLaw27642: argenRef.isExemptLaw27642,
            referenceSource: argenRef.referenceSource,
            isProxy: true,
            proxyProductName: workingProduct?.proxyProductName ?? argenProxyName,
            proxyBarcode: workingProduct?.proxyBarcode ?? 'ARGENFOODS',
          );
          onProductUpdated(workingProduct);
        }
      }
    } catch (_) {}
  }

  String _formatProxyOriginalName(OffProduct proxy) {
    final name = (proxy.productName ?? '').trim();
    final brand = (proxy.brands ?? '').trim();
    final qty = (proxy.quantity ?? '').trim();
    final parts = <String>[
      if (name.isNotEmpty) name else 'Producto equivalente Open Food Facts',
      if (brand.isNotEmpty && !name.toLowerCase().contains(brand.toLowerCase())) '• $brand',
      if (qty.isNotEmpty && !name.toLowerCase().contains(qty.toLowerCase())) '($qty)',
    ];
    return parts.join(' ');
  }

  /// Nivel 2: Consulta EANs hermanos del mismo clúster (Producto + Variedad + Presentación).
  /// Nivel 3: Si ningún hermano tiene nutrición en OFF, busca equivalente por Producto + Variedad.
  Future<OffProduct?> _findClusterOrGenericNutrition({
    required String cleanBarcode,
    required Map<String, dynamic>? primaryData,
    required String fallbackQueryName,
  }) async {
    final rawSiblings = primaryData?['sibling_ids'];
    if (rawSiblings is List) {
      int checked = 0;
      for (final item in rawSiblings) {
        final sibEan = item?.toString().trim() ?? '';
        if (sibEan.isEmpty || sibEan == cleanBarcode) continue;
        if (CarrefourCatalogService.isInternalOrPluBarcode(sibEan)) continue;

        checked++;
        if (checked > 3) break; // Máximo 3 hermanos para mantener respuesta veloz

        final sibRes = await _offService.getProduct(sibEan);
        if (sibRes.status == 1 && sibRes.product != null) {
          final sp = sibRes.product!;
          final hasNutri =
              (sp.nutriments != null && sp.nutriments!.isNotEmpty) ||
              sp.nutriscoreGrade != null;
          if (hasNutri) {
            debugPrint(
                '✅ [OFF Nivel 2] Nutrición heredada de EAN hermano del clúster: $sibEan');
            return sp;
          }
        }
      }
    }

    // Nivel 3: Búsqueda genérica usando Producto + Variedad del clúster
    final prod = primaryData?['producto']?.toString().trim() ?? '';
    final varName = primaryData?['variedad']?.toString().trim() ?? '';
    final query = (prod.isNotEmpty)
        ? (varName.isNotEmpty && varName.toLowerCase() != 'clásico'
            ? '$prod $varName'
            : prod)
        : fallbackQueryName;

    return _offService.searchGenericEquivalent(query);
  }

  /// Consulta OFF como fallback cuando Supabase no tiene el producto (solo si es EAN global válido)
  Future<OffProduct?> fetchProductFromOffFallback(String cleanBarcode) async {
    if (CarrefourCatalogService.isInternalOrPluBarcode(cleanBarcode)) {
      return null;
    }
    final offResponse = await _offService.getProduct(cleanBarcode);
    if (offResponse.status != 1 || offResponse.product == null) {
      return null;
    }

    final p = offResponse.product!;
    final offNameClean = PriceSearchUtils.cleanProductTitle(p.productName, brand: p.brands);
    var product = OffProduct(
      barcode: cleanBarcode,
      productName: offNameClean.isNotEmpty ? offNameClean : 'Producto sin nombre',
      imageUrl: p.imageUrl,
      ingredientsText: p.ingredientsText,
      brands: p.brands,
      nutriscoreGrade: p.nutriscoreGrade,
      novaGroup: p.novaGroup,
      ecoscoreGrade: p.ecoscoreGrade,
      quantity: p.quantity,
      allergensTags: p.allergensTags,
      labelsTags: p.labelsTags,
      nutriments: p.nutriments,
    );

    if (p.imageUrl != null && p.imageUrl!.isNotEmpty) {
      unawaited(_priceRepository.updateProductImage(cleanBarcode, p.imageUrl!));
    } else {
      final crfRes = await CarrefourCatalogService.findProductImage(
        ean: cleanBarcode,
        productTitle: offNameClean,
      );
      if (crfRes != null && crfRes.imageUrl != null && crfRes.imageUrl!.isNotEmpty) {
        unawaited(_priceRepository.updateProductImage(cleanBarcode, crfRes.imageUrl!));
        product = OffProduct(
          barcode: cleanBarcode,
          productName: (product.productName != null && product.productName!.isNotEmpty)
              ? product.productName
              : crfRes.productName,
          imageUrl: crfRes.imageUrl,
          ingredientsText: p.ingredientsText,
          brands: product.brands ?? crfRes.brand,
          nutriscoreGrade: p.nutriscoreGrade,
          novaGroup: p.novaGroup,
          ecoscoreGrade: p.ecoscoreGrade,
          quantity: p.quantity,
          allergensTags: p.allergensTags,
          labelsTags: p.labelsTags,
          nutriments: p.nutriments,
        );
      }
    }

    return product;
  }

  Future<bool> uploadProductImage(String barcode, File imageFile) async {
    return _offService.uploadProductImage(
      barcode: barcode,
      imageFile: imageFile,
    );
  }
}
