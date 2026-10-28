import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/app_constants.dart';
import '../core/database/app_database.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/dates.dart';
import '../models/enums.dart';
import '../models/inventory_movement.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import 'cash_repository.dart';
import 'inventory_repository.dart';

/// Línea del carrito antes de cobrarse. A diferencia de [SaleItem], aquí el
/// producto aún puede cambiar de precio.
class CartLine {
  CartLine({
    required this.productId,
    required this.productName,
    required this.unitCost,
    required this.unitPrice,
    required this.quantity,
    this.unit = 'pieza',
    this.availableStock = 0,
  });

  final String productId;
  final String productName;

  /// Costo snapshot taken al agregar al carrito.
  int unitCost;
  int unitPrice;
  int quantity;
  String unit;
  double availableStock;

  int get lineTotal => unitPrice * quantity;
  int get lineCost => unitCost * quantity;
  int get lineProfit => lineTotal - lineCost;

  SaleItem toSaleItem() => SaleItem(
    productId: productId,
    productName: productName,
    cost: unitCost,
    price: unitPrice,
    quantity: quantity,
    unit: unit,
  );

  CartLine copyWith({
    int? unitPrice,
    int? unitCost,
    int? quantity,
    double? availableStock,
  }) => CartLine(
    productId: productId,
    productName: productName,
    unitCost: unitCost ?? this.unitCost,
    unitPrice: unitPrice ?? this.unitPrice,
    quantity: quantity ?? this.quantity,
    unit: unit,
    availableStock: availableStock ?? this.availableStock,
  );
}

/// Resultado de cobrar: la venta guardada más los movimientos de stock.
class SaleResult {
  const SaleResult({
    required this.sale,
    required this.folio,
    required this.movements,
  });

  final Sale sale;
  final String folio;
  final List<InventoryMovement> movements;

  int get total => sale.total;
  int get profit => sale.profit;
}

/// Ventas: carrito, cobro, folios, cancelaciones y devoluciones.
///
/// Reglas que este repositorio garantiza:
/// - El stock se descuenta sólo al cobrar, no al agregar al carrito.
/// - El folio es único y nunca se reutiliza, ni tras cancelar (§38).
/// - Una venta nunca se borra: se marca CANCELADA y se restaura el stock (§26).
class SalesRepository {
  SalesRepository(this._inventory);

  final InventoryRepository _inventory;
  static const Uuid _uuid = Uuid();

  // --- Lectura ---

  Stream<List<Sale>> watchAll() async* {
    // `box.watch()` no emite el estado actual; sin este yield inicial la
    // pantalla de ventas se queda cargando con la base vacía.
    yield all();
    yield* AppDatabase.sales.watch().map((BoxEvent _) => all());
  }

  Stream<List<Sale>> watchRange(DateTime from, DateTime to) async* {
    // Valor inicial antes de los cambios: ver `watchAll`.
    yield salesInRange(from, to);
    yield* AppDatabase.sales.watch().map((BoxEvent _) => salesInRange(from, to));
  }

  List<Sale> all() => AppDatabase.sales.values.toList(growable: false);

  Sale? byId(String id) => AppDatabase.sales.get(id);

  Sale? byFolio(String folio) {
    for (final Sale s in AppDatabase.sales.values) {
      if (s.folio == folio) return s;
    }
    return null;
  }

  /// Búsqueda en historial por folio o nombre de producto (§25).
  List<Sale> search(String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return recent();
    return AppDatabase.sales.values
        .where(
          (Sale s) =>
              s.folio.toLowerCase().contains(q) ||
              s.items.any(
                (SaleItem i) => i.productName.toLowerCase().contains(q),
              ) ||
              s.notes.toLowerCase().contains(q),
        )
        .toList()
      ..sort((Sale a, Sale b) => b.date.compareTo(a.date));
  }

  List<Sale> recent({int limit = 100}) {
    final List<Sale> list = AppDatabase.sales.values.toList()
      ..sort((Sale a, Sale b) => b.date.compareTo(a.date));
    return list.length > limit ? list.sublist(0, limit) : list;
  }

