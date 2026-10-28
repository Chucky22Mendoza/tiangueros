import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/dates.dart';
import '../models/category.dart';
import '../models/cash_movement.dart';
import '../models/daily_closing.dart';
import '../models/expense.dart';
import '../models/inventory_movement.dart';
import '../models/product.dart';
import '../repositories/reports_repository.dart' show DashboardSnapshot;
import '../models/sale.dart';
import 'repository_providers.dart';

/// Productos activos, ordenados por nombre. Se refresca con cada cambio en
/// Hive, así que el inventario y el carrito nunca muestran datos viejos.
final productsProvider = StreamProvider<List<Product>>(
  (Ref ref) => ref.watch(productRepositoryProvider).watchAll(),
);

/// Búsqueda de productos con consulta del usuario (§40).
final productSearchQueryProvider =
    NotifierProvider<ProductSearchQuery, String>(ProductSearchQuery.new);

class ProductSearchQuery extends Notifier<String> {
  @override
  String build() => '';
  void set(String value) => state = value;
  void clear() => state = '';
}

/// Categorías de producto.
final categoriesProvider = StreamProvider<List<Category>>(
  (Ref ref) => ref.watch(productRepositoryProvider).watchCategories(),
);

/// Historial de ventas (§25).
final salesProvider = StreamProvider<List<Sale>>(
  (Ref ref) => ref.watch(salesRepositoryProvider).watchAll(),
);

/// Ventas de hoy.
final todaySalesProvider = Provider<List<Sale>>((Ref ref) {
  final DateTime now = DateTime.now();
  return ref
      .watch(salesProvider)
      .maybeWhen(
        data: (List<Sale> all) => all
            .where((Sale s) => Dates.isSameDay(s.date, now))
            .toList(growable: false),
        orElse: () => const <Sale>[],
      );
});

/// Movimientos de inventario recientes (§22).
final movementsProvider = StreamProvider<List<InventoryMovement>>(
  (Ref ref) => ref.watch(inventoryRepositoryProvider).watchMovements(),
);

/// Movimientos de un producto concreto.
final productMovementsProvider = FutureProvider.family<
  List<InventoryMovement>,
  String
>((Ref ref, String productId) async {
  return ref.watch(inventoryRepositoryProvider).recentMovements(
    productId: productId,
    limit: 100,
  );
});

/// Gastos recientes (§23).
final expensesProvider = StreamProvider<List<Expense>>(
  (Ref ref) => ref.watch(expenseRepositoryProvider).watchAll(),
);

/// Categorías de gasto disponibles.
final expenseCategoriesProvider = Provider<List<String>>(
  (Ref ref) => ref.watch(expenseRepositoryProvider).availableCategories,
);

/// Movimientos de caja (§28).
final cashMovementsProvider = StreamProvider<List<CashMovement>>(
  (Ref ref) => ref.watch(cashRepositoryProvider).watchAll(),
);

/// Cuadre de caja de hoy.
final cashBreakdownProvider = Provider((Ref ref) {
  // Se declara como dependencia para invalidar cuando cambia la caja.
  ref.watch(cashMovementsProvider);
  return ref.watch(cashRepositoryProvider).breakdownForDay(DateTime.now());
});

/// Cierres guardados (§29). Se recalcula cuando cambian ventas o gastos.
final closingsProvider = Provider<List<DailyClosing>>((Ref ref) {
  ref.watch(salesProvider);
  ref.watch(expensesProvider);
  return ref.watch(reportsRepositoryProvider).closings();
});

/// Métricas del Dashboard (§12, §13).
///
/// Provider derivado, no un stream: recalcula sólo cuando cambia una de las
/// cajas que alimenta.
final dashboardProvider = Provider<DashboardSnapshot>((Ref ref) {
  ref.watch(salesProvider);
  ref.watch(expensesProvider);
  ref.watch(productsProvider);
  return ref.watch(reportsRepositoryProvider).todaySnapshot();
});
