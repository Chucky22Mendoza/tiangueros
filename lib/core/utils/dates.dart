/// Helpers de fecha. Todo el almacenamiento es UTC ISO-8601; la presentación
/// usa zona local y formato `es_MX`.
abstract final class Dates {
  const Dates._();

  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Clave `YYYY-MM-DD` usada para agrupar ventas por día en reportes.
  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Inicio del mes calendario actual.
  static DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month);

  static DateTime startOfWeek(DateTime d) {
    // Semana iniciada en lunes.
    final DateTime day = startOfDay(d);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  /// `28/09/2026`
  static String formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// `03:42 PM`
  static String formatTime(DateTime d) {
    final int hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final String amPm = d.hour < 12 ? 'AM' : 'PM';
    return '${hour12.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')} $amPm';
  }

  /// `28/09/2026 03:42 PM`
  static String formatDateTime(DateTime d) =>
      '${formatDate(d)} ${formatTime(d)}';

  /// Etiqueta corta de eje para gráficas: `28 sep`
  static String formatChartLabel(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_monthShort(d.month)}';

  /// `Hoy`, `Ayer`, o `28/09/2026`.
  static String relativeDay(DateTime d, {DateTime? now}) {
    final DateTime ref = now ?? DateTime.now();
    if (isSameDay(d, ref)) return 'Hoy';
    if (isSameDay(d, ref.subtract(const Duration(days: 1)))) return 'Ayer';
    return formatDate(d);
  }

  /// Saludo según la hora local (§11).
  static String greeting({DateTime? now}) {
    final int h = (now ?? DateTime.now()).hour;
    if (h < 12) return 'Buenos días';
    if (h < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  static const List<String> _months = <String>[
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  static String _monthShort(int month) => _months[month - 1];

  /// Nombre de mes para encabezados: `Septiembre 2026`.
  static String monthTitle(DateTime d) {
    const List<String> full = <String>[
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
    ];
    return '${full[d.month - 1]} ${d.year}';
  }
}
