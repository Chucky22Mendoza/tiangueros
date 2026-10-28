import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';
import '../core/errors/app_exception.dart';
import '../models/enums.dart';
import '../models/inventory_movement.dart';
import '../models/product.dart';

/// Moves de stock: entradas, ventas, devoluciones, ajustes y mermas (§22).
///
/// **Regla central:** el stock de un producto NUNCA se cambia directamente.
/// Toda mutación pasa por [applyMovement], que descuenta, valida y deja
/// rastro. Así el inventario siempre cuadra con su historial.
class InventoryRepository {
  InventoryRepository();

  static const Uuid _uuid = Uuid();

  Stream<List<InventoryMovement>> watchMovements({int limit = 200}) async* {
    // `box.watch()` no emite el estado actual; sin este yield inicial el
    // inventario se queda cargando con la base vacía.
    yield recentMovements(limit: limit);
    yield* AppDatabase.movements.watch().map(
      (BoxEvent _) => recentMovements(limit: limit),
    );
  }

  List<InventoryMovement> recentMovements({
    int limit = 200,
    String? productId,
  }) {
    final List<InventoryMovement> list = AppDatabase.movements.values
        .where(
          (InventoryMovement m) =>
              productId == null || m.productId == productId,
        )
        .toList()
      ..sort(
        (InventoryMovement a, InventoryMovement b) => b.date.compareTo(a.date),
      );
    return list.length > limit ? list.sublist(0, limit) : list;
  }

  /// Aplica un movimiento y actualiza el stock del producto.
  ///
  /// [amount] es la cantidad en positivo y [type] decide la dirección, salvo
  /// que se pase [delta] con signo, que manda sobre todo lo demás. El signo
  /// importa en los ajustes: "dejar el producto en 20" puede subir o bajar el
  /// stock, y un ajuste que siempre resta es incorrecto por construcción.
  Future<InventoryMovement> applyMovement({
    required Product product,
    required MovementType type,
    required double amount,
    double? delta,
    String reason = '',
    String? referenceId,
  }) async {
    if (amount <= 0 && delta == null) {
      throw const ValidationException('La cantidad debe ser mayor a cero');
    }

    final double previous = product.stock;
    final double effective = delta ?? (type.increasesStock ? amount : -amount);
    if (effective == 0) {
      throw const ValidationException('El movimiento no cambia el stock');
    }
    final double next = previous + effective;

    if (next < 0) {
      throw ValidationException(
        'Stock insuficiente de "${product.name}". '
        'Disponible: ${_trim(previous)} ${product.unit}',
      );
    }

    product.stock = next;
    product.updatedAt = DateTime.now();
    await AppDatabase.products.put(product.id, product);

    final InventoryMovement movement = InventoryMovement(
      id: _uuid.v4(),
      productId: product.id,
      productName: product.name,
      type: type,
      quantity: effective.abs(),
      previousStock: previous,
      newStock: next,
      reason: reason,
      referenceId: referenceId,
    );
    await AppDatabase.movements.put(movement.id, movement);
    return movement;
  }

  /// Devuelve stock sin condición de saldo: la devolución siempre restaura
  /// lo que se llevó la venta, aunque el stock haya cambiado desde entonces.
  Future<InventoryMovement> restoreStock({
    required Product product,
    required double amount,
    required MovementType type,
    required String reason,
    String? referenceId,
  }) async {
    final double previous = product.stock;
    product.stock = previous + amount;
    product.updatedAt = DateTime.now();
    await AppDatabase.products.put(product.id, product);

    final InventoryMovement movement = InventoryMovement(
      id: _uuid.v4(),
      productId: product.id,
      productName: product.name,
      type: type,
      quantity: amount,
      previousStock: previous,
      newStock: product.stock,
      reason: reason,
      referenceId: referenceId,
    );
    await AppDatabase.movements.put(movement.id, movement);
    return movement;
  }

  /// "Agregar mercancía" desde Inventario (§21).
  Future<InventoryMovement> addStock({
    required String productId,
    required double quantity,
    String reason = 'Entrada de mercancía',
  }) async {
    final Product? product = AppDatabase.products.get(productId);
    if (product == null) {
      throw const StorageException('Producto no encontrado');
    }
    return applyMovement(
      product: product,
      type: MovementType.entrada,
      amount: quantity,
      reason: reason,
    );
  }

  /// Ajuste manual a un valor absoluto (merma, conteo físico).
  Future<InventoryMovement> setStockTo({
    required String productId,
    required double newStock,
    String reason = 'Ajuste manual',
  }) async {
    final Product? product = AppDatabase.products.get(productId);
    if (product == null) {
      throw const StorageException('Producto no encontrado');
    }
    if (newStock < 0) {
      throw const ValidationException('El stock no puede ser negativo');
    }
    final double delta = newStock - product.stock;
    if (delta == 0) {
      throw const ValidationException('El stock ya tiene ese valor');
    }
    return applyMovement(
      product: product,
      type: MovementType.ajuste,
      amount: delta.abs(),
      delta: delta,
      reason: reason,
    );
  }

  /// Merma: producto dañado o perdido (§22).
  Future<InventoryMovement> reportWaste({
    required String productId,
    required double quantity,
    String reason = 'Merma',
  }) async {
    final Product? product = AppDatabase.products.get(productId);
    if (product == null) {
      throw const StorageException('Producto no encontrado');
    }
    return applyMovement(
      product: product,
      type: MovementType.merma,
      amount: quantity,
      reason: reason,
    );
  }

  Future<void> deleteMovements(Iterable<String> ids) =>
      AppDatabase.movements.deleteAll(ids);

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}
