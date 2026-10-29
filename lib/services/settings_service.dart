import 'package:flutter/foundation.dart';
import '../core/cache/hive_manager.dart';

class SettingsService extends ChangeNotifier {
  static const String _prefRadiusKey = 'search_radius_km';
  static const String _prefPostalCodeKey = 'user_postal_code';
  static const String _prefPromosKey = 'show_promotional_prices';
  static const String _prefSearchTagsKey = 'recent_search_tags';
  static const String _prefTagVariedadKey = 'pref_show_tag_variedad';
  static const String _prefTagPresentacionKey = 'pref_show_tag_presentacion';
  static const String _prefTagMarcaKey = 'pref_show_tag_marca';
  static const String _prefTagEnvaseKey = 'pref_show_tag_envase';
  static const String _prefFontScaleKey = 'pref_font_scale';
  static const String _prefFontSizeKey = 'pref_font_size';
  static const double defaultSearchRadiusKm = 1.0;
  static const double minFontScale = 0.85;
  static const double maxFontScale = 1.35;
  static const double stepFontScale = 0.08;

  // Rango absoluto de tamaño de fuente: 12.0 dp a 26.0 dp con saltos de 2.0 dp
  static const double minFontSize = 12.0;
  static const double maxFontSize = 26.0;
  static const double stepFontSize = 2.0;
  static const double defaultFontSize = 16.0;

  static const List<String> defaultQuickTags = [
    'Leche',
    'Aceite',
    'Arroz',
    'Fideos',
    'Yerba',
    'Galletitas',
    'Azúcar',
    'Café',
  ];

  double _searchRadiusKm = defaultSearchRadiusKm;
  double get searchRadiusKm => _searchRadiusKm;

  String _postalCode = '';
  String get postalCode => _postalCode;

  double _fontSize = defaultFontSize;
  double get fontSize => _fontSize;

  double _fontScale = 1.0;
  double get fontScale => _fontScale;

  bool _showPromotionalPrices = false;
  bool get showPromotionalPrices => _showPromotionalPrices;

  List<String> _recentSearchTags = [...defaultQuickTags];
  List<String> get recentSearchTags => List.unmodifiable(_recentSearchTags);

  // Visibilidad de etiquetas en búsqueda (por defecto variedad y contenido activos)
  bool _showVariedadTag = true;
  bool get showVariedadTag => _showVariedadTag;

  bool _showPresentacionTag = true;
  bool get showPresentacionTag => _showPresentacionTag;

  bool _showMarcaTag = false;
  bool get showMarcaTag => _showMarcaTag;

  bool _showEnvaseTag = false;
  bool get showEnvaseTag => _showEnvaseTag;

  SettingsService() {
    _loadSettings();
  }

  void _loadSettings() {
    try {
      final savedRadius = HiveManager.getSync<double>(_prefRadiusKey);
      if (savedRadius != null && savedRadius > 0) {
        _searchRadiusKm = savedRadius;
      }
      final savedPostalCode = HiveManager.getSync<String>(_prefPostalCodeKey);
      if (savedPostalCode != null) {
        _postalCode = savedPostalCode;
      }
      final savedFontSize = HiveManager.getSync<double>(_prefFontSizeKey);
      if (savedFontSize != null) {
        _fontSize = savedFontSize.clamp(minFontSize, maxFontSize);
        _fontScale = (_fontSize / defaultFontSize * 100).round() / 100.0;
      } else {
        final savedFontScale = HiveManager.getSync<double>(_prefFontScaleKey);
        if (savedFontScale != null) {
          _fontScale = savedFontScale.clamp(minFontScale, maxFontScale);
          _fontSize = ((defaultFontSize * _fontScale) / 2.0).round() * 2.0;
        }
      }
      final savedPromos = HiveManager.getSync<bool>(_prefPromosKey);
      if (savedPromos != null) {
        _showPromotionalPrices = savedPromos;
      }
      final savedTags = HiveManager.getSync<List<dynamic>>(_prefSearchTagsKey);
      if (savedTags != null && savedTags.isNotEmpty) {
        _recentSearchTags = savedTags.cast<String>();
      }

      final savedVar = HiveManager.getSync<bool>(_prefTagVariedadKey);
      if (savedVar != null) {
        _showVariedadTag = savedVar;
      }
      final savedPres = HiveManager.getSync<bool>(_prefTagPresentacionKey);
      if (savedPres != null) {
        _showPresentacionTag = savedPres;
      }
      final savedMarca = HiveManager.getSync<bool>(_prefTagMarcaKey);
      if (savedMarca != null) {
        _showMarcaTag = savedMarca;
      }
      final savedEnv = HiveManager.getSync<bool>(_prefTagEnvaseKey);
      if (savedEnv != null) {
        _showEnvaseTag = savedEnv;
      }
    } catch (e) {
      debugPrint('[SettingsService] Error al cargar configuración desde Hive: $e');
    }
  }

