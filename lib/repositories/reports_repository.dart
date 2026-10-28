import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';
import '../core/utils/dates.dart';
import '../models/daily_closing.dart';
import '../models/expense.dart';
import '../models/product.dart';
import '../models/enums.dart';
import '../models/profit_summary.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';

/// Una venta a lo largo del tiempo, para las gráficas de fl_chart (§30).
class TimePoint {
  const TimePoint(this.date, this.revenue, this.profit, this.expenses);

  final DateTime date;
  final int revenue;
  final int profit;
  final int expenses;
}

/// Ranking de un producto en un periodo (§30).
class ProductRank {
  const ProductRank({
    required this.productId,
    required this.name,
    required this.units,
    required this.revenue,
    required this.profit,
  });

  final String? productId;
  final String name;
  final int units;
  final int revenue;
  final int profit;
}

/// Rango seleccionable en reportes (§24).
enum ReportRange {
  hoy('Hoy'),
  sieteDias('7 días'),
  treintaDias('30 días'),
  mesActual('Mes actual'),
  personalizado('Personalizado');

  const ReportRange(this.label);

  final String label;

  /// Resuelve el rango a fechas concretas.
  (DateTime, DateTime) resolve({DateTime? from, DateTime? to, DateTime? now}) {
    final DateTime ref = now ?? DateTime.now();
    return switch (this) {
      ReportRange.hoy => (Dates.startOfDay(ref), Dates.endOfDay(ref)),
      ReportRange.sieteDias => (
        Dates.startOfDay(ref.subtract(const Duration(days: 6))),
        Dates.endOfDay(ref),
      ),
      ReportRange.treintaDias => (
        Dates.startOfDay(ref.subtract(const Duration(days: 29))),
        Dates.endOfDay(ref),
      ),
      ReportRange.mesActual => (
        Dates.startOfMonth(ref),
        Dates.endOfDay(ref),
      ),
      ReportRange.personalizado => (
        Dates.startOfDay(from ?? ref.subtract(const Duration(days: 6))),
        Dates.endOfDay(to ?? ref),
      ),
    };
  }
}

/// Agregaciones para el Dashboard y la pantalla de Reportes.
///
/// Todas las iteraciones son perezosas sobre `Box.values`, así que el volumen
/// objetivo de 10,000 ventas / 50,000 líneas no se carga completo en memoria
/// (§49).
class ReportsRepository {
  ReportsRepository();

  static const Uuid _uuid = Uuid();

  // --- Ventas ---

  /// Ingresos − costo de mercancía − gastos del rango (§24).
  ///
  /// Los gastos entran aquí y no en cada pantalla: si los resta quien arma la
  /// tarjeta, alguno se olvida y termina enseñando la ganancia bruta con la
  /// etiqueta de neta. `netProfit` ya viene con la cuenta hecha.
  ProfitSummary summaryForRange(DateTime from, DateTime to) {
    int revenue = 0;
    int cost = 0;
    int count = 0;
    int items = 0;
    final Map<PaymentMethod, int> byMethod = <PaymentMethod, int>{};

    for (final Sale s in AppDatabase.sales.values) {
      if (s.date.isBefore(from) || s.date.isAfter(to)) continue;
      if (!s.countsInStats) continue;
      revenue += s.total;
      cost += s.costTotal;
      count++;
      items += s.itemCount;
      byMethod[s.paymentMethod] = (byMethod[s.paymentMethod] ?? 0) + s.total;
    }

    return ProfitSummary(
      revenue: revenue,
      costOfGoods: cost,
      expenses: expensesInRange(from, to),
      salesCount: count,
      itemsSold: items,
      byPaymentMethod: byMethod,
    );
  }

  /// Total de gastos del rango, en centavos.
  int expensesInRange(DateTime from, DateTime to) => AppDatabase.expenses.values
      .where((Expense e) => !e.date.isBefore(from) && !e.date.isAfter(to))
      .fold<int>(0, (int sum, Expense e) => sum + e.amount);

