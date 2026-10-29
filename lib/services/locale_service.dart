import 'package:flutter/foundation.dart';
import '../core/cache/hive_manager.dart';

class LocaleService extends ChangeNotifier {
  static const String _prefKey = 'selected_app_language';

  String _currentLanguage = 'Español';
  String get currentLanguage => _currentLanguage;

  String get languageCode => switch (_currentLanguage) {
        'English' => 'en',
        'Português' => 'pt',
        "Avañe'ẽ" => 'gn',
        _ => 'es',
      };

  LocaleService() {
    _loadLanguage();
  }

  void _loadLanguage() {
    try {
      final saved = HiveManager.getSync<String>(_prefKey);
      if (saved != null && languages.contains(saved)) {
        _currentLanguage = saved;
      }
    } catch (_) {}
  }

  void setLanguage(String lang) {
    if (!languages.contains(lang) || _currentLanguage == lang) return;
    _currentLanguage = lang;
    notifyListeners();
    HiveManager.setSync<String>(_prefKey, lang);
  }

  static const List<String> languages = [
    'Español',
    'English',
    'Português',
    "Avañe'ẽ",
  ];

  /// Traducciones de la app por clave e idioma
  String t(String key, [List<dynamic>? args]) {
    final lang = languageCode;
    var text = _translations[lang]?[key] ?? _translations['es']?[key] ?? key;
    if (args != null && args.isNotEmpty) {
      for (var i = 0; i < args.length; i++) {
        text = text.replaceAll('{$i}', args[i].toString());
      }
    }
    return text;
  }

  /// Traducción del grupo NOVA
  String getNovaDescription(int? group) {
    if (group == null) return t('nova_unknown');
    return switch (group) {
      1 => t('nova_1'),
      2 => t('nova_2'),
      3 => t('nova_3'),
      4 => t('nova_4'),
      _ => t('nova_unknown'),
    };
  }

  /// Traducción del Eco-Score
  String getEcoScoreDescription(String? grade) {
    if (grade == null) return t('ecoscore_unknown');
    return switch (grade.toLowerCase()) {
      'a' => t('ecoscore_a'),
      'b' => t('ecoscore_b'),
      'c' => t('ecoscore_c'),
      'd' => t('ecoscore_d'),
      'e' => t('ecoscore_e'),
      _ => t('ecoscore_unknown'),
    };
  }

  /// Traducción amigable de etiquetas y octógonos
  String formatLabel(String rawTag) {
    final cleaned = rawTag.toLowerCase().replaceAll(RegExp(r'^(es:|en:|fr:)'), '');
    return switch (cleaned) {
      'exceso-azucares' || 'high-sugar' => t('label_excess_sugars'),
      'exceso-grasas-totales' || 'high-fat' => t('label_excess_fats'),
      'exceso-grasas-saturadas' || 'high-saturated-fat' => t('label_excess_sat_fats'),
      'exceso-sodio' || 'high-sodium' => t('label_excess_sodium'),
      'exceso-calorias' || 'high-calories' => t('label_excess_calories'),
      'contiene-edulcorantes' => t('label_sweeteners'),
      'contiene-cafeina' => t('label_caffeine'),
      'sin-tacc' || 'no-gluten' || 'gluten-free' => t('label_sin_tacc'),
      'vegan' || 'vegano' => t('label_vegan'),
      'vegetarian' || 'vegetariano' => t('label_vegetarian'),
      'organic' || 'organico' => t('label_organic'),
      _ => cleaned.replaceAll('-', ' ').toUpperCase(),
    };
  }

  /// Traducción amigable de alérgenos
  String formatAllergen(String rawTag) {
    final cleaned = rawTag.toLowerCase().replaceAll(RegExp(r'^(es:|en:|fr:)'), '');
    return switch (cleaned) {
      'milk' || 'leche' => t('allergen_milk'),
      'eggs' || 'huevos' => t('allergen_eggs'),
      'peanuts' || 'mani' || 'cacahuetes' => t('allergen_peanuts'),
      'soybeans' || 'soja' => t('allergen_soy'),
      'gluten' => t('allergen_gluten'),
      'fish' || 'pescado' => t('allergen_fish'),
      'crustaceans' || 'crustaceos' => t('allergen_crustaceans'),
      'nuts' || 'frutos-secos' => t('allergen_nuts'),
      _ => cleaned.replaceAll('-', ' ').toUpperCase(),
    };
  }

