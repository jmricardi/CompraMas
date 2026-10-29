/// Entidad que representa un descuento o promoción bancaria/billetera
/// configurable por el usuario y almacenado localmente.
class DiscountEntity {
  final int id;
  final String supermarketName;
  final String dayOfWeek;
  final String paymentMethod;
  final String bank;
  final String bankOrMethod;
  final bool isRecurring;
  final String? validDate; // Formato YYYY-MM-DD para promociones de única vez
  final double percentage;
  final double maxCap; // 0.0 si no tiene tope
  final double minAmount; // 0.0 si no exige monto mínimo
  final bool isActive;

  DiscountEntity({
    this.id = 0,
    required this.supermarketName,
    this.dayOfWeek = 'Todos los días',
    this.paymentMethod = 'Tarjeta de Débito',
    this.bank = '',
    String? bankOrMethod,
    this.isRecurring = true,
    this.validDate,
    required this.percentage,
    this.maxCap = 0.0,
    this.minAmount = 0.0,
    this.isActive = true,
  }) : bankOrMethod = (bankOrMethod != null && bankOrMethod.isNotEmpty)
            ? bankOrMethod
            : (bank.isNotEmpty ? '$bank - $paymentMethod' : paymentMethod);

  DiscountEntity copyWith({
    int? id,
    String? supermarketName,
    String? dayOfWeek,
    String? paymentMethod,
    String? bank,
    String? bankOrMethod,
    bool? isRecurring,
    String? validDate,
    double? percentage,
    double? maxCap,
    double? minAmount,
    bool? isActive,
  }) {
    return DiscountEntity(
      id: id ?? this.id,
      supermarketName: supermarketName ?? this.supermarketName,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      bank: bank ?? this.bank,
      bankOrMethod: bankOrMethod ?? this.bankOrMethod,
      isRecurring: isRecurring ?? this.isRecurring,
      validDate: validDate ?? this.validDate,
      percentage: percentage ?? this.percentage,
      maxCap: maxCap ?? this.maxCap,
      minAmount: minAmount ?? this.minAmount,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != 0) 'id': id,
      'supermarketName': supermarketName,
      'dayOfWeek': dayOfWeek,
      'paymentMethod': paymentMethod,
      'bank': bank,
      'bankOrMethod': bankOrMethod,
      'isRecurring': isRecurring ? 1 : 0,
      'validDate': validDate,
      'percentage': percentage,
      'maxCap': maxCap,
      'minAmount': minAmount,
      'isActive': isActive ? 1 : 0,
    };
  }

  factory DiscountEntity.fromMap(Map<String, dynamic> map) {
    final paymentMethod = (map['paymentMethod'] as String?) ?? 'Tarjeta de Débito';
    final bank = (map['bank'] as String?) ?? '';
    final legacyBankOrMethod = map['bankOrMethod'] as String? ?? '';

    return DiscountEntity(
      id: (map['id'] as int?) ?? 0,
      supermarketName: (map['supermarketName'] as String?) ?? '',
      dayOfWeek: (map['dayOfWeek'] as String?) ?? 'Todos los días',
      paymentMethod: paymentMethod,
      bank: bank,
      bankOrMethod: legacyBankOrMethod.isNotEmpty ? legacyBankOrMethod : null,
      isRecurring: ((map['isRecurring'] as int?) ?? 1) == 1,
      validDate: map['validDate'] as String?,
      percentage: ((map['percentage'] as num?) ?? 0.0).toDouble(),
      maxCap: ((map['maxCap'] as num?) ?? 0.0).toDouble(),
      minAmount: ((map['minAmount'] as num?) ?? 0.0).toDouble(),
      isActive: ((map['isActive'] as int?) ?? 1) == 1,
    );
  }

  static String _normalizeStr(String text) {
    return text
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll('%', '')
        .replaceAll('-', ' ')
        .trim();
  }

  /// Verifica si el descuento aplica al día de la fecha dada (o hoy por defecto).
  bool appliesToday([DateTime? targetDate]) {
    if (!isActive) return false;
    final now = targetDate ?? DateTime.now();

    // 1. Si es promoción de única vez con fecha específica
    if (!isRecurring && validDate != null && validDate!.isNotEmpty) {
      try {
        final parsedDate = DateTime.parse(validDate!);
        return parsedDate.year == now.year &&
            parsedDate.month == now.month &&
            parsedDate.day == now.day;
      } catch (_) {
        return false;
      }
    }

    // 2. Si es recurrente por día de la semana
    final dayNormalized = _normalizeStr(dayOfWeek);
    if (dayNormalized.contains('todos') || dayNormalized.contains('todas')) {
      return true;
    }

    final weekdayNames = [
      'lunes',
      'martes',
      'miercoles',
      'jueves',
      'viernes',
      'sabado',
      'domingo'
    ];
    // DateTime.weekday: 1 es lunes, 7 es domingo
    final currentDayName = weekdayNames[now.weekday - 1];
    return dayNormalized.contains(currentDayName);
  }

  /// Verifica si coincide con el comercio o cadena buscado (insensible a mayúsculas/tildes y multi-marca)
  bool matchesSupermarket(String? querySupermarket) {
    if (querySupermarket == null || querySupermarket.isEmpty) return false;
    final q = _normalizeStr(querySupermarket);
    final s = _normalizeStr(supermarketName);

    if (s == 'todos' || s == 'todas' || s == 'cualquiera' || s.isEmpty) return true;

    final candidates = supermarketName.split(',').map((e) => _normalizeStr(e)).where((e) => e.isNotEmpty);
    for (final cand in candidates) {
      if (cand == 'todos' || cand == 'todas' || cand == 'cualquiera') return true;
      if (q.contains(cand) || cand.contains(q)) return true;
    }

    return q.contains(s) || s.contains(q);
  }

  /// Verifica si el monto cumple con el mínimo requerido para que aplique la promo
  bool satisfiesMinAmount(double amount) {
    if (minAmount <= 0.0) return true;
    return amount >= minAmount;
  }

  /// Calcula el monto de ahorro en pesos sobre el importe dado
  double calculateSavings(double amount) {
    if (!satisfiesMinAmount(amount) || percentage <= 0.0 || amount <= 0.0) {
      return 0.0;
    }

    final rawDiscount = amount * (percentage / 100.0);
    if (maxCap > 0.0 && rawDiscount > maxCap) {
      return maxCap;
    }
    return rawDiscount;
  }

  /// Calcula el precio neto final con el descuento aplicado
  double calculateDiscountedPrice(double originalPrice) {
    final savings = calculateSavings(originalPrice);
    final finalPrice = originalPrice - savings;
    return finalPrice < 0 ? 0.0 : finalPrice;
  }

  /// Lista de bancos/billeteras configurados
  List<String> get banksList {
    if (bank.trim().isEmpty) return const [];
    return bank.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  /// Lista de medios de pago configurados
  List<String> get paymentMethodsList {
    if (paymentMethod.trim().isEmpty) return const [];
    return paymentMethod.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  /// Lista de días configurados
  List<String> get daysList {
    if (dayOfWeek.trim().isEmpty) return const ['Todos los días'];
    return dayOfWeek.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  /// Título resumen para la promo (ej. "20% OFF · MODO Nación")
  String get promoTag {
    final pct = percentage % 1 == 0 ? percentage.toInt().toString() : percentage.toStringAsFixed(1);
    final banks = banksList;
    final methods = paymentMethodsList;

    String entity;
    if (banks.isNotEmpty) {
      if (banks.length == 1 && methods.length <= 1) {
        final b = banks.first;
        final m = methods.isNotEmpty ? methods.first : '';
        entity = (m.isNotEmpty && m != 'Otro') ? '$m $b' : b;
      } else {
        final bankSummary = banks.length > 2
            ? '${banks.take(2).join(', ')} (+${banks.length - 2})'
            : banks.join(', ');

        if (methods.isNotEmpty && !methods.contains('Otro')) {
          final methodSummary = methods.length > 2
              ? '${methods.take(2).join(', ')} (+${methods.length - 2})'
              : methods.join(', ');
          entity = '$bankSummary ($methodSummary)';
        } else {
          entity = bankSummary;
        }
      }
    } else {
      entity = methods.isNotEmpty ? methods.join(', ') : paymentMethod;
    }

    return '$pct% OFF · $entity';
  }
}
