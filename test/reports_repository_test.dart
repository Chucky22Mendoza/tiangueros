import 'package:flutter_test/flutter_test.dart';
import 'package:tianguis_control/core/database/app_database.dart';
import 'package:tianguis_control/models/enums.dart';
import 'package:tianguis_control/models/expense.dart';
import 'package:tianguis_control/models/product.dart';
import 'package:tianguis_control/models/sale.dart';
import 'package:tianguis_control/repositories/reports_repository.dart';

import 'helpers.dart';

/// Escritura directa en las cajas: `checkout` siempre fecha en ahora y para
/// el agrupado hacen falta fechas repartidas.
abstract final class _Put {
  static Future<void> sale(Sale s) => AppDatabase.sales.put(s.id, s);
  static Future<void> expense(Expense e) => AppDatabase.expenses.put(e.id, e);
  static Future<void> product(Product p) => AppDatabase.products.put(p.id, p);
}

/// Reportes: el agrupamiento de la serie (§30) y la foto del inventario.
///
/// Las ventas se escriben directamente en la caja porque `checkout` siempre
/// fecha en `DateTime.now()` y para probar el agrupado semanal y mensual
/// hacen falta fechas repartidas.
void main() {
  late ReportsRepository reports;

  setUp(() async {
    await openTestDatabase();
    reports = ReportsRepository();
  });

  Sale venta({
    required DateTime date,
    int total = 1000,
    int profit = 300,
    SaleStatus status = SaleStatus.activa,
  }) => Sale(
    id: 's-${date.microsecondsSinceEpoch}-$total',
    folio: 'V-${date.microsecondsSinceEpoch}',
    total: total,
    costTotal: total - profit,
    profit: profit,
    date: date,
    status: status,
  );

  group('Serie de la gráfica', () {
    test('agrupa por día, con una barra por día del rango', () async {
      final DateTime from = DateTime(2026, 9, 1);
      await _Put.sale(venta(date: DateTime(2026, 9, 1, 10), total: 500));
      await _Put.sale(
        venta(date: DateTime(2026, 9, 1, 18), total: 250),
      );
      await _Put.sale(
        venta(date: DateTime(2026, 9, 3, 12), total: 1000),
      );

      final List<TimePoint> s = reports.series(
        from,
        DateTime(2026, 9, 5),
        granularity: SeriesGranularity.diario,
      );

      expect(s.length, 5, reason: 'del 1 al 5, aunque no haya venta');
      expect(s.first.revenue, 750, reason: 'las dos ventas del día 1 suman');
      expect(s[1].revenue, 0);
      expect(s[2].revenue, 1000);
      expect(s[3].revenue, 0);
    });

    test('agrupa por semana en lunes, aunque el rango empiece en domingo', () async {
      // Domingo 30/08, lunes 31/08 y jueves 3/09 caen en semanas distintas.
      await _Put.sale(venta(date: DateTime(2026, 8, 30, 12), total: 100));
      await _Put.sale(venta(date: DateTime(2026, 8, 31, 9), total: 200));
      await _Put.sale(venta(date: DateTime(2026, 9, 3, 9), total: 400));

      final List<TimePoint> s = reports.series(
        DateTime(2026, 8, 30),
        DateTime(2026, 9, 6),
        granularity: SeriesGranularity.semanal,
      );

      expect(s.length, 2, reason: 'dos semanas: 24/08 y 31/08');
      expect(s[0].date, DateTime(2026, 8, 24), reason: 'lunes de arranque');
      expect(
        s[0].revenue,
        100,
        reason: 'el domingo 30 cierra la semana del lunes 24',
      );
      expect(s[1].date, DateTime(2026, 8, 31));
      expect(
        s[1].revenue,
        600,
        reason: 'el lunes abre semana nueva: 200 del lunes + 400 del jueves',
      );
    });

    test('agrupa por mes y respeta el cambio de año', () async {
      await _Put.sale(venta(date: DateTime(2026, 9, 2), total: 700));
      await _Put.sale(venta(date: DateTime(2026, 9, 28), total: 300));
      await _Put.sale(venta(date: DateTime(2026, 10, 1), total: 900));

      final List<TimePoint> s = reports.series(
        DateTime(2026, 9, 1),
        DateTime(2026, 10, 31),
        granularity: SeriesGranularity.mensual,
      );

      expect(s.length, 2);
      expect(s[0].date, DateTime(2026, 9), reason: 'empieza el mes, no el día');
      expect(s[0].revenue, 1000);
      expect(s[1].date, DateTime(2026, 10));
      expect(s[1].revenue, 900);
    });

    test('los gastos caen en el cubo que les toca', () async {
      await _Put.sale(venta(date: DateTime(2026, 9, 1), total: 500));
      await _Put.expense(
        Expense(
          id: 'e1',
          concept: 'Cuota',
          category: 'Cuota del tianguis',
          amount: 120,
          date: DateTime(2026, 9, 1, 8),
        ),
      );
      await _Put.expense(
        Expense(
          id: 'e2',
          concept: 'Bolsas',
          category: 'Bolsas',
          amount: 80,
          date: DateTime(2026, 9, 2, 8),
        ),
      );

      final List<TimePoint> diaria = reports.series(
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 2),
      );
      expect(diaria[0].expenses, 120);
      expect(diaria[1].expenses, 80);

      final List<TimePoint> mensual = reports.series(
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 30),
        granularity: SeriesGranularity.mensual,
      );
      expect(mensual.single.expenses, 200, reason: 'septiembre completo');
    });

    test('las ventas canceladas y devueltas no llegan a la gráfica', () async {
      await _Put.sale(venta(date: DateTime(2026, 9, 1), total: 500));
      await _Put.sale(
        venta(date: DateTime(2026, 9, 1), total: 900, status: SaleStatus.cancelada),
      );
      await _Put.sale(
        venta(date: DateTime(2026, 9, 1), total: 700, status: SaleStatus.devuelta),
      );

      final List<TimePoint> s = reports.series(
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 1),
      );
      expect(s.single.revenue, 500);
    });
  });

  group('Foto del inventario', () {
    setUp(() async {
      await _Put.product(
        Product(id: 'ok', name: 'Refresco', cost: 1000, price: 1500, stock: 50, minStock: 5),
      );
      await _Put.product(
        Product(id: 'bajo1', name: 'Gorra', cost: 2000, price: 3000, stock: 2, minStock: 5),
      );
      await _Put.product(
        Product(id: 'bajo2', name: 'Cachucha', cost: 2000, price: 3000, stock: 4, minStock: 5),
      );
      await _Put.product(
        Product(id: 'out', name: 'Playera', cost: 8000, price: 15000, stock: 0, minStock: 5),
      );
      await _Put.product(
        Product(id: 'inactivo', name: 'Retirado', cost: 100, price: 200, stock: 99, minStock: 5, active: false),
      );
    });

    test('cuenta valor, stock bajo y agotados, sin los inactivos', () {
      final InventoryReport r = reports.inventoryReport();

      expect(r.totalProducts, 4, reason: 'el inactivo no cuenta');
      expect(r.lowStock, 2);
      expect(r.outOfStock, 1);
      expect(r.needsAttention, isTrue);
      // 50×1000 + 2×2000 + 4×2000 + 0×8000
      expect(r.inventoryValue, 62000);
    });

    test('lista primero lo que se acaba y respeta el límite', () async {
      await _Put.product(
        Product(id: 'out2', name: 'Botella', cost: 100, price: 200, stock: 0, minStock: 5),
      );
      await _Put.product(
        Product(id: 'out3', name: 'Vaso', cost: 100, price: 200, stock: 0, minStock: 5),
      );

      final InventoryReport r = reports.inventoryReport(limit: 2);

      expect(r.outOfStock, 3);
      expect(r.outOfStockProducts.length, 2, reason: 'respeta el límite');
      expect(
        r.lowStockProducts.map((Product p) => p.id).toList(),
        <String>['bajo1', 'bajo2'],
        reason: 'del más urgente al menos: 2 antes que 4',
      );
    });

    test('un inventario sano no pide atención', () async {
      await AppDatabase.products.clear();
      await _Put.product(
        Product(id: 'sano', name: 'Refresco 2L', cost: 1000, price: 2000, stock: 99, minStock: 5),
      );

      final InventoryReport r = reports.inventoryReport();
      expect(r.needsAttention, isFalse);
      expect(r.lowStock, 0);
      expect(r.outOfStock, 0);
      expect(r.inventoryValue, 99000);
      expect(r.lowStockProducts, isEmpty);
      expect(r.outOfStockProducts, isEmpty);
    });
  });
}