  /// Iteración perezosa dentro de un rango: no carga las 10,000 ventas (§49).
  Iterable<Sale> lazyInRange(DateTime from, DateTime to) =>
      AppDatabase.sales.values.where(
        (Sale s) => !s.date.isBefore(from) && !s.date.isAfter(to),
      );

  List<Sale> salesInRange(DateTime from, DateTime to) =>
      lazyInRange(from, to).toList()
        ..sort((Sale a, Sale b) => b.date.compareTo(a.date));

  List<Sale> salesOnDay(DateTime day) => salesInRange(
    Dates.startOfDay(day),
    Dates.endOfDay(day),
  );

  // --- Folios (§38) ---

  /// Siguiente folio consecutivo. Persistido en `meta` para que nunca se
  /// reutilice, incluso si la caja de ventas se vacía.
  int get nextFolio {
    final int stored =
        AppDatabase.meta.get(AppConstants.keyNextFolio, defaultValue: 1) as int;
    // Red de seguridad: si alguien importó ventas con folios más altos, nos
    // adelantamos para no generar duplicados.
    int candidate = stored;
    for (final Sale s in AppDatabase.sales.values) {
      final int? parsed = _parseFolioNumber(s.folio);
      if (parsed != null && parsed >= candidate) candidate = parsed + 1;
    }
    return candidate;
  }

  String formatFolio(int number) =>
      '$prefix-${number.toString().padLeft(AppConstants.saleFolioPadding, '0')}';

  /// Prefijo de folio tomado de preferencias, normalizado en mayúsculas (§38).
  String get prefix {
    final String raw = AppDatabase.settings.get(AppDatabase.settingsKey)?.salePrefix ?? '';
    final String clean = raw.trim().toUpperCase();
    return clean.isEmpty ? AppConstants.defaultSalePrefix : clean;
  }

  // --- Cobro ---

  /// Guarda la venta: valida stock, persiste, descuenta inventario y, si fue
  /// en efectivo, deja movimiento en caja.
  Future<SaleResult> checkout({
    required List<CartLine> lines,
    required PaymentMethod paymentMethod,
    int discount = 0,
    String notes = '',
    bool isQuickSale = false,
  }) async {
    if (lines.isEmpty) {
      throw const ValidationException('Agrega al menos un producto');
    }
    if (discount < 0) {
      throw const ValidationException('El descuento no puede ser negativo');
    }

    final int subtotal = lines.fold<int>(
      0,
      (int sum, CartLine l) => sum + l.lineTotal,
    );
    if (discount > subtotal) {
      throw const ValidationException(
        'El descuento no puede ser mayor al total',
      );
    }

    // Validar stock antes de escribir nada: si algo falla, no queda venta
    // a medias (§57 — todo debe funcionar de verdad).
    for (final CartLine line in lines) {
      if (line.quantity <= 0) {
        throw ValidationException(
          'Cantidad inválida para "${line.productName}"',
        );
      }
      if (line.availableStock < line.quantity) {
        throw ValidationException(
          'Stock insuficiente de "${line.productName}". '
          'Disponible: ${_trim(line.availableStock)}, '
          'pedido: ${line.quantity}',
        );
      }
    }

    final int total = subtotal - discount;
    final int costTotal = lines.fold<int>(
      0,
      (int sum, CartLine l) => sum + l.lineCost,
    );

    final int folioNumber = nextFolio;
    final String folio = formatFolio(folioNumber);

    final Sale sale = Sale(
      id: _uuid.v4(),
      folio: folio,
      items: lines.map((CartLine l) => l.toSaleItem()).toList(),
      subtotal: subtotal,
      discount: discount,
      total: total,
      costTotal: costTotal,
      profit: total - costTotal,
      paymentMethod: paymentMethod,
      isQuickSale: isQuickSale,
      notes: notes,
    );

    final List<InventoryMovement> movements = <InventoryMovement>[];

    try {
      await AppDatabase.sales.put(sale.id, sale);
      await AppDatabase.meta.put(AppConstants.keyNextFolio, folioNumber + 1);

      for (final CartLine line in lines) {
        final Product? product = AppDatabase.products.get(line.productId);
        if (product == null) continue;
        final InventoryMovement movement = await _inventory.applyMovement(
          product: product,
          type: MovementType.venta,
          amount: line.quantity.toDouble(),
          reason: 'Venta $folio',
          referenceId: sale.id,
        );
        movements.add(movement);
      }

      if (paymentMethod == PaymentMethod.efectivo && total > 0) {
        await CashRepository().recordSale(sale);
      }
    } catch (error) {
      // Si algo falla a medio escribir, deshacemos todo lo hecho: stock, venta,
      // efectivo y contador de folios. Queda como si la venta no hubiera
      // pasado (§57).
      await _rollback(sale, movements, folioNumber);
      rethrow;
    }

    return SaleResult(sale: sale, folio: folio, movements: movements);
  }

