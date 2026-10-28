import 'package:flutter_test/flutter_test.dart';
import 'package:tianguis_control/core/database/app_database.dart';
import 'package:tianguis_control/core/errors/app_exception.dart';
import 'package:tianguis_control/models/enums.dart';
import 'package:tianguis_control/models/cash_movement.dart';
import 'package:tianguis_control/models/daily_closing.dart';
import 'package:tianguis_control/models/inventory_movement.dart';
import 'package:tianguis_control/models/profit_summary.dart';
import 'package:tianguis_control/models/product.dart';
import 'package:tianguis_control/models/sale.dart';
import 'package:tianguis_control/repositories/expense_repository.dart';
import 'package:tianguis_control/repositories/inventory_repository.dart';
import 'package:tianguis_control/repositories/product_repository.dart';
import 'package:tianguis_control/repositories/reports_repository.dart';
import 'package:tianguis_control/repositories/sales_repository.dart';

import 'helpers.dart';

/// Cubre las tres áreas que la especificación §50 pide y que estaban sin
/// ningún test: márgenes, devoluciones y cierre diario.
void main() {
  late SalesRepository sales;
  late ReportsRepository reports;

  CartLine lineaDe(Product p, {int cantidad = 1}) => CartLine(
    productId: p.id,
    productName: p.name,
    unitCost: p.cost,
    unitPrice: p.price,
    quantity: cantidad,
    availableStock: p.stock,
  );

  Future<Product> producto({
    String name = 'Refresco',
    int cost = 1000,
    int price = 1500,
    double stock = 100,
  }) => ProductRepository().create(
    name: name,
    cost: cost,
    price: price,
    stock: stock,
  );

  setUp(() async {
    await openTestDatabase();
    sales = SalesRepository(InventoryRepository());
    reports = ReportsRepository();
  });

  // --- Márgenes (§19) ---

  group('Márgenes', () {
    test('ganancia y margen del producto salen de precio y costo', () {
      final Product p = Product(cost: 8000, price: 15000);
      expect(p.profit, 7000);
      expect(p.marginPercent, closeTo(46.6, 0.1));

      // vender por debajo del costo es pérdida, no margen negativo raro
      final Product bajo = Product(cost: 15000, price: 12000);
      expect(bajo.profit, -3000);
      expect(bajo.marginPercent, closeTo(-25, 0.01));
    });

    test('un producto sin precio no revienta el margen', () {
      final Product p = Product(cost: 8000, price: 0);
      expect(p.marginPercent, 0);
      expect(p.profit, -8000);
    });

    test('el descuento se come el margen de la venta', () async {
      final Product p = await producto(cost: 10000, price: 20000);
      // 2 piezas = $400.00, costo $200.00
      final SaleResult r = await sales.checkout(
        lines: <CartLine>[lineaDe(p, cantidad: 2)],
        paymentMethod: PaymentMethod.efectivo,
        discount: 10000,
      );

      expect(r.sale.subtotal, 40000);
      expect(r.sale.discount, 10000);
      expect(r.sale.total, 30000);
      expect(r.sale.profit, 10000, reason: '30,000 - 20,000 de costo');
    });

    test('el resumen del rango calcula el margen neto', () async {
      await producto(name: 'A', cost: 5000, price: 10000);
      final Product b = await producto(name: 'B', cost: 5000, price: 20000);
      await sales.checkout(
        lines: <CartLine>[lineaDe(b)],
        paymentMethod: PaymentMethod.efectivo,
      );
      await ExpenseRepository().create(
        concept: 'Transporte',
        category: 'Transporte',
        amount: 5000,
        date: DateTime.now(),
      );

      final (DateTime from, DateTime to) = _hoy();
      final ProfitSummary s = reports.summaryForRange(from, to);
      expect(s.revenue, 20000);
      expect(s.grossProfit, 15000);
      expect(s.netProfit, 10000);
      expect(s.netMarginPercent, closeTo(50, 0.01));
    });
  });

  // --- Devoluciones (§27) ---

  group('Devoluciones', () {
    test('devolver devuelve el stock y deja movimiento de devolución', () async {
      final Product p = await producto(stock: 10);
      final SaleResult r = await sales.checkout(
        lines: <CartLine>[lineaDe(p, cantidad: 4)],
        paymentMethod: PaymentMethod.efectivo,
      );
      expect(AppDatabase.products.get(p.id)!.stock, 6);

      await sales.returnSale(r.sale.id);

      expect(AppDatabase.products.get(p.id)!.stock, 10);
      final movements = AppDatabase.movements.values
          .where((InventoryMovement m) => m.referenceId == r.sale.id)
          .toList();
      expect(movements.length, greaterThanOrEqualTo(2));
      expect(
        movements.any((InventoryMovement m) => m.type == MovementType.devolucion),
        isTrue,
      );
    });

    test('la venta devuelta queda fuera de las estadísticas', () async {
      final Product p = await producto();
      final SaleResult r = await sales.checkout(
        lines: <CartLine>[lineaDe(p)],
        paymentMethod: PaymentMethod.tarjeta,
      );
      final (DateTime from, DateTime to) = _hoy();
      expect(reports.summaryForRange(from, to).revenue, 1500);

      final Sale devuelta = await sales.returnSale(r.sale.id);

      expect(devuelta.status, SaleStatus.devuelta);
      expect(devuelta.countsInStats, isFalse);
      expect(devuelta.returnedAt, isNotNull);
      // la venta no se borra: el historial manda
      expect(AppDatabase.sales.get(r.sale.id), isNotNull);
      expect(reports.summaryForRange(from, to).revenue, 0);
    });

    test('devolver en efectivo saca el dinero de la caja', () async {
      final Product p = await producto();
      final SaleResult r = await sales.checkout(
        lines: <CartLine>[lineaDe(p, cantidad: 2)],
        paymentMethod: PaymentMethod.efectivo,
      );
      expect(AppDatabase.cash.values.where((CashMovement m) =>
          m.referenceId == r.sale.id).length, 1);

      await sales.returnSale(r.sale.id);

      expect(
        AppDatabase.cash.values
            .where((CashMovement m) => m.referenceId == r.sale.id)
            .length,
        0,
      );
    });

    test('no se puede devolver dos veces ni una venta inexistente', () async {
      final Product p = await producto();
      final SaleResult r = await sales.checkout(
        lines: <CartLine>[lineaDe(p)],
        paymentMethod: PaymentMethod.efectivo,
      );
      await sales.returnSale(r.sale.id);

      expect(
        () => sales.returnSale(r.sale.id),
        throwsA(isA<ConflictException>()),
      );
      expect(
        () => sales.returnSale('no-existe'),
        throwsA(isA<StorageException>()),
      );
    });

    test('devolver no libera el folio (§38)', () async {
      final Product p = await producto();
      final SaleResult r = await sales.checkout(
        lines: <CartLine>[lineaDe(p)],
        paymentMethod: PaymentMethod.efectivo,
      );
      expect(r.folio, 'V-000001');

      await sales.returnSale(r.sale.id);

      final SaleResult siguiente = await sales.checkout(
        lines: <CartLine>[lineaDe(p)],
        paymentMethod: PaymentMethod.efectivo,
      );
      expect(siguiente.folio, 'V-000002');
    });
  });

  // --- Cierre diario (§29) ---

  group('Cierre diario', () {
    test('el cierre cuadra ventas, gastos y utilidad del día', () async {
      final Product p = await producto(cost: 10000, price: 20000);
      await sales.checkout(
        lines: <CartLine>[lineaDe(p, cantidad: 2)],
        paymentMethod: PaymentMethod.efectivo,
      );
      await sales.checkout(
        lines: <CartLine>[lineaDe(p)],
        paymentMethod: PaymentMethod.tarjeta,
      );
      await ExpenseRepository().create(
        concept: 'Bolsas',
        category: 'Insumos',
        amount: 5000,
        date: DateTime.now(),
      );

      final DailyClosing c = reports.buildClosing();

      expect(c.salesCount, 2);
      expect(c.itemsSold, 3);
      expect(c.cashTotal, 40000);
      expect(c.cardTotal, 20000);
      expect(c.total, 60000);
      expect(c.costTotal, 30000);
      expect(c.grossProfit, 30000);
      expect(c.expensesTotal, 5000);
      expect(c.netProfit, 25000);
    });

    test('un día sin ventas cierra en cero, no en negativo', () async {
      final DailyClosing c = reports.buildClosing(
        day: DateTime.now().subtract(const Duration(days: 3)),
      );
      expect(c.salesCount, 0);
      expect(c.total, 0);
      expect(c.netProfit, 0);
    });

    test('el cierre se guarda con id y sale en el historial', () async {
      final Product p = await producto();
      await sales.checkout(
        lines: <CartLine>[lineaDe(p)],
        paymentMethod: PaymentMethod.efectivo,
      );
      final DailyClosing built = reports.buildClosing();
      final DailyClosing saved = await reports.saveClosing(
        DailyClosing(
          id: '',
          date: built.date,
          salesCount: built.salesCount,
          total: built.total,
          netProfit: built.netProfit,
          countedCash: built.cashTotal,
          closingNote: 'Caja cuadrada',
        ),
      );

      expect(saved.id, isNotEmpty);
      expect(saved.countedCash, 1500);
      final List<DailyClosing> historial = reports.closings();
      expect(historial.length, 1);
      expect(historial.first.closingNote, 'Caja cuadrada');
      expect(AppDatabase.closings.get(saved.id), isNotNull);
    });
  });
}

(DateTime, DateTime) _hoy() {
  final DateTime now = DateTime.now();
  return (
    DateTime(now.year, now.month, now.day),
    DateTime(now.year, now.month, now.day, 23, 59, 59),
  );
}
