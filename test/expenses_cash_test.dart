import 'package:flutter_test/flutter_test.dart';
import 'package:tianguis_control/core/database/app_database.dart';
import 'package:tianguis_control/core/errors/app_exception.dart';
import 'package:tianguis_control/models/cash_movement.dart';
import 'package:tianguis_control/models/enums.dart';
import 'package:tianguis_control/models/expense.dart';
import 'package:tianguis_control/models/sale.dart';
import 'package:tianguis_control/repositories/cash_repository.dart';
import 'package:tianguis_control/repositories/expense_repository.dart';

import 'helpers.dart';

/// Gastos (§23) y caja (§28), las dos áreas que §50 pedía y que no tenían
/// ningún test: los gastos aparecen de refilón en otras pruebas y la caja no se
/// probaba en absoluto, siendo la que sostiene el cuadre del día.
void main() {
  late ExpenseRepository expenses;
  late CashRepository cash;

  DateTime hoy({int hour = 12}) {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour);
  }

  setUp(() async {
    await openTestDatabase();
    expenses = ExpenseRepository();
    cash = CashRepository();
  });

  // --- Gastos (§23) ---

  group('Gastos', () {
    test('crea y valida concepto, monto y categoría', () async {
      final Expense e = await expenses.create(
        concept: '  Cuota del tianguis  ',
        category: 'Cuota del tianguis',
        amount: 15000,
        notes: '  Semana 38  ',
      );

      expect(e.id, isNotEmpty);
      expect(e.concept, 'Cuota del tianguis', reason: 'sin espacios sueltos');
      expect(e.notes, 'Semana 38');
      expect(AppDatabase.expenses.get(e.id), isNotNull);

      await expectLater(
        expenses.create(concept: '  ', category: 'Otro', amount: 100),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        expenses.create(concept: 'X', category: 'Otro', amount: 0),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        expenses.create(concept: 'X', category: '  ', amount: 100),
        throwsA(isA<ValidationException>()),
      );
    });

    test('un gasto en efectivo mueve la caja; una transferencia no', () async {
      final Expense efectivo = await expenses.create(
        concept: 'Bolsas',
        category: 'Bolsas',
        amount: 2500,
      );
      expect(_movimientoDe(efectivo.id), isNotNull);
      expect(_movimientoDe(efectivo.id)!.type, CashMovementType.gasto);
      expect(cash.expectedCashToday(), -2500);

      // Una transferencia no salió de la bolsa, no debe tocar la caja.
      final Expense transferencia = await expenses.create(
        concept: 'Transferencia luz',
        category: 'Transferencia',
        amount: 80000,
      );
      expect(transferencia.affectsCash, isFalse);
      expect(_movimientoDe(transferencia.id), isNull);
      expect(cash.expectedCashToday(), -2500);
    });

    test('editar un gasto resincroniza su movimiento sin duplicarlo', () async {
      final Expense e = await expenses.create(
        concept: 'Transporte',
        category: 'Transporte',
        amount: 3000,
      );
      expect(cash.expectedCashToday(), -3000);

      e.amount = 5000;
      e.concept = 'Transporteida';
      await expenses.update(e);

      final List<CashMovement> propios = AppDatabase.cash.values
          .where((CashMovement m) => m.referenceId == e.id)
          .toList();
      expect(propios.length, 1, reason: 'no debe quedar el movimiento viejo');
      expect(propios.first.amount, 5000);
      expect(propios.first.concept, 'Transporteida');
      expect(cash.expectedCashToday(), -5000);
    });

    test('borrar un gasto se lleva su movimiento de caja', () async {
      final Expense e = await expenses.create(
        concept: 'Comida',
        category: 'Comida',
        amount: 1200,
      );
      await expenses.delete(e.id);

      expect(AppDatabase.expenses.get(e.id), isNull);
      expect(_movimientoDe(e.id), isNull);
      expect(cash.expectedCashToday(), 0);
    });

    test('los totales respetan el rango y la categoría', () async {
      final DateTime hoy10 = hoy(hour: 10);
      final DateTime ayer = DateTime.now().subtract(const Duration(days: 1));

      await expenses.create(
        concept: 'A',
        category: 'Transporte',
        amount: 1000,
        date: hoy10,
      );
      await expenses.create(
        concept: 'B',
        category: 'Transporte',
        amount: 2000,
        date: hoy10,
      );
      await expenses.create(
        concept: 'C',
        category: 'Comida',
        amount: 5000,
        date: ayer,
      );

      expect(expenses.totalToday(), 3000);
      expect(expenses.totalInRange(ayer, hoy10), 8000);
      expect(expenses.onDay(ayer).single.concept, 'C');
      expect(expenses.totalsByCategory(hoy10, hoy10), <String, int>{
        'Transporte': 3000,
      });
    });

    test('las categorías disponibles traen las del spec más las usadas', () {
      final List<String> cats = expenses.availableCategories;
      expect(
        cats,
        containsAll(<String>[
          'Cuota del tianguis',
          'Transporte',
          'Comida',
          'Bolsas',
          'Mercancía',
          'Publicidad',
          'Otro',
        ]),
        reason: '§23',
      );
    });
  });

  // --- Caja (§28) ---

  group('Caja', () {
    test('el efectivo esperado es fondo + ventas + entradas − salidas − gastos',
        () async {
      await cash.setOpeningFund(10000);
      await cash.recordSale(
        Sale(id: 's1', folio: 'V-000001', total: 2500),
      );
      await cash.recordEntry(700, 'Cambio pedido');
      await cash.recordExit(400, 'Comida del dueño');
      await cash.record(
        type: CashMovementType.gasto,
        amount: 150,
        concept: 'Bolsas',
      );

      expect(cash.expectedCashToday(), 10000 + 2500 + 700 - 400 - 150);
      final CashBreakdown b = cash.breakdownForDay(DateTime.now());
      expect(b.openingFund, 10000);
      expect(b.cashSales, 2500);
      expect(b.entries, 700);
      expect(b.exits, 400);
      expect(b.cashExpenses, 150);
      expect(b.expected, 12650);
    });

    test('el desglose no se lleva movimientos de otro día', () async {
      await cash.setOpeningFund(5000, day: DateTime.now().subtract(
            const Duration(days: 2),
          ));
      await cash.setOpeningFund(1000);

      final CashBreakdown hoy = cash.breakdownForDay(DateTime.now());
      expect(hoy.openingFund, 1000);
      expect(
        cash.breakdownForDay(
          DateTime.now().subtract(const Duration(days: 2)),
        ).openingFund,
        5000,
      );
    });

    test('el fondo inicial es uno por día: repetirlo no duplica la caja',
        () async {
      await cash.setOpeningFund(10000);
      await cash.setOpeningFund(20000);

      expect(cash.breakdownForDay(DateTime.now()).openingFund, 20000);
      expect(
        AppDatabase.cash.values
            .where((CashMovement m) => m.type == CashMovementType.fondoInicial)
            .length,
        1,
      );

      await expectLater(
        cash.setOpeningFund(-1),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        cash.setOpeningFund(0),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rechaza montos cero o negativos', () async {
      await expectLater(
        cash.recordEntry(0, 'Nada'),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        cash.recordExit(-100, 'Salida negativa'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('la diferencia es el efectivo contado contra el esperado', () async {
      await cash.setOpeningFund(10000);
      await cash.recordSale(Sale(id: 's1', folio: 'V-000001', total: 2500));
      final CashBreakdown b = cash.breakdownForDay(DateTime.now());

      expect(b.expected, 12500);
      expect(b.difference(12500), 0);
      expect(b.difference(12300), -200, reason: 'faltan 200 centavos');
      expect(b.difference(13000), 500);
      expect(b.difference(null), 0, reason: 'sin conteo no hay diferencia');
    });

    test('revertir una venta en efectivo saca el dinero y la reabre', () async {
      final Sale venta = Sale(
        id: 's1',
        folio: 'V-000001',
        total: 2500,
        paymentMethod: PaymentMethod.efectivo,
      );
      await cash.recordSale(venta);
      expect(cash.expectedCashToday(), 2500);

      await cash.reverseSale(venta);
      expect(cash.expectedCashToday(), 0);

      await cash.reapplySale(venta);
      expect(cash.expectedCashToday(), 2500);
    });

    test('una venta con tarjeta no toca la caja ni al revertirla', () async {
      final Sale tarjeta = Sale(
        id: 's2',
        folio: 'V-000002',
        total: 9000,
        paymentMethod: PaymentMethod.tarjeta,
      );
      await cash.reverseSale(tarjeta);
      await cash.reapplySale(tarjeta);
      expect(cash.expectedCashToday(), 0);
      expect(AppDatabase.cash.values, isEmpty);
    });

    test('borrar un movimiento devuelve el efectivo al esperado', () async {
      await cash.setOpeningFund(10000);
      final CashMovement e = await cash.recordEntry(3000, 'Vuelto');
      expect(cash.expectedCashToday(), 13000);

      await cash.deleteMovement(e.id);
      expect(cash.expectedCashToday(), 10000);
    });
  });
}

CashMovement? _movimientoDe(String expenseId) {
  for (final CashMovement m in AppDatabase.cash.values) {
    if (m.referenceId == expenseId) return m;
  }
  return null;
}