  /// Venta rápida: concepto libre, sin producto registrado (§16, §17).
  Future<SaleResult> quickSale({
    required String concept,
    required int price,
    int quantity = 1,
    int cost = 0,
    required PaymentMethod paymentMethod,
  }) async {
    if (concept.trim().isEmpty) {
      throw const ValidationException('El concepto es obligatorio');
    }
    if (price <= 0) {
      throw const ValidationException('El precio debe ser mayor a cero');
    }
    if (quantity <= 0) {
      throw const ValidationException('La cantidad debe ser mayor a cero');
    }
    if (cost < 0) {
      throw const ValidationException('El costo no puede ser negativo');
    }
    if (cost > price) {
      throw const ValidationException(
        'El costo no puede ser mayor al precio de venta',
      );
    }

    final int total = price * quantity;
    final int totalCost = cost * quantity;
    final int folioNumber = nextFolio;
    final String folio = formatFolio(folioNumber);

    final Sale sale = Sale(
      id: _uuid.v4(),
      folio: folio,
      items: <SaleItem>[
        SaleItem(
          productId: null,
          productName: concept.trim(),
          cost: cost,
          price: price,
          quantity: quantity,
        ),
      ],
      subtotal: total,
      discount: 0,
      total: total,
      costTotal: totalCost,
      profit: total - totalCost,
      paymentMethod: paymentMethod,
      isQuickSale: true,
    );

    try {
      await AppDatabase.sales.put(sale.id, sale);
      await AppDatabase.meta.put(AppConstants.keyNextFolio, folioNumber + 1);

      if (paymentMethod == PaymentMethod.efectivo && total > 0) {
        await CashRepository().recordSale(sale);
      }
    } catch (error) {
      await _rollback(sale, const <InventoryMovement>[], folioNumber);
      rethrow;
    }

    return SaleResult(sale: sale, folio: folio, movements: const <InventoryMovement>[]);
  }

  // --- Cancelación (§26) ---

  /// Marca la venta como CANCELADA, devuelve el stock y revierte la caja.
  /// La venta permanece visible en el historial y fuera de estadísticas.
  Future<Sale> cancelSale(String saleId, {String reason = ''}) async {
    final Sale? sale = AppDatabase.sales.get(saleId);
    if (sale == null) throw const StorageException('Venta no encontrada');
    if (sale.status != SaleStatus.activa) {
      throw const ConflictException('La venta ya está cancelada');
    }

    for (final SaleItem item in sale.items) {
      final String? productId = item.productId;
      if (productId == null) continue;
      final Product? product = AppDatabase.products.get(productId);
      if (product == null) continue;
      await _inventory.restoreStock(
        product: product,
        amount: item.quantity.toDouble(),
        type: MovementType.devolucion,
        reason: 'Cancelación ${sale.folio}'
            '${reason.isEmpty ? '' : ' — $reason'}',
        referenceId: sale.id,
      );
    }

    sale.status = SaleStatus.cancelada;
    sale.voidedAt = DateTime.now();
    if (reason.isNotEmpty) {
      sale.notes = sale.notes.isEmpty
          ? 'Cancelada: $reason'
          : '${sale.notes}\nCancelada: $reason';
    }
    await AppDatabase.sales.put(sale.id, sale);
    await CashRepository().reverseSale(sale);

    return sale;
  }

