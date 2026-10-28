import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/dates.dart';
import '../models/cash_movement.dart';
import '../models/enums.dart';
import '../models/expense.dart';
import '../models/sale.dart';

/// Cuadre de caja: fondo inicial, ventas en efectivo, entradas, salidas y
/// gastos (§28).
///
/// `Efectivo esperado` = fondo inicial + entradas + ventas en efectivo
/// − salidas − gastos en efectivo.
class CashRepository {
  CashRepository();

  static const Uuid _uuid = Uuid();

  Stream<List<CashMovement>> watchAll() async* {
    // `box.watch()` no emite el estado actual; sin este yield inicial la caja
    // se queda cargando con la base vacía.
    yield all();
    yield* AppDatabase.cash.watch().map((BoxEvent _) => all());
  }

  List<CashMovement> all() => AppDatabase.cash.values.toList(growable: false);

  List<CashMovement> onDay(DateTime day) {
    final DateTime from = Dates.startOfDay(day);
    final DateTime to = Dates.endOfDay(day);
    final List<CashMovement> list = AppDatabase.cash.values
        .where((CashMovement m) => !m.date.isBefore(from) && !m.date.isAfter(to))
        .toList()
      ..sort((CashMovement a, CashMovement b) => b.date.compareTo(a.date));
    return list;
  }

  Iterable<CashMovement> lazyInRange(DateTime from, DateTime to) =>
      AppDatabase.cash.values.where(
        (CashMovement m) => !m.date.isBefore(from) && !m.date.isAfter(to),
      );

  // --- Movimientos ---

  Future<CashMovement> record({
    required CashMovementType type,
    required int amount,
    String concept = '',
    String? referenceId,
  }) async {
    if (amount <= 0) {
      throw const ValidationException('El monto debe ser mayor a cero');
    }
    final CashMovement movement = CashMovement(
      id: _uuid.v4(),
      type: type,
      amount: amount,
      concept: concept.trim().isEmpty ? type.label : concept.trim(),
      referenceId: referenceId,
    );
    await AppDatabase.cash.put(movement.id, movement);
    return movement;
  }

  Future<CashMovement> recordSale(Sale sale) => record(
    type: CashMovementType.venta,
    amount: sale.total,
    concept: 'Venta ${sale.folio}',
    referenceId: sale.id,
  );

  Future<CashMovement> recordExpense(Expense expense) => record(
    type: CashMovementType.gasto,
    amount: expense.amount,
    concept: expense.concept,
    referenceId: expense.id,
  );

  /// Fondo inicial del día. Sólo uno por fecha: repetirlo duplicaría la caja.
  Future<CashMovement> setOpeningFund(int amount, {DateTime? day}) async {
    if (amount < 0) {
      throw const ValidationException('El monto no puede ser negativo');
    }
    final DateTime target = day ?? DateTime.now();
    final String key = _openingFundKey(target);
    final CashMovement? existing = AppDatabase.cash.get(key);
    if (existing != null) {
      await AppDatabase.cash.delete(key);
    }
    if (amount == 0) {
      throw const ValidationException('El monto debe ser mayor a cero');
    }
    final CashMovement movement = CashMovement(
      id: key,
      type: CashMovementType.fondoInicial,
      amount: amount,
      concept: 'Fondo inicial',
      date: Dates.startOfDay(target),
    );
    await AppDatabase.cash.put(key, movement);
    return movement;
  }

  Future<CashMovement> recordEntry(int amount, String concept) =>
      record(
        type: CashMovementType.entrada,
        amount: amount,
        concept: concept,
      );

  Future<CashMovement> recordExit(int amount, String concept) =>
      record(
        type: CashMovementType.salida,
        amount: amount,
        concept: concept,
      );

  Future<void> deleteMovement(String id) => AppDatabase.cash.delete(id);

  /// Da de baja los movimientos generados por una venta (al cancelarla).
  Future<void> reverseSale(Sale sale) async {
    if (sale.paymentMethod != PaymentMethod.efectivo || sale.total <= 0) {
      return;
    }
    final List<String> ids = AppDatabase.cash.values
        .where(
          (CashMovement m) =>
              m.referenceId == sale.id && m.type == CashMovementType.venta,
        )
        .map((CashMovement m) => m.id)
        .toList();
    await AppDatabase.cash.deleteAll(ids);
  }

  /// Vuelve a crear el movimiento de efectivo al reabrir una venta cancelada.
  Future<void> reapplySale(Sale sale) async {
    if (sale.paymentMethod != PaymentMethod.efectivo || sale.total <= 0) {
      return;
    }
    await reverseSale(sale);
    await recordSale(sale);
  }

  // --- Cuadre ---

  /// Efectivo esperado en un rango.
  int expectedCash(DateTime from, DateTime to) {
    return lazyInRange(from, to).fold<int>(
      0,
      (int sum, CashMovement m) => sum + m.signedAmount,
    );
  }

  int expectedCashToday() => expectedCash(
    Dates.startOfDay(DateTime.now()),
    Dates.endOfDay(DateTime.now()),
  );

  /// Desglose de la caja de hoy para la pantalla de Control de caja.
  CashBreakdown breakdownForDay(DateTime day) {
    final DateTime from = Dates.startOfDay(day);
    final DateTime to = Dates.endOfDay(day);

    int opening = 0;
    int sales = 0;
    int entries = 0;
    int exits = 0;
    int expenses = 0;

    for (final CashMovement m in lazyInRange(from, to)) {
      switch (m.type) {
        case CashMovementType.fondoInicial:
          opening += m.amount;
        case CashMovementType.venta:
          sales += m.amount;
        case CashMovementType.entrada:
          entries += m.amount;
        case CashMovementType.salida:
          exits += m.amount;
        case CashMovementType.gasto:
          expenses += m.amount;
      }
    }

    return CashBreakdown(
      openingFund: opening,
      cashSales: sales,
      entries: entries,
      exits: exits,
      cashExpenses: expenses,
    );
  }

  static String _openingFundKey(DateTime day) =>
      'opening-${Dates.dayKey(day)}';
}

/// Resultado del cuadre de caja de un día.
class CashBreakdown {
  const CashBreakdown({
    this.openingFund = 0,
    this.cashSales = 0,
    this.entries = 0,
    this.exits = 0,
    this.cashExpenses = 0,
  });

  final int openingFund;
  final int cashSales;
  final int entries;
  final int exits;
  final int cashExpenses;

  int get expected => openingFund + cashSales + entries - exits - cashExpenses;

  /// Diferencia contra el efectivo contado.
  int difference(int? counted) => counted == null ? 0 : counted - expected;
}
