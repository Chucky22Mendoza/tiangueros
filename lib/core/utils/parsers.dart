/// Parsers tolerantes para importación de CSV/JSON.
///
/// El importador nunca debe fallar por un campo mal formado: registra el
/// error de esa fila y continúa con las demás (§33).
abstract final class Parsers {
  const Parsers._();

  static String asString(Object? value, {String fallback = ''}) {
    if (value == null) return fallback;
    final String s = value.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  /// Entero cents-safe: acepta `$1,250.50`, `1250`, `80.5`.
  static int? asCents(Object? value) {
    if (value is int) return value * 100;
    if (value is double) return (value * 100).round();
    if (value is String) {
      final int? cents = _centsFromString(value);
      if (cents != null) return cents;
    }
    return null;
  }

  static int asCentsOrZero(Object? value) => asCents(value) ?? 0;

  /// Cantidad de stock: admite decimales (0.5) y separador coma.
  static double? asDouble(Object? value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.trim().replaceAll(',', '.'));
    }
    return null;
  }

  static double asDoubleOrZero(Object? value) => asDouble(value) ?? 0;

  /// Booleanos: `true`, `1`, `sí`, `si`, `x`, `activo`, `verdadero`.
  static bool asBool(Object? value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final String v = value.trim().toLowerCase();
      if (const <String>{
        'true', '1', 'si', 'sí', 'x', 'activo', 'verdadero', 'yes',
      }.contains(v)) {
        return true;
      }
      if (const <String>{
        'false', '0', 'no', 'inactivo', 'falso',
      }.contains(v)) {
        return false;
      }
    }
    return fallback;
  }

  /// ISO-8601 o `dd/MM/yyyy`. Devuelve `null` si no parsea.
  static DateTime? asDate(Object? value) {
    if (value is DateTime) return value;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is! String) return null;
    final String v = value.trim();
    if (v.isEmpty) return null;
    final DateTime? iso = DateTime.tryParse(v);
    if (iso != null) return iso;
    final RegExpMatch? m = RegExp(
      r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})',
    ).firstMatch(v);
    if (m != null) {
      return DateTime(
        int.parse(m.group(3)!),
        int.parse(m.group(2)!),
        int.parse(m.group(1)!),
      );
    }
    return null;
  }

  static DateTime asDateOrNow(Object? value) => asDate(value) ?? DateTime.now();

  /// Normaliza un encabezado de CSV: sin acentos, minúsculas, `_` por espacio.
  static String normalizeKey(String raw) {
    const Map<String, String> accents = <String, String>{
      'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'é': 'e', 'è': 'e', 'ë': 'e',
      'ê': 'e', 'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i', 'ó': 'o', 'ò': 'o',
      'ö': 'o', 'ô': 'o', 'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u', 'ñ': 'n',
      'ç': 'c',
    };
    final StringBuffer out = StringBuffer();
    for (final int code in raw.toLowerCase().trim().runes) {
      final String s = String.fromCharCode(code);
      out.write(accents[s] ?? s);
    }
    return out.toString().replaceAll(RegExp(r'[\s\-]+'), '_');
  }

  static int? _centsFromString(String raw) {
    final String cleaned = raw
        .replaceAll(r'$', '')
        .replaceAll(' ', '')
        .replaceAll(',', '')
        .trim();
    if (cleaned.isEmpty) return null;
    final double? value = double.tryParse(cleaned);
    if (value == null || value.isNaN || value.isInfinite) return null;
    return (value * 100).round();
  }
}