  /// Reabre una venta cancelada: vuelve a descontar stock (§26).
  Future<Sale> restoreSale(String saleId) async {
    final Sale? sale = AppDatabase.sales.get(saleId);
    if (sale == null) throw const StorageException('Venta no encontrada');
    if (sale.status != SaleStatus.cancelada) {
      throw const ConflictException('La venta no está cancelada');
    }

    for (final SaleItem item in sale.items) {
      final String? productId = item.productId;
      if (productId == null) continue;
      final Product? product = AppDatabase.products.get(productId);
      if (product == null) continue;
      await _inventory.applyMovement(
        product: product,
        type: MovementType.venta,
        amount: item.quantity.toDouble(),
        reason: 'Reapertura ${sale.folio}',
        referenceId: sale.id,
      );
    }

    sale.status = SaleStatus.activa;
    sale.voidedAt = null;
    await AppDatabase.sales.put(sale.id, sale);
    await CashRepository().reapplySale(sale);
    return sale;
  }

  // --- Devoluciones (§27) ---

  /// Devuelve productos de una venta: restaura stock y marca la venta como
  /// devuelta, excluyéndola de estadísticas.
  Future<Sale> returnSale(String saleId, {String reason = 'Devolución'}) async {
    final Sale? sale = AppDatabase.sales.get(saleId);
    if (sale == null) throw const StorageException('Venta no encontrada');
    if (sale.status != SaleStatus.activa) {
      throw const ConflictException(
        'Sólo se pueden devolver ventas activas',
      );
    }

    for (final SaleItem item in sale.items) {
      final String? productId = item.productId;
      if (productId == null) continue;
      final Product? product = AppDatabase.products.get(productId);
      if (product == null) continue;
      await _inventory.restoreStock(
        product: product,
        amount: item.quantity.toDouble(),
        type: MovementType.devolucion,
        reason: '$reason ${sale.folio}',
        referenceId: sale.id,
      );
    }

    sale.status = SaleStatus.devuelta;
    sale.returnedAt = DateTime.now();
    await AppDatabase.sales.put(sale.id, sale);
    await CashRepository().reverseSale(sale);
    return sale;
  }

  // --- Estadísticas ---

  Future<void> _rollback(
    Sale sale,
    List<InventoryMovement> movements,
    int folioNumber,
  ) async {
    // Best-effort y en orden inverso al de escritura. Cualquier fallo aquí se
    // ignora a propósito:onormalmente la causa raíz ya se está reportando al
    // usuario y, si un paso falla, los siguientes siguen intentándose para
    // dejar el menor estado roto posible.
    try {
      await CashRepository().reverseSale(sale);
    } catch (_) {
      // el efectivo esperado se recalcula de los movimientos, así que sin este
      // movimiento la caja queda igual que antes del cobro
    }
    for (final InventoryMovement m in movements) {
      try {
        final Product? product = AppDatabase.products.get(m.productId);
        if (product == null) continue;
        product.stock = m.previousStock;
        await AppDatabase.products.put(product.id, product);
      } catch (_) {
        // sigue con el siguiente producto
      }
    }
    try {
      await AppDatabase.sales.delete(sale.id);
    } catch (_) {
      // la venta queda en el historial; el usuario puede cancelarla
    }
    try {
      // El folio nunca se mostró al usuario, así que devolver el contador no
      // reutiliza ninguno emitido: evita huecos tras un fallo.
      await AppDatabase.meta.put(AppConstants.keyNextFolio, folioNumber);
    } catch (_) {
      // en el peor caso queda un hueco de folio, que es inofensivo
    }
  }

  static int? _parseFolioNumber(String folio) {
    final int dash = folio.lastIndexOf('-');
    if (dash < 0) return null;
    return int.tryParse(folio.substring(dash + 1));
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}