  void increaseFontScale() {
    if (_fontSize >= maxFontSize) return;
    final nextSize = (_fontSize + stepFontSize).clamp(minFontSize, maxFontSize);
    if (nextSize == _fontSize) return;
    _fontSize = nextSize;
    _fontScale = (_fontSize / defaultFontSize * 100).round() / 100.0;
    notifyListeners();
    HiveManager.setSync<double>(_prefFontSizeKey, _fontSize);
    HiveManager.setSync<double>(_prefFontScaleKey, _fontScale);
  }

  void decreaseFontScale() {
    if (_fontSize <= minFontSize) return;
    final nextSize = (_fontSize - stepFontSize).clamp(minFontSize, maxFontSize);
    if (nextSize == _fontSize) return;
    _fontSize = nextSize;
    _fontScale = (_fontSize / defaultFontSize * 100).round() / 100.0;
    notifyListeners();
    HiveManager.setSync<double>(_prefFontSizeKey, _fontSize);
    HiveManager.setSync<double>(_prefFontScaleKey, _fontScale);
  }

  void addSearchTag(String tag) {
    final clean = tag.trim();
    if (clean.length < 2 || RegExp(r'^\d+$').hasMatch(clean)) return;

    final formatted = clean[0].toUpperCase() + clean.substring(1);
    _recentSearchTags.removeWhere((t) => t.toLowerCase() == formatted.toLowerCase());
    _recentSearchTags.insert(0, formatted);
    if (_recentSearchTags.length > 8) {
      _recentSearchTags = _recentSearchTags.sublist(0, 8);
    }
    notifyListeners();
    HiveManager.setSync<List<String>>(_prefSearchTagsKey, _recentSearchTags);
  }

  void setShowPromotionalPrices(bool value) {
    if (_showPromotionalPrices == value) return;
    _showPromotionalPrices = value;
    notifyListeners();
    HiveManager.setSync<bool>(_prefPromosKey, value);
  }

  void setSearchRadiusKm(double km) {
    if (km <= 0 || _searchRadiusKm == km) return;
    _searchRadiusKm = km;
    notifyListeners();
    HiveManager.setSync<double>(_prefRadiusKey, km);
  }

  void setPostalCode(String cp) {
    final clean = cp.trim();
    if (_postalCode == clean) return;
    _postalCode = clean;
    notifyListeners();
    HiveManager.setSync<String>(_prefPostalCodeKey, clean);
  }

  void setShowVariedadTag(bool value) {
    if (_showVariedadTag == value) return;
    _showVariedadTag = value;
    notifyListeners();
    HiveManager.setSync<bool>(_prefTagVariedadKey, value);
  }

  void setShowPresentacionTag(bool value) {
    if (_showPresentacionTag == value) return;
    _showPresentacionTag = value;
    notifyListeners();
    HiveManager.setSync<bool>(_prefTagPresentacionKey, value);
  }

  void setShowMarcaTag(bool value) {
    if (_showMarcaTag == value) return;
    _showMarcaTag = value;
    notifyListeners();
    HiveManager.setSync<bool>(_prefTagMarcaKey, value);
  }

  void setShowEnvaseTag(bool value) {
    if (_showEnvaseTag == value) return;
    _showEnvaseTag = value;
    notifyListeners();
    HiveManager.setSync<bool>(_prefTagEnvaseKey, value);
  }

  static const List<double> presetRadii = [0.5, 1.0, 2.0, 3.0, 5.0, 10.0];
}
