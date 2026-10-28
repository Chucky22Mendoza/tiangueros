import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/app_constants.dart';
import '../core/database/app_database.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/dates.dart';
import '../models/cash_movement.dart';
import '../models/enums.dart';
import '../models/expense.dart';

/// Gastos del puesto: cuota, transporte, comida, bolsas, mercancía… (§23).
class ExpenseRepository {
  ExpenseRepository();

  static const Uuid _uuid = Uuid();

  Stream<List<Expense>> watchAll() async* {
    // `box.watch()` no emite el estado actual; sin este yield inicial la
    // pantalla de gastos se queda cargando con la base vacía.
    yield all();
    yield* AppDatabase.expenses.watch().map((BoxEvent _) => all());
  }

  Stream<List<Expense>> watchRange(DateTime from, DateTime to) async* {
    // Valor inicial antes de los cambios: ver `watchAll`.
    yield expensesInRange(from, to);
    yield* AppDatabase.expenses.watch().map(
      (BoxEvent _) => expensesInRange(from, to),
    );
  }

  List<Expense> all() => AppDatabase.expenses.values.toList(growable: false);

  Expense? byId(String id) => AppDatabase.expenses.get(id);

  List<Expense> recent({int limit = 200}) {
    final List<Expense> list = AppDatabase.expenses.values.toList()
      ..sort((Expense a, Expense b) => b.date.compareTo(a.date));
    return list.length > limit ? list.sublist(0, limit) : list;
  }

  List<Expense> expensesInRange(DateTime from, DateTime to) =>
      lazyInRange(from, to).toList()
        ..sort((Expense a, Expense b) => b.date.compareTo(a.date));

  Iterable<Expense> lazyInRange(DateTime from, DateTime to) =>
      AppDatabase.expenses.values.where(
        (Expense e) => !e.date.isBefore(from) && !e.date.isAfter(to),
      );

  List<Expense> onDay(DateTime day) => expensesInRange(
    Dates.startOfDay(day),
    Dates.endOfDay(day),
  );

  Future<Expense> create({
    required String concept,
    required String category,
    required int amount,
    String notes = '',
    DateTime? date,
  }) async {
    if (concept.trim().isEmpty) {
      throw const ValidationException('El concepto es obligatorio');
    }
    if (amount <= 0) {
      throw const ValidationException('El monto debe ser mayor a cero');
    }
    if (category.trim().isEmpty) {
      throw const ValidationException('La categoría es obligatoria');
    }

    final Expense expense = Expense(
      id: _uuid.v4(),
      concept: concept.trim(),
      category: category.trim(),
      amount: amount,
      notes: notes.trim(),
      date: date ?? DateTime.now(),
    );
    await AppDatabase.expenses.put(expense.id, expense);
    if (expense.affectsCash) {
      await _writeCashMovement(expense);
    }
    return expense;
  }

  /// Editar el gasto ya no revierte caja automáticamente: el movimiento de
  /// caja se ajusta según la diferencia en la caja, no aquí. Para mantener la
  /// caja cuadrada, el movimiento previo se elimina y se vuelve a crear.
  Future<Expense> update(Expense expense) async {
    if (expense.amount <= 0) {
      throw const ValidationException('El monto debe ser mayor a cero');
    }
    if (expense.concept.trim().isEmpty) {
      throw const ValidationException('El concepto es obligatorio');
    }
    await AppDatabase.expenses.put(expense.id, expense);
    await _resyncCashMovement(expense);
    return expense;
  }

  Future<void> delete(String id) async {
    await AppDatabase.cash.delete(_cashMovementId(id));
    await AppDatabase.expenses.delete(id);
  }

  int totalInRange(DateTime from, DateTime to) => lazyInRange(
    from,
    to,
  ).fold<int>(0, (int sum, Expense e) => sum + e.amount);

  int totalToday() => totalInRange(
    Dates.startOfDay(DateTime.now()),
    Dates.endOfDay(DateTime.now()),
  );

  /// Suma por categoría, para reportes y gráficas (§30).
  Map<String, int> totalsByCategory(DateTime from, DateTime to) {
    final Map<String, int> out = <String, int>{};
    for (final Expense e in lazyInRange(from, to)) {
      out[e.category] = (out[e.category] ?? 0) + e.amount;
    }
    return out;
  }

  /// Categorías usadas + las sugeridas por defecto, sin duplicados.
  List<String> get availableCategories {
    final Set<String> set = AppConstants.defaultExpenseCategories.toSet();
    set.addAll(AppDatabase.expenses.values.map((Expense e) => e.category));
    final List<String> list = set.toList()..sort();
    return list;
  }

  /// El movimiento de caja de un gasto usa el mismo id, para poder borrarlo
  /// y regenerarlo sin duplicar.
  String _cashMovementId(String expenseId) => 'expense-$expenseId';

  Future<void> _resyncCashMovement(Expense expense) async {
    final String key = _cashMovementId(expense.id);
    await AppDatabase.cash.delete(key);
    if (expense.affectsCash) {
      await AppDatabase.cash.put(key, _buildCashMovement(key, expense));
    }
  }

  Future<void> _writeCashMovement(Expense expense) => AppDatabase.cash.put(
    _cashMovementId(expense.id),
    _buildCashMovement(_cashMovementId(expense.id), expense),
  );

  CashMovement _buildCashMovement(String id, Expense expense) => CashMovement(
    id: id,
    type: CashMovementType.gasto,
    amount: expense.amount,
    concept: expense.concept,
    referenceId: expense.id,
    date: expense.date,
  );
}
