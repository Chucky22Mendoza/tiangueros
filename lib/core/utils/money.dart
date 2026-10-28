import 'package:intl/intl.dart';

/// Utilidades monetarias.
///
/// Regla crítica (§37): **todo monto se guarda como `int` en centavos.**
/// `double` no se usa para aritmética monetaria en ninguna parte del código.
abstract final class Money {
  const Money._();

  /// Formatea centavos como moneda legible: `$150.00`, `$1,250.50`.
  static String format(int cents, {String symbol = r'$'}) {
    final NumberFormat f = NumberFormat.currency(
      locale: 'es_MX',
      symbol: symbol,
      decimalDigits: 2,
    );
    return f.format(cents / 100);
  }

  /// Formato compacto para cards: `$2,450`, `$1.2k`, `$15k`.
  ///
  /// El escalado va con `num`, nunca con el `String` que devuelve
  /// `toStringAsFixed`: `NumberFormat.format` pide `num` y si le llega un
  /// `String` truena adentro con `NoSuchMethodError: 'String' has no getter
  /// isNegative` al partir el número. Con eso reventaba toda etiqueta de la
  /// gráfica de reportes desde $1,000 en adelante.
  static String formatCompact(int cents, {String symbol = r'$'}) {
    final double value = cents.abs() / 100;
    final NumberFormat f = NumberFormat.decimalPattern('es_MX');
    final String sign = cents < 0 ? '-' : '';
    if (value >= 1000000) {
      return '$sign$symbol${_scaled(f, value / 1000000)}M';
    }
    if (value >= 1000) {
      // $999,999.99 escalado a k daría "$1,000.0k": se sube a M.
      if (value >= 999950) return '$sign$symbol${_scaled(f, value / 1000000)}M';
      return '$sign$symbol${_scaled(f, value / 1000)}k';
    }
    return format(cents, symbol: symbol);
  }

  /// Un decimal, como `num`, en el formato de milares.
  static String _scaled(NumberFormat f, double value) =>
      f.format(double.parse(value.toStringAsFixed(1)));

  /// Sólo la parte entera, sin centavos: `$150`.
  static String formatWhole(int cents, {String symbol = r'$'}) {
    final NumberFormat f = NumberFormat.decimalPattern('es_MX');
    return '$symbol${f.format(cents ~/ 100)}';
  }

  /// Entero con separador de miles para conteos (productos, ventas, días).
  ///
  /// Distinto de [formatWhole]: ahí el número representa pesos y se divide
  /// entre 100; aquí es una cantidad tal cual.
  static String formatUnits(int value) =>
      NumberFormat.decimalPattern('es_MX').format(value);

  /// Convierte texto de usuario a centavos. Acepta `$`, espacios y comas.
  /// Devuelve `null` si no es un número válido.
  static int? tryParseToCents(String raw) {
    String cleaned = raw
        .replaceAll(r'$', '')
        .replaceAll(' ', '')
        .replaceAll(',', '')
        .trim();
    if (cleaned.isEmpty) return null;
    final double? value = double.tryParse(cleaned);
    if (value == null || value.isNaN || value.isInfinite) return null;
    return (value * 100).round();
  }

  /// Igual que [tryParseToCents] pero devuelve 0 en vez de `null`.
  static int parseToCentsOrZero(String raw) => tryParseToCents(raw) ?? 0;

  /// Convierte centavos a texto editable (`150.00`) para precargar campos.
  static String toEditableString(int cents) => (cents / 100).toStringAsFixed(2);

  /// Aplica un porcentaje de descuento a un total en centavos.
  static int discount(int totalCents, num percent) =>
      (totalCents * percent / 100).round();
}