  /// Snapshot del día para las cards del Dashboard (§12, §13).
  DashboardSnapshot todaySnapshot({DateTime? now}) {
    final DateTime ref = now ?? DateTime.now();
    final DateTime from = Dates.startOfDay(ref);
    final DateTime to = Dates.endOfDay(ref);

    final ProfitSummary sales = summaryForRange(from, to);
    final int expenses = sales.expenses;

    final InventoryReport inventory = inventoryReport();

    return DashboardSnapshot(
      revenue: sales.revenue,
      estimatedProfit: sales.grossProfit,
      itemsSold: sales.itemsSold,
      expenses: expenses,
      salesCount: sales.salesCount,
      totalProducts: inventory.totalProducts,
      lowStock: inventory.lowStock,
      outOfStock: inventory.outOfStock,
      inventoryValue: inventory.inventoryValue,
    );
  }

  /// Foto del inventario para la sección de Reportes (§30).
  ///
  /// El inventario no es un rango sino un estado: siempre el de hoy, con o sin
  /// filtro de fechas. Por eso el Dashboard y Reportes leen los mismos números
  /// desde aquí en lugar de recorrer la caja cada uno por su lado.
  InventoryReport inventoryReport({int limit = 5}) {
    int total = 0;
    int low = 0;
    int out = 0;
    int value = 0;
    final List<Product> lowList = <Product>[];
    final List<Product> outList = <Product>[];

    for (final Product p in AppDatabase.products.values) {
      if (!p.active) continue;
      total++;
      value += p.inventoryValue;
      switch (p.stockState) {
        case StockState.agotado:
          out++;
          outList.add(p);
        case StockState.stockBajo:
          low++;
          lowList.add(p);
        case StockState.disponible:
          break;
      }
    }

    // Lo más urgente arriba: primero lo que se acaba, luego lo que se acaba
    // primero.
    outList.sort((Product a, Product b) => a.stock.compareTo(b.stock));
    lowList.sort((Product a, Product b) => a.stock.compareTo(b.stock));

    return InventoryReport(
      totalProducts: total,
      lowStock: low,
      outOfStock: out,
      inventoryValue: value,
      lowStockProducts: lowList.take(limit).toList(growable: false),
      outOfStockProducts: outList.take(limit).toList(growable: false),
    );
  }

  /// Serie para la gráfica de barras, agrupada por día, semana o mes (§30).
  List<TimePoint> series(
    DateTime from,
    DateTime to, {
    SeriesGranularity granularity = SeriesGranularity.diario,
  }) {
    final Map<String, TimePoint> buckets = <String, TimePoint>{};

    // `to` suele venir a medianoche (inicio del día); sin estirarlo a su fin,
    // todo lo que pasó después se saldría de la gráfica en silencio.
    final DateTime toEnd = Dates.endOfDay(to);
    final DateTime last = Dates.startOfDay(to);
    for (DateTime start = granularity.bucketStart(from);
        !start.isAfter(last);
        start = granularity.advance(start)) {
      buckets[granularity.bucketKey(start)] = TimePoint(start, 0, 0, 0);
    }

    for (final Sale s in AppDatabase.sales.values) {
      if (s.date.isBefore(from) || s.date.isAfter(toEnd)) continue;
      if (!s.countsInStats) continue;
      final String key = granularity.bucketKey(s.date);
      final TimePoint? base = buckets[key];
      if (base == null) continue;
      buckets[key] = TimePoint(
        base.date,
        base.revenue + s.total,
        base.profit + s.profit,
        base.expenses,
      );
    }

    for (final Expense e in AppDatabase.expenses.values) {
      if (e.date.isBefore(from) || e.date.isAfter(toEnd)) continue;
      final String key = granularity.bucketKey(e.date);
      final TimePoint? base = buckets[key];
      if (base == null) continue;
      buckets[key] = TimePoint(
        base.date,
        base.revenue,
        base.profit,
        base.expenses + e.amount,
      );
    }

    final List<String> keys = buckets.keys.toList()..sort();
    return keys.map((String k) => buckets[k]!).toList(growable: false);
  }

