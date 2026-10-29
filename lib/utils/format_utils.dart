import 'package:intl/intl.dart';

class AppFormatters {
  static final NumberFormat _priceNumberFormatter = NumberFormat('#,##0.00', 'es_AR');
  static final NumberFormat _decimalFormatter1 = NumberFormat('#,##0.0', 'es_AR');
  static final NumberFormat _integerFormatter = NumberFormat('#,##0', 'es_AR');

  /// Formatea un valor monetario como "$ 1.250,50"
  static String currency(double value, {bool showSymbol = true}) {
    final formatted = _priceNumberFormatter.format(value);
    return showSymbol ? '\$ $formatted' : formatted;
  }

  /// Formatea una distancia en metros a "450 m" o "1,2 km"
  static String distance(double? meters) {
    if (meters == null) return '';
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    final km = meters / 1000.0;
    return '${_decimalFormatter1.format(km)} km';
  }

  /// Formatea un porcentaje como "15,5%" o "+15,5%"
  static String percentage(double value, {bool includePlus = false}) {
    final formatted = _decimalFormatter1.format(value);
    if (includePlus && value > 0) {
      return '+$formatted%';
    }
    return '$formatted%';
  }

  /// Formatea un decimal con coma
  static String decimal(double value, {int decimals = 1}) {
    if (decimals == 0) {
      return _integerFormatter.format(value);
    }
    final formatter = NumberFormat(
      '#,##0.${'0' * decimals}',
      'es_AR',
    );
    return formatter.format(value);
  }
}