  static const Map<String, Map<String, String>> _translations = {
    'es': {
      'app_title': 'CompraMas',
      'scan_product': 'Escanea un producto',
      'scan_idle_desc': 'Compara precios en supermercados cercanos y descubre opciones más saludables.',
      'start_scanner': 'Iniciar Escáner',
      'scan_another': 'Escanear otro',
      'scan_loading': 'Consultando bases de datos...',
      'product_not_found': 'No pudimos encontrar el producto',
      'retry': 'Reintentar',
      'add_photo': 'Añadir Foto',
      'photo_success': 'Imagen subida a Open Food Facts con éxito.',
      'photo_error': 'Error al subir la imagen.',
      'nutrition_info': 'Información Nutricional (por 100g)',
      'calories': 'Calorías',
      'sugars': 'Azúcares',
      'sat_fat': 'Grasas Sat.',
      'sodium': 'Sodio',
      'healthier_alternatives': 'Alternativas Saludables (Gemini AI)',
      'price_comparison': 'Comparativa de Precios (Supabase)',
      'no_prices_found': 'No se encontraron sucursales con precios registrados para este producto.',
      'best_price': 'MEJOR PRECIO',
      'fallback_notice_title': 'Sugerencia por descripción (código vigente):',
      'indices_title': 'Índices Nutricionales y Ambientales',
      'nutriscore_label': 'Nutri-Score',
      'nova_label': 'Grupo NOVA',
      'ecoscore_label': 'Eco-Score',
      'nova_1': 'Alimento no procesado o mínimamente procesado',
      'nova_2': 'Ingrediente culinario procesado',
      'nova_3': 'Alimento procesado',
      'nova_4': 'Alimento ultraprocesado',
      'nova_unknown': 'Nivel de procesamiento no determinado',
      'ecoscore_a': 'Impacto ambiental muy bajo',
      'ecoscore_b': 'Impacto ambiental bajo',
      'ecoscore_c': 'Impacto ambiental moderado',
      'ecoscore_d': 'Impacto ambiental alto',
      'ecoscore_e': 'Impacto ambiental muy alto',
      'ecoscore_unknown': 'Impacto ambiental no evaluado',
      'warning_seals': 'Sellos de Advertencia y Certificaciones',
      'allergens_alert': 'Alerta de Alérgenos Declarados:',
      'quantity_net': 'Contenido Neto:',
      'label_excess_sugars': 'EXCESO EN AZÚCARES',
      'label_excess_fats': 'EXCESO EN GRASAS TOTALES',
      'label_excess_sat_fats': 'EXCESO EN GRASAS SATURADAS',
      'label_excess_sodium': 'EXCESO EN SODIO',
      'label_excess_calories': 'EXCESO EN CALORÍAS',
      'label_sweeteners': 'CONTIENE EDULCORANTES',
      'label_caffeine': 'CONTIENE CAFEÍNA',
      'label_sin_tacc': 'SIN T.A.C.C. (LIBRE DE GLUTEN)',
      'label_vegan': 'APTO VEGANO',
      'label_vegetarian': 'APTO VEGETARIANO',
      'label_organic': 'ORGÁNICO CERTIFICADO',
      'allergen_milk': 'Leche / Derivados lácteos',
      'allergen_eggs': 'Huevo',
      'allergen_peanuts': 'Maní',
      'allergen_soy': 'Soja',
      'allergen_gluten': 'Gluten',
      'allergen_fish': 'Pescado',
      'allergen_crustaceans': 'Crustáceos',
      'allergen_nuts': 'Frutos Secos',
      'search_radius': 'Radio de búsqueda',
      'search_radius_desc': 'Distancia máxima para comparar precios al escanear',
      'search_radius_km': 'Radio: {0} km',
      'best_price_in_radius': 'Mejor precio en tu radio',
      'prices_within_radius': 'Precios a menos de {0} km a la redonda',
      'no_prices_in_radius': 'No se encontraron precios a menos de {0} km de tu ubicación.',
      'prices_outside_radius': 'Hay {0} precios registrados fuera de este radio.',
      'adjust_radius_hint': 'Puedes ampliar el radio de búsqueda en Ajustes.',
      'search_radius_setting_title': 'Radio de búsqueda (km)',
      'search_radius_setting_desc': 'Buscar sucursales hasta {0} km a la redonda',
    },
    'en': {
      'app_title': 'CompraMas',
      'scan_product': 'Scan a product',
      'scan_idle_desc': 'Compare supermarket prices and discover healthier options.',
      'start_scanner': 'Start Scanner',
      'scan_another': 'Scan another',
      'scan_loading': 'Querying databases...',
      'product_not_found': 'Product not found',
      'retry': 'Retry',
      'add_photo': 'Add Photo',
      'photo_success': 'Image uploaded to Open Food Facts successfully.',
      'photo_error': 'Failed to upload image.',
      'nutrition_info': 'Nutrition Facts (per 100g)',
      'calories': 'Calories',
      'sugars': 'Sugars',
      'sat_fat': 'Sat. Fat',
      'sodium': 'Sodium',
      'healthier_alternatives': 'Healthier Alternatives (Gemini AI)',
      'price_comparison': 'Price Comparison (Supabase)',
      'no_prices_found': 'No stores found with prices for this item.',
      'best_price': 'BEST PRICE',
      'fallback_notice_title': 'Suggested by description (active code):',
      'indices_title': 'Nutritional & Environmental Scores',
      'nutriscore_label': 'Nutri-Score',
      'nova_label': 'NOVA Group',
      'ecoscore_label': 'Eco-Score',
      'nova_1': 'Unprocessed or minimally processed food',
      'nova_2': 'Processed culinary ingredient',
      'nova_3': 'Processed food',
      'nova_4': 'Ultra-processed food',
      'nova_unknown': 'Processing level not determined',
      'ecoscore_a': 'Very low environmental impact',
      'ecoscore_b': 'Low environmental impact',
      'ecoscore_c': 'Moderate environmental impact',
      'ecoscore_d': 'High environmental impact',
      'ecoscore_e': 'Very high environmental impact',
      'ecoscore_unknown': 'Environmental impact not evaluated',
      'warning_seals': 'Warning Seals & Certifications',
      'allergens_alert': 'Declared Allergens Warning:',
      'quantity_net': 'Net Weight / Volume:',
      'label_excess_sugars': 'HIGH IN SUGARS',
      'label_excess_fats': 'HIGH IN TOTAL FAT',
      'label_excess_sat_fats': 'HIGH IN SATURATED FAT',
      'label_excess_sodium': 'HIGH IN SODIUM',
      'label_excess_calories': 'HIGH IN CALORIES',
      'label_sweeteners': 'CONTAINS SWEETENERS',
      'label_caffeine': 'CONTAINS CAFFEINE',
      'label_sin_tacc': 'GLUTEN FREE',
      'label_vegan': 'VEGAN',
      'label_vegetarian': 'VEGETARIAN',
      'label_organic': 'CERTIFIED ORGANIC',
      'allergen_milk': 'Milk / Dairy',
      'allergen_eggs': 'Egg',
      'allergen_peanuts': 'Peanuts',
      'allergen_soy': 'Soybeans',
      'allergen_gluten': 'Gluten',
      'allergen_fish': 'Fish',
      'allergen_crustaceans': 'Crustaceans',
      'allergen_nuts': 'Tree nuts',
      'search_radius': 'Search radius',
      'search_radius_desc': 'Maximum distance to compare prices when scanning',
      'search_radius_km': 'Radius: {0} km',
      'best_price_in_radius': 'Best price within radius',
      'prices_within_radius': 'Prices within {0} km radius',
      'no_prices_in_radius': 'No prices found within {0} km of your location.',
      'prices_outside_radius': '{0} prices available outside this radius.',
      'adjust_radius_hint': 'You can expand the search radius in Settings.',
      'search_radius_setting_title': 'Search radius (km)',
      'search_radius_setting_desc': 'Find branches within {0} km around you',
    },
    'pt': {
      'app_title': 'CompraMas',
      'scan_product': 'Digitalize um produto',
      'scan_idle_desc': 'Compare preços em supermercados e descubra opções mais saudáveis.',
      'start_scanner': 'Iniciar Scanner',
      'scan_another': 'Escanear outro',
      'scan_loading': 'Consultando bancos de dados...',
      'product_not_found': 'Produto não encontrado',
      'retry': 'Tentar novamente',
      'add_photo': 'Adicionar Foto',
      'photo_success': 'Imagem enviada para o Open Food Facts com sucesso.',
      'photo_error': 'Erro ao enviar a imagem.',
      'nutrition_info': 'Informação Nutricional (por 100g)',
      'calories': 'Calorias',
      'sugars': 'Açúcares',
      'sat_fat': 'Gorduras Sat.',
      'sodium': 'Sódio',
      'healthier_alternatives': 'Alternativas Saudáveis (Gemini AI)',
      'price_comparison': 'Comparação de Preços (Supabase)',
      'no_prices_found': 'Nenhum supermercado encontrado com preços para este produto.',
      'best_price': 'MELHOR PREÇO',
      'fallback_notice_title': 'Sugestão por descrição (código ativo):',
      'indices_title': 'Índices Nutricionais e Ambientais',
      'nutriscore_label': 'Nutri-Score',
      'nova_label': 'Grupo NOVA',
      'ecoscore_label': 'Eco-Score',
      'nova_1': 'Alimento não processado ou minimamente processado',
      'nova_2': 'Ingrediente culinário processado',
      'nova_3': 'Alimento processado',
      'nova_4': 'Alimento ultraprocessado',
      'nova_unknown': 'Nível de processamento não determinado',
      'ecoscore_a': 'Impacto ambiental muito baixo',
      'ecoscore_b': 'Impacto ambiental baixo',
      'ecoscore_c': 'Impacto ambiental moderado',
      'ecoscore_d': 'Impacto ambiental alto',
      'ecoscore_e': 'Impacto ambiental muito alto',
      'ecoscore_unknown': 'Impacto ambiental não avaliado',
      'warning_seals': 'Selos de Advertência e Certificados',
      'allergens_alert': 'Alerta de Alérgenos Declarados:',
      'quantity_net': 'Conteúdo Líquido:',
      'label_excess_sugars': 'ALTO EM AÇÚCARES',
      'label_excess_fats': 'ALTO EM GORDURAS TOTAIS',
      'label_excess_sat_fats': 'ALTO EM GORDURAS SATURADAS',
      'label_excess_sodium': 'ALTO EM SÓDIO',
      'label_excess_calories': 'ALTO EM CALORIAS',
      'label_sweeteners': 'CONTÉM ADOÇANTES',
      'label_caffeine': 'CONTÉM CAFEÍNA',
      'label_sin_tacc': 'SEM GLÚTEN',
      'label_vegan': 'APTO VEGANO',
      'label_vegetarian': 'APTO VEGETARIANO',
      'label_organic': 'ORGÂNICO CERTIFICADO',
      'allergen_milk': 'Leite / Laticínios',
      'allergen_eggs': 'Ovos',
      'allergen_peanuts': 'Amendoim',
      'allergen_soy': 'Soja',
      'allergen_gluten': 'Glúten',
      'allergen_fish': 'Peixe',
      'allergen_crustaceans': 'Crustáceos',
      'allergen_nuts': 'Frutos de casca rija',
      'search_radius': 'Raio de busca',
      'search_radius_desc': 'Distância máxima para comparar preços ao digitalizar',
      'search_radius_km': 'Raio: {0} km',
      'best_price_in_radius': 'Melhor preço no seu raio',
      'prices_within_radius': 'Preços a menos de {0} km de distância',
      'no_prices_in_radius': 'Nenhum preço encontrado a menos de {0} km da sua localização.',
      'prices_outside_radius': 'Há {0} preços registrados fora deste raio.',
      'adjust_radius_hint': 'Você pode ampliar o raio de busca em Ajustes.',
      'search_radius_setting_title': 'Raio de busca (km)',
      'search_radius_setting_desc': 'Buscar supermercados até {0} km ao seu redor',
    },
    'gn': {
      'app_title': 'CompraMas',
      'scan_product': 'Ehesa’ỹijo tembi’u',
      'scan_idle_desc': 'Embojoja repykue ñemuha guasúpe ha ejuhu tembi’u tesãirã.',
      'start_scanner': 'Eñepyrũ Escáner',
      'scan_another': 'Ehesa’ỹijo ambue',
      'scan_loading': 'Oheka base de datos-pe...',
      'product_not_found': 'Ndojejuhúi ko tembi’u',
      'retry': 'Eha’ã jey',
      'add_photo': 'Emoĩ Ta’anga',
      'photo_success': 'Ta’anga ojupi porã Open Food Facts-pe.',
      'photo_error': 'Ojavy ojehupívo ta’anga.',
      'nutrition_info': 'Marandu Tesãirã (100g rehe)',
      'calories': 'Calorías',
      'sugars': 'Asuka',
      'sat_fat': 'Kyra Sat.',
      'sodium': 'Juky (Sodio)',
      'healthier_alternatives': 'Tembi’u Tesãirãve (Gemini AI)',
      'price_comparison': 'Repykue Ñembojoja (Supabase)',
      'no_prices_found': 'Ndojejuhúi ñemuha orekóva ko tembi’u repykue.',
      'best_price': 'HEPYKUE IPORÃVÉVA',
      'fallback_notice_title': 'Ñehesa’ỹijo réra rupive (código oikóva):',
      'indices_title': 'Mba’e rechaukaha Tesãirã ha Tekohápe',
      'nutriscore_label': 'Nutri-Score',
      'nova_label': 'Aty NOVA',
      'ecoscore_label': 'Eco-Score',
      'nova_1': 'Tembi’u noñemboykévai térã sa’i oñembopyahúva',
      'nova_2': 'Tembi’u apo rehegua oñembopyahúva',
      'nova_3': 'Tembi’u oñembopyahúva',
      'nova_4': 'Tembi’u hetaiterei oñembopyahúva (ultraprocesado)',
      'nova_unknown': 'Ndojekuaái mboýpa oñembopyahu',
      'ecoscore_a': 'Tekoha jeiko sa’i ombyai',
      'ecoscore_b': 'Tekoha sa’i ombyai',
      'ecoscore_c': 'Tekoha mbyte ombyai',
      'ecoscore_d': 'Tekoha heta ombyai',
      'ecoscore_e': 'Tekoha hetaiterei ombyai',
      'ecoscore_unknown': 'Ndojeikuaái tekoha rehegua',
      'warning_seals': 'Marandu Kuatia ha Ñeñangareko',
      'allergens_alert': 'Marandu Alérgenos rehegua:',
      'quantity_net': 'Hetakue tee:',
      'label_excess_sugars': 'HETAITERI ASUKA',
      'label_excess_fats': 'HETAITERI KYRA',
      'label_excess_sat_fats': 'HETAITERI KYRA HYKÚVA',
      'label_excess_sodium': 'HETAITERI JUKY',
      'label_excess_calories': 'HETAITERI CALORÍAS',
      'label_sweeteners': 'OREKO EDULCORANTE',
      'label_caffeine': 'OREKO CAFEÍNA',
      'label_sin_tacc': 'T.A.C.C. ILIBRE (GLUTEN ỸRE)',
      'label_vegan': 'VEGANO-PE GUARÃ',
      'label_vegetarian': 'VEGETARIANO-PE GUARÃ',
      'label_organic': 'ORGÁNICO TEETE',
      'allergen_milk': 'Kamby / Kamby rehegua',
      'allergen_eggs': 'Rupia’a',
      'allergen_peanuts': 'Mandi’o / Manduvi',
      'allergen_soy': 'Soja',
      'allergen_gluten': 'Gluten',
      'allergen_fish': 'Pira',
      'allergen_crustaceans': 'Crustáceos',
      'allergen_nuts': 'Yva aky / Frutos secos',
      'search_radius': 'Jepoka pukukue',
      'search_radius_desc': 'Mombyrykue tuichavéva embojoja hag̃ua repykue',
      'search_radius_km': 'Pukukue: {0} km',
      'best_price_in_radius': 'Repykue iporãvéva ne pukukuépe',
      'prices_within_radius': 'Repykuéra {0} km ryepýpe',
      'no_prices_in_radius': 'Ndojejuhúi repykue {0} km ryepýpe ne rendágui.',
      'prices_outside_radius': 'Oĩ {0} repykue ko pukukue okápe.',
      'adjust_radius_hint': 'Ikatu embohetave jepoka pukukue Mba’eapópe.',
      'search_radius_setting_title': 'Jepoka pukukue (km)',
      'search_radius_setting_desc': 'Eheka ñemuha {0} km ne jerére',
    },
  };
}