  /// Ventas por método de pago, para la gráfica de torta (§30).
  Map<PaymentMethod, int> paymentBreakdown(DateTime from, DateTime to) {
    final Map<PaymentMethod, int> out = <PaymentMethod, int>{};
    for (final Sale s in AppDatabase.sales.values) {
      if (s.date.isBefore(from) || s.date.isAfter(to)) continue;
      if (!s.countsInStats) continue;
      out[s.paymentMethod] = (out[s.paymentMethod] ?? 0) + s.total;
    }
    return out;
  }

  // --- Productos ---

  /// Ranking por unidades vendidas, facturación o ganancia (§30).
  List<ProductRank> rankProducts(
    DateTime from,
    DateTime to, {
    ProductRankMetric metric = ProductRankMetric.unidades,
    int limit = 10,
  }) {
    final Map<String, ProductRank> acc = <String, ProductRank>{};

    for (final Sale s in AppDatabase.sales.values) {
      if (s.date.isBefore(from) || s.date.isAfter(to)) continue;
      if (!s.countsInStats) continue;
      for (final SaleItem item in s.items) {
        final String key = item.productId ?? 'quick:${item.productName}';
        final ProductRank? base = acc[key];
        acc[key] = ProductRank(
          productId: item.productId,
          name: item.productName,
          units: (base?.units ?? 0) + item.quantity,
          revenue: (base?.revenue ?? 0) + item.lineTotal,
          profit: (base?.profit ?? 0) + item.lineProfit,
        );
      }
    }

    final List<ProductRank> list = acc.values.toList();
    list.sort((ProductRank a, ProductRank b) {
      final int cmp = switch (metric) {
        ProductRankMetric.unidades => b.units.compareTo(a.units),
        ProductRankMetric.facturacion => b.revenue.compareTo(a.revenue),
        ProductRankMetric.ganancia => b.profit.compareTo(a.profit),
      };
      return cmp != 0 ? cmp : a.name.compareTo(b.name);
    });
    return list.length > limit ? list.sublist(0, limit) : list;
  }

  // --- Cierres (§29) ---

  DailyClosing buildClosing({DateTime? day}) {
    final DateTime ref = day ?? DateTime.now();
    final DateTime from = Dates.startOfDay(ref);
    final DateTime to = Dates.endOfDay(ref);

    final ProfitSummary sales = summaryForRange(from, to);
    final int expenses = sales.expenses;

    final Map<PaymentMethod, int> byMethod = sales.byPaymentMethod;
    final int grossProfit = sales.revenue - sales.costOfGoods;

    return DailyClosing(
      id: '',
      date: from,
      salesCount: sales.salesCount,
      itemsSold: sales.itemsSold,
      cashTotal: byMethod[PaymentMethod.efectivo] ?? 0,
      transferTotal: byMethod[PaymentMethod.transferencia] ?? 0,
      cardTotal: byMethod[PaymentMethod.tarjeta] ?? 0,
      otherTotal: byMethod[PaymentMethod.otro] ?? 0,
      total: sales.revenue,
      costTotal: sales.costOfGoods,
      grossProfit: grossProfit,
      expensesTotal: expenses,
      netProfit: grossProfit - expenses,
    );
  }

