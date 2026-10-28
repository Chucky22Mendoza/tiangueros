import 'enums.dart';

/// Resumen de un periodo: ingresos, costos, gastos y utilidad (§24).
///
/// Desacoplado de Hive para poder testearlo sin base de datos.
class ProfitSummary {
  const ProfitSummary({
    this.revenue = 0,
    this.costOfGoods = 0,
    this.expenses = 0,
    this.salesCount = 0,
    this.itemsSold = 0,
    this.byPaymentMethod = const <PaymentMethod, int>{},
  });

  final int revenue;
  final int costOfGoods;
  final int expenses;
  final int salesCount;
  final int itemsSold;

  /// Reparto de ingresos por método de pago.
  final Map<PaymentMethod, int> byPaymentMethod;

  /// Ingresos - Costo de mercancía (§24)
  int get grossProfit => revenue - costOfGoods;

  /// Ganancia bruta - Gastos (§24)
  int get netProfit => grossProfit - expenses;

  /// Ganancia / Ingresos * 100
  double get netMarginPercent => revenue == 0 ? 0 : netProfit / revenue * 100;

  int totalFor(PaymentMethod method) => byPaymentMethod[method] ?? 0;

  static const ProfitSummary empty = ProfitSummary();

  ProfitSummary merge(ProfitSummary other) => ProfitSummary(
    revenue: revenue + other.revenue,
    costOfGoods: costOfGoods + other.costOfGoods,
    expenses: expenses + other.expenses,
    salesCount: salesCount + other.salesCount,
    itemsSold: itemsSold + other.itemsSold,
    byPaymentMethod: _mergeMaps(byPaymentMethod, other.byPaymentMethod),
  );

  static Map<PaymentMethod, int> _mergeMaps(
    Map<PaymentMethod, int> a,
    Map<PaymentMethod, int> b,
  ) {
    final Map<PaymentMethod, int> out = Map<PaymentMethod, int>.of(a);
    b.forEach((PaymentMethod k, int v) {
      out[k] = (out[k] ?? 0) + v;
    });
    return out;
  }
}