  Future<DailyClosing> saveClosing(DailyClosing closing) async {
    final DailyClosing toSave = DailyClosing(
      id: closing.id.isEmpty ? _uuid.v4() : closing.id,
      date: closing.date,
      salesCount: closing.salesCount,
      itemsSold: closing.itemsSold,
      cashTotal: closing.cashTotal,
      transferTotal: closing.transferTotal,
      cardTotal: closing.cardTotal,
      otherTotal: closing.otherTotal,
      total: closing.total,
      costTotal: closing.costTotal,
      grossProfit: closing.grossProfit,
      expensesTotal: closing.expensesTotal,
      netProfit: closing.netProfit,
      countedCash: closing.countedCash,
      closingNote: closing.closingNote,
    );
    await AppDatabase.closings.put(toSave.id, toSave);
    return toSave;
  }

  List<DailyClosing> closings({int limit = 30}) {
    final List<DailyClosing> list = AppDatabase.closings.values.toList()
      ..sort((DailyClosing a, DailyClosing b) => b.date.compareTo(a.date));
    return list.length > limit ? list.sublist(0, limit) : list;
  }

  DailyClosing? closingForDay(DateTime day) {
    final String key = Dates.dayKey(day);
    for (final DailyClosing c in AppDatabase.closings.values) {
      if (Dates.dayKey(c.date) == key) return c;
    }
    return null;
  }

  Future<void> deleteClosing(String id) => AppDatabase.closings.delete(id);
}

/// Cada cuánto se agrupa la serie de la gráfica (§30).
enum SeriesGranularity {
  diario('Diario'),
  semanal('Semanal'),
  mensual('Mensual');

  const SeriesGranularity(this.label);

  final String label;

  /// Inicio del cubo que contiene a [d].
  DateTime bucketStart(DateTime d) => switch (this) {
    SeriesGranularity.diario => Dates.startOfDay(d),
    SeriesGranularity.semanal => Dates.startOfWeek(d),
    SeriesGranularity.mensual => Dates.startOfMonth(d),
  };

  /// Siguiente cubo a partir del inicio de uno.
  DateTime advance(DateTime start) => switch (this) {
    SeriesGranularity.diario => start.add(const Duration(days: 1)),
    SeriesGranularity.semanal => start.add(const Duration(days: 7)),
    SeriesGranularity.mensual => DateTime(start.year, start.month + 1),
  };

  /// Clave de agrupación; las ventas caen en el cubo que las contiene.
  String bucketKey(DateTime d) => bucketStart(d).toIso8601String();
}

/// Criterio de orden del ranking de productos.
enum ProductRankMetric {
  unidades('Más vendidos'),
  facturacion('Mayor facturación'),
  ganancia('Mayor ganancia');

  const ProductRankMetric(this.label);

  final String label;
}

/// Lo que el Dashboard necesita en una sola pasada (§12, §13).
class DashboardSnapshot {
  const DashboardSnapshot({
    this.revenue = 0,
    this.estimatedProfit = 0,
    this.itemsSold = 0,
    this.expenses = 0,
    this.salesCount = 0,
    this.totalProducts = 0,
    this.lowStock = 0,
    this.outOfStock = 0,
    this.inventoryValue = 0,
  });

  final int revenue;
  final int estimatedProfit;
  final int itemsSold;
  final int expenses;
  final int salesCount;
  final int totalProducts;
  final int lowStock;
  final int outOfStock;
  final int inventoryValue;

  bool get hasData => salesCount > 0 || totalProducts > 0;
}

/// Estado del inventario y los productos que necesitan atención (§30).
class InventoryReport {
  const InventoryReport({
    this.totalProducts = 0,
    this.lowStock = 0,
    this.outOfStock = 0,
    this.inventoryValue = 0,
    this.lowStockProducts = const <Product>[],
    this.outOfStockProducts = const <Product>[],
  });

  final int totalProducts;
  final int lowStock;
  final int outOfStock;

  /// Suma de `costo × stock` de los productos activos.
  final int inventoryValue;

  /// Los primeros [limit] con poco stock, del más urgente al menos.
  final List<Product> lowStockProducts;

  /// Los primeros [limit] agotados.
  final List<Product> outOfStockProducts;

  bool get needsAttention => lowStock > 0 || outOfStock > 0;
}
